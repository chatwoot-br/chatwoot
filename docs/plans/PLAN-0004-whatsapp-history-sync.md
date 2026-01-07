# Plan: WhatsApp History Sync on Connection

## Status: Implemented

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

### 6. Missing Contact Names
**Problem**: Contacts imported without names because PUSH_NAME sync comes after RECENT messages.

**Cause**: WhatsApp sends multiple sync events in sequence (RECENT, PUSH_NAME, etc.). Webhook was firing after EACH event, so RECENT messages were imported before PUSH_NAME (containing names) arrived.

**Fix**: Added debounce mechanism in go-whatsapp to wait 5 seconds after the last sync event:
```go
var (
    historySyncDebounceTimer *time.Timer
    historySyncDebounceMu    sync.Mutex
    historySyncDebounceDelay = 5 * time.Second
)

func scheduleHistorySyncWebhook(client *whatsmeow.Client, syncType string) {
    historySyncDebounceMu.Lock()
    defer historySyncDebounceMu.Unlock()

    if historySyncDebounceTimer != nil {
        historySyncDebounceTimer.Stop()
    }

    historySyncDebounceTimer = time.AfterFunc(historySyncDebounceDelay, func() {
        forwardHistorySyncCompleteToWebhook(context.Background(), client, syncType)
    })
}
```

**File:** `src/infrastructure/whatsapp/history_sync.go`

### 7. Chat Info Enrichment
**Problem**: Chat data from `/chats` API might lack complete name/jid info.

**Fix**: Merge `chat_info` from messages API response into chat data:
```ruby
def sync_history_chat_messages(chat)
  enriched_chat = chat.dup
  # ...
  response = inbox.channel.provider_service.fetch_chat_messages(...)
  chat_info = response['chat_info']
  enriched_chat = enriched_chat.merge(chat_info) if chat_info.present?
  process_history_messages(batch, enriched_chat)
end
```

**File:** `app/services/whatsapp/incoming_message_whatsapp_web_service.rb`

### 8. Group Sender Names Showing Wrong Names
**Problem**: Group message senders were showing group name instead of sender name.

**Cause**: `build_history_message_params` used `chat['name']` for all chats, including groups where `chat['name']` is the group name.

**Fix (2 parts)**:

**go-whatsapp** - Added `SenderName` field to `MessageInfo`:
```go
// chat.go domain
type MessageInfo struct {
    SenderName string `json:"sender_name"`
    // ... other fields
}

// chat.go usecase - populate sender_name
senderName := ""
if message.Sender != "" && !message.IsFromMe {
    senderChat, _ := service.chatStorageRepo.GetChat(message.Sender)
    if senderChat != nil && senderChat.Name != "" {
        senderName = senderChat.Name
    } else {
        senderName = whatsapp.GetPushNameFromCache(extractUserFromJID(message.Sender))
    }
}
```

**Chatwoot** - Use `sender_name` for groups:
```ruby
def build_history_message_params(message, chat)
  sender_name = if group_chat?(chat_jid)
                  lookup_sender_name_for_group(message, sender_jid)
                else
                  chat['name']
                end
  # ...
end

def lookup_sender_name_for_group(message, sender_jid)
  name = message['sender_name']
  return name if name.present?
  # Fallback to chat lookup for sender's individual chat
  sender_chat = @history_chats_by_jid[sender_jid]
  sender_chat&.dig('name')
end
```

### 9. Placeholder Names for Outgoing Messages
**Problem**: Contacts created from outgoing messages (`is_from_me=true`) got placeholder names like "Quiet-Pine-759" instead of the actual contact name (e.g., "Vivian Barros").

**Cause**: In `build_contact`, for outgoing messages:
```ruby
profile_name = payload[:is_from_me] ? nil : payload[:from_name]
```
When the first message for a contact is outgoing, `profile_name` was `nil`, causing placeholder name generation.

**Fix (2 parts)**:

**build_contact** - Use `contact_name` for outgoing messages:
```ruby
profile_name = if payload[:is_from_me]
                 payload[:contact_name] # Set by history sync
               else
                 payload[:from_name]
               end
```

