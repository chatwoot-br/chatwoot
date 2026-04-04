# WhatsApp History Sync - Validate JIDs & Improve Resilience

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix history sync failures by validating JIDs against WHATSAPP_CHANNEL_REGEX before processing, and make sync resilient to individual chat failures.

**Architecture:** Add `processable_chat_jid?` helper that uses existing `WHATSAPP_CHANNEL_REGEX` validation. Apply it in realtime and history sync flows. Wrap chat processing in error handlers to continue on failure.

**Tech Stack:** Ruby on Rails, RSpec

---

## Task 1: Add `processable_chat_jid?` Helper Method

**Files:**
- Modify: `app/services/whatsapp/incoming_message_whatsapp_web_service.rb`
- Test: `spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb`

**Step 1: Write the failing test**

Add to the spec file under a new describe block:

```ruby
describe '#processable_chat_jid?' do
  let(:service) { described_class.new(inbox: inbox, params: {}) }

  it 'returns true for valid @s.whatsapp.net JID' do
    expect(service.send(:processable_chat_jid?, '556281945389@s.whatsapp.net')).to be true
  end

  it 'returns true for valid @g.us group JID' do
    expect(service.send(:processable_chat_jid?, '120363419221703893@g.us')).to be true
  end

  it 'returns true for valid @lid JID' do
    expect(service.send(:processable_chat_jid?, '142897974350025@lid')).to be true
  end

  it 'returns false for status@broadcast' do
    expect(service.send(:processable_chat_jid?, 'status@broadcast')).to be false
  end

  it 'returns false for nil' do
    expect(service.send(:processable_chat_jid?, nil)).to be false
  end

  it 'returns false for blank string' do
    expect(service.send(:processable_chat_jid?, '')).to be false
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb -e "processable_chat_jid" -v`

Expected: FAIL with "undefined method `processable_chat_jid?'"

**Step 3: Write minimal implementation**

Add to `app/services/whatsapp/incoming_message_whatsapp_web_service.rb` in the private section, near `group_message?`:

```ruby
def processable_chat_jid?(jid)
  return false if jid.blank?

  source_id = extract_source_id_from_jid(jid)
  RegexHelper::WHATSAPP_CHANNEL_REGEX.match?(source_id)
end
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb -e "processable_chat_jid" -v`

Expected: PASS (6 examples, 0 failures)

**Step 5: Commit**

```bash
git add app/services/whatsapp/incoming_message_whatsapp_web_service.rb spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb
git commit -m "feat(whatsapp): add processable_chat_jid? helper for JID validation"
```

---

## Task 2: Skip Invalid JIDs in Realtime Message Processing

**Files:**
- Modify: `app/services/whatsapp/incoming_message_whatsapp_web_service.rb:42-66` (transform_webhook_payload)

**Step 1: Write the failing test**

Add test for realtime broadcast skipping:

```ruby
describe 'realtime message processing' do
  context 'when chat_id is status@broadcast' do
    let(:params) do
      {
        'event' => 'message',
        'payload' => {
          'id' => 'msg123',
          'chat_id' => 'status@broadcast',
          'from' => '556281157376@s.whatsapp.net',
          'body' => 'Hello'
        }
      }
    end

    it 'returns empty hash and does not process the message' do
      service = described_class.new(inbox: inbox, params: params)
      expect(service.send(:transform_webhook_payload)).to eq({})
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb -e "status@broadcast" -v`

Expected: FAIL (returns message data instead of empty hash)

**Step 3: Write minimal implementation**

In `transform_webhook_payload`, add early return after getting payload:

```ruby
def transform_webhook_payload
  return {} if webhook_params[:payload].blank?

  payload = webhook_params[:payload].with_indifferent_access
  event_type = webhook_params[:event]

  # Skip invalid JIDs (e.g., status@broadcast)
  return {} unless processable_chat_jid?(payload[:chat_id])

  # ... rest of method unchanged
```

**Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb -e "status@broadcast" -v`

Expected: PASS

**Step 5: Commit**

```bash
git add app/services/whatsapp/incoming_message_whatsapp_web_service.rb spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb
git commit -m "feat(whatsapp): skip invalid JIDs in realtime message processing"
```

---

## Task 3: Skip Invalid JIDs in History Sync Collection

**Files:**
- Modify: `app/services/whatsapp/incoming_message_whatsapp_web_service.rb:865-880` (collect_all_history_messages)

**Step 1: Locate and modify `collect_all_history_messages`**

Find the loop in `collect_all_history_messages` and replace:

```ruby
# Before:
next if chat_jid.blank?
next if ignore_group_messages? && group_chat?(chat_jid)

