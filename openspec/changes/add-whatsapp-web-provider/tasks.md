# Tasks: Add WhatsApp Web Provider

## 1. Backend Model Layer

- [x] 1.1 Add `whatsapp_web` to `PROVIDERS` constant in `Channel::Whatsapp`
- [x] 1.2 Update `provider_service` method to route to `WhatsappWebService`
- [x] 1.3 Add `whatsapp_web?` helper method
- [x] 1.4 Modify `after_create :sync_templates` to skip for whatsapp_web

## 2. Provider Service

- [x] 2.1 Create `Whatsapp::Providers::WhatsappWebService` inheriting from `BaseService`
- [x] 2.2 Implement `send_message` for text messages
- [x] 2.3 Implement `send_message` for attachment messages (image, video, audio, file)
- [x] 2.4 Implement `send_template` as no-op (return nil, mark message failed)
- [x] 2.5 Implement `sync_templates` as no-op
- [x] 2.6 Implement `validate_provider_config?` to check device status
- [x] 2.7 Implement device management methods (`get_qr_code`, `get_device_status`, `reconnect_device`, `logout_device`)

## 3. Device Management Service

- [x] 3.1 Create `Whatsapp::WhatsappWebDeviceService` for device lifecycle
- [x] 3.2 Implement `create_device(phone_number)` - creates device with phone as ID
- [x] 3.3 Implement `get_device_info(phone_number)`
- [x] 3.4 Implement `delete_device(phone_number)`

## 4. Webhook Infrastructure

- [x] 4.1 Create `Webhooks::WhatsappWebController` with `process_payload` action
- [x] 4.2 Implement channel lookup by `device_id` in `provider_config`
- [x] 4.3 Create `Webhooks::WhatsappWebEventsJob` for async processing
- [x] 4.4 Add route: `post 'webhooks/whatsapp_web'`

## 5. Incoming Message Service

- [x] 5.1 Create `Whatsapp::IncomingMessageWhatsappWebService` inheriting from `IncomingMessageBaseService`
- [x] 5.2 Implement `processed_params` to transform webhook payload
- [x] 5.3 Implement `download_attachment_file` for media messages
- [x] 5.4 Handle message status updates (delivered, read)

## 6. Device Management API

- [x] 6.1 Create `Api::V1::Accounts::WhatsappWeb::DevicesController`
- [x] 6.2 Implement `create` action - creates device in external server
- [x] 6.3 Implement `qr_code` action - returns QR code image
- [x] 6.4 Implement `status` action - returns connection status
- [x] 6.5 Implement `reconnect` action - triggers reconnection
- [x] 6.6 Implement `logout` action - logs out device
- [x] 6.7 Add routes within accounts scope

## 7. Frontend API Client

- [x] 7.1 Create `whatsappWebChannel.js` API client
- [x] 7.2 Implement `createDevice(phoneNumber)`
- [x] 7.3 Implement `getQRCode(inboxId)` with blob response
- [x] 7.4 Implement `getDeviceStatus(inboxId)`
- [x] 7.5 Implement `reconnect(inboxId)`
- [x] 7.6 Implement `logout(inboxId)`

## 8. Frontend Component

- [x] 8.1 Create `WhatsappWeb.vue` component
- [x] 8.2 Implement step 1: Phone number input form
- [x] 8.3 Implement step 2: QR code display with status polling
- [x] 8.4 Implement step 3: Success state and inbox creation
- [x] 8.5 Add QR code refresh functionality
- [x] 8.6 Handle error states and reconnection

## 9. Frontend Integration

- [x] 9.1 Add `WHATSAPP_WEB` to `PROVIDER_TYPES` in `Whatsapp.vue`
- [x] 9.2 Add provider to `availableProviders` (conditional on env var)
- [x] 9.3 Import and render `WhatsappWeb` component
- [x] 9.4 Add computed property for `hasWhatsappWebEnabled`

## 10. Configuration

- [x] 10.1 Expose `WHATSAPP_WEB_API_URL` to frontend via `window.chatwootConfig`
- [x] 10.2 Document env vars in `.env.example`

## 11. Translations

- [x] 11.1 Add provider strings to `inboxMgmt.json` (WHATSAPP_WEB, WHATSAPP_WEB_DESC)
- [x] 11.2 Add QR scan flow strings (TITLE, DESC, SCAN_QR_TITLE, etc.)
- [x] 11.3 Add error message strings

## 12. Validation

- [ ] 12.1 Test inbox creation flow end-to-end
- [ ] 12.2 Test message sending (text, attachments)
- [ ] 12.3 Test message receiving via webhook
- [ ] 12.4 Test reconnection flow
- [ ] 12.5 Test error handling (server unavailable, device disconnected)
