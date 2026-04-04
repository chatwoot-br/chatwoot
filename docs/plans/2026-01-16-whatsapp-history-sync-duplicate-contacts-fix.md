# WhatsApp History Sync Duplicate Contacts Fix

**Status:** Implemented (2026-01-17)

**Goal:** Fix duplicate contacts during WhatsApp history sync by implementing a two-phase approach that normalizes LID→phone mappings before creating contacts.

**Architecture:** Phase 1 collects all messages and builds a LID↔phone mapping from `from_lid` fields, then deduplicates contacts by resolved phone number. Phase 2 bulk-creates contacts once and processes messages using cached lookups combined with the existing message processing flow.

**Tech Stack:** Ruby on Rails, ActiveRecord, existing ContactInboxWithContactBuilder

---

## Implementation Summary

### Commits
- `fc8bccab89` - feat(whatsapp): add LID to phone mapping builder for history sync
- `fa3ccf276a` - feat(whatsapp): add contact map normalization with LID merging
- `c7d8c8870e` - feat(whatsapp): add bulk contact creation with cache for history sync
- `80f6746658` - feat(whatsapp): add contact resolution from history sync cache
- `b11b2b02f9` - feat(whatsapp): refactor history sync to two-phase approach
- `d578803e5f` - fix(whatsapp): align history sync with go-whatsapp API field names
- `59df1a4ba7` - fix(whatsapp): reuse existing message processing in history sync

### Key Learnings & Fixes Applied

**1. API Field Names (Fixed in d578803e5f)**
- go-whatsapp API uses `chat_jid` not `chat_id` for messages
- go-whatsapp API uses `jid` not `id` for chat identifiers
- Tests must use the same field names as the actual API

**2. Timestamp Format (Fixed in 59df1a4ba7)**
- API returns ISO 8601 strings: `"2026-01-15T20:50:20Z"`
- Must use `Time.zone.parse()` not `Time.zone.at(.to_i)`
- `"2026-01-15T20:50:20Z".to_i` = 2026 (just the year!) → caused Dec 31, 1969 dates

**3. Reuse Existing Code (Fixed in 59df1a4ba7)**
- Initial implementation duplicated message creation logic
- This caused missing: avatars, media handling, proper timestamps
- Solution: Reuse `build_history_message_params` + `self.class.new().perform`

**4. Regex Validation (Fixed in d578803e5f)**
- `WHATSAPP_CHANNEL_REGEX` needed `@broadcast` support
- `extract_phone_number_from_jid` must return nil for groups/broadcasts

---

## Architecture

### Phase 1: Collect and Normalize
```
fetch_all_history_chats()
    ↓
collect_all_history_messages(chats)
    ↓
build_lid_to_phone_mapping(all_messages)  → { "123@lid" => "5511999@s.whatsapp.net" }
    ↓
build_normalized_contact_map(chats, lid_to_phone)  → Deduplicated contact map
```

### Phase 2: Create and Process
```
bulk_create_contacts_for_history_sync(contact_map)  → Cache by JID and LID
    ↓
for each chat:
    messages = @history_messages_by_chat[chat_jid]
    process_history_messages_with_cache(messages, cache, lid_to_phone)
        ↓
        resolve_contact_from_history_cache(message, cache, lid_to_phone)
            ↓
        process_single_history_message_with_contact(chat_jid, message, contact_inbox)
            ↓
        build_history_message_params(message, chat)  ← Reuses existing logic
            ↓
        self.class.new(inbox:, params:).perform      ← Full webhook flow
```

---

## Key Methods

### `build_lid_to_phone_mapping(messages)`
Extracts LID→phone mappings from messages with `from_lid` field.

```ruby
# Input: messages with from_lid field
{ 'chat_jid' => '5511999@s.whatsapp.net', 'from_lid' => '123@lid' }

# Output: mapping
{ '123@lid' => '5511999@s.whatsapp.net' }
```

### `build_normalized_contact_map(chats_by_jid, lid_to_phone_mapping)`
Merges LID chat entries into their phone counterparts.

```ruby
# Before: 3 chats (phone + LID + other)
# After: 2 contacts (LID merged into phone)
```

### `bulk_create_contacts_for_history_sync(contact_map)`
Creates contacts once and caches by both JID and LID for O(1) lookups.

### `resolve_contact_from_history_cache(message, cache, lid_to_phone)`
Multi-strategy resolution:
1. Direct `chat_jid` lookup
2. `from_lid` lookup
3. LID→phone mapping lookup

### `process_single_history_message_with_contact(chat_jid, message, _contact_inbox)`
**Important:** Reuses existing `build_history_message_params` + `perform` flow.

```ruby
def process_single_history_message_with_contact(chat_jid, message, _contact_inbox)
  source_id = message['id']
  return if source_id.blank?
  return if inbox.messages.exists?(source_id: source_id)

  # Reuse existing logic for timestamps, avatars, media, sender resolution
  chat = @history_chats_by_jid[chat_jid]
  return if chat.nil?

  transformed_params = build_history_message_params(message, chat)
  self.class.new(inbox: inbox, params: transformed_params).perform
end
```

---

## go-whatsapp API Reference

### GET /chats
```json
{
  "data": [
    {
      "jid": "5511999@s.whatsapp.net",
      "name": "Contact Name",
      "last_message_time": "2026-01-15T20:49:35Z"
    }
  ],
  "pagination": { "limit": 50, "offset": 0, "total": 38 }
}
```

### GET /chat/{jid}/messages
```json
{
  "data": [
    {
      "id": "3EB0FFB4EFC481D7454A48",
      "chat_jid": "5511999@s.whatsapp.net",
      "sender_jid": "5521995539939@s.whatsapp.net",
      "content": "Hello",
      "timestamp": "2026-01-15T20:50:20Z",
      "is_from_me": true,
      "from_lid": "123456@lid"
    }
  ],
  "chat_info": { "jid": "...", "name": "..." }
}
```

**Key fields:**
- `jid` (chats) / `chat_jid` (messages) - NOT `id` / `chat_id`
- `timestamp` - ISO 8601 string, NOT Unix timestamp
- `from_lid` - Links phone message to LID identity

---

## Tests

All tests pass (40 examples):

```bash
bundle exec rspec spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb
```

Key test scenarios:
- `#build_lid_to_phone_mapping` - extracts mappings, handles edge cases
- `#build_normalized_contact_map` - merges LID into phone entries
- `#bulk_create_contacts_for_history_sync` - creates cache, handles duplicates
- `#resolve_contact_from_history_cache` - multi-strategy resolution
- `#process_history_sync two-phase approach` - integration tests

---

## Related Documentation

- Issue: `docs/issues/ISSUE-0002-whatsapp-history-sync-duplicate-contacts.md`
- LID Support: `docs/plans/PLAN-0006-whatsapp-lid-support.md`
- History Sync: `docs/plans/PLAN-0004-whatsapp-history-sync.md`
