# External Integrations

**Analysis Date:** 2026-04-11

## Messaging Channels & APIs

**WhatsApp:**
- Cloud API (Meta/Facebook)
  - SDK/Client: `facebook-sdk-php` via `facebook_api_client.rb`
  - Implementation: `app/services/whatsapp/providers/whatsapp_cloud_service.rb`
  - Auth: `FACEBOOK_BUSINESS_ACCOUNT_ID`, `WHATSAPP_BUSINESS_PHONE_NUMBER_ID`, `FACEBOOK_GRAPH_API_TOKEN`
  - Webhooks: `app/controllers/webhooks/whatsapp_controller.rb`
  - Model: `app/models/channel/whatsapp.rb`

- 360Dialog Provider
  - SDK/Client: HTTP REST via Faraday
  - Implementation: `app/services/whatsapp/providers/whatsapp_360_dialog_service.rb`
  - Auth: `WHATSAPP_360_DIALOG_API_KEY`
  - Webhooks: `app/controllers/webhooks/whatsapp_controller.rb`

- WhatsApp Web (QR Code Auth via gowa)
  - SDK/Client: go-whatsapp-web-multidevice (external service at `WHATSAPP_WEB_API_URL`)
  - Implementation: `app/services/whatsapp/providers/whatsapp_web_service.rb`
  - Auth: QR code-based, no manual credentials required
  - Configuration: `WHATSAPP_WEB_API_URL=http://localhost:3001`, `WHATSAPP_WEB_WEBHOOK_SECRET` (for HMAC verification)
  - Webhooks: `app/controllers/webhooks/whatsapp_web_controller.rb`
  - Incoming messages: `app/services/whatsapp/incoming_message_whatsapp_web_service.rb` (49KB service)
  - Note: Custom fork feature added in feature/whatsapp-web branch; requires gowa service running on port 3001

**Facebook:**
- Facebook Messenger Bot API
  - SDK/Client: `facebook-messenger` gem
  - Implementation: `app/services/facebook/send_on_facebook_service.rb`
  - Auth: `FB_APP_SECRET`, `FB_APP_ID`, `FB_VERIFY_TOKEN`
  - Webhooks: `app/controllers/webhooks/instagram_controller.rb` (handles Facebook and Instagram)
  - Model: `app/models/channel/facebook_page.rb`

**Instagram:**
- Instagram Direct Messages API (via Facebook)
  - SDK/Client: `facebook-messenger` gem
  - Implementation: Uses Facebook API client via `app/services/whatsapp/facebook_api_client.rb`
  - Auth: `IG_VERIFY_TOKEN`
  - Webhooks: `app/controllers/webhooks/instagram_controller.rb`
  - Model: `app/models/channel/instagram.rb`

**SMS Channels:**

- Twilio SMS
  - SDK/Client: `twilio-ruby` gem
  - Implementation: `app/services/sms/send_on_sms_service.rb`
  - Auth: `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`
  - Webhooks: `app/controllers/webhooks/sms_controller.rb`
  - Model: `app/models/channel/twilio_sms.rb`
  - Voice: `@twilio/voice-sdk` (2.12.4) in frontend for voice calls

- SMS (Generic Provider)
  - Model: `app/models/channel/sms.rb`
  - Campaigns: `app/services/sms/oneoff_sms_campaign_service.rb`

**Social & Messaging:**

- Twitter/X
  - SDK/Client: `twitty` gem (0.1.5) for streaming and API
  - Implementation: Handles account subscription events
  - Auth: `TWITTER_APP_ID`, `TWITTER_CONSUMER_KEY`, `TWITTER_CONSUMER_SECRET`, `TWITTER_ENVIRONMENT`
  - OAuth callback: `app/controllers/twitter/callbacks_controller.rb`
  - Model: `app/models/channel/twitter_profile.rb`

- LINE Messaging API
  - SDK/Client: `line-bot-api` gem
  - Implementation: LINE channel integration
  - Auth: `LINE_BOT_CHANNEL_ID`, `LINE_BOT_CHANNEL_SECRET`
  - Webhooks: `app/controllers/webhooks/line_controller.rb`
  - Model: `app/models/channel/line.rb`

