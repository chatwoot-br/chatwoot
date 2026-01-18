# Issue: WhatsApp History Sync Creates Duplicate Contacts/Conversations

## Status: Fixed ✅

## Fix Applied (2026-01-16)

Both **history sync** and **real-time message flow** duplicate contacts issues have been fixed.

**Implementation:** See `docs/plans/2026-01-16-whatsapp-history-sync-duplicate-contacts-fix.md`

### History Sync Fix (Two-Phase Approach)
**Commits:**
- `fc8bccab89` - feat(whatsapp): add LID to phone mapping builder for history sync
- `fa3ccf276a` - feat(whatsapp): add contact map normalization with LID merging
- `c7d8c8870e` - feat(whatsapp): add bulk contact creation with cache for history sync
- `80f6746658` - feat(whatsapp): add contact resolution from history sync cache
- `b11b2b02f9` - feat(whatsapp): refactor history sync to two-phase approach

**How it works:**
1. **Phase 1 (Collection):** Extracts LID→phone mappings from `from_lid` fields, normalizes contacts by merging LID entries into phone entries
2. **Phase 2 (Processing):** Bulk-creates all contacts once, caches by both JID and LID, then processes messages using cache lookups

### Real-Time Message Flow Fix (LID→Phone Linking)
**Fix:** When phone message with `from_lid` arrives, store the LID on the contact. When LID message arrives later, look up existing phone contact by stored LID.

**New methods added:**
- `store_from_lid_on_contact` - Stores `from_lid` in contact's `additional_attributes`
- `phone_contact_with_lid_exists?` - Checks if a phone contact has this LID stored
- `set_contact_from_phone_with_lid` - Links LID message to existing phone contact

## Summary
Contact "Quezia" with phone number 556796707788 appears multiple times in the conversation list during WhatsApp history sync, creating duplicate conversations for the same contact.

## Observed Behavior
From the screenshot:
- "Quezia" appears 3 times as separate conversation entries (at 14m+18h, 14m+18h, 21h+18h)
- Phone number "556796707788" appears separately without the name "Quezia"
- Contact panel shows the phone number as display name with "Indisponivel" status
- Total of 4 entries for what should be a single contact

## Root Cause Analysis

### 1. Concurrent History Sync Jobs (Primary Cause)
The worker logs show **3 concurrent jobs** processing the same inbox's history sync simultaneously:
- `4a748f19-3da6-4712-be71-5db94b017c43`
- `4e7ee3da-825d-4006-8854-3ed2a7b706a5`
- `2f353d6a-7a63-4321-b921-b760f57ec41a`

**Evidence from logs:**
```
[2026-01-16T12:15:08.474539] [4a748f19...] build_params: chat_jid=554688221361@s.whatsapp.net
[2026-01-16T12:15:08.532587] [4e7ee3da...] build_params: chat_jid=5511981498491@s.whatsapp.net
[2026-01-16T12:15:09.196259] [2f353d6a...] build_params: chat_jid=554688221361@s.whatsapp.net
[2026-01-16T12:15:09.287347] [4a748f19...] build_params: chat_jid=554688221361@s.whatsapp.net
```

The same `chat_jid` is processed by multiple jobs within milliseconds, causing race conditions in:
- `ContactInboxWithContactBuilder` - multiple contacts created before uniqueness check
- Conversation creation - multiple conversations created for same contact

### 2. LID-to-Phone Linking Failure (Secondary Cause)
Per PLAN-0006-whatsapp-lid-support.md, contacts can be created in two phases:
1. **Phase 1**: LID-based message creates contact with `source_id=215946727821336@lid`, `phone_number=nil`
2. **Phase 2**: Phone-based message with `from_lid` should UPDATE existing contact, not create new

**Potential failure points:**
- `from_lid_matches_existing_contact?` returns false if LID contact doesn't exist yet (race condition)
- Multiple jobs create separate contacts before linking can occur
- `from_lid` field might not be present in all webhook payloads

### 3. Missing Concurrency Controls
The history sync implementation lacks:
- Job deduplication (multiple `history_sync_complete` webhooks can queue multiple jobs)
- Database-level locking for contact/conversation creation
- Idempotency checks at the job level

## Impact
- Duplicate conversations pollute the inbox
- Messages may go to wrong conversation
- Contact information is fragmented across multiple records
- Agent confusion about which conversation to use

## Technical Details

### Affected Files
- `app/services/whatsapp/incoming_message_whatsapp_web_service.rb` - `process_history_sync` method
- `app/builders/contact_inbox_with_contact_builder.rb` - contact creation
- `app/jobs/webhooks/whatsapp_web_events_job.rb` - job enqueuing

### Related Plans
- PLAN-0004-whatsapp-history-sync.md - History sync implementation
- PLAN-0006-whatsapp-lid-support.md - LID contact handling

## Proposed Solutions

### Option A: Add Job-Level Deduplication (Recommended)
```ruby
# In WhatsappWebEventsJob or IncomingMessageWhatsappWebService
def process_history_sync
  lock_key = "history_sync:#{inbox.id}"

  # Use Redis lock to ensure only one sync runs at a time
  return if already_syncing?(lock_key)

  with_sync_lock(lock_key) do
    # ... existing sync logic
  end
end
```

### Option B: Database-Level Uniqueness
Add unique index on `contact_inboxes` for `(inbox_id, source_id)` with proper error handling:
```ruby
def find_or_create_contact_inbox
  inbox.contact_inboxes.find_or_create_by(source_id: source_id) do |ci|
    # ... attributes
  end
rescue ActiveRecord::RecordNotUnique
  inbox.contact_inboxes.find_by!(source_id: source_id)
end
```

### Option C: Debounce at Webhook Level (go-whatsapp)
Extend the existing 5-second debounce in `history_sync.go` to also deduplicate by inbox/device:
```go
var pendingHistorySyncs = make(map[string]bool)

func scheduleHistorySyncWebhook(client, syncType) {
  deviceID := client.Store.ID.String()
  if pendingHistorySyncs[deviceID] {
    return // Already pending
  }
  pendingHistorySyncs[deviceID] = true
  // ... schedule with cleanup
}
```

### Option D: Cleanup Migration
For existing duplicates, run a migration to:
1. Find contacts with duplicate phone numbers in same inbox
2. Merge conversations to oldest contact
3. Delete duplicate contacts

## Reproduction Steps
1. Connect a WhatsApp device via QR code
2. Trigger history sync (either automatic or via reconnect)
3. Observe multiple concurrent jobs in Sidekiq logs
4. Check conversation list for duplicate entries

## Tests

All tests now pass (40 examples, 0 failures):

```bash
bundle exec rspec spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb
```

### History Sync Tests ✅
```bash
bundle exec rspec spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb \
  --example "two-phase history sync"
```

### Real-Time LID→Phone Linking Test ✅
```bash
bundle exec rspec spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb \
  --example "should link LID message to existing phone contact"
```

**Test:** `spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb:565`

**Test Scenario:**
1. Phone message arrives first with `from_lid` field → stores LID on contact
2. LID message arrives after → finds existing phone contact by stored LID
3. ✅ LID message links to existing phone contact (no duplicate created)

## Environment
- Chatwoot version: v4.9.1+3
- go-whatsapp-web-multidevice
- Ruby workers: Multiple concurrent Sidekiq processes

## Screenshots
See attached screenshot showing:
- Multiple "Quezia" entries in conversation list
- Separate "556796707788" entry without name
- Contact panel showing phone number only

## Priority
High - Affects data integrity and user experience

## Related Issues
- ISSUE-0001-whatsapp-web-file-handling.md
