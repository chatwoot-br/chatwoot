# WhatsApp Web Channel - Group Message Support

This extends the WhatsApp Web Channel capability to support group messages.

## ADDED Requirements

### Requirement: Group Message Detection

The system SHALL detect WhatsApp group messages by the `chat_id` suffix.

#### Scenario: Identify group message
- **GIVEN** a webhook payload with `chat_id: "120363421050222105@g.us"`
- **WHEN** the system processes the message
- **THEN** it identifies this as a group message (suffix `@g.us`)
- **AND** routes to group contact handling

#### Scenario: Identify individual message
- **GIVEN** a webhook payload with `chat_id: "5521999999999@s.whatsapp.net"`
- **WHEN** the system processes the message
- **THEN** it identifies this as an individual message
- **AND** routes to individual contact handling (existing behavior)

### Requirement: Group Contact Creation

The system SHALL create dedicated contacts for WhatsApp groups using the group ID as identifier.

#### Scenario: Create new group contact
- **GIVEN** a group message from `chat_id: "120363421050222105@g.us"`
- **WHEN** no contact exists for this group
- **THEN** the system creates a contact with `source_id: "120363421050222105@g.us"`
- **AND** fetches group name from go-whatsapp API
- **AND** sets `additional_attributes.is_group: true`

#### Scenario: Reuse existing group contact
- **GIVEN** a group message from `chat_id: "120363421050222105@g.us"`
- **WHEN** a contact already exists with this source_id
- **THEN** the system uses the existing contact
- **AND** messages appear in the same conversation

### Requirement: Group Name Retrieval

The system SHALL fetch group names from go-whatsapp API for display.

#### Scenario: Fetch group name successfully
- **GIVEN** a new group contact is being created
- **WHEN** the system calls `GET /group/info?group_id=120363421050222105@g.us`
- **THEN** it extracts the group name from the response
- **AND** uses it as the contact name

#### Scenario: Fallback when group name unavailable
- **GIVEN** a new group contact is being created
- **WHEN** the group info API call fails or returns no name
- **THEN** the system uses "Group {id}" as a fallback name
- **AND** continues with contact creation

### Requirement: Group Message Sender Attribution

The system SHALL store the actual sender information for group messages.

#### Scenario: Store sender info in message
- **GIVEN** a group message from sender `5521998762522@s.whatsapp.net` named "Antonio"
- **WHEN** the message is created
- **THEN** `additional_attributes.sender_phone` is set to `5521998762522`
- **AND** `additional_attributes.sender_name` is set to "Antonio"

### Requirement: Group ID Validation

The system SHALL accept group IDs as valid source_id values for WhatsApp contacts.

#### Scenario: Valid group ID format
- **GIVEN** a contact_inbox creation with `source_id: "120363421050222105@g.us"`
- **WHEN** validation runs
- **THEN** the source_id is accepted as valid

#### Scenario: Valid phone number format (unchanged)
- **GIVEN** a contact_inbox creation with `source_id: "5521999999999"`
- **WHEN** validation runs
- **THEN** the source_id is accepted as valid (existing behavior preserved)
