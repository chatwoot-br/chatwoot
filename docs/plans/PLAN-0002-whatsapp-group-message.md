# Plan: Add WhatsApp Group Message Support

## Overview
Add support for WhatsApp group messages in the WhatsApp Web provider. Currently, group messages are incorrectly routed to individual contact conversations. They should create/use a separate "group contact" conversation.

## Problem
**Webhook payload for group message:**
```json
{
  "chat_id": "120363421050222105@g.us",  // Group ID (ends with @g.us)
  "from": "5521998762522@s.whatsapp.net", // Actual sender
  "from_name": "Antonio Milesi",
  "body": "xxx"
}
```

Currently, messages are routed by `from` (the sender), so group messages appear in the sender's individual conversation instead of a group conversation.

## Solution
- Detect group messages by checking if `chat_id` ends with `@g.us`
- For groups: create a "group contact" using `chat_id` as the identifier
- Fetch group name from go-whatsapp API (`GET /group/info?group_id=xxx`)
- Store actual sender info in message's `additional_attributes`

## Implementation

### 1. Add group detection in `IncomingMessageWhatsappWebService`

**File**: `app/services/whatsapp/incoming_message_whatsapp_web_service.rb`

Add method to detect group messages:
```ruby
def group_message?
  webhook_params.dig(:payload, :chat_id).to_s.end_with?('@g.us')
end

def group_id
  webhook_params.dig(:payload, :chat_id)
end
```

### 2. Override `set_contact` for groups

For group messages, create/find a contact using the group ID instead of sender phone:
```ruby
def set_contact
  if group_message?
    set_group_contact
  else
    super
    sync_contact_avatar if @contact
  end
end

def set_group_contact
  group_jid = group_id
  group_name = fetch_group_name(group_jid) || "Group #{group_jid.split('@').first}"

  contact_inbox = ::ContactInboxWithContactBuilder.new(
    source_id: group_jid,
    inbox: inbox,
    contact_attributes: {
      name: group_name,
      additional_attributes: { is_group: true }
    }
  ).perform

  @contact_inbox = contact_inbox
  @contact = contact_inbox.contact
end
```

### 3. Add method to fetch group name from go-whatsapp API

**File**: `app/services/whatsapp/providers/whatsapp_web_service.rb`

```ruby
def fetch_group_info(group_id)
  response = HTTParty.get(
    "#{api_base_path}/group/info",
    headers: api_headers,
    query: { group_id: group_id },
    timeout: HTTP_TIMEOUT
  )

  return nil unless response.success?

  parsed = response.parsed_response
  return nil unless parsed['code'] == 'SUCCESS'

  parsed['results']
rescue StandardError => e
  Rails.logger.error "[WhatsApp Web] Failed to fetch group info: #{e.message}"
  nil
end
```

### 4. Store sender info in message for group messages

Update `create_message` to store the actual sender for group messages:
```ruby
def create_message(message)
  @message = @conversation.messages.build(
    content: message_content(message),
    account_id: @inbox.account_id,
    inbox_id: @inbox.id,
    message_type: :incoming,
    sender: @contact,
    source_id: message[:id].to_s,
    in_reply_to_external_id: @in_reply_to_external_id,
    additional_attributes: group_message? ? group_sender_attributes : {}
  )
end

def group_sender_attributes
  payload = webhook_params[:payload]
  {
    sender_phone: extract_phone_number(payload[:from]),
    sender_name: payload[:from_name]
  }
end
```

### 5. Update ContactInbox validation to accept group IDs

**File**: `app/models/contact_inbox.rb`

Update the regex to accept `@g.us` suffix for groups:
```ruby
WHATSAPP_CHANNEL_REGEX = /^\+?\d{1,15}(@(s\.whatsapp\.net|g\.us))?$/
```

## Files to Modify

| File | Changes |
|------|---------|
| `app/services/whatsapp/incoming_message_whatsapp_web_service.rb` | Add group detection, override `set_contact`, store sender info |
| `app/services/whatsapp/providers/whatsapp_web_service.rb` | Add `fetch_group_info` method |
| `app/models/contact_inbox.rb` | Update regex to accept group IDs |

## Data Flow

**Before (broken):**
```
Group message → uses sender phone → creates message in sender's conversation ❌
```

**After (fixed):**
```
Group message → detects @g.us → creates group contact → creates message in group conversation ✓
Individual message → uses sender phone → creates message in sender's conversation ✓
```

## Notes
- Group contacts will have `additional_attributes.is_group = true`
- Actual sender info stored in message's `additional_attributes` for display
- Group name fetched once when contact is created
- Individual messages continue to work unchanged
- Frontend may need updates to display sender name for group messages (future work)

## Testing
1. Send individual message → appears in sender's conversation
2. Send group message → creates new group conversation with group name
3. Another participant sends to same group → message appears in same group conversation
4. Group name displays correctly (fetched from WhatsApp API)
