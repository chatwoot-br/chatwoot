# Issue: WhatsApp Web File Handling

## Status: Fixed

## Date: 2026-01-13

---

## Issue 1: Sending PDF Files Fails with Multipart Error

### Symptoms
When sending a PDF file through WhatsApp Web provider, the message fails with error:
```
request Content-Type has bad boundary or is not multipart/form-data
```

### Root Cause
The go-whatsapp-web-multidevice `/send/file` endpoint **only** accepts multipart form data uploads. Unlike the `/send/image`, `/send/video`, and `/send/audio` endpoints which support both file uploads and URLs (`image_url`, `video_url`, `audio_url`), the `/send/file` endpoint has no `file_url` parameter.

Chatwoot was sending JSON with a `file_url` parameter:
```json
{"phone": "...", "file_url": "http://..."}
```

But go-whatsapp expected multipart form data with the actual file bytes.

### Solution
Modified `app/services/whatsapp/providers/whatsapp_web_service.rb` to:
1. Detect when sending a file (not image/video/audio)
2. Download the file from ActiveStorage using `blob.open`
3. Send via multipart form data using Faraday

**Key changes:**
- Added `send_file_multipart` method for multipart uploads
- Added `build_file_form_data` helper
- Added `post_multipart_file` for Faraday connection
- Added `process_faraday_response` and `handle_faraday_error` for response handling

### Files Modified
- `app/services/whatsapp/providers/whatsapp_web_service.rb`

---

## Issue 1b: Sending PDF Files Missing Caption/Text

### Symptoms
When sending a PDF file with accompanying text (caption) from Chatwoot, only the file is sent - the text is not included.

### Root Cause
The `build_file_form_data` method was not including the message content as the `caption` field in the multipart form data.

### Solution
Added caption field to the multipart form data:
```ruby
form_data[:caption] = message.content if message.content.present?
```

### Files Modified
- `app/services/whatsapp/providers/whatsapp_web_service.rb`

---

## Issue 2: Incoming PDF Caption Not Saved

### Symptoms
When receiving a PDF (document) message with a caption/text from WhatsApp, only the file attachment was saved. The caption text was missing from the message content.

### Root Cause
The go-whatsapp webhook sends captions **nested inside** the media object:
```json
{
  "document": {
    "media_path": "statics/media/...",
    "mime_type": "application/pdf",
    "caption": "This is the caption text"
  }
}
```

But the `build_media_object` method in `IncomingMessageWhatsappWebService` only looked for a caption passed as a separate parameter, ignoring the nested `media_data[:caption]` field.

### Solution
Modified `build_media_object` in `app/services/whatsapp/incoming_message_whatsapp_web_service.rb` to extract the caption from the nested media data when no explicit caption parameter is provided:

```ruby
# Before:
media_obj[:caption] = caption if caption.present?

# After:
effective_caption = caption.presence || (media_data.is_a?(Hash) ? media_data[:caption] : nil)
media_obj[:caption] = effective_caption if effective_caption.present?
```

This fix also benefits images, videos, and audio messages that might have captions nested in the media object.

### Files Modified
- `app/services/whatsapp/incoming_message_whatsapp_web_service.rb`

---

## Testing

### Sending Files
1. Open a WhatsApp Web conversation in Chatwoot
2. Send a PDF file
3. Verify the file is sent successfully (no multipart error)

### Receiving Files with Caption
1. Send a PDF with caption text from WhatsApp mobile to the connected number
2. Verify the message in Chatwoot shows both the file attachment AND the caption text

---

## Related
- Plan: `docs/plans/PLAN-0001-whatsapp-web-provider.md`
- go-whatsapp-web-multidevice API endpoints:
  - `/send/file` - Only accepts multipart form data
  - `/send/image` - Accepts both multipart and `image_url`
  - `/send/video` - Accepts both multipart and `video_url`
  - `/send/audio` - Accepts both multipart and `audio_url`
