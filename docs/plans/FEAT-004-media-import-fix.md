# Plan: Fix Image Import on First Sync in WhatsApp Message History

## Problem Summary

Images only import on the SECOND sync (after deleting the contact), not on the first sync.

## Root Cause (FOUND)

**URL path duplication bug in `trigger_gateway_media_download`**

The gateway's download endpoint returns `file_path` WITH phone number prefix:
```
file_path: "/5521995539939/statics/media/..."
```

But `media_url()` ALSO adds the phone number:
```ruby
def media_url(media_id)
  "#{api_path}/#{media_id.sub(%r{^/}, '')}"
  # api_path = "http://localhost:3002/5521995539939"
end
```

Result: **Duplicated phone prefix** → 404 error
```
http://localhost:3002/5521995539939/5521995539939/statics/media/...
```

### Why Second Sync Worked

1. First sync: used `file_path` from download endpoint (WITH prefix) → wrong URL → failed
2. Download endpoint updated `media_path` in gateway DB
3. Second sync: messages API returned `media_path` (WITHOUT prefix) → correct URL → worked

## Solution (IMPLEMENTED)

### 1. Added `normalize_media_path()` method
Strips phone number prefix from gateway's `file_path`:
```ruby
def normalize_media_path(path)
  path.sub(%r{^/\d+/}, '/')
end
# "/5521995539939/statics/media/..." → "/statics/media/..."
```

### 2. Added media retry for existing messages
When message exists but has no attachments, retry media download:
```ruby
if existing
  if media?(message_data) && existing.attachments.empty?
    attach_media(existing, message_data, chat_jid: chat_jid)
  end
  @stats[:messages_skipped] += 1
  return
end
```

## Files Modified

**`app/services/whatsapp/message_import_service.rb`**
- Line 165-169: Added retry logic for existing messages without attachments
- Line 327: Call `normalize_media_path()` on gateway response
- Line 336-348: Added `normalize_media_path()` method

## Test Results

- ✅ 4 messages with cached media now import correctly on first sync
- ✅ Re-sync retries media for messages that failed previously
- ⚠️ Old messages with expired WhatsApp CDN tokens remain unrecoverable (WhatsApp limitation)
