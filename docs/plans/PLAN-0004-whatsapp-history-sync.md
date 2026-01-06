# Plan: WhatsApp History Sync on Connection

## Status: Partial - Known Issues Pending

## Overview
Automatically sync WhatsApp message history to Chatwoot when a device connects. When go-whatsapp completes a history sync (after QR scan), it sends a webhook notification. Chatwoot then fetches chats and messages via existing APIs and processes them through the standard message flow.

---

## Architecture Flow

```
1. Device connects (QR scan)
         |
         v
2. go-whatsapp stores messages in SQLite (existing behavior)
         |
         v
3. go-whatsapp sends webhook: { event: "history_sync_complete" }
         |
         v
4. WhatsappWebEventsJob calls IncomingMessageWhatsappWebService (unchanged)
         |
         v
5. transform_webhook_payload handles 'history_sync_complete' event
         |
         v
6. Fetches chats via GET /chats, then messages via GET /chat/{jid}/messages
         |
         v
7. For each message: transform to webhook format -> process via existing logic
```

---

## go-whatsapp-web-multidevice Changes

### Webhook Notification
**File:** `src/infrastructure/whatsapp/history_sync.go`

Added at end of `handleHistorySync` function:
```go
// Send webhook notification after history sync completes
// Use context.Background() because this runs async and the event context will be canceled
if len(config.WhatsappWebhook) > 0 {
    go forwardHistorySyncCompleteToWebhook(context.Background(), client, evt.Data.GetSyncType().String())
}
```

**Important**: Must use `context.Background()` instead of the event's `ctx` because the goroutine runs asynchronously and the event context is canceled when the handler returns.

Added new function:
```go
// forwardHistorySyncCompleteToWebhook sends a webhook notification when history sync completes
func forwardHistorySyncCompleteToWebhook(ctx context.Context, client *whatsmeow.Client, syncType string) {
    deviceID := ""
    if client != nil && client.Store != nil && client.Store.ID != nil {
        deviceJID := NormalizeJIDFromLID(ctx, client.Store.ID.ToNonAD(), client)
        deviceID = deviceJID.ToNonAD().String()
    }

    payload := map[string]any{
        "event":     "history_sync_complete",
        "device_id": deviceID,
        "payload": map[string]any{
            "sync_type": syncType,
            "timestamp": time.Now().Format(time.RFC3339),
        },
    }

    if err := forwardPayloadToConfiguredWebhooks(ctx, payload, "history_sync_complete"); err != nil {
        log.Errorf("Failed to forward history_sync_complete webhook: %v", err)
    }
}
```

Webhook payload:
```json
{
  "event": "history_sync_complete",
  "device_id": "5521995539939@s.whatsapp.net",
  "payload": {
    "sync_type": "RECENT",
    "timestamp": "2026-01-05T22:16:16Z"
  }
}
```

---

## Chatwoot Changes

### 1. Provider Service Methods
**File:** `app/services/whatsapp/providers/whatsapp_web_service.rb`

Added methods for fetching chats, messages, and downloading media:
```ruby
# Fetch list of chats from go-whatsapp API for history sync
def fetch_chats(limit: 100, offset: 0)
  # Returns: { "data": [...], "pagination": {...} }
end

# Fetch messages from a specific chat for history sync
def fetch_chat_messages(chat_jid:, limit: 100, offset: 0)
  # Returns: { "data": [...], "pagination": {...}, "chat_info": {...} }
end

# Download and decrypt media for a history sync message
# WhatsApp CDN URLs require decryption with MediaKey
def download_message_media(message_id:, chat_jid:)
  # Calls GET /message/{id}/download?phone={phone}
  # Returns the accessible URL to the downloaded file
end
```

### 2. History Sync Event Handling
**File:** `app/services/whatsapp/incoming_message_whatsapp_web_service.rb`

Added case to `transform_webhook_payload`:
```ruby
when 'history_sync_complete'
  process_history_sync
  {} # Return empty - messages processed inline
```

Added history sync processing methods:
```ruby
# History sync configuration
HISTORY_CHAT_BATCH_SIZE = 100
HISTORY_MESSAGE_BATCH_SIZE = 100

# Process history sync complete event by fetching and importing messages
def process_history_sync
  Rails.logger.info "[WhatsApp History Sync] Starting for inbox #{inbox.id}"

  fetch_all_history_chats.each do |chat|
    sync_history_chat_messages(chat)
  end

  Rails.logger.info "[WhatsApp History Sync] Completed for inbox #{inbox.id}"
rescue StandardError => e
  Rails.logger.error "[WhatsApp History Sync] Failed: #{e.message}"
end

def fetch_all_history_chats
  # Fetches all chats with pagination
end

def sync_history_chat_messages(chat)
  # Fetches and processes messages for each chat
end

def process_single_history_message(message, chat)
  # Transforms message to webhook format and processes via existing flow
  # Skips if message already exists (duplicate prevention)
end

def build_history_message_params(message, chat)
  # Builds webhook-compatible params from history message
end
```