- Telegram Bot API
  - SDK/Client: Implied from webhook controller
  - Webhooks: `app/controllers/webhooks/telegram_controller.rb`
  - Model: Channel integration via `app/models/channel` infrastructure

- TikTok
  - Model: `app/models/channel/tiktok.rb`
  - Webhooks: `app/controllers/webhooks/tiktok_controller.rb`

**Email Channels:**

- Email Channel
  - Incoming: Action Mailbox integration via `config/application.rb`
  - Providers:
    - Amazon SES (via `aws-actionmailbox-ses` gem)
    - Mailgun (signature key: `MAILGUN_INGRESS_SIGNING_KEY`)
    - Mandrill (API key: `MANDRILL_INGRESS_API_KEY`)
    - Postmark
    - Sendgrid
  - Configuration: `RAILS_INBOUND_EMAIL_SERVICE`, `RAILS_INBOUND_EMAIL_PASSWORD`
  - SNS Topic (SES): `ACTION_MAILBOX_SES_SNS_TOPIC`
  - Model: `app/models/channel/email.rb`
  - Outgoing: SMTP via `SMTP_*` environment variables

**API Channel:**

- Web/REST API Integration
  - Model: `app/models/channel/api.rb`
  - Direct API endpoint for conversation creation and message handling

**Web Widget:**

- Embedded Chat Widget
  - Model: `app/models/channel/web_widget.rb`
  - Frontend: `@rails/actioncable` for real-time updates
  - Lightweight chat embed for websites

## Authentication & OAuth Providers

**Google OAuth2:**
- Provider: Google Cloud Identity
- SDK/Client: `omniauth-google-oauth2` gem (1.1.3+)
- Configuration: `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `GOOGLE_OAUTH_CALLBACK_URL`
- Callback: `app/controllers/google/callbacks_controller.rb`
- Mobile fingerprint: `ANDROID_SHA256_CERT_FINGERPRINT` (for Android app authentication)

**Slack:**
- OAuth2 Integration
- SDK/Client: `slack-ruby-client` gem (2.7.0)
- Configuration: `SLACK_CLIENT_ID`, `SLACK_CLIENT_SECRET`
- Implementation: `app/controllers/api/v1/accounts/integrations/slack_controller.rb`
- Integration type: CRM/notification integration

**Microsoft / Azure AD:**
- OAuth2 Integration
- Configuration: `AZURE_APP_ID`, `AZURE_APP_SECRET`
- Callback: `app/controllers/microsoft/callbacks_controller.rb`
- Supports OAuth2 refresh tokens for long-lived access

**SAML Single Sign-On:**
- SDK/Client: `omniauth-saml` gem
- Enterprise authentication via SAML 2.0

**Twitter/X:**
- OAuth2 flow handled via omniauth
- Callback: `app/controllers/twitter/callbacks_controller.rb`

## Analytics & Data

**Amplitude:**
- Frontend analytics
- SDK/Client: `@amplitude/analytics-browser` (2.11.10)
- Tracks user events and engagement

**OpenSearch / Elasticsearch:**
- Full-text search for conversations and articles
- SDK/Client: `opensearch-ruby` gem, `searchkick` gem
- Configuration: Environment variables for OpenSearch endpoint
- Vector search: `pgvector` + `neighbor` gem for semantic search

## AI & Language Models

**OpenAI:**
- SDK/Client: `ruby-openai` gem
- Configuration: `OPENAI_API_KEY`
- Models supported (via `config/llm.yml`):
  - GPT-4.1, GPT-4.1 Mini, GPT-4.1 Nano
  - GPT-5, GPT-5.1, GPT-5 Mini, GPT-5.2, GPT-5 Nano
  - Whisper (speech-to-text)
  - Text Embedding 3 Small
- Implementation: Integrated via `ruby-openai` and `ai-agents` framework
- Use cases: Content assistance, conversation summarization, email draft generation

**Anthropic:**
- SDK/Client: Via `ruby_llm` abstraction layer
- Models supported (via `config/llm.yml`):
  - Claude Haiku 4.5
  - Claude Sonnet 4.5
- Framework: `ruby_llm` gem (1.8.2+), `ruby_llm-schema`

**Google Gemini:**
- SDK/Client: Via `ruby_llm` abstraction layer
- Models supported (via `config/llm.yml`):
  - Gemini 3 Flash
  - Gemini 3 Pro
- Framework: `ruby_llm` gem (1.8.2+)

**Google Dialogflow:**
- SDK/Client: `google-cloud-dialogflow-v2` gem (0.24.0+), gRPC
- Use case: Natural language understanding for bot conversations
- Implementation: `app/services/google_dialogflow_service.rb` (if exists)

**Google Translate:**
- SDK/Client: `google-cloud-translate-v3` gem (0.7.0+)
- Use case: Message translation for multi-language support
- Implementation: Via translation service integration

**LLM Framework:**
- Abstraction: `ruby_llm` gem (1.8.2+) provides vendor-agnostic LLM client
- Agent Framework: `ai-agents` gem (0.9.1+) for autonomous task execution
- Schema: `ruby_llm-schema` for structured output validation
- Configuration: `config/llm.yml` defines available providers and models
- Editor Integration: AI-powered message/response editing with configurable model selection

## CRM & Business Integrations

**Shopify:**
- SDK/Client: `shopify_api` gem
- Implementation: `app/controllers/api/v1/accounts/integrations/shopify_controller.rb`
- Webhooks: `app/controllers/webhooks/shopify_controller.rb`
- Use case: Customer conversations from Shopify orders

**Stripe (Billing & Payments):**
- SDK/Client: `stripe` gem (18.0)
- Configuration: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`
- Use case: Subscription management, billing in Chatwoot BR product tier
- Implementation: Billing/subscription processing

