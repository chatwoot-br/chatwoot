# Codebase Concerns

**Analysis Date:** 2026-04-11

## Tech Debt

### Global Phone Number Uniqueness Blocks Multi-Tenant Inbox Creation

**Issue:** `Channel::Whatsapp` enforces a GLOBAL uniqueness constraint on `phone_number` via database index, preventing multiple accounts from using the same phone number for different inboxes.

**Files:**
- `app/models/channel/whatsapp.rb:33` — `validates :phone_number, presence: true, uniqueness: true`
- `db/migrate/20230426130150_init_schema.rb:341` — `t.index ["phone_number"], name: "index_channel_whatsapp_on_phone_number", unique: true`

**Impact:** 
- Multi-tenant setups cannot reuse phone numbers across accounts
- Phone number recycling (e.g., after channel deletion) blocks new inbox creation until DB cleanup
- Violates multi-tenant isolation principle

**Fix Approach:**
- Change uniqueness constraint from `uniqueness: true` to scoped uniqueness: `uniqueness: { scope: :account_id }`
- Update database index to be composite: `t.index ["account_id", "phone_number"], name: "index_channel_whatsapp_on_account_and_phone_number", unique: true`
- Add data migration to clean up any existing duplicates before deploying constraint change
- Verify all phone_number lookups properly filter by account_id (e.g., in `WhatsappWebChannelFinder`)

---

### Webhook Secret Verification Mismatch (GoWA Integration)

**Issue:** GoWA (go-whatsapp-web-multidevice) signs webhooks with `X-Hub-Signature-256` (HMAC-SHA256), but Chatwoot verifies using `X-Webhook-Secret` (plain string comparison). In development, this is bypassed by setting `WHATSAPP_WEB_WEBHOOK_SECRET` to blank.

**Files:**
- `app/controllers/webhooks/whatsapp_web_controller.rb:35-45` — `verify_webhook_secret` method accepts blank secret or plain string comparison
- Memory reference: [gowa → Chatwoot HMAC mismatch](project_gowa_webhook_hmac_mismatch.md)

**Impact:**
- No cryptographic signature validation in production (if HMAC is expected)
- Webhook spoofing vulnerability: attackers can send fake events if they know the channel's device_id
- Security bypass in development environment

**Fix Approach:**
- Implement proper HMAC-SHA256 verification for GoWA signatures on `X-Hub-Signature-256` header
- Validate signature against a shared secret stored in channel provider_config
- Ensure secret is never logged or exposed in error messages
- Add tests for valid and invalid signatures
- Document GoWA webhook signing requirements in code comments

---

### Encryption Guard Still in Place for 8+ Channels

**Issue:** Multiple channel models conditionally encrypt sensitive credentials only if `Chatwoot.encryption_configured?` is true. This was a temporary migration pattern that should be finalized.

**Files:**
- `app/models/channel/email.rb:43-46` — `if Chatwoot.encryption_configured?` guard on imap/smtp passwords
- `app/models/channel/instagram.rb:22` — Guard on facebook token
- `app/models/channel/tiktok.rb:24` — Guard on access token
- `app/models/channel/twilio_sms.rb:31` — Guard on auth token
- `app/models/channel/telegram.rb:20` — Guard on telegram token
- `app/models/channel/line.rb:21` — Guard on channel access token
- `app/models/channel/twitter_profile.rb:22` — Guard on api key/secret
- `app/models/channel/facebook_page.rb:24` — Guard on facebook token
- `app/integrations/hook.rb:24, 34` — Guards on hook URLs and credentials

**Impact:**
- Credentials may be stored unencrypted in database if encryption not configured
- Inconsistent encryption state across deployments
- Migration burden when encryption becomes mandatory
- Dependency on external encryption configuration that may not be set