# After:
next unless processable_chat_jid?(chat_jid)
next if ignore_group_messages? && group_chat?(chat_jid)
```

**Step 2: Run existing history sync tests**

Run: `bundle exec rspec spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb -e "history" -v`

Expected: PASS (existing tests should still pass)

**Step 3: Commit**

```bash
git add app/services/whatsapp/incoming_message_whatsapp_web_service.rb
git commit -m "feat(whatsapp): skip invalid JIDs in history sync collection"
```

---

## Task 4: Skip Invalid JIDs in History Sync Main Processing Loop

**Files:**
- Modify: `app/services/whatsapp/incoming_message_whatsapp_web_service.rb:844-852` (process_history_sync main loop)

**Step 1: Locate and modify the main processing loop**

Find the loop in `process_history_sync` and replace:

```ruby
# Before:
chat_jid = chat['jid']
next if chat_jid.blank?
next if ignore_group_messages? && group_chat?(chat_jid)

# After:
chat_jid = chat['jid']
next unless processable_chat_jid?(chat_jid)
next if ignore_group_messages? && group_chat?(chat_jid)
```

**Step 2: Run history sync tests**

Run: `bundle exec rspec spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb -e "history" -v`

Expected: PASS

**Step 3: Commit**

```bash
git add app/services/whatsapp/incoming_message_whatsapp_web_service.rb
git commit -m "feat(whatsapp): skip invalid JIDs in history sync main loop"
```

---

## Task 5: Add Resilient Error Handling in Contact Creation

**Files:**
- Modify: `app/services/whatsapp/incoming_message_whatsapp_web_service.rb:1210-1225` (bulk_create_contacts_for_history_sync)

**Step 1: Add error handling to `bulk_create_contacts_for_history_sync`**

Modify the method to rescue errors per-contact:

```ruby
def bulk_create_contacts_for_history_sync(contact_map)
  cache = {}

  contact_map.each do |jid, data|
    contact_inbox = find_or_create_contact_for_history_sync(jid, data)
    next if contact_inbox.nil?

    cache[jid] = contact_inbox
    cache[data[:lid]] = contact_inbox if data[:lid].present?
  rescue StandardError => e
    Rails.logger.error "[WhatsApp History Sync] Failed to create contact for #{jid}: #{e.message}"
  end

  cache
end
```

**Step 2: Run history sync tests**

Run: `bundle exec rspec spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb -e "history" -v`

Expected: PASS

**Step 3: Commit**

```bash
git add app/services/whatsapp/incoming_message_whatsapp_web_service.rb
git commit -m "fix(whatsapp): add resilient error handling in history sync contact creation"
```

---

## Task 6: Add Resilient Error Handling in Chat Processing Loop

**Files:**
- Modify: `app/services/whatsapp/incoming_message_whatsapp_web_service.rb:844-852` (process_history_sync main loop)

**Step 1: Wrap chat processing in begin/rescue**

Modify the main loop to handle errors per-chat:

```ruby
@history_chats.each do |chat|
  chat_jid = chat['jid']
  next unless processable_chat_jid?(chat_jid)
  next if ignore_group_messages? && group_chat?(chat_jid)

  begin
    messages = @history_messages_by_chat[chat_jid] || []
    process_history_messages_with_cache(chat_jid, messages, contact_cache, lid_to_phone)
    update_conversation_timestamps_for_chat(chat_jid)
  rescue StandardError => e
    Rails.logger.error "[WhatsApp History Sync] Failed to process chat #{chat_jid}: #{e.message}"
  end
end
```

**Step 2: Run all WhatsApp Web service tests**

Run: `bundle exec rspec spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb -v`

Expected: PASS (all tests pass)

**Step 3: Commit**

```bash
git add app/services/whatsapp/incoming_message_whatsapp_web_service.rb
git commit -m "fix(whatsapp): add resilient error handling in history sync chat processing"
```

---

## Task 7: Final Verification

**Step 1: Run full test suite for WhatsApp services**

Run: `bundle exec rspec spec/services/whatsapp/ -v`

Expected: All tests pass

**Step 2: Run linter**

Run: `bundle exec rubocop app/services/whatsapp/incoming_message_whatsapp_web_service.rb --autocorrect`

Expected: No offenses or auto-corrected

**Step 3: Create final commit if any lint fixes**

```bash
git add app/services/whatsapp/incoming_message_whatsapp_web_service.rb
git commit -m "style: apply rubocop fixes"
```

---

## Verification Summary

| Test | Command | Expected |
|------|---------|----------|
| Unit tests | `bundle exec rspec spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb` | All pass |
| Lint | `bundle exec rubocop app/services/whatsapp/` | No offenses |
| Manual - Realtime | Send message from `status@broadcast` | Silently skipped |
| Manual - History sync | Trigger sync with `status@broadcast` | Skipped without errors |
