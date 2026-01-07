# Change: Add WhatsApp Group Message Support

## Why

WhatsApp Web provider currently routes all messages by sender phone number, which works for individual chats but breaks for group messages. When a message arrives from a group (identified by `chat_id` ending with `@g.us`), it incorrectly appears in the sender's individual conversation instead of a dedicated group conversation. This prevents users from managing group conversations effectively.

## What Changes

- Detect group messages by checking if `chat_id` ends with `@g.us`
- Create "group contacts" using the group ID as the identifier (instead of sender phone)
- Fetch group name from go-whatsapp API (`GET /group/info`) for display
- Store actual sender info (phone, name) in message's `additional_attributes` for group messages
- Update `WHATSAPP_CHANNEL_REGEX` to accept group IDs format

## Impact

- **Affected specs**: whatsapp-web-channel (MODIFIED)
- **Affected code**:
  - `app/services/whatsapp/incoming_message_whatsapp_web_service.rb` - Group detection, contact routing
  - `app/services/whatsapp/providers/whatsapp_web_service.rb` - Add `fetch_group_info` method
  - `lib/regex_helper.rb` - Update `WHATSAPP_CHANNEL_REGEX` for group IDs
- **Frontend impact**: May need future work to display sender name for group messages
- **Data model**: Group contacts will have `additional_attributes.is_group = true`

## Risks

- Group name API calls add latency (mitigated: only called when creating new group contact)
- Sender display in group messages requires frontend updates (separate future work)