**Fix Approach:**
- Make encryption mandatory across all deployments
- Add migration to encrypt existing unencrypted credentials
- Remove all `if Chatwoot.encryption_configured?` guards
- Add validation that encryption keys exist before channel creation
- Update deployment docs to require encryption key setup during initialization

---

### Missing Webhook Registration with GoWA

**Issue:** `Whatsapp::WebhookSetupService` handles webhook registration with Meta's Cloud API (WhatsApp Business Account), but there's no corresponding webhook registration with GoWA itself. GoWA needs to be configured with a callback URL to post events to Chatwoot.

**Files:**
- `app/services/whatsapp/webhook_setup_service.rb` — Registers only with Meta API, not GoWA
- `app/services/whatsapp/providers/whatsapp_web_service.rb` — Provider service lacks GoWA webhook registration

**Impact:**
- GoWA webhook endpoint not registered during channel setup
- Admins must manually configure GoWA webhook URL
- Event delivery may not start until webhook is registered externally
- Webhook registration is incomplete and error-prone

**Fix Approach:**
- Extend `WhatsappWebService` or create `WhatsappWebWebhookSetupService` to register webhook with GoWA
- Store GoWA webhook credentials (if needed) in channel provider_config
- Call webhook registration when WhatsApp Web channel is created
- Add webhook health check endpoint to verify GoWA is posting events
- Update device pair flow to include webhook registration confirmation

---

## Known Bugs

### WhatsApp Web Incoming Message Service Large (1374 Lines)

**Issue:** `Whatsapp::IncomingMessageWhatsappWebService` is a 1374-line monolith handling all WhatsApp Web message processing, including message creation, contact mapping, status updates, reactions, group handling, and media downloads.

**Files:** `app/services/whatsapp/incoming_message_whatsapp_web_service.rb:1-1374`

**Symptoms:**
- Difficult to test individual message handling paths
- High cognitive load for code review and maintenance
- Small changes require full service retest
- Error handling spread across many conditional branches
- Multiple database queries without obvious transaction boundaries

**Workaround:** None — service must be decomposed or carefully tested

**Fix Approach:**
- Extract message type handlers into separate service classes:
  - `WhatsappWebTextMessageService`
  - `WhatsappWebMediaMessageService`
  - `WhatsappWebStatusUpdateService`
  - `WhatsappWebReactionService`
  - `WhatsappWebGroupEventService`
- Create message dispatcher to route events to appropriate handler
- Add transaction management to ensure atomic updates
- Reduce service from 1374 to ~300-400 lines with clear responsibilities

---

### Devices Controller Large (287 Lines)

**Issue:** `WhatsappWeb::DevicesController` handles QR generation, pairing, unpairing, webhook registration, and device status — all in one controller class.

**Files:** `app/controllers/api/v1/accounts/whatsapp_web/devices_controller.rb:1-287`

**Symptoms:**
- Multiple error rescue blocks with generic handling
- Long methods that combine API calls, error handling, and response formatting
- Hard to test individual pairing/unpairing flows
- Exception handling raises with mixed exception types
- No separation between business logic and HTTP concerns

**Workaround:** None — logic must be refactored

**Fix Approach:**
- Extract pairing logic to `WhatsappWeb::DeviceService`
- Extract QR generation to `WhatsappWeb::QrCodeService`
- Extract unpairing logic to `WhatsappWeb::UnpairingService`
- Move webhook registration to dedicated service
- Controller should orchestrate services and handle HTTP responses
- Standardize error responses across endpoints

---

### Database Queries in WhatsappWeb Message Service Without Eager Loading

**Issue:** `Whatsapp::IncomingMessageWhatsappWebService` executes multiple `find_by` queries without eager loading related records, creating potential N+1 query patterns.

