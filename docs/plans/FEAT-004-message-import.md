# Plan: WhatsApp Message Import Feature (FEAT-004)

## Overview
Import historical WhatsApp messages from the WhatsApp Web API into Chatwoot conversations.

## Requirements (User Confirmed)
- **Trigger**: Automatically when WhatsApp number connects + manual via Rails console
- **Scope**: Import all historical messages (entire chat history)
- **Media**: Download and store as Chatwoot attachments

## Automatic Trigger Points

### Option 1: Frontend triggers after QR scan (Recommended)
- `QRCodeModal` already emits `connected` event
- `handleWhatsAppConnected` in `WhatsappWebForm.vue` can call `syncHistory`
- Existing endpoint: `POST /sync_history` → `Whatsapp::HistorySyncApiJob`

### Option 2: Backend triggers on first webhook
- In `IncomingMessageWhatsappWebService`, check if this is first message
- If inbox has no messages yet, trigger import job

## API Endpoints Used (from openapi.yaml)

### For Fetching Data:
- `GET /chats` - List all chats (with pagination: limit, offset)
- `GET /chat/{chat_jid}/messages` - Get messages from a chat
  - Supports: `limit`, `offset`, `start_time`, `end_time`, `media_only`, `is_from_me`, `search`
  - Returns: message id, content, timestamp, is_from_me, media_type, url, etc.

### Message Response Structure:
```yaml
ChatMessage:
  id: string              # WhatsApp message ID (use as source_id)
  chat_jid: string        # Chat identifier
  sender_jid: string      # Sender JID
  content: string         # Message text
  timestamp: datetime     # Original message time
  is_from_me: boolean     # Direction
  media_type: string      # image, video, audio, document, etc.
  filename: string        # For media
  url: string             # Media URL
  file_length: integer    # File size
```

## Architecture Approach

### Leverage Existing Code

The codebase already has:
- `Whatsapp::Providers::WhatsappWebService` - HTTP client with `api_headers`, `api_path`, `media_url`
- `Whatsapp::IncomingMessageWhatsappWebService` - Message processing patterns
- `ContactInboxWithContactBuilder` - Contact/conversation creation

**Key files to reference:**
- `app/services/whatsapp/providers/whatsapp_web_service.rb` - Extend with fetch methods
- `app/services/whatsapp/incoming_message_whatsapp_web_service.rb` - Reuse patterns

### 1. Extend WhatsappWebService

Add new methods to existing `Whatsapp::Providers::WhatsappWebService`:

```ruby
def fetch_chats(limit: 25, offset: 0)
  response = HTTParty.get(
    "#{api_path}/chats",
    headers: api_headers,
    query: { limit: limit, offset: offset }
  )
  response.parsed_response
end

def fetch_messages(chat_jid:, limit: 50, offset: 0)
  response = HTTParty.get(
    "#{api_path}/chat/#{chat_jid}/messages",
    headers: api_headers,
    query: { limit: limit, offset: offset }
  )
  response.parsed_response
end
```

### 2. New Import Service

Create `Whatsapp::MessageImportService`:
- Accept inbox parameter
- Use channel's `WhatsappWebService` for API calls
- Reuse patterns from `IncomingMessageWhatsappWebService`:
  - `ContactInboxWithContactBuilder` for contacts
  - `ConversationBuilder` for conversations
  - Similar message creation logic

### 3. Background Job

Create `Whatsapp::HistorySyncApiJob` (matches existing controller reference):
- Wraps `MessageImportService` for async execution
- Logs progress
- Prevents duplicate imports (track in `provider_config['history_synced']`)

### 4. Message Creation Pattern

Follow existing pattern from `Whatsapp::IncomingMessageBaseService`:

```ruby
# For each imported message:
@message = @conversation.messages.build(
  content: message[:content],
  account_id: @inbox.account_id,
  inbox_id: @inbox.id,
  message_type: message[:is_from_me] ? :outgoing : :incoming,
  sender: message[:is_from_me] ? nil : @contact,
  source_id: message[:id],  # WhatsApp message ID - prevents duplicates
  content_attributes: {
    external_created_at: message[:timestamp]
  }
)
```

### 5. Duplicate Prevention

Use existing mechanisms:
- `source_id` uniqueness check (indexed column)
- Skip if message with same `source_id` exists in inbox

### 6. Media Handling

Use existing `media_url` method and download pattern from `IncomingMessageWhatsappWebService`:

```ruby
def download_attachment_file(url)
  media_url = inbox.channel.media_url(url)
  Down.download(media_url, headers: inbox.channel.api_headers)
end
```

## Implementation Steps

### Step 1: Extend WhatsappWebService
Add `fetch_chats` and `fetch_messages` methods to existing service:
- File: `app/services/whatsapp/providers/whatsapp_web_service.rb`
- Add pagination support
- Handle API errors

### Step 2: Create Message Import Service
Create new service `Whatsapp::MessageImportService`:
- File: `app/services/whatsapp/message_import_service.rb`
- Iterate through all chats
- For each chat:
  - Find/create contact using `ContactInboxWithContactBuilder`
  - Find/create conversation
  - Paginate through all messages
  - Create messages (skip if source_id exists)
  - Download and attach media files

### Step 3: Create Background Job
Create job:
- File: `app/jobs/whatsapp/history_sync_api_job.rb`
- Accept inbox_id and options (manual: true/false)
- Call `MessageImportService`
- Track sync status in `provider_config['history_synced']`
- Log progress

### Step 4: Trigger on Connection
Modify frontend to auto-trigger sync:
- File: `app/javascript/dashboard/routes/dashboard/settings/inbox/channels/whatsapp/WhatsappWebForm.vue`
- In `handleWhatsAppConnected`, call `WhatsappWebGatewayApi.syncHistory(inbox.id)`

## Files to Modify/Create

**Modify:**
- `app/services/whatsapp/providers/whatsapp_web_service.rb` - Add `fetch_chats` and `fetch_messages` methods
- `app/javascript/dashboard/routes/dashboard/settings/inbox/channels/whatsapp/WhatsappWebForm.vue` - Call `syncHistory` on `handleWhatsAppConnected`

**Create:**
- `app/services/whatsapp/message_import_service.rb` - Import orchestration logic
- `app/jobs/whatsapp/history_sync_api_job.rb` - Background job (rename from `MessageImportJob` to match existing controller reference)

## Usage

### Automatic (on connect)
After QR code scan success, frontend calls `POST /sync_history` which triggers the job automatically.

### Manual (Rails Console)
```ruby
# Import all messages for an inbox
inbox = Inbox.find(123)
Whatsapp::HistorySyncApiJob.perform_later(inbox.id)

# Or run synchronously for debugging
Whatsapp::MessageImportService.new(inbox: inbox).perform
```

### Manual (UI)
Sync History button already exists in gateway controller - just needs the job to be implemented.

## Considerations

### Rate Limiting
- WhatsApp API may have rate limits
- Implement backoff/retry logic
- Batch requests appropriately

### Large Imports
- Use pagination (default 50 messages per request)
- Process in background job
- Consider chunking large date ranges

### Media Handling
- Download media from WhatsApp API URLs
- Use existing `attach_files` pattern
- Media URLs may expire - download promptly

### Message Ordering
- Import in chronological order (use start_time/end_time)
- Store `external_created_at` for display ordering

### Duplicate Safety
- Always use `source_id` from WhatsApp message ID
- Existing index ensures uniqueness
- Gracefully handle duplicates (skip, don't error)
