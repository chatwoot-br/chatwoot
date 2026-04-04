# Fix Duplicate Conversations Race Condition Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent duplicate conversations from being created when concurrent WhatsApp webhook jobs process messages for the same contact simultaneously.

**Architecture:** Add pessimistic locking on `contact_inbox` record within the existing transaction in `set_conversation` method. This ensures only one job can create a conversation for a given contact at a time.

**Tech Stack:** Ruby on Rails, ActiveRecord pessimistic locking (`with_lock`), RSpec for testing

---

## Task 1: Add Pessimistic Locking to set_conversation

**Files:**
- Modify: `app/services/whatsapp/incoming_message_base_service.rb:102-113`

**Step 1: Replace the `set_conversation` method**

Open `app/services/whatsapp/incoming_message_base_service.rb` and replace lines 102-113:

**Current code:**
```ruby
def set_conversation
  # if lock to single conversation is disabled, we will create a new conversation if previous conversation is resolved
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

**New code:**
```ruby
def set_conversation
  @contact_inbox.with_lock do
    @conversation = find_existing_conversation
    return if @conversation

    @conversation = ::Conversation.create!(conversation_params)
  end
end

def find_existing_conversation
  # if lock to single conversation is disabled, we will create a new conversation if previous conversation is resolved
  if @inbox.lock_to_single_conversation
    @contact_inbox.conversations.last
  else
    @contact_inbox.conversations.where.not(status: :resolved).last
  end
end
```

**Step 2: Run existing tests to verify no regression**

Run:
```bash
bundle exec rspec spec/services/whatsapp/incoming_message_service_spec.rb -v
```

Expected: All existing tests pass (the locking is transparent to existing behavior)

**Step 3: Commit**

```bash
git add app/services/whatsapp/incoming_message_base_service.rb
git commit -m "fix(whatsapp): add pessimistic locking to prevent duplicate conversations

Add with_lock on contact_inbox to serialize conversation creation.
Prevents race condition when concurrent jobs process same contact.

Fixes ISSUE-0003"
```

---

## Task 2: Add Concurrency Test

**Files:**
- Modify: `spec/services/whatsapp/incoming_message_service_spec.rb`

**Step 1: Add the concurrent conversation creation test**

Add after line 70 (after the existing conversation tests):

```ruby
it 'creates only one conversation when called concurrently for the same contact' do
  contact_inbox = create(:contact_inbox, inbox: whatsapp_channel.inbox, source_id: params[:messages].first[:from])

  # Simulate concurrent webhook processing
  threads = 2.times.map do
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        described_class.new(inbox: whatsapp_channel.inbox, params: params.deep_dup).perform
      end
    end
  end

  threads.each(&:join)

  # Should create only one conversation despite concurrent calls
  expect(contact_inbox.conversations.count).to eq(1)
end
```

**Step 2: Run the new test to verify it passes**

Run:
```bash
bundle exec rspec spec/services/whatsapp/incoming_message_service_spec.rb:72 -v
```

Expected: PASS - The locking prevents duplicate conversations

**Step 3: Run full test suite for the file**

Run:
```bash
bundle exec rspec spec/services/whatsapp/incoming_message_service_spec.rb -v
```

Expected: All tests pass

**Step 4: Commit**

```bash
git add spec/services/whatsapp/incoming_message_service_spec.rb
git commit -m "test(whatsapp): add concurrency test for conversation creation

Verifies that pessimistic locking prevents duplicate conversations
when concurrent webhook jobs process messages for same contact."
```

---

## Task 3: Update Issue Status

**Files:**
- Modify: `docs/issues/ISSUE-0003-whatsapp-duplicate-conversations-race-condition.md`

**Step 1: Update status to Fixed**

Change line 3 from:
```markdown
## Status: Open
```

To:
```markdown
## Status: Fixed
```

**Step 2: Add fix details after line 3**

Add:
```markdown

## Fix Applied (2026-01-21)

**Implementation:** Pessimistic locking on `contact_inbox` record in `set_conversation` method.

**Commits:**
- `<commit-hash>` - fix(whatsapp): add pessimistic locking to prevent duplicate conversations
- `<commit-hash>` - test(whatsapp): add concurrency test for conversation creation

**How it works:**
1. `with_lock` issues `SELECT ... FOR UPDATE` on `contact_inbox` row
2. Concurrent jobs wait until lock is released
3. Second job sees newly created conversation and reuses it
```

**Step 3: Commit**

```bash
git add docs/issues/ISSUE-0003-whatsapp-duplicate-conversations-race-condition.md
git commit -m "docs: mark ISSUE-0003 as fixed"
```

---

## Verification Checklist

After all tasks complete:

1. [ ] All existing tests pass: `bundle exec rspec spec/services/whatsapp/incoming_message_service_spec.rb`
2. [ ] New concurrency test passes
3. [ ] No duplicate conversations created in manual testing
4. [ ] Issue document updated with fix status

## Related Files Reference

- **Issue:** `docs/issues/ISSUE-0003-whatsapp-duplicate-conversations-race-condition.md`
- **Service:** `app/services/whatsapp/incoming_message_base_service.rb`
- **Spec:** `spec/services/whatsapp/incoming_message_service_spec.rb`
- **Transaction context:** Lines 35-39 in `incoming_message_base_service.rb`
