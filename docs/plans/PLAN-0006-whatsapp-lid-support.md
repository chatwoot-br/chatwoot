# Plan: Handle WhatsApp LID-Based Chats

## Status: Implemented

## Overview
Add support for WhatsApp LID (Linked ID) addresses. WhatsApp is transitioning from phone-based to LID-based addressing for some contacts. LID-based chats should be handled similarly to groups (`@g.us`), with phone number updated when later discovered via `from_lid` matching.

## Problem
- Gowa sends `chat_id: "215946727821336@lid"` for LID-based chats when phone is not yet identified
- Currently, this LID is incorrectly stored as the phone number
- When sending, gowa tries to validate LID as phone number → "Phone X@s.whatsapp.net is not on whatsapp"
- Phone number becomes available LATER when a message arrives with `chat_id: "@s.whatsapp.net"` AND `from_lid` that matches the original LID

**Key Insight from gowa webhook docs** (`go-whatsapp-web-multidevice/docs/webhook-payload.md`):
- `from_lid` field contains the sender's LID (present in all messages when available)
- When `chat_id` is `@lid`: phone is NOT known yet, contact created with LID as source_id
- When `chat_id` is `@s.whatsapp.net` with `from_lid`: we can link back to existing LID contact via `from_lid` → `source_id` match

**Fix requires two parts:**
1. **Chatwoot** (this plan): Handle LID as valid source_id, link phone later via `from_lid`
2. **Gowa**: Recognize `@lid` suffix and send to LID-based chats directly

## Solution
1. Add `@lid` to WHATSAPP_CHANNEL_REGEX validation
2. **LID-only message** (`chat_id` ends with `@lid`): Create contact with LID as source_id, phone_number = nil
3. **Phone-based message with `from_lid`**: Check if `from_lid` matches existing `source_id`, update that contact's phone
4. Keep using source_id for sending (gowa handles LID→phone resolution)

---

## Files Modified

### 1. Regex Helper
**`lib/regex_helper.rb`** (line 19)

```ruby
# Accepts phone numbers (1-15 digits), WhatsApp group IDs (@g.us), and LID addresses (@lid)
# LID (Linked ID) is WhatsApp's new identifier format for contacts without known phone numbers
WHATSAPP_CHANNEL_REGEX = Regexp.new('^(\d{1,15}|\d+@g\.us|\d+@lid)\z')
```

### 2. Incoming Message Service
**`app/services/whatsapp/incoming_message_whatsapp_web_service.rb`**

Added LID detection and linking:

```ruby
# LID (Linked ID) detection methods
def lid_based_chat?
  webhook_params.dig(:payload, :chat_id).to_s.end_with?('@lid')
end

def lid_chat_id
  webhook_params.dig(:payload, :chat_id)
end

# Check if from_lid matches an existing LID-based contact
def from_lid_matches_existing_contact?
  from_lid = payload_from_lid
  return false if from_lid.blank?
  return false unless from_lid.end_with?('@lid')

  inbox.contact_inboxes.exists?(source_id: from_lid)
end

def payload_from_lid
  webhook_params.dig(:payload, :from_lid)
end
```

Updated `set_contact` to handle both scenarios:

```ruby
def set_contact
  if group_message?
    set_group_contact
  elsif lid_based_chat?
    # Scenario 1: chat_id is @lid (phone not known yet)
    set_lid_contact
  elsif from_lid_matches_existing_contact?
    # Scenario 2: chat_id is @s.whatsapp.net but from_lid matches existing LID contact
    set_contact_from_lid_match
  else
    super
    sync_contact_avatar if @contact
  end
end
```

Added contact management methods:

