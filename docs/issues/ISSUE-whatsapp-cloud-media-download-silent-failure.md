# WhatsApp Cloud API Media Download Silent Failure

## Status

**FIXED** - Cherry-picked from upstream [v4.10.1](https://github.com/chatwoot/chatwoot/releases/tag/v4.10.1)

## Summary

WhatsApp image/video/audio/document messages received via webhook were not saving attachments. Messages appeared with empty content and no attachments.

## Root Cause

The `phone_number_id` parameter was incorrectly passed to Meta's Graph API when downloading incoming media.

```ruby
# BEFORE (broken)
inbox.channel.media_url(attachment_payload[:id], inbox.channel.provider_config['phone_number_id'])
```

Per [Meta's documentation](https://developers.facebook.com/docs/whatsapp/cloud-api/reference/media):

> "If `phone_number_id` is included, the request will only be processed if it matches the ID of the business phone number **that the media was uploaded on**."

For incoming messages, media is uploaded by the **customer**, not the business. The API rejected requests with:

```
Param phone_number_id is not a valid whatsapp business phone number id ID
```

## The Fix

Remove `phone_number_id` parameter from media URL requests for incoming messages:

```ruby
# AFTER (fixed)
inbox.channel.media_url(attachment_payload[:id])
```

## Upstream References

- **PR**: [chatwoot/chatwoot#13319](https://github.com/chatwoot/chatwoot/pull/13319)
- **Issue**: [chatwoot/chatwoot#13317](https://github.com/chatwoot/chatwoot/issues/13317)
- **Commit**: `457430e8d9f137a226d2f60459e6129c1dd63858`

## Date

2026-01-20
