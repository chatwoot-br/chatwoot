# Plan: Ignore Group Messages Option for WhatsApp Web

## Status: Implemented

## Overview
Add a toggle setting to WhatsApp Web inboxes that, when enabled, causes the system to skip/ignore all incoming messages from WhatsApp groups (chat IDs ending with `@g.us`).

---

## Storage Approach

Uses `Channel::Whatsapp.provider_config['ignore_group_messages']` (existing JSONB field).

Access pattern:
```ruby
inbox.channel.provider_config['ignore_group_messages']
```

---

## Implementation

### 1. Backend: Skip Group Messages in Service
**File:** `app/services/whatsapp/incoming_message_whatsapp_web_service.rb`

Added helper method:
```ruby
def ignore_group_messages?
  inbox.channel.provider_config['ignore_group_messages'] == true
end
```

Added early return in `perform`:
```ruby
def perform
  processed_params
  return if ignore_group_messages? && group_message?

  if processed_params.try(:[], :reaction).present?
    # ...
```

Added skip during history sync in `sync_history_chat_messages`:
```ruby
def sync_history_chat_messages(chat)
  chat_jid = chat['jid']
  return if chat_jid.blank?
  return if ignore_group_messages? && group_chat?(chat_jid)
  # ...
```

### 2. Frontend: Inbox Creation Screen
**File:** `app/javascript/dashboard/routes/dashboard/settings/inbox/channels/WhatsappWeb.vue`

- Added `const ignoreGroupMessages = ref(false);`
- Added checkbox in the phone input form template
- Included in `createInbox()` payload inside `provider_config`:
```javascript
const whatsappChannel = await store.dispatch('inboxes/createChannel', {
  name: inboxName.value.trim(),
  channel: {
    type: 'whatsapp',
    phone_number: phoneNumber.value,
    provider: 'whatsapp_web',
    provider_config: {
      device_id: deviceId.value,
      ignore_group_messages: ignoreGroupMessages.value,
    },
  },
});
```

### 3. Frontend: Connection Tab
**File:** `app/javascript/dashboard/routes/dashboard/settings/inbox/components/WhatsAppWebConnection.vue`

- Added state: `const ignoreGroupMessages = ref(false);`
- Initialized from inbox on mount: `props.inbox.provider_config?.ignore_group_messages ?? false`
- Added watcher to sync with inbox prop
- Added `handleIgnoreGroupMessagesChange` method to save via Vuex
- Added UI section with checkbox toggle

### 4. Frontend: Translations
**File:** `app/javascript/dashboard/i18n/locale/en/inboxMgmt.json`

Added to `ADD.WHATSAPP_WEB` section:
```json
"IGNORE_GROUP_MESSAGES": "Ignore group messages",
"IGNORE_GROUP_MESSAGES_HELP": "When enabled, messages from WhatsApp groups will not be imported"
```

Added to `WHATSAPP_WEB_CONNECTION` section:
```json
"IGNORE_GROUP_MESSAGES": "Ignore group messages",
"IGNORE_GROUP_MESSAGES_HELP": "When enabled, messages from WhatsApp groups will not be imported"
```

---

## Files Summary

| File | Action | Description |
|------|--------|-------------|
| `incoming_message_whatsapp_web_service.rb` | MODIFY | Add `ignore_group_messages?` helper and early return checks |
| `WhatsappWeb.vue` | MODIFY | Add toggle to inbox creation screen |
| `WhatsAppWebConnection.vue` | MODIFY | Add toggle to connection settings tab |
| `inboxMgmt.json` | MODIFY | Add i18n translations |

---

## Testing Checklist

- [x] New inbox creation with option enabled → group messages ignored
- [x] New inbox creation with option disabled → group messages processed
- [x] Toggle on existing inbox → setting persists (via provider_config)
- [x] History sync respects the setting
- [x] Individual messages still work regardless of setting