```ruby
# Scenario 1: Create contact with LID as source_id, no phone
def set_lid_contact
  lid_jid = lid_chat_id
  payload = webhook_params[:payload]
  contact_name = payload[:is_from_me] ? payload[:chat_name] : payload[:from_name]

  contact_inbox = ::ContactInboxWithContactBuilder.new(
    source_id: lid_jid,
    inbox: inbox,
    contact_attributes: {
      name: contact_name || lid_jid.split('@').first,
      phone_number: nil,
      additional_attributes: { is_lid_chat: true, lid: lid_jid }
    }
  ).perform

  @contact_inbox = contact_inbox
  @contact = contact_inbox.contact
end

# Scenario 2: Phone-based message with from_lid matching existing LID contact
def set_contact_from_lid_match
  from_lid = payload_from_lid
  contact_inbox = inbox.contact_inboxes.find_by(source_id: from_lid)

  @contact_inbox = contact_inbox
  @contact = contact_inbox.contact

  update_contact_with_discovered_phone
  sync_contact_avatar if @contact
end

def update_contact_with_discovered_phone
  payload = webhook_params[:payload]
  phone_jid = payload[:is_from_me] ? payload[:chat_id] : payload[:from]
  phone = extract_phone_number(phone_jid)

  return if phone.blank?
  return if @contact.phone_number.present?

  formatted_phone = "+#{phone}"
  @contact.update(phone_number: formatted_phone)
end
```

---

## Data Flow

### Phase 1: Initial LID Message (phone unknown)
```
Webhook: chat_id="215946727821336@lid", from_lid="215946727821336@lid"
    ↓
lid_based_chat? = true (chat_id ends with @lid)
    ↓
set_lid_contact():
  - lid_jid = "215946727821336@lid"
  - phone_number = nil (not known yet!)
    ↓
ContactInboxWithContactBuilder(
  source_id: "215946727821336@lid",
  contact_attributes: {
    name: "Unknown" or from_name,
    phone_number: nil,
    additional_attributes: { is_lid_chat: true, lid: "215946727821336@lid" }
  }
)
    ↓
Contact created with LID, no phone ✓
```

### Phase 2: Phone-Based Message with from_lid (phone discovered!)
```
Webhook: chat_id="556796707788@s.whatsapp.net", from="556796707788@s.whatsapp.net", from_lid="215946727821336@lid"
    ↓
lid_based_chat? = false (chat_id is @s.whatsapp.net)
from_lid_matches_existing_contact? = true (from_lid matches source_id!)
    ↓
set_contact_from_lid_match():
  - Find contact_inbox where source_id = "215946727821336@lid"
  - Update contact.phone_number = "+556796707788"
    ↓
Contact now has phone number ✓
Message goes to existing conversation ✓
```

### Phase 3: Outgoing Message to LID Contact
```
SendOnWhatsappService.send_session_message()
    ↓
contact_inbox.source_id = "215946727821336@lid"
    ↓
channel.send_message("215946727821336@lid", message)
    ↓
POST /send/message { phone: "215946727821336@lid", message: "..." }
    ↓
gowa resolves LID to phone and sends ✓
```

**Note:** Gowa needs to handle LID addresses. When it receives `phone: "215946727821336@lid"`, it should recognize the `@lid` suffix and send to the LID-based chat (not try to validate as phone number).

---

## Testing

1. **Regex validation**: Verify `215946727821336@lid` passes WHATSAPP_CHANNEL_REGEX
2. **LID-only message**: Create contact with LID source_id and nil phone
3. **Phone discovery**: When message arrives with matching from_lid, verify phone is updated
4. **Same conversation**: Verify messages go to same conversation after phone discovery
5. **Outgoing message**: Reply to LID contact via source_id
6. **History sync**: LID contacts created during sync work correctly

---

## Migration Note
Existing LID contacts with wrong phone numbers will need manual correction or a data migration. This fix prevents new LID contacts from being created incorrectly.

---

## Files Summary
| File | Change |
|------|--------|
| `lib/regex_helper.rb` | Add `\d+@lid` to regex |
| `app/services/whatsapp/incoming_message_whatsapp_web_service.rb` | Add LID detection, from_lid matching, phone discovery |

**No changes needed to `send_on_whatsapp_service.rb`** - it already passes `contact_inbox.source_id` which will be the LID. Gowa handles the LID→phone resolution.