**Files:** `app/services/whatsapp/incoming_message_whatsapp_web_service.rb` — Lines with `find_by` queries:
- Line 137: `inbox.messages.find_by(source_id: reaction_data[:message_id])`
- Line 239: `inbox.contacts.find_by("additional_attributes->>'from_lid' = ?", lid_jid)`
- Line 325: `inbox.contact_inboxes.find_by(source_id: from_lid)`
- Line 384: `inbox.messages.find_by(source_id: source_id)`
- Line 794: `Message.find_by(source_id: status_update[:id])`
- Line 1135-1137: Two sequential `contact_inboxes.find_by` calls in same flow
- Line 1279-1291: Multiple sequential lookups in contact/contact_inbox resolution

**Impact:**
- Each webhook event may trigger 5-10 additional database queries
- Under high message volume (1000+ messages/hour), this creates database load spikes
- Query performance degrades proportionally with message volume
- No opportunity for caching or batch operations

**Fix Approach:**
- Analyze message flow to identify all required associations upfront
- Use single batched query with `find_by` or `where` with multiple conditions
- Consider caching contact_inbox mappings in Redis for 15-30 minutes
- Add query logging to identify actual N+1 patterns in production
- Monitor slow query log to catch performance degradation
- Batch webhook processing to amortize database overhead

---

## Security Considerations

### No HMAC Signature Validation on WhatsApp Web Webhooks

**Risk:** Webhook endpoints (`/webhooks/whatsapp_web`) can be spoofed by any actor who knows the channel's device_id. The secret verification is optional (blank secret disables it) and uses plain string comparison instead of cryptographic signature.

**Files:**
- `app/controllers/webhooks/whatsapp_web_controller.rb:35-45`
- Development configuration bypasses all validation

**Current Mitigation:**
- `verify_webhook_secret` method checks `X-Webhook-Secret` header
- If secret is blank, verification is skipped (deliberate bypass for dev)
- `ActiveSupport::SecurityUtils.secure_compare` prevents timing attacks if secret is configured

**Recommendations:**
- Implement HMAC-SHA256 verification matching GoWA's `X-Hub-Signature-256` header format
- Require non-blank secret in production (add validation on channel creation)
- Log all webhook verification failures with full request headers for audit trail
- Add webhook signature test endpoint to validate integration setup
- Consider IP whitelisting if GoWA publishes its IP range

---

### Provider Config Stored Unencrypted

**Risk:** `Channel::Whatsapp.provider_config` is a JSONB field storing sensitive data:
- `api_key` for Meta WhatsApp API
- `business_account_id` (semi-sensitive)
- `verification_pin` (6-digit PIN, low entropy)
- Device credentials for WhatsApp Web

**Files:**
- `app/models/channel/whatsapp.rb` — No encryption on provider_config
- `db/migrate/20230426130150_init_schema.rb` — JSONB field without encryption

**Current Mitigation:** None visible in code

**Recommendations:**
- Encrypt entire `provider_config` JSONB or migrate to separate encrypted columns
- For WhatsApp Web, consider storing sensitive fields in separate encrypted columns
- Implement key rotation mechanism for stored credentials
- Add audit logging when provider_config is accessed or modified
- Mask API keys in logs and error messages

---

### Webhook Secret Optional in Controller

**Risk:** `WhatsappWebController.verify_webhook_secret` allows blank secret to completely disable verification.

**Files:** `app/controllers/webhooks/whatsapp_web_controller.rb:36-37`

```ruby
secret = ENV.fetch('WHATSAPP_WEB_WEBHOOK_SECRET', nil)
return if secret.blank? # Skip verification if secret not configured
```

**Current Mitigation:** Development pattern, unclear if enforced in production

**Recommendations:**
- Add ENV validation at application startup to require non-blank secret
- Consider using unique secret per channel instead of environment variable
- Add warning log if verification is disabled
- Document security implications of blank secret in code comment

---

## Performance Bottlenecks

### Large Message Service (1374 Lines) Creates Cognitive Bottleneck

**Problem:** Single service handling all WhatsApp Web message types makes it hard to optimize specific paths or identify bottlenecks.

