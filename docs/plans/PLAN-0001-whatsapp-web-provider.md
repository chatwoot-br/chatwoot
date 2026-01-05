# Plan: Add WhatsApp Web Provider

## Overview
Add a `whatsapp_web` provider to Chatwoot's WhatsApp inbox that integrates with go-whatsapp-web-multidevice for QR code-based WhatsApp connection.

## Requirements
- **Full UI integration**: Device creation, QR code display, login status polling
- **Global env var**: `WHATSAPP_WEB_API_URL` for API base URL
- **No templates**: Session-only messaging (WhatsApp Web limitation)
- **Dedicated webhook**: Single global endpoint `/webhooks/whatsapp_web` for all devices
- **Phone as device_id**: Use phone number (without +) as `device_id`
- **Inbox deletion cleanup**: When inbox is deleted, logout and remove device from go-whatsapp
- **Deferred connection**: Inbox creation must NOT require WhatsApp connection; user can skip QR scan and connect later from inbox settings

---

## Files to Create

### 1. Provider Service
**`app/services/whatsapp/providers/whatsapp_web_service.rb`**
- Inherit from `BaseService`
- Implement: `send_message`, `send_template` (no-op), `sync_templates` (no-op), `validate_provider_config?`
- `validate_provider_config?` should only check that `WHATSAPP_WEB_API_URL` env var and `device_id` are present (NOT connection status)
- API calls to go-whatsapp-web-multidevice: `/send/message`, `/send/image`, `/send/file`, etc.
- Device management: `get_qr_code`, `get_device_status`, `reconnect_device`, `logout_device`
- Use `X-Device-Id` header with `device_id` from `provider_config`

### 2. Incoming Message Service
**`app/services/whatsapp/incoming_message_whatsapp_web_service.rb`**
- Inherit from `IncomingMessageBaseService`
- Transform go-whatsapp-web-multidevice webhook format to Chatwoot format
- Handle: `device_id`, `event`, `payload` structure
- Override `download_attachment_file` for media downloads

### 3. Dedicated Webhook Controller
**`app/controllers/webhooks/whatsapp_web_controller.rb`**
- Single global endpoint: `POST /webhooks/whatsapp_web`
- Extract `device_id` from payload (= phone number)
- Find channel by matching `device_id` in `provider_config`
- Queue `WhatsappWebEventsJob`

### 4. Dedicated Webhook Job
**`app/jobs/webhooks/whatsapp_web_events_job.rb`**
- Process whatsapp_web webhook events
- Find channel by `device_id` (phone number)
- Route to `IncomingMessageWhatsappWebService`

### 5. Device Management Service
**`app/services/whatsapp/whatsapp_web_device_service.rb`**
- `create_device(phone_number)` - POST `/devices` with phone as device_id
- `get_device_info(phone_number)` - GET `/devices/{phone}`
- `delete_device(phone_number)` - DELETE `/devices/{phone}`

### 6. Device Controller
**`app/controllers/api/v1/accounts/whatsapp_web/devices_controller.rb`**
- `POST /devices` - Create device using phone number as device_id
- `GET /:inbox_id/qr_code` - Return QR code image
- `GET /:inbox_id/status` - Return connection status
- `POST /:inbox_id/reconnect` - Trigger reconnection
- `POST /:inbox_id/logout` - Logout device

### 7. Frontend Component
**`app/javascript/dashboard/routes/dashboard/settings/inbox/channels/WhatsappWeb.vue`**
- 2-step flow: Enter Phone Number → Create Inbox (QR scan is optional)
- Show QR code after device creation with "Skip" button to proceed without connecting
- Poll status every 3 seconds during QR scan step (if user chooses to scan)
- Display connection status, handle refresh QR
- User can connect later from inbox settings page

### 8. API Client
**`app/javascript/dashboard/api/channel/whatsappWebChannel.js`**
- `createDevice(phoneNumber)`, `getQRCode(inboxId)`, `getDeviceStatus(inboxId)`, `reconnect(inboxId)`, `logout(inboxId)`

---

## Files to Modify

### 1. Channel Model
**`app/models/channel/whatsapp.rb`**
```ruby
# Line 28: Add provider
PROVIDERS = %w[default whatsapp_cloud whatsapp_web].freeze

# Line 42-47: Update provider_service
def provider_service
  case provider
  when 'whatsapp_cloud'
    Whatsapp::Providers::WhatsappCloudService.new(whatsapp_channel: self)
  when 'whatsapp_web'
    Whatsapp::Providers::WhatsappWebService.new(whatsapp_channel: self)
  else
    Whatsapp::Providers::Whatsapp360DialogService.new(whatsapp_channel: self)
  end
end

# Add helper
def whatsapp_web?
  provider == 'whatsapp_web'
end

# Line 35: Skip template sync for whatsapp_web
after_create :sync_templates, unless: :whatsapp_web?

# Cleanup device on destroy
before_destroy :cleanup_whatsapp_web_device, if: :whatsapp_web?

private

def cleanup_whatsapp_web_device
  return unless whatsapp_web? && provider_config['device_id'].present?

  provider_service.logout_device
rescue StandardError => e
  Rails.logger.error "WhatsApp Web: Failed to cleanup device on inbox deletion: #{e.message}"
end
```