**Linear:**
- OAuth2 Integration
- Implementation: `app/controllers/linear/callbacks_controller.rb`
- Use case: Issue tracking and CRM integration
- Configuration: `LINEAR_CLIENT_ID` via `GlobalConfigService`

**Notion:**
- Integration: `app/controllers/api/v1/accounts/integrations/notion_controller.rb`
- Use case: Knowledge base and documentation integration

## File Storage & CDN

**Amazon S3:**
- SDK/Client: `aws-sdk-s3` gem
- Configuration: `S3_BUCKET_NAME`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`
- Active Storage: Primary production storage backend

**Google Cloud Storage (GCS):**
- SDK/Client: `google-cloud-storage` gem (1.48.0+)
- Configuration: `GCS_PROJECT`, `GCS_CREDENTIALS`, `GCS_BUCKET`
- Active Storage: Alternative cloud storage backend

**Microsoft Azure Blob Storage:**
- SDK/Client: `azure-storage-blob` gem (custom fork from chatwoot/azure-storage-ruby)
- Configuration: `AZURE_STORAGE_ACCOUNT_NAME`, `AZURE_STORAGE_ACCESS_KEY`, `AZURE_STORAGE_CONTAINER`
- Active Storage: Alternative cloud storage backend

**S3-Compatible Stores:**
- Support for DigitalOcean Spaces, MinIO, etc.
- Configuration: `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY`, `STORAGE_REGION`, `STORAGE_BUCKET_NAME`, `STORAGE_ENDPOINT`, `STORAGE_FORCE_PATH_STYLE`

**Local Filesystem:**
- Default: `storage/` directory for development
- Configuration: `ACTIVE_STORAGE_SERVICE=local`

**CDN:**
- Configuration: `ASSET_CDN_HOST` for serving assets through a CDN

## Monitoring & Error Tracking

**Sentry:**
- SDK/Client: `sentry-rails`, `sentry-ruby`, `sentry-sidekiq` gems
- Configuration: `SENTRY_DSN`
- Use: Error tracking and performance monitoring across Rails, JavaScript, and Sidekiq workers

**Datadog:**
- SDK/Client: `datadog` gem (2.0)
- Configuration: Loaded conditionally via `application.rb`
- Use: APM tracing, metrics, logs

**Elastic APM:**
- SDK/Client: `elastic-apm` gem
- Configuration: `ELASTIC_APM_SERVER_URL`, `ELASTIC_APM_SECRET_TOKEN`
- Use: Elasticsearch APM tracing

**New Relic APM:**
- SDK/Client: `newrelic_rpm`, `newrelic-sidekiq-metrics` gems
- Configuration: `NEW_RELIC_LICENSE_KEY`, `NEW_RELIC_APPLICATION_LOGGING_ENABLED`
- Use: Application performance monitoring

**Scout APM:**
- SDK/Client: `scout_apm` gem
- Configuration: `SCOUT_KEY`, `SCOUT_NAME`, `SCOUT_MONITOR=true`
- Use: Performance monitoring and optimization

**OpenTelemetry:**
- SDK/Client: `opentelemetry-sdk`, `opentelemetry-exporter-otlp` gems
- Use: LLM observability and distributed tracing
- Exporters: OTLP protocol for vendor-agnostic telemetry

## Push Notifications

**Firebase Cloud Messaging (FCM):**
- SDK/Client: `fcm` gem
- Configuration: `FCM_SERVER_KEY` (server-side)
- Use: Push notifications to Android and iOS mobile apps

**Web Push:**
- SDK/Client: `web-push` gem (3.0.1+)
- Configuration: `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`
- Use: Browser push notifications via Service Workers

**Push Relay Server:**
- Configuration: `ENABLE_PUSH_RELAY_SERVER=true`
- Use: Relay push notifications for official mobile apps via Chatwoot server

## Webhooks & Callbacks

**Incoming Webhooks (Chatwoot receives):**
- SMS: `app/controllers/webhooks/sms_controller.rb` - Incoming SMS messages
- WhatsApp Cloud: `app/controllers/webhooks/whatsapp_controller.rb` - Message events
- WhatsApp Web (gowa): `app/controllers/webhooks/whatsapp_web_controller.rb` - QR-authenticated sessions
- Instagram/Facebook: `app/controllers/webhooks/instagram_controller.rb` - Messenger events
- Telegram: `app/controllers/webhooks/telegram_controller.rb` - Bot messages
- LINE: `app/controllers/webhooks/line_controller.rb` - Messaging events
- TikTok: `app/controllers/webhooks/tiktok_controller.rb` - Message events
- Shopify: `app/controllers/webhooks/shopify_controller.rb` - Order and customer events
- Email: `app/controllers/action_mailbox/` - Incoming mail via ActionMailbox
- Stripe: Webhook endpoint for payment events
- Custom: `app/controllers/api/v1/integrations/webhooks_controller.rb` - Generic webhook handling

**Outgoing Webhooks (Chatwoot sends):**
- Model: `app/models/integrations/hook.rb` - Webhook event publisher
- Event types: Conversation creation, message sent, conversation status changes
- Configuration: Custom webhooks can be created via integrations API

**Webhook Security:**
- Method: HMAC signature verification (where applicable)
- WhatsApp Web: X-Hub-Signature-256 header (currently not verified; see CONCERNS.md)
- Stripe: Signature-based verification via webhook secret

## Geolocation & IP Lookup

**MaxMind GeoIP2:**
- SDK/Client: `maxminddb` gem
- Database: GeoLite2 City database (auto-downloaded)
- Configuration: `IP_LOOKUP_API_KEY` (MaxMind free tier)
- Use: IP-to-location mapping for contact insights

**Geocoder:**
- SDK/Client: `geocoder` gem
- Use: Address geocoding and reverse IP lookups

## Other Integrations

**Dyte (Video Conferencing):**
- Widget: `app/controllers/api/v1/widget/integrations/dyte_controller.rb`
- Use: Embedded video meetings in conversations

**Language Detection:**
- SDK/Client: `cld3` gem (3.7) - Compact Language Detection v3
- Use: Auto-detect message language for translation

**Email Provider Validation:**
- SDK/Client: `email-provider-info` gem
- Use: Validate email domains and detect bounces

---

*Integration audit: 2026-04-11*