**Files:** `app/services/whatsapp/incoming_message_whatsapp_web_service.rb`

**Cause:**
- Service mixes message handling, contact creation, contact_inbox mapping, message creation, status updates, reactions, group events, and media handling
- No separation of concerns makes profiling difficult
- Changes to any path require testing all paths

**Improvement Path:**
1. Profile service on realistic message load to identify actual slow operations
2. Extract slowest paths to dedicated services
3. Add query caching for frequently accessed records (contacts, contact_inboxes)
4. Consider async processing for media downloads and heavy computations
5. Implement circuit breaker for external API calls (media downloads)

---

### PIN Generation in Webhook Setup

**Problem:** `Whatsapp::WebhookSetupService.fetch_or_create_pin` generates a new 6-digit PIN on every call if one isn't stored. This is not necessarily a performance issue but creates lookup overhead.

**Files:** `app/services/whatsapp/webhook_setup_service.rb:42-50`

**Cause:**
- PIN generation has weak entropy (only 900,000 possible values)
- Every webhook setup attempts PIN lookup in provider_config

**Improvement Path:**
- Consider generating PIN once during device pairing, not during webhook setup
- Use provider_config directly without repeated lookups
- Document PIN lifecycle and storage strategy

---

### Default Scopes on Message and InstallationConfig

**Problem:** `Message` model has `default_scope { order(created_at: :asc) }` which is problematic for browsing recent messages.

**Files:**
- `app/models/message.rb:126` — Default scope
- `app/models/message.rb:123` — TODO: Get rid of default scope
- `app/models/installation_config.rb:30` — Default scope

**Impact:**
- Default ascending order by created_at may cause slow queries on large conversations
- Developers must remember to `reorder` in most queries
- Risk of bugs if reorder is forgotten

**Improvement Path:**
- Remove default scope entirely
- Make explicit ordering required in finders
- Add scope helpers: `latest_first`, `oldest_first`
- Update all usages to call explicit ordering

---

## Fragile Areas

### WhatsApp Web Channel Finder Uses JID Parsing

**Issue:** `WhatsappWebChannelFinder.extract_phone_from_jid` parses JID format with naive string splitting, assuming format `phone@domain.ext`.

**Files:** `app/models/concerns/whatsapp_web_channel_finder.rb:18-23`

```ruby
def extract_phone_from_jid(jid)
  return jid if jid.blank?
  jid.split('@').first
end
```

**Why Fragile:**
- No validation that extracted phone is actually a valid number
- No handling for different JID formats GoWA might use
- If GoWA changes format, extraction silently produces invalid phone numbers
- No error logging when extraction fails

**Safe Modification:**
1. Add phone number validation after extraction
2. Log warnings if JID format is unexpected
3. Add `processable_chat_jid?` helper (mentioned in commit history as existing)
4. Unit test with various JID formats from GoWA documentation
5. Add observability to track extraction failures

**Test Coverage Gaps:**
- No test for malformed JIDs
- No test for various JID formats
- No test for extraction failure scenarios

---

### Contact Lookup Without Rate Limiting

**Issue:** `Whatsapp::IncomingMessageWhatsappWebService` performs multiple sequential `find_by` queries to resolve contact, without rate limiting or caching.

**Files:** `app/services/whatsapp/incoming_message_whatsapp_web_service.rb:1135-1291`

**Why Fragile:**
- Under message volume spike, creates N+1 queries
- No circuit breaker if contact lookups fail
- Silent failure to find contact may create duplicate contacts
- Concurrent webhook processing may race on contact creation

**Safe Modification:**
1. Add pessimistic locking or database-level unique constraints on contact phone number + account
2. Implement contact lookup cache with TTL
3. Add transaction to prevent race conditions
4. Log contact lookup failures with context
5. Add metrics to track lookup cache hit/miss rates

**Test Coverage Gaps:**
- No test for concurrent contact creation
- No test for contact lookup cache behavior
- No test for race conditions