### 2. Routes
**`config/routes.rb`**
```ruby
# Dedicated webhook endpoint (global, receives all whatsapp_web messages)
post 'webhooks/whatsapp_web', to: 'webhooks/whatsapp_web#process_payload'

# API routes (within accounts scope)
namespace :whatsapp_web do
  resources :devices, only: [:create] do
    member do
      get :qr_code
      get :status
      post :reconnect
      post :logout
    end
  end
end
```

### 3. Frontend Parent Component
**`app/javascript/dashboard/routes/dashboard/settings/inbox/channels/Whatsapp.vue`**
```javascript
// Add to PROVIDER_TYPES
WHATSAPP_WEB: 'whatsapp_web',

// Add to availableProviders (conditionally)
{
  key: PROVIDER_TYPES.WHATSAPP_WEB,
  title: t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WHATSAPP_WEB'),
  description: t('INBOX_MGMT.ADD.WHATSAPP.PROVIDERS.WHATSAPP_WEB_DESC'),
  icon: 'i-woot-whatsapp',
}

// Add component rendering
<WhatsappWeb v-else-if="selectedProvider === PROVIDER_TYPES.WHATSAPP_WEB" />
```

### 4. Translations
**`app/javascript/dashboard/i18n/locale/en/inboxMgmt.json`**
- Add `WHATSAPP_WEB` provider strings
- Add QR scan flow strings

### 5. Global Config
**`app/views/layouts/vueapp.html.erb`** (or config injection point)
- Expose `WHATSAPP_WEB_API_URL` to frontend

---

## Implementation Order

1. **Backend Model** - Add `whatsapp_web` to `PROVIDERS`, update `provider_service`
2. **Provider Service** - Create `WhatsappWebService` with all API calls
3. **Device Service** - Create `WhatsappWebDeviceService` (phone as device_id)
4. **Incoming Service** - Create `IncomingMessageWhatsappWebService`
5. **Webhook Controller** - Create dedicated `WhatsappWebController`
6. **Webhook Job** - Create dedicated `WhatsappWebEventsJob`
7. **Device Controller** - Create `WhatsappWeb::DevicesController`
8. **Routes** - Add webhook route + API routes
9. **Frontend API** - Create `whatsappWebChannel.js`
10. **Frontend Component** - Create `WhatsappWeb.vue`
11. **Parent Component** - Add provider option to `Whatsapp.vue`
12. **Translations** - Add i18n strings
13. **Config** - Expose env var to frontend
14. **Inbox Deletion Cleanup** - Add `before_destroy` callback to cleanup device from go-whatsapp

---

## go-whatsapp-web-multidevice API Reference

### Device Management
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/devices` | Create device |
| GET | `/devices/{id}/login` | Get QR code |
| GET | `/devices/{id}/status` | Connection status |
| POST | `/devices/{id}/reconnect` | Reconnect |
| POST | `/devices/{id}/logout` | Logout |

### Message Sending (requires `X-Device-Id` header)
| Method | Endpoint | Body |
|--------|----------|------|
| POST | `/send/message` | `{phone, message}` |
| POST | `/send/image` | `{phone, image, caption}` |
| POST | `/send/file` | `{phone, file}` |
| POST | `/send/video` | `{phone, video, caption}` |
| POST | `/send/audio` | `{phone, audio}` |

### Webhook Format
```json
{
  "event": "message",
  "device_id": "chatwoot_xxx",
  "payload": {
    "id": "msg_id",
    "from": "628xxx@s.whatsapp.net",
    "body": "Hello",
    "timestamp": "2024-12-28T10:00:00Z"
  }
}
```

---

## Environment Variables
```bash
WHATSAPP_WEB_API_URL=http://localhost:3000
WHATSAPP_WEB_WEBHOOK_SECRET=optional_secret
```

---

## provider_config Structure
```json
{
  "device_id": "5511999999999"  // Phone number without + (same as device_id in go-whatsapp-web-multidevice)
}
```

## Webhook Flow
```
go-whatsapp-web-multidevice
    │
    │ POST /webhooks/whatsapp_web
    │ Body: { event: "message", device_id: "5511999999999", payload: {...} }
    ▼
WhatsappWebController#process_payload
    │
    │ Find channel by: provider_config->>'device_id' = params[:device_id]
    ▼
WhatsappWebEventsJob
    │
    ▼
IncomingMessageWhatsappWebService
    │
    ▼
Create Message in Conversation
```
