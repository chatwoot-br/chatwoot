# Change: Add WhatsApp Web Provider

## Why

Chatwoot currently supports WhatsApp integration via official Business API providers (360dialog, WhatsApp Cloud). However, many businesses need a simpler, cost-free alternative that connects directly via WhatsApp Web using QR code authentication. This enables small businesses and self-hosted deployments to use WhatsApp without requiring a Meta Business Account or paying for API access.

The `go-whatsapp-web-multidevice` project provides a reliable REST API bridge to WhatsApp Web that supports multi-device connections, making it ideal for integration with Chatwoot.

## What Changes

- Add `whatsapp_web` as a new provider option for WhatsApp inboxes
- Create dedicated webhook endpoint (`/webhooks/whatsapp_web`) for receiving messages
- Implement QR code-based device authentication flow in the inbox creation wizard
- Use phone number (without +) as the `device_id` for simplicity
- Support text and media message sending/receiving
- **No template support** (WhatsApp Web limitation - session-only messaging within 24h window)

## Impact

- **Affected specs**: New capability (whatsapp-web-channel)
- **Affected code**:
  - `app/models/channel/whatsapp.rb` - Add provider constant
  - `app/services/whatsapp/providers/` - New provider service
  - `app/controllers/webhooks/` - New webhook controller
  - `app/jobs/webhooks/` - New webhook job
  - `app/controllers/api/v1/accounts/whatsapp_web/` - New device management API
  - `app/javascript/dashboard/routes/dashboard/settings/inbox/channels/` - New Vue component
  - `config/routes.rb` - New routes
- **Environment variables**: `WHATSAPP_WEB_API_URL` (required), `WHATSAPP_WEB_WEBHOOK_SECRET` (optional)
- **External dependency**: go-whatsapp-web-multidevice server instance

## Risks

- WhatsApp Web connections may be less stable than official Business API
- WhatsApp may block numbers that appear to be automated
- No official template support limits proactive outreach
- Requires self-hosting go-whatsapp-web-multidevice server