---

## Scaling Limits

### Webhook Job Queue at Low Priority

**Issue:** `Webhooks::WhatsappWebEventsJob` queues at `:low` priority, same as other webhook jobs, but may need higher throughput.

**Files:** `app/jobs/webhooks/whatsapp_web_events_job.rb:4`

**Current Capacity:**
- Low queue priority may be delayed during peak load
- No retry strategy visible for failed webhook processing
- Single job processing sequential events (no parallelization)

**Scaling Path:**
1. Profile job processing time to determine if `:default` or `:high` is appropriate
2. Implement exponential backoff for job retries
3. Add circuit breaker for downstream service failures
4. Consider batch webhook processing to reduce job count
5. Monitor queue depth and job processing time
6. Scale Sidekiq workers based on queue depth

---

### No Batch Operations for Incoming Events

**Issue:** Each webhook event creates a separate job, without batching or deduplication.

**Files:** `app/controllers/webhooks/whatsapp_web_controller.rb:29`

```ruby
Webhooks::WhatsappWebEventsJob.perform_later(params.to_unsafe_hash)
```

**Limit:** At 10K messages/day (116/minute), each creates separate job overhead

**Scaling Path:**
1. Consider batching webhook events in a buffer
2. Process 10-50 events per job to amortize overhead
3. Implement deduplication for duplicate webhook deliveries
4. Add circuit breaker if event processing fails

---

## Dependencies at Risk

### Chatwoot Encryption Configuration

**Risk:** Codebase has encryption guards in 8+ channel models waiting for mandatory encryption. If encryption is not configured on initial setup, credentials may be stored unencrypted indefinitely.

**Impact:** 
- Security regression if not detected
- Data exposure in backups
- Difficult to retrofit encryption to existing deployments

**Migration Plan:**
- Add pre-flight check during application initialization
- Require encryption key setup before allowing channel creation
- Provide clear error message if encryption not configured
- Add migration script to encrypt existing unencrypted credentials

---

### GoWA External Dependency

**Risk:** WhatsApp Web functionality completely depends on GoWA (go-whatsapp-web-multidevice) external service availability.

**Impact:**
- Service outages are customer-facing
- No fallback if GoWA is down
- Device pairing/unpairing fails if GoWA is unavailable
- Message delivery delayed if webhook processing is slow

**Migration Plan:**
- Add health check endpoint to verify GoWA connectivity
- Implement circuit breaker for GoWA API calls
- Log GoWA availability metrics
- Document SLA expectations for WhatsApp Web vs other providers

---

## Missing Critical Features

### WhatsApp Web Device Registration Incomplete

**Issue:** GoWA webhook registration is missing from device setup flow. Admins must manually register webhook URL in GoWA after pairing device.

**Files:**
- `app/controllers/api/v1/accounts/whatsapp_web/devices_controller.rb` — No webhook registration
- `app/services/whatsapp/providers/whatsapp_web_service.rb` — No GoWA webhook setup

**Problem:** Device pairing is not fully automated. Additional manual steps create user friction and support burden.

**Blocks:** Fully autonomous device setup without admin intervention

---

### No QR Code Expiration or Refresh

**Issue:** QR codes generated for device pairing have no visible expiration time or ability to refresh.

**Files:** `app/controllers/api/v1/accounts/whatsapp_web/devices_controller.rb` — `generate_qr_code` method

**Problem:** Unclear to users if QR is still valid. If pairing fails, users don't know whether to refresh or wait.

**Blocks:** Clear user experience for device pairing flow

---

## Test Coverage Gaps

### WhatsApp Web Controller Webhook Endpoint Not Tested

**What's Not Tested:**
- `Webhooks::WhatsappWebController.process_payload` webhook endpoint
- Webhook signature verification
- Device_id extraction and channel lookup
- Channel inactive status handling

