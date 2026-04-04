# Issue: WhatsApp Web Creates Duplicate Conversations Due to Race Condition

## Status: Fixed

## Fix Applied (2026-01-21)

**Implementation:** Pessimistic locking on `contact_inbox` record in `set_conversation` method.

**Commits:**
- `e6c449ab1e` - fix(whatsapp): add pessimistic locking to prevent duplicate conversations
- (test commit amended into above)

**How it works:**
1. `with_lock` issues `SELECT ... FOR UPDATE` on `contact_inbox` row
2. Concurrent jobs wait until lock is released
3. Second job sees newly created conversation and reuses it

## Summary

Multiple conversations are being created for the same contact when concurrent `WhatsappWebEventsJob` processes handle messages simultaneously. This results in duplicate conversation entries in the inbox list for contacts like "Vivian Barros", "Gabriel Paduch", and "'Mauro Amaral | Business Intelligence".

## Observed Behavior

From the screenshots and logs:
- Same contact appears multiple times in conversation list (e.g., "Vivian Barros" x2, "Gabriel Paduch" x2)
- Different conversation IDs for the same contact (e.g., conversation/4 and conversation/5 for "'Mauro Amaral | Business Intelligence")
- Messages are split across duplicate conversations

## Root Cause Analysis

### Primary Cause: Race Condition in Conversation Creation

The worker logs show **two concurrent jobs** processing messages for the same contact simultaneously:

**Evidence from `acme-chatwoot-worker.log`:**
```
23:45:54.645 [3bd2dbae-a72a-47a2-a1a3-eb0bbb1f276d] conversation.created, Conversation/214
23:45:54.661 [c9b99c79-fe23-4aa4-84fe-3edae91d9d4c] conversation.created, Conversation/215
```

Both conversations were created for the same `contact_inbox` (id: 156, source_id: "558199630554", contact: "Compras Rediesel") within **16 milliseconds**.

### Technical Details

The race condition occurs in `app/services/whatsapp/incoming_message_base_service.rb:102-113`:

```ruby
def set_conversation
  @conversation = if @inbox.lock_to_single_conversation
                    @contact_inbox.conversations.last
                  else
                    @contact_inbox.conversations
                                  .where.not(status: :resolved).last
                  end
  return if @conversation

  @conversation = ::Conversation.create!(conversation_params)
end
```

**Race condition sequence:**
1. Job A checks `@contact_inbox.conversations.last` → returns `nil`
2. Job B checks `@contact_inbox.conversations.last` → returns `nil` (before Job A commits)
3. Job A creates Conversation 214
4. Job B creates Conversation 215
5. Result: Two conversations for the same contact_inbox

### Why This Differs from ISSUE-0002

ISSUE-0002 addressed **contact** deduplication during history sync using a two-phase approach. This issue is about **conversation** creation race conditions during real-time message processing.

The history sync fix does not prevent this issue because:
- Multiple `history_sync_complete` webhooks can still trigger concurrent jobs
- Each job processes messages independently without conversation-level locking
- The `set_conversation` method lacks pessimistic locking

## Impact

- Duplicate conversations pollute the inbox
- Messages may go to wrong/different conversations
- Agent confusion about which conversation to use
- Potential data fragmentation

## Affected Files

- `app/services/whatsapp/incoming_message_base_service.rb` - `set_conversation` method
- `app/jobs/webhooks/whatsapp_web_events_job.rb` - Job enqueuing

## Proposed Solutions

### Option A: Pessimistic Locking on Conversation Creation (Recommended)

Add database locking to prevent concurrent conversation creation:

```ruby
def set_conversation
  @contact_inbox.with_lock do
    @conversation = find_existing_conversation
    return if @conversation

    @conversation = ::Conversation.create!(conversation_params)
  end
end

def find_existing_conversation
  if @inbox.lock_to_single_conversation
    @contact_inbox.conversations.last
  else
    @contact_inbox.conversations.where.not(status: :resolved).last
  end
end
```

### Option B: Job-Level Deduplication

Ensure only one job processes a given contact_inbox at a time:

```ruby
# In WhatsappWebEventsJob
def perform(params = {})
  lock_key = "whatsapp_web_events:#{params['device_id']}:#{extract_contact_id(params)}"

  Redis.current.with_lock(lock_key, timeout: 30.seconds) do
    # ... existing processing
  end
end
```

### Option C: Database Uniqueness Constraint

Add a partial unique index to prevent multiple open conversations per contact_inbox:

```ruby
# Migration
add_index :conversations, [:contact_inbox_id],
          unique: true,
          where: "status != 2", # 2 = resolved
          name: 'index_conversations_on_contact_inbox_id_open_unique'
```

Then handle `RecordNotUnique` exception:

```ruby
def set_conversation
  @conversation = find_existing_conversation
  return if @conversation

  @conversation = ::Conversation.create!(conversation_params)
rescue ActiveRecord::RecordNotUnique
  @conversation = find_existing_conversation
end
```

### Option D: Cleanup Migration for Existing Duplicates

For existing duplicate conversations:
1. Find conversations with duplicate contact_inbox_id where status != resolved
2. Merge messages to oldest conversation
3. Delete duplicate conversations

## Reproduction Steps

1. Connect a WhatsApp device via QR code
2. Trigger history sync (automatic on connect or via reconnect)
3. Send/receive multiple messages rapidly
4. Observe multiple concurrent jobs in Sidekiq logs
5. Check conversation list for duplicate entries

## Environment

- Chatwoot version: v4.10.1+1
- go-whatsapp-web-multidevice
- Ruby workers: Multiple concurrent Sidekiq processes
- Queue: `low` priority for `WhatsappWebEventsJob`

## Priority

High - Affects data integrity and user experience

## Related Issues

- ISSUE-0001-whatsapp-web-file-handling.md
- ISSUE-0002-whatsapp-history-sync-duplicate-contacts.md (related but different issue)

## Related Plans

- PLAN-0004-whatsapp-history-sync.md
- PLAN-0006-whatsapp-lid-support.md
