# Tasks: Add WhatsApp Group Message Support

## 1. Backend Service Layer

- [ ] 1.1 Add `group_message?` method to detect group messages (`chat_id` ends with `@g.us`)
- [ ] 1.2 Add `group_id` method to extract group ID from webhook payload
- [ ] 1.3 Override `set_contact` to route group messages to group contact
- [ ] 1.4 Add `set_group_contact` method to create/find group contact by group ID
- [ ] 1.5 Add `fetch_group_name` method to get group name from go-whatsapp API
- [ ] 1.6 Store sender info in message `additional_attributes` for group messages

## 2. Provider Service

- [ ] 2.1 Add `fetch_group_info(group_id)` method to `WhatsappWebService`
- [ ] 2.2 Parse group info response and extract group name

## 3. Model Validation

- [ ] 3.1 Update `WHATSAPP_CHANNEL_REGEX` in `RegexHelper` to accept group IDs
- [ ] 3.2 New regex pattern: `^\d{1,15}(@g\.us)?$` (allows phone numbers and group IDs)

## 4. Validation

- [ ] 4.1 Test individual message routing (unchanged behavior)
- [ ] 4.2 Test group message creates group conversation
- [ ] 4.3 Test multiple senders in same group use same conversation
- [ ] 4.4 Test group name fetched from API
- [ ] 4.5 Test sender info stored in message additional_attributes