---

## Files Summary

| File | Action | Description |
|------|--------|-------------|
| `go-whatsapp/.../history_sync.go` | MODIFY | Add webhook after sync completes |
| `go-whatsapp/.../chat.go` | MODIFY | Add URL decoding for chat_jid path params |
| `chatwoot/.../whatsapp_web_service.rb` | MODIFY | Add fetch_chats, fetch_chat_messages, download_message_media |
| `chatwoot/.../incoming_message_whatsapp_web_service.rb` | MODIFY | Handle history_sync_complete event, timestamp fix |
| `chatwoot/.../message_finder.rb` | MODIFY | Use created_at-based pagination for history messages |

**No changes to:**
- `whatsapp_web_events_job.rb` - routes to service as usual
- No new files created

---

## API Response Structures

### GET /chats
```json
{
  "code": "SUCCESS",
  "results": {
    "data": [
      { "jid": "628xxx@s.whatsapp.net", "name": "John", ... }
    ],
    "pagination": { "limit": 100, "offset": 0, "total": 50 }
  }
}
```

### GET /chat/{jid}/messages
```json
{
  "code": "SUCCESS",
  "results": {
    "data": [
      {
        "id": "msg_id",
        "sender_jid": "628xxx@s.whatsapp.net",
        "content": "Hello",
        "timestamp": "2026-01-05T10:30:45Z",
        "is_from_me": false,
        "media_type": "image",
        "url": "https://mmg.whatsapp.net/...",
        "filename": "image.jpg"
      }
    ],
    "pagination": { "limit": 100, "offset": 0, "total": 150 }
  }
}
```

### GET /message/{id}/download
```json
{
  "code": "SUCCESS",
  "results": {
    "message_id": "msg_id",
    "media_type": "image",
    "filename": "image-xxx.jpg",
    "file_path": "statics/media/628xxx/2026-01-05/image-xxx.jpg",
    "file_size": 12345
  }
}
```

---

## Media Download Flow

WhatsApp CDN URLs (e.g., `https://mmg.whatsapp.net/...`) are encrypted and require:
1. The `MediaKey` for decryption
2. WhatsApp authentication

The history sync uses the `/message/{id}/download` endpoint which:
1. Retrieves message metadata from SQLite (including MediaKey)
2. Downloads encrypted media from WhatsApp CDN
3. Decrypts using MediaKey
4. Saves to local storage
5. Returns accessible URL

```
History Message with media_type
        |
        v
Call /message/{id}/download?phone={chat_jid}
        |
        v
go-whatsapp downloads & decrypts media
        |
        v
Returns: { file_path: "statics/media/..." }
        |
        v
Chatwoot uses: {WHATSAPP_WEB_API_URL}/{file_path}
```

---

## Benefits

- **Single responsibility**: All WhatsApp Web message handling in one service
- **Code reuse**: Each history message processed via same `perform` flow
- **No job changes**: `WhatsappWebEventsJob` stays unchanged
- **Minimal files**: Only 3 files modified (1 go-whatsapp, 2 Chatwoot)

---

## Error Handling

- **Per-chat errors**: Logged, continues with other chats
- **Per-message errors**: Logged, continues with other messages
- **Duplicate prevention**: Checks `source_id` before processing
- **API failures**: Logged, returns nil

## Performance

- Chat batch: 100 per request
- Message batch: 100 per request
- Processed synchronously in webhook job (`:low` queue)

---

## Bug Fixes During Implementation

### 1. Context Canceled Error
**Problem**: Webhook failed with "context canceled" error.

**Cause**: The goroutine used the event context (`ctx`) which gets canceled when the handler returns.

**Fix**: Changed to `context.Background()` in the goroutine call:
```go
go forwardHistorySyncCompleteToWebhook(context.Background(), client, evt.Data.GetSyncType().String())
```

### 2. URL Encoding Error
**Problem**: `/chat/{jid}/messages` calls failed with "chat not found" - JID had `%40` instead of `@`.

**Cause**: Fiber web framework doesn't auto-decode URL path parameters.

**Fix**: Added `url.PathUnescape()` in go-whatsapp `chat.go` handlers:
```go
chatJID, _ := url.PathUnescape(c.Params("chat_jid"))
```

### 3. Timestamp Issue
**Problem**: All synced messages displayed with current sync time instead of original timestamps.

