# Design: WhatsApp Web Provider

## Context

Chatwoot's WhatsApp integration uses a provider pattern where `Channel::Whatsapp` delegates to provider-specific services. Current providers:
- `default` (360dialog) - Official Business API via 360dialog
- `whatsapp_cloud` - Official Meta Cloud API

This design adds `whatsapp_web` provider that bridges to go-whatsapp-web-multidevice, an open-source WhatsApp Web API server.

## Goals

- Integrate with go-whatsapp-web-multidevice REST API
- Follow existing WhatsApp provider patterns
- Provide QR code authentication flow in inbox wizard
- Keep implementation minimal and focused

## Non-Goals

- Template message support (not available via WhatsApp Web)
- Interactive messages (buttons/lists)
- Business profile management
- Multiple phone numbers per inbox

## Decisions

### 1. Phone Number as Device ID

**Decision**: Use the phone number (without +) as `device_id` in go-whatsapp-web-multidevice.

**Rationale**:
- Simple 1:1 mapping between Chatwoot inbox and WhatsApp device
- Easy to identify devices in external server
- No need to generate/store separate IDs

**Example**: Phone `+5511999999999` becomes device_id `5511999999999`

### 2. Dedicated Webhook Endpoint

**Decision**: Create dedicated `/webhooks/whatsapp_web` endpoint instead of reusing existing WhatsApp webhook.

**Rationale**:
- go-whatsapp-web-multidevice webhook format differs from official WhatsApp APIs
- Single global endpoint receives all messages (routes by `device_id` in payload)
- Cleaner separation of concerns, easier debugging
- No risk of breaking existing WhatsApp integrations

### 3. Global Environment Variable for API URL

**Decision**: Use single `WHATSAPP_WEB_API_URL` env var for all whatsapp_web inboxes.

**Rationale**:
- Simpler configuration (one server serves all accounts)
- Consistent with other Chatwoot integrations
- Per-inbox configuration can be added later if needed

### 4. No Template Support

**Decision**: Skip template functionality entirely for whatsapp_web provider.

**Rationale**:
- WhatsApp Web doesn't use the official template system
- Messages can be sent anytime without restrictions (no 24h window like Business API)
- Templates are unnecessary since proactive messaging is unrestricted
- Keeps implementation simple
- `sync_templates` returns no-op

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Chatwoot                                  │
├─────────────────────────────────────────────────────────────┤
│  Channel::Whatsapp (provider: 'whatsapp_web')               │
│       │                                                      │
│       ├── provider_config: { device_id: "5511999999999" }   │
│       │                                                      │
│       └── provider_service ──► WhatsappWebService           │
│                                    │                         │
│  ┌─────────────────────────────────┼─────────────────────┐  │
│  │ Outbound                        │                     │  │
│  │  SendOnWhatsappService ─────────┘                     │  │
│  │       │                                               │  │
│  │       └── POST /send/message (X-Device-Id header)     │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Inbound                                               │  │
│  │  POST /webhooks/whatsapp_web                          │  │
│  │       │                                               │  │
│  │       └── WhatsappWebController                       │  │
│  │               │                                       │  │
│  │               └── WhatsappWebEventsJob                │  │
│  │                       │                               │  │
│  │                       └── IncomingMessageWhatsappWeb  │  │
│  │                              Service                  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│            go-whatsapp-web-multidevice                       │
├─────────────────────────────────────────────────────────────┤
│  Device: 5511999999999                                       │
│       │                                                      │
│       ├── /devices/{id}/login  ──► QR Code                  │
│       ├── /devices/{id}/status ──► Connection State         │
│       ├── /send/message        ──► Send Text                │
│       └── Webhook POST         ──► Incoming Messages        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    WhatsApp                                  │
└─────────────────────────────────────────────────────────────┘
```

## Webhook Payload Transformation

**go-whatsapp-web-multidevice format**:
```json
{
  "event": "message",
  "device_id": "5511999999999",
  "payload": {
    "id": "3EB0A1B2C3D4E5F6",
    "from": "628123456789@s.whatsapp.net",
    "body": "Hello",
    "timestamp": "2024-12-28T10:00:00Z"
  }
}
```

**Transformed to Chatwoot format** (IncomingMessageWhatsappWebService):
```ruby
{
  contacts: [{ wa_id: "628123456789", profile: { name: nil } }],
  messages: [{
    id: "3EB0A1B2C3D4E5F6",
    from: "628123456789",
    type: "text",
    text: { body: "Hello" },
    timestamp: 1703760600
  }]
}
```

## Open Questions

None - all key decisions have been made.

## Migration Plan

No migration needed - this is a new feature. Existing WhatsApp inboxes are unaffected.