**build_history_message_params** - Add `contact_name` to payload:
```ruby
payload = {
  # ... other fields
  from_name: sender_name,
  contact_name: chat['name'], # Used for outgoing messages to get recipient name
  # ...
}
```

### 10. Chat Info Name Overwriting
**Problem**: When merging `chat_info` from messages API, blank names could overwrite valid names.

**Fix**: Added `merge_chat_info_preserving_name`:
```ruby
def merge_chat_info_preserving_name(enriched_chat, chat_info)
  return enriched_chat if chat_info.blank?
  original_name = enriched_chat['name']
  merged = enriched_chat.merge(chat_info)
  if merged['name'].blank? && original_name.present?
    merged['name'] = original_name
  end
  merged
end
```

### 11. Real-Time Outgoing Messages Missing Contact Names
**Problem**: Real-time outgoing messages (sent from WhatsApp device, not history sync) created contacts with placeholder names like "Delicate-Feather-260".

**Cause**: The webhook for real-time messages didn't include `chat_name`. The fix in #9 only worked for history sync (which has `contact_name`). For real-time messages:
1. `chatStorageRepo.GetChat()` failed because the chat wasn't in storage yet (only populated during history sync)
2. No fallback existed for contacts not in history sync

**Fix (go-whatsapp)**: Added fallback to WhatsApp's contact store in `buildEventPayload`:
```go
// For outgoing messages, look up chat name for contact creation
// Try multiple sources: chat storage (history sync) → contact store (WhatsApp contacts)
if evt.Info.IsFromMe {
    chatJID := evt.Info.Chat
    var chatName string

    // First try: chat storage (populated during history sync)
    if chatStorageRepo != nil {
        if chat, err := chatStorageRepo.GetChat(chatJIDStr); err == nil && chat != nil && chat.Name != "" {
            chatName = chat.Name
        }
    }

    // Second try: WhatsApp contact store (for contacts not in history sync)
    if chatName == "" && client != nil && client.Store.Contacts != nil {
        if contact, err := client.Store.Contacts.GetContact(ctx, chatJID.ToNonAD()); err == nil {
            if contact.FullName != "" {
                chatName = contact.FullName
            } else if contact.PushName != "" {
                chatName = contact.PushName
            }
        }
    }

    if chatName != "" {
        payload["chat_name"] = chatName
    }
}
```

**Fix (Chatwoot)**: Updated `build_contact` to use `chat_name` as fallback:
```ruby
profile_name = if payload[:is_from_me]
                 payload[:contact_name] || payload[:chat_name]  # history sync OR real-time
               else
                 payload[:from_name]
               end
```

**File:** `src/infrastructure/whatsapp/event_message.go`
**File:** `app/services/whatsapp/incoming_message_whatsapp_web_service.rb`

### 12. Device Contact Getting Wrong Name (Recipient's Name)
**Problem**: The device contact (sender of outgoing messages) was incorrectly named with the first chat recipient's name instead of the device owner's actual name.

**Example**: If the first outgoing message processed is in a chat with "Antonio Milesi", the device contact gets named "Antonio Milesi" even though the device owner is a different person.

