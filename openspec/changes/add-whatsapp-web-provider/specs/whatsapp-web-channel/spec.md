# WhatsApp Web Channel Capability

This capability enables WhatsApp messaging via QR code authentication using go-whatsapp-web-multidevice as the bridge server.

## ADDED Requirements

### Requirement: WhatsApp Web Provider Registration

The system SHALL support `whatsapp_web` as a valid provider option for WhatsApp inboxes.

#### Scenario: Provider is accepted during inbox creation
- **GIVEN** a user creates a WhatsApp inbox
- **WHEN** they select `whatsapp_web` as the provider
- **THEN** the inbox is created with `provider: 'whatsapp_web'`
- **AND** `provider_config` stores `device_id` (phone number without +)

#### Scenario: Provider service routing
- **GIVEN** a WhatsApp inbox with `provider: 'whatsapp_web'`
- **WHEN** `provider_service` is called
- **THEN** it returns an instance of `Whatsapp::Providers::WhatsappWebService`

### Requirement: QR Code Device Authentication

The system SHALL provide QR code-based authentication for connecting WhatsApp devices.

#### Scenario: Device creation with phone number as ID
- **GIVEN** an administrator creating a WhatsApp Web inbox
- **WHEN** they enter a phone number `+5511999999999`
- **THEN** a device is created with `device_id: '5511999999999'`
- **AND** the QR code is displayed for scanning

#### Scenario: QR code retrieval
- **GIVEN** a device has been created in go-whatsapp-web-multidevice
- **WHEN** the user requests the QR code
- **THEN** the system returns the QR code image from `/devices/{id}/login`

#### Scenario: Connection status polling
- **GIVEN** a user is scanning the QR code
- **WHEN** the frontend polls the status endpoint
- **THEN** it receives the current state (`disconnected`, `connecting`, `connected`, `logged_in`)
- **AND** transitions to success when state is `logged_in`

### Requirement: Message Sending via WhatsApp Web

The system SHALL send messages through go-whatsapp-web-multidevice API.

#### Scenario: Send text message
- **GIVEN** an agent replies to a conversation in a WhatsApp Web inbox
- **WHEN** the message is processed
- **THEN** the system calls `POST /send/message` with `X-Device-Id` header
- **AND** the message body contains `phone` and `message` fields

#### Scenario: Send image attachment
- **GIVEN** an agent sends an image in a WhatsApp Web conversation
- **WHEN** the message is processed
- **THEN** the system calls `POST /send/image` with the image URL
- **AND** includes optional caption from message content

#### Scenario: Send file attachment
- **GIVEN** an agent sends a document in a WhatsApp Web conversation
- **WHEN** the message is processed
- **THEN** the system calls `POST /send/file` with the file URL

#### Scenario: Unrestricted message sending
- **GIVEN** a WhatsApp Web inbox
- **WHEN** an agent sends a message to any contact
- **THEN** the message is sent without restrictions
- **AND** no 24h session window applies (unlike official Business API)

### Requirement: Dedicated Webhook Endpoint

The system SHALL provide a dedicated webhook endpoint for receiving WhatsApp Web messages.

#### Scenario: Webhook receives incoming message
- **GIVEN** go-whatsapp-web-multidevice sends a webhook
- **WHEN** `POST /webhooks/whatsapp_web` receives the payload
- **THEN** the system extracts `device_id` from the payload
- **AND** finds the corresponding WhatsApp channel
- **AND** queues `WhatsappWebEventsJob` for processing

#### Scenario: Channel lookup by device_id
- **GIVEN** a webhook payload with `device_id: '5511999999999'`
- **WHEN** the system looks up the channel
- **THEN** it finds the channel where `provider_config->>'device_id' = '5511999999999'`

#### Scenario: Message creation from webhook
- **GIVEN** `WhatsappWebEventsJob` processes an incoming message event
- **WHEN** `IncomingMessageWhatsappWebService` handles it
- **THEN** a new message is created in the conversation
- **AND** the contact is created or found by phone number

### Requirement: Device Lifecycle Management

The system SHALL support device reconnection and logout operations.

#### Scenario: Reconnect disconnected device
- **GIVEN** a WhatsApp Web device becomes disconnected
- **WHEN** an administrator triggers reconnection
- **THEN** the system calls `POST /devices/{id}/reconnect`
- **AND** the channel's reauthorization status is cleared on success

#### Scenario: Logout device
- **GIVEN** an administrator wants to disconnect a WhatsApp Web inbox
- **WHEN** they trigger logout
- **THEN** the system calls `POST /devices/{id}/logout`
- **AND** the channel is marked as requiring reauthorization

### Requirement: Configuration via Environment Variable

The system SHALL use a global environment variable for the WhatsApp Web API URL.

#### Scenario: API URL configuration
- **GIVEN** `WHATSAPP_WEB_API_URL` is set to `http://whatsapp-server:3000`
- **WHEN** any WhatsApp Web operation is performed
- **THEN** API calls are made to `http://whatsapp-server:3000`

#### Scenario: Provider availability in UI
- **GIVEN** `WHATSAPP_WEB_API_URL` is configured
- **WHEN** a user views WhatsApp provider options
- **THEN** "WhatsApp Web" appears as an available provider

#### Scenario: Provider hidden when not configured
- **GIVEN** `WHATSAPP_WEB_API_URL` is not set
- **WHEN** a user views WhatsApp provider options
- **THEN** "WhatsApp Web" does not appear as an option

### Requirement: No Template Synchronization

The system SHALL skip template synchronization for WhatsApp Web inboxes since templates are not needed (messages can be sent anytime without restrictions).

#### Scenario: Skip template sync on inbox creation
- **GIVEN** a WhatsApp Web inbox is created
- **WHEN** the `after_create` callbacks run
- **THEN** `sync_templates` is NOT called
- **AND** this is acceptable because messages can be sent anytime

#### Scenario: Template sync returns empty
- **GIVEN** a WhatsApp Web inbox
- **WHEN** `sync_templates` is explicitly called
- **THEN** no API call is made
- **AND** `message_templates` remains empty
- **AND** messaging functionality is unaffected
