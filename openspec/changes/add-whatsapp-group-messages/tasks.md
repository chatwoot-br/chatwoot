# Tasks: Add WhatsApp Group Message Support

## 1. Backend Service Layer

- [x] 1.1 Add `group_message?` method to detect group messages (`chat_id` ends with `@g.us`)
- [x] 1.2 Add `group_id` method to extract group ID from webhook payload
- [x] 1.3 Override `set_contact` to route group messages to group contact
- [x] 1.4 Add `set_group_contact` method to create/find group contact by group ID
- [x] 1.5 Add `fetch_group_name` method to get group name from go-whatsapp API
- [x] 1.6 Store sender info in message `additional_attributes` for group messages

## 2. Provider Service

- [x] 2.1 Add `fetch_group_info(group_id)` method to `WhatsappWebService`
- [x] 2.2 Parse group info response and extract group name

## 3. Model Validation

- [x] 3.1 Update `WHATSAPP_CHANNEL_REGEX` in `RegexHelper` to accept group IDs
- [x] 3.2 New regex pattern: `^(\d{1,15}|\d+@g\.us)$` (allows phone numbers and group IDs with any length)

## 4. Frontend Changes

- [x] 4.1 Add `additionalAttributes` prop to Message.vue
- [x] 4.2 Detect group messages via `additionalAttributes.sender_name`
- [x] 4.3 Show avatar for incoming group messages (left side)
- [x] 4.4 Display "Sent by: {sender_name}" tooltip on avatar hover
- [x] 4.5 Adjust grid layout for left-side avatar

## 5. Validation

- [ ] 5.1 Test individual message routing (unchanged behavior)
- [ ] 5.2 Test group message creates group conversation
- [ ] 5.3 Test multiple senders in same group use same conversation
- [ ] 5.4 Test group name fetched from API
- [ ] 5.5 Test sender info stored in message additional_attributes
- [ ] 5.6 Test sender avatar and tooltip display in group conversations