**Cause**: `message_attributes` didn't set `created_at`, so Rails used current time.

**Fix**: Added timestamp extraction in `incoming_message_whatsapp_web_service.rb`:
```ruby
def message_attributes(message)
  base_attrs = {
    # ...
    created_at: message_created_at(message)
  }
  # ...
end

def message_created_at(message)
  timestamp = message[:timestamp]
  return Time.current if timestamp.blank?
  Time.zone.at(timestamp.to_i)
rescue ArgumentError
  Time.current
end
```

### 4. Message Pagination Issue
**Problem**: History-synced messages don't appear when scrolling up in conversation view.

**Cause**: `MessageFinder` used `where('id < ?', before_id)` to find older messages. But history-synced messages have **higher IDs** (inserted later) with **lower created_at** (original timestamps), so they were never found.

**Fix**: Changed `MessageFinder` to use `created_at`-based pagination instead of `id`-based:
```ruby
def messages_before(before_id)
  reference_message = @conversation.messages.find_by(id: before_id)
  return [] unless reference_message

  messages.reorder('created_at desc')
          .where('created_at < ? OR (created_at = ? AND id < ?)',
                 reference_message.created_at, reference_message.created_at, before_id)
          .limit(20)
          .reverse
end
```

**File:** `app/finders/message_finder.rb`

### 5. Conversation Timestamps Issue
**Problem**: Conversation `created_at` shows sync time instead of oldest message date, and `last_activity_at` reflects the last processed message (not chronologically newest).

**Cause**:
- `created_at` is set when conversation is first created (current time)
- `last_activity_at` is updated by each message's `after_create_commit` callback, so processing order determines the final value

**Fix**: Added `update_conversation_timestamps_for_chat` method that runs after all messages are synced:
```ruby
def update_conversation_timestamps_for_chat(chat_jid)
  # Find conversation for this chat
  contact_inbox = inbox.contact_inboxes.find_by(source_id: chat_jid)
  conversation = contact_inbox&.conversations&.last
  return unless conversation

  # Get actual message timestamp range
  message_timestamps = conversation.messages.pluck(:created_at)
  oldest_message_at = message_timestamps.min
  newest_message_at = message_timestamps.max

  # Update conversation timestamps
  updates = { last_activity_at: newest_message_at }
  updates[:created_at] = oldest_message_at if oldest_message_at < conversation.created_at
  conversation.update_columns(updates)
end
```

**File:** `app/services/whatsapp/incoming_message_whatsapp_web_service.rb`

---

## Known Issues (Pending Fix)

### 1. Duplicate Conversations
**Problem**: Same chat creates multiple conversations during history sync.

**Symptoms**:
- Multiple conversations for the same contact (e.g., "Sisbratel" x3, "Spring-Sea-377" x4)
- Most show "No Messages" - messages went to one conversation only

**Cause**: Each history message creates a new service instance via:
```ruby
self.class.new(inbox: inbox, params: transformed_params).perform
```

Each instance goes through `set_conversation` which can create new conversations when:
1. `lock_to_single_conversation` is false (default)
2. Existing conversations are resolved
3. Multiple contact_inboxes exist with different source_id formats

**Root Cause Analysis**:
- Existing contact_inboxes might have `source_id: "551151480620@s.whatsapp.net"` (full JID)
- History sync lookup uses `source_id: "551151480620"` (phone only)
- These don't match → new contact_inbox created → new conversation created

**Proposed Fix**:
1. Create ONE conversation per chat BEFORE processing messages
2. Find existing contact_inbox by multiple source_id formats (phone, full JID, phone_number)
3. Process all messages directly into the pre-created conversation
4. Skip broadcast lists (`@broadcast` JIDs)

### 2. Broadcast List Errors
**Problem**: Broadcast lists (`*@broadcast`) fail validation.

**Proposed Fix**: Skip broadcast lists in `sync_history_chat_messages`:
```ruby
return if chat_jid.end_with?('@broadcast')
```

### 3. Group Sender Names
**Problem**: Group message senders might show wrong names (group name instead of sender name).

**Cause**: History API may not provide individual sender names for group messages.

**Proposed Fix**: Use `message['sender_name']` if available, fallback to phone number.

---

## Next Steps

1. Implement `find_or_create_history_conversation` that:
   - Checks existing contact_inbox by multiple formats
   - Creates ONE conversation per chat upfront
   - Skips broadcast lists

2. Modify history sync to:
   - Create conversation first
   - Process messages directly (bypass `self.class.new().perform`)
   - Handle group vs individual contacts correctly

3. Test with clean database (delete corrupted conversations first)