**Cause**: In `build_history_message_params`, for non-group chats, `sender_name` was always set to `chat['name']` regardless of whether the message was outgoing or incoming. This chat name is the **recipient's** name, not the **sender's** (device owner's) name. Then `find_or_create_device_contact` used this `from_name` to name the device contact.

**Fix**: Added `lookup_device_owner_name` method that looks up the device owner's name from their own chat entry (self-chat). For outgoing messages, `sender_name` now uses this method instead of the chat name:
```ruby
sender_name = if is_from_me
                # For outgoing messages, get device owner's name from their own chat entry
                lookup_device_owner_name
              elsif group_chat?(chat_jid)
                lookup_sender_name_for_group(message, sender_jid)
              else
                chat['name']
              end

def lookup_device_owner_name
  return nil unless @history_chats_by_jid
  device_id = webhook_params[:device_id]
  return nil if device_id.blank?

  device_jid = "#{device_id}@s.whatsapp.net"
  device_chat = @history_chats_by_jid[device_jid]
  name = device_chat&.dig('name')

  # If name is just the phone number, return nil to use phone as fallback
  return nil if name.blank? || name == device_id
  name
end
```

**File:** `app/services/whatsapp/incoming_message_whatsapp_web_service.rb`

---

## Known Issues (Minor)

### 1. Duplicate Conversations
**Problem**: Same chat may create multiple conversations during history sync.

**Cause**: Each history message creates a new service instance via:
```ruby
self.class.new(inbox: inbox, params: transformed_params).perform
```

**Mitigation**: Auto-enabled `lock_to_single_conversation` for whatsapp_web inboxes prevents multiple conversations for the same contact.

### 2. Broadcast List Errors
**Problem**: Broadcast lists (`*@broadcast`) may fail validation.

**Workaround**: Skip broadcast lists manually if needed.

---

## Additional Features Implemented

### Auto-Enable Lock to Single Conversation
WhatsApp Web inboxes automatically enable `lock_to_single_conversation` to prevent duplicate conversations during history sync.

**File**: `app/models/inbox.rb`
```ruby
after_create :enable_lock_to_single_conversation_for_whatsapp_web

def enable_lock_to_single_conversation_for_whatsapp_web
  return unless channel.is_a?(Channel::Whatsapp) && channel.whatsapp_web?
  update_column(:lock_to_single_conversation, true)
end
```

**Note**: Must use `update_column` because `after_create` runs after the INSERT.

### 13. Duplicate Message Filtering (Frontend)
**Problem**: Messages with content not appearing in conversation view, showing empty duplicates instead.

**Cause**: go-whatsapp sends duplicate webhooks for the same message ID - first without body/content, second with content. Due to race conditions and PostgreSQL non-deterministic ordering for same timestamps, the `filterDuplicateSourceMessages` function in the frontend was keeping the FIRST message with a given `source_id`, which could be the empty one.

**Fix (2 parts)**:

**Frontend** - Modified `filterDuplicateSourceMessages` to prefer messages with content:
```javascript
// app/javascript/dashboard/helper/conversationHelper.js

const hasContent = message => {
  return (
    (message.content && message.content.trim().length > 0) ||
    (message.attachments && message.attachments.length > 0)
  );
};

export const filterDuplicateSourceMessages = (messages = []) => {
  const messagesWithoutDuplicates = [];
  messages.forEach(m1 => {
    if (m1.source_id) {
      const index = messagesWithoutDuplicates.findIndex(
        m2 => m1.source_id === m2.source_id
      );
      if (index < 0) {
        messagesWithoutDuplicates.push(m1);
      } else if (
        hasContent(m1) &&
        !hasContent(messagesWithoutDuplicates[index])
      ) {
        // Replace empty duplicate with one that has content
        messagesWithoutDuplicates[index] = m1;
      }
    } else {
      messagesWithoutDuplicates.push(m1);
    }
  });
  return messagesWithoutDuplicates;
};
```

**Backend** - Added duplicate detection in `create_message` to prevent race conditions:
```ruby
# app/services/whatsapp/incoming_message_whatsapp_web_service.rb

def create_regular_message(message)
  create_message(message)
  return if @message_already_exists

  attach_files
  attach_location if message_type == 'location'
  @message.save!
end

def create_message(message)
  source_id = message[:id].to_s
  existing_message = inbox.messages.find_by(source_id: source_id)

  if existing_message
    new_content = message_content(message)
    existing_message.update!(content: new_content) if new_content.present? && existing_message.content.blank?
    @message = existing_message
    @message_already_exists = true
    return
  end

  @message = @conversation.messages.build(message_attributes(message))
end
```

**Files:**
- `app/javascript/dashboard/helper/conversationHelper.js`
- `app/services/whatsapp/incoming_message_whatsapp_web_service.rb`