**Files:**
- `app/controllers/webhooks/whatsapp_web_controller.rb` — No corresponding spec file in webhooks folder
- Only `spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb` exists for service

**Risk:** Critical webhook endpoint could have bugs that go undetected. Signature bypass or device_id handling errors could be silently introduced.

**Priority:** HIGH — Webhook endpoint is the security boundary

---

### WhatsApp Web Devices Controller Partially Tested

**What's Not Tested:**
- QR code generation error cases
- Webhook registration failures
- Device unpairing edge cases
- Concurrent device pair requests

**Files:** 
- `app/controllers/api/v1/accounts/whatsapp_web/devices_controller.rb` — 287 lines with minimal spec coverage
- Multiple rescue blocks without test coverage
- Exception handling paths untested

**Risk:** Device pairing failures could go undiagnosed, leaving devices in inconsistent state.

**Priority:** HIGH — Device lifecycle is critical path

---

### WhatsappWebChannelFinder Not Directly Tested

**What's Not Tested:**
- JID parsing with various formats
- Phone number extraction from malformed JIDs
- Channel lookup by device_id
- Inactive channel detection

**Files:** `app/models/concerns/whatsapp_web_channel_finder.rb` — No dedicated test file

**Risk:** Webhook routing could silently fail for unexpected JID formats.

**Priority:** MEDIUM — Used by webhook controller, but indirectly tested through integration tests

---

### WhatsApp Web Service Provider Large but Undertested

**What's Not Tested:**
- Error handling for GoWA API failures
- Retry logic and circuit breaker behavior
- Webhook registration during device setup
- Device pairing flow end-to-end

**Files:** `app/services/whatsapp/providers/whatsapp_web_service.rb` — 387 lines

**Risk:** Complex device pairing flow could have bugs that only manifest under failures.

**Priority:** MEDIUM — Many error paths untested

---

## Fork-Specific Divergence from Upstream

### WhatsApp Web Provider Not in Upstream

**Status:** Custom fork feature, added post-4.12.1 base (commit 765842bc6)

**Files Affected:**
- `app/models/channel/whatsapp.rb` — WHATSAPP_WEB_PROVIDER constant
- `app/services/whatsapp/providers/whatsapp_web_service.rb` — 387 lines
- `app/services/whatsapp/incoming_message_whatsapp_web_service.rb` — 1374 lines
- `app/controllers/api/v1/accounts/whatsapp_web/devices_controller.rb` — 287 lines
- `app/jobs/webhooks/whatsapp_web_events_job.rb`
- `app/controllers/webhooks/whatsapp_web_controller.rb`

**Impact:**
- Cherry-pick conflicts likely when rebasing from upstream
- Maintenance burden to keep WhatsApp Web working during upstream merges
- No equivalent in upstream for testing/reference implementation
- WhatsApp Web customizations must be maintained locally

**Mitigation:**
- Document WhatsApp Web provider architecture for future developers
- Keep WhatsApp Web code isolated from other provider logic
- Add comprehensive integration tests to catch regressions during upstream merges
- Consider contributing WhatsApp Web provider back to upstream if viable

---

## Codebase Statistics

**Large Files (>250 lines) with Complex Logic:**
- `app/services/whatsapp/incoming_message_whatsapp_web_service.rb` — 1374 lines (message handling monolith)
- `app/controllers/api/v1/accounts/whatsapp_web/devices_controller.rb` — 287 lines (device lifecycle)
- `app/services/whatsapp/providers/whatsapp_web_service.rb` — 387 lines (provider service)
- `app/models/message.rb` — 452 lines
- `app/models/conversation.rb` — 348 lines

**TODO/FIXME Count:** 3026 comments across codebase (mostly non-blocking)

**Encryption Guards:** 8 locations in channel models (email, instagram, tiktok, twilio_sms, telegram, line, twitter_profile, facebook_page) + 2 in integrations/hook.rb

---

*Concerns audit: 2026-04-11*
