<!-- generated-by: gsd-doc-writer -->
# Configuration Reference

This document covers every significant environment variable and installation-wide config key for
this Chatwoot fork. Variables live in `.env` (copied from `.env.example`); installation-wide
feature flags and branding overrides live in `config/installation_config.yml` and are editable
at runtime via the Super Admin dashboard.

> **Fork note:** This is a Brazilian SaaS fork of Chatwoot 4.12.1. Fork-specific additions
> (WhatsApp Web / gowa, branding overrides, Stripe billing) are called out in their own section.

---

## Table of Contents

1. [Core Rails](#core-rails)
2. [Database (PostgreSQL)](#database-postgresql)
3. [Redis](#redis)
4. [Web Server (Puma)](#web-server-puma)
5. [Background Jobs (Sidekiq)](#background-jobs-sidekiq)
6. [Storage](#storage)
7. [Outbound Email (SMTP)](#outbound-email-smtp)
8. [Inbound Email (Action Mailbox)](#inbound-email-action-mailbox)
9. [Channels — WhatsApp Cloud API](#channels--whatsapp-cloud-api)
10. [Channels — 360Dialog](#channels--360dialog)
11. [Channels — WhatsApp Web / gowa (fork-specific)](#channels--whatsapp-web--gowa-fork-specific)
12. [Channels — Facebook & Instagram](#channels--facebook--instagram)
13. [Channels — SMS (Twilio)](#channels--sms-twilio)
14. [Channels — Twitter / X](#channels--twitter--x)
15. [Channels — LINE](#channels--line)
16. [Channels — TikTok](#channels--tiktok)
17. [OAuth Providers](#oauth-providers)
18. [AI / LLM (Captain)](#ai--llm-captain)
19. [LLM Observability](#llm-observability)
20. [Push Notifications](#push-notifications)
21. [File Storage Backends](#file-storage-backends)
22. [Observability & Error Tracking](#observability--error-tracking)
23. [Search (OpenSearch)](#search-opensearch)
24. [Geolocation](#geolocation)
25. [Rate Limiting (Rack::Attack)](#rate-limiting-rackattack)
26. [Billing (Stripe — fork-specific)](#billing-stripe--fork-specific)
27. [Feature Flags](#feature-flags)
28. [Installation Config Keys](#installation-config-keys)
29. [Active Record Encryption](#active-record-encryption)

---

## Core Rails

Source: `.env.example`, `config/application.rb`

| Variable | Required | Default | Description |
|---|---|---|---|
| `SECRET_KEY_BASE` | **Yes** | — | Signs cookies and sessions. Generate with `rake secret`. Alphanumeric only. |
| `FRONTEND_URL` | **Yes** | `http://0.0.0.0:3000` | Public URL of the app. Used in outbound links and CORS. |
| `HELPCENTER_URL` | No | same as `FRONTEND_URL` | Dedicated URL for Help Center pages. |
| `RAILS_ENV` | **Yes** | `development` | `development`, `test`, or `production`. |
| `FORCE_SSL` | No | `false` | Redirect all HTTP traffic to HTTPS. |
| `ENABLE_ACCOUNT_SIGNUP` | No | `false` | `true` / `false` / `api_only`. Controls public sign-up. |
| `DEFAULT_LOCALE` | No | `en` | Default locale for new accounts and unauthenticated pages. |
| `ASSET_CDN_HOST` | No | _(blank)_ | CDN host for serving compiled assets (e.g. `https://cdn.example.com`). <!-- VERIFY: production CDN hostname --> |
| `RAILS_LOG_TO_STDOUT` | No | `true` | Write logs to stdout instead of a file. |
| `LOG_LEVEL` | No | `info` | `debug`, `info`, `warn`, `error`, `fatal`. |
| `LOG_SIZE` | No | `500` | Max log file size in MB (used when `RAILS_LOG_TO_STDOUT=false`). |
| `LOGRAGE_ENABLED` | No | _(unset)_ | Set `true` to use lograge structured logging. |
| `CW_API_ONLY_SERVER` | No | `false` | Disables the frontend dashboard; serves API endpoints only. |
| `LETTER_OPENER` | No | _(unset)_ | Set `true` in development to preview emails with letter_opener. |

---

## Database (PostgreSQL)

Source: `config/database.yml`

| Variable | Required | Default | Description |
|---|---|---|---|
| `POSTGRES_HOST` | **Yes** | `localhost` (dev: `postgres`) | PostgreSQL hostname. |
| `POSTGRES_PORT` | No | `5432` | PostgreSQL port. |
| `POSTGRES_DATABASE` | No | env-dependent (`chatwoot_production`) | Database name. |
| `POSTGRES_USERNAME` | No | `postgres` (prod: `chatwoot_prod`) | Database user. |
| `POSTGRES_PASSWORD` | No | _(blank)_ | Database password. |
| `POSTGRES_SCHEMA` | No | `public` | Schema search path. |
| `RAILS_MAX_THREADS` | No | `5` | Puma thread count; also sets the AR connection pool size for web processes. |
| `POSTGRES_STATEMENT_TIMEOUT` | No | `14s` | Per-query statement timeout enforced via `SET statement_timeout`. |
| `DB_POOL_REAPING_FREQUENCY` | No | `30` | Seconds between AR connection pool reaping runs. |

---

## Redis

Source: `.env.example`, `config/cable.yml`, `config/initializers/01_redis.rb`

| Variable | Required | Default | Description |
|---|---|---|---|
| `REDIS_URL` | **Yes** | `redis://redis:6379` | Redis connection URL. Supports `redis://:password@host:port/db`. |
| `REDIS_PASSWORD` | No | _(blank)_ | Password for the Redis instance (also used by Docker Compose). |
| `REDIS_SENTINELS` | No | _(blank)_ | Comma-separated `host:port` pairs for Redis Sentinel HA. |
| `REDIS_SENTINEL_MASTER_NAME` | No | `mymaster` | Sentinel master name. Required when `REDIS_SENTINELS` is set. |
| `REDIS_SENTINEL_PASSWORD` | No | _(same as `REDIS_PASSWORD`)_ | Override password for Sentinel nodes only. |
| `REDIS_OPENSSL_VERIFY_MODE` | No | _(unset)_ | Set `none` for Heroku Redis TLS workaround. |
| `REDIS_ALFRED_SIZE` | No | `5` | Connection pool size for the `$alfred` namespace (round robin, presence). |
| `REDIS_VELMA_SIZE` | No | `10` | Connection pool size for the `$velma` namespace (Rack::Attack throttle). |

ActionCable also uses Redis; its channel prefix is automatically set to
`chatwoot_{RAILS_ENV}_action_cable` via `config/cable.yml`.

---

## Web Server (Puma)

Source: `config/puma.rb`

| Variable | Required | Default | Description |
|---|---|---|---|
| `PORT` | No | `3000` | Port Puma listens on. |
| `RAILS_MIN_THREADS` | No | same as `RAILS_MAX_THREADS` | Minimum Puma thread count. |
| `RAILS_MAX_THREADS` | No | `5` | Maximum Puma thread count. |
| `WEB_CONCURRENCY` | No | `0` | Number of Puma worker processes (clustered mode). `0` = single-process. |
| `PIDFILE` | No | `tmp/pids/server.pid` | Path to Puma's PID file. |

---

## Background Jobs (Sidekiq)

Source: `config/sidekiq.yml`

| Variable | Required | Default | Description |
|---|---|---|---|
| `SIDEKIQ_CONCURRENCY` | No | `10` | Number of Sidekiq threads. Matches the AR pool size on workers. |
| `ENABLE_SIDEKIQ_DEQUEUE_LOGGER` | No | `false` | Log a line for each dequeued job (verbose, use in debugging only). |

Queues in priority order (highest first): `critical`, `high`, `medium`, `default`, `mailers`,
`action_mailbox_routing`, `low`, `scheduled_jobs`, `deferred`, `purgable`, `housekeeping`,
`async_database_migration`, `bulk_reindex_low`, `active_storage_analysis`, `active_storage_purge`,
`action_mailbox_incineration`.

WhatsApp Web webhook events are processed on the `low` queue via
`app/jobs/webhooks/whatsapp_web_events_job.rb`.

---

## Storage

Source: `.env.example`, `config/storage.yml`

The active backend is selected by `ACTIVE_STORAGE_SERVICE`.

| Variable | Required | Default | Description |
|---|---|---|---|
| `ACTIVE_STORAGE_SERVICE` | No | `local` | Backend: `local`, `amazon`, `google`, `microsoft`, `s3_compatible`. |
| `DIRECT_UPLOADS_ENABLED` | No | `false` | Upload files directly from browser to cloud storage. Requires CORS config on the storage bucket. |

See [File Storage Backends](#file-storage-backends) for per-backend variables.

---

## Outbound Email (SMTP)

Source: `.env.example`, `config/initializers/mailer.rb`

| Variable | Required | Default | Description |
|---|---|---|---|
| `MAILER_SENDER_EMAIL` | **Yes** | `Chatwoot <accounts@chatwoot.com>` | From address for all outgoing emails. |
| `SMTP_DOMAIN` | No | `chatwoot.com` | Domain used in HELO/EHLO greeting. |
| `SMTP_ADDRESS` | No | _(blank → sendmail)_ | SMTP server hostname. Leave blank to use local Postfix/sendmail. |
| `SMTP_PORT` | No | `1025` | SMTP port (`25`, `465`, `587`, or `1025` for MailHog in dev). |
| `SMTP_USERNAME` | No | _(blank)_ | SMTP authentication username. |
| `SMTP_PASSWORD` | No | _(blank)_ | SMTP authentication password. |
| `SMTP_AUTHENTICATION` | No | _(blank)_ | Auth mechanism: `plain`, `login`, or `cram_md5`. |
| `SMTP_ENABLE_STARTTLS_AUTO` | No | `true` | Attempt STARTTLS upgrade. |
| `SMTP_OPENSSL_VERIFY_MODE` | No | `peer` | TLS verification: `none`, `peer`, `client_once`, `fail_if_no_peer_cert`. |
| `SMTP_TLS` | No | _(unset)_ | Force TLS (port 465 style). |
| `SMTP_SSL` | No | _(unset)_ | Alias for `SMTP_TLS`. |
| `SMTP_OPEN_TIMEOUT` | No | _(default)_ | SMTP connection open timeout in seconds. |
| `SMTP_READ_TIMEOUT` | No | _(default)_ | SMTP read timeout in seconds. |

---

## Inbound Email (Action Mailbox)

Source: `.env.example`

| Variable | Required | Default | Description |
|---|---|---|---|
| `MAILER_INBOUND_EMAIL_DOMAIN` | No | _(blank)_ | Domain used to generate `reply+{id}@domain` conversation-continuity addresses. |
| `RAILS_INBOUND_EMAIL_SERVICE` | No | _(blank)_ | Ingress provider: `relay`, `mailgun`, `mandrill`, `postmark`, `sendgrid`, or `ses`. |
| `RAILS_INBOUND_EMAIL_PASSWORD` | No | _(blank)_ | Password for the Action Mailbox ingress webhook (used in webhook URL). |
| `MAILGUN_INGRESS_SIGNING_KEY` | No | _(blank)_ | Mailgun webhook signing key for HMAC verification. |
| `MANDRILL_INGRESS_API_KEY` | No | _(blank)_ | Mandrill API key for inbound email authentication. |
| `ACTION_MAILBOX_SES_SNS_TOPIC` | No | _(blank)_ | SNS topic ARN for SES inbound mail (`arn:aws:sns:region:account-id:topic-name`). Required when `RAILS_INBOUND_EMAIL_SERVICE=ses`. |

Inbound webhook URL pattern:

```
https://actionmailbox:[RAILS_INBOUND_EMAIL_PASSWORD]@[YOUR_DOMAIN]/rails/action_mailbox/[SERVICE]/inbound_emails
```

---

## Channels — WhatsApp Cloud API

Source: `config/installation_config.yml`, `app/services/whatsapp/providers/whatsapp_cloud_service.rb`

These values are stored as **InstallationConfig** keys (set via Super Admin dashboard or seeded
from `installation_config.yml`), not as env vars.

| Key | Default | Description |
|---|---|---|
| `WHATSAPP_APP_ID` | _(blank)_ | Facebook App ID for WhatsApp Business API. |
| `WHATSAPP_APP_SECRET` | _(blank)_ | App Secret for WhatsApp Embedded Signup flow. |
| `WHATSAPP_CONFIGURATION_ID` | _(blank)_ | Configuration ID for WhatsApp Embedded Signup. |
| `WHATSAPP_API_VERSION` | `v22.0` | Meta Graph API version prefix (e.g. `v22.0`). |

Per-inbox credentials (`api_key`, `business_account_id`, `phone_number_id`) are stored in
`Channel::Whatsapp#provider_config` (JSONB), set during inbox creation. See
`app/models/channel/whatsapp.rb`.

> **Security note:** `provider_config` is currently stored unencrypted in the database.
> See `docs/ARCHITECTURE.md` for the encryption roadmap.

---

## Channels — 360Dialog

Source: `app/services/whatsapp/providers/whatsapp_360_dialog_service.rb`

The `WHATSAPP_360_DIALOG_API_KEY` is stored per-inbox inside `provider_config`, not as a global
env var. No installation-wide key is required.

---

## Channels — WhatsApp Web / gowa (fork-specific)

Source: `.env.example` lines 273–281, `app/controllers/webhooks/whatsapp_web_controller.rb`,
`.devcontainer/docker-compose.yml`

This channel is a **custom fork addition** — it is not present in upstream Chatwoot. It routes
messages through [go-whatsapp-web-multidevice (gowa)](https://github.com/aldinokemal/go-whatsapp-web-multidevice),
a separate sidecar service, using QR-code authentication.

| Variable | Required | Default | Description |
|---|---|---|---|
| `WHATSAPP_WEB_API_URL` | **Yes** (if using WA Web) | `http://localhost:3001` | Base URL of the gowa service. In devcontainer: `http://localhost:4000`. <!-- VERIFY: production gowa URL --> |
| `WHATSAPP_WEB_WEBHOOK_SECRET` | No (dev) / **Yes** (prod) | _(blank)_ | Plain-text secret sent in the `X-Webhook-Secret` header from gowa to Chatwoot. Blank disables verification. |

> **Security warning:** gowa signs webhooks using `X-Hub-Signature-256` (HMAC-SHA256), but the
> current controller at `app/controllers/webhooks/whatsapp_web_controller.rb:41` uses `ActiveSupport::SecurityUtils.secure_compare` (constant-time comparison) —
> against `X-Webhook-Secret`. In production, `WHATSAPP_WEB_WEBHOOK_SECRET`
> **must** be set, and proper HMAC verification must be implemented before go-live.
> See `.planning/codebase/CONCERNS.md` for the tracking issue.

**gowa sidecar environment** (`.devcontainer/docker-compose.yml`):

```yaml
WHATSAPP_WEBHOOK: http://localhost:3000/webhooks/whatsapp_web
WHATSAPP_WEBHOOK_SECRET: dev-secret
WHATSAPP_WEBHOOK_INSECURE_SKIP_VERIFY: "true"
WHATSAPP_AUTO_MARK_READ: "true"
WHATSAPP_AUTO_DOWNLOAD_MEDIA: "true"
WHATSAPP_ACCOUNT_VALIDATION: "true"
WHATSAPP_CHAT_STORAGE: "true"
APP_PORT: "4000"
```

The devcontainer image is `ghcr.io/chatwoot-br/go-whatsapp-web-multidevice:v8.1.2-1`.
<!-- VERIFY: production gowa image tag and registry URL -->

---

## Channels — Facebook & Instagram

Source: `.env.example`, `config/installation_config.yml`

| Variable / Key | Type | Default | Description |
|---|---|---|---|
| `FB_APP_ID` | env + InstallationConfig | _(blank)_ | Facebook App ID. |
| `FB_APP_SECRET` | env + InstallationConfig | _(blank)_ | Facebook App Secret for webhook verification. |
| `FB_VERIFY_TOKEN` | env + InstallationConfig | _(blank)_ | Arbitrary token for verifying Facebook webhook subscription. |
| `IG_VERIFY_TOKEN` | env + InstallationConfig | _(blank)_ | Verify token for Instagram webhook subscription. |
| `FACEBOOK_API_VERSION` | InstallationConfig | `v18.0` | Meta Graph API version used for Messenger. |
| `ENABLE_MESSENGER_CHANNEL_HUMAN_AGENT` | InstallationConfig | `false` | Enable human-agent tag for extended 7-day reply window. Requires Meta app approval. |
| `INSTAGRAM_APP_ID` | InstallationConfig | _(blank)_ | Instagram App ID (separate from Facebook App ID). |
| `INSTAGRAM_APP_SECRET` | InstallationConfig | _(blank)_ | Instagram App Secret. |
| `INSTAGRAM_VERIFY_TOKEN` | InstallationConfig | _(blank)_ | Instagram-specific verify token. |
| `INSTAGRAM_API_VERSION` | InstallationConfig | `v22.0` | Instagram Graph API version (locked). |
| `ENABLE_INSTAGRAM_CHANNEL_HUMAN_AGENT` | InstallationConfig | `false` | Human-agent tag for Instagram. |

Webhooks are handled at `app/controllers/webhooks/instagram_controller.rb`.

---

## Channels — SMS (Twilio)

Source: `app/models/channel/twilio_sms.rb`, `app/services/sms/send_on_sms_service.rb`

| Variable | Required | Default | Description |
|---|---|---|---|
| `TWILIO_ACCOUNT_SID` | No | _(blank)_ | Twilio Account SID (per-inbox; stored in channel model). |
| `TWILIO_AUTH_TOKEN` | No | _(blank)_ | Twilio Auth Token. Encrypted when `ACTIVE_RECORD_ENCRYPTION_*` keys are set. |

Twilio credentials are stored per-inbox in the `Channel::TwilioSms` model, not as global env vars.
SMS webhooks are handled at `app/controllers/webhooks/sms_controller.rb`.

---

## Channels — Twitter / X

Source: `.env.example`, `app/models/channel/twitter_profile.rb`

| Variable | Required | Default | Description |
|---|---|---|---|
| `TWITTER_APP_ID` | No | _(blank)_ | Twitter App ID. |
| `TWITTER_CONSUMER_KEY` | No | _(blank)_ | Twitter OAuth consumer key. |
| `TWITTER_CONSUMER_SECRET` | No | _(blank)_ | Twitter OAuth consumer secret. |
| `TWITTER_ENVIRONMENT` | No | _(blank)_ | Twitter dev environment label for Account Activity API. |

> The `channel_twitter` feature flag is `deprecated: true` in `config/features.yml`.

---

## Channels — LINE

Source: `app/models/channel/line.rb`

| Variable | Required | Default | Description |
|---|---|---|---|
| `LINE_BOT_CHANNEL_ID` | No | _(blank)_ | LINE Bot channel ID (per-inbox). |
| `LINE_BOT_CHANNEL_SECRET` | No | _(blank)_ | LINE Bot channel secret. Encrypted when AR encryption keys are set. |

---

## Channels — TikTok

Source: `config/installation_config.yml`

| Key | Default | Description |
|---|---|---|
| `TIKTOK_API_VERSION` | `v1.3` | TikTok API version prefix. |
| `TIKTOK_APP_ID` | _(blank)_ | TikTok App ID. |
| `TIKTOK_APP_SECRET` | _(blank)_ | TikTok App Secret. |

Webhooks are handled at `app/controllers/webhooks/tiktok_controller.rb`.

---

## OAuth Providers

Source: `.env.example`, `config/installation_config.yml`

### Google OAuth2

| Variable / Key | Default | Description |
|---|---|---|
| `GOOGLE_OAUTH_CLIENT_ID` | _(blank)_ | Google OAuth 2.0 Client ID. |
| `GOOGLE_OAUTH_CLIENT_SECRET` | _(blank)_ | Google OAuth 2.0 Client Secret. |
| `GOOGLE_OAUTH_CALLBACK_URL` | _(blank)_ | Authorized redirect URI registered in Google Cloud Console. |
| `GOOGLE_OAUTH_REDIRECT_URI` | _(blank)_ | Alias for callback URL (used by InstallationConfig). |
| `ENABLE_GOOGLE_OAUTH_LOGIN` | `true` | Show Google OAuth on the login page when credentials are configured. |
| `ANDROID_SHA256_CERT_FINGERPRINT` | (Chatwoot default) | SHA-256 fingerprint for Android app authentication. |

### Microsoft / Azure AD

| Variable / Key | Default | Description |
|---|---|---|
| `AZURE_APP_ID` | _(blank)_ | Azure AD App (client) ID. |
| `AZURE_APP_SECRET` | _(blank)_ | Azure AD client secret. |

### Slack

| Key | Default | Description |
|---|---|---|
| `SLACK_CLIENT_ID` | _(blank)_ | Slack OAuth app client ID. |
| `SLACK_CLIENT_SECRET` | _(blank)_ | Slack OAuth app client secret. |

### SAML SSO

| Key | Default | Description |
|---|---|---|
| `ENABLE_SAML_SSO_LOGIN` | `true` | Show SAML SSO option on login. Cannot be disabled if SAML users exist. |

SAML is a premium feature (`config/features.yml`: `saml`, `enabled: false`, `premium: true`).

### Linear

| Key | Default | Description |
|---|---|---|
| `LINEAR_CLIENT_ID` | _(blank)_ | Linear OAuth client ID. |
| `LINEAR_CLIENT_SECRET` | _(blank)_ | Linear OAuth client secret. |

### Notion

| Key | Default | Description |
|---|---|---|
| `NOTION_CLIENT_ID` | _(blank)_ | Notion OAuth client ID. |
| `NOTION_CLIENT_SECRET` | _(blank)_ | Notion OAuth client secret. |
| `NOTION_VERSION` | `2022-06-28` | Notion API version header. |

### Shopify

| Key | Default | Description |
|---|---|---|
| `SHOPIFY_CLIENT_ID` | _(blank)_ | Shopify Partner API key. |
| `SHOPIFY_CLIENT_SECRET` | _(blank)_ | Shopify Partner API secret key. |

---

## AI / LLM (Captain)

Source: `config/installation_config.yml`, `config/llm.yml`, `config/initializers/ai_agents.rb`

Captain AI features are gated by the `captain_integration` feature flag (premium, disabled by default).
All Captain keys are **InstallationConfig** values (Super Admin dashboard → Captain Config).

| Key | Default | Description |
|---|---|---|
| `CAPTAIN_OPEN_AI_API_KEY` | _(blank)_ | OpenAI API key used by the `ai-agents` SDK. |
| `CAPTAIN_OPEN_AI_MODEL` | `gpt-4.1-mini` | Default model for Captain. Must be a key from `config/llm.yml`. |
| `CAPTAIN_OPEN_AI_ENDPOINT` | `https://api.openai.com/` | OpenAI-compatible base URL. Override for Azure OpenAI or proxy endpoints. <!-- VERIFY: production endpoint if not api.openai.com --> |
| `CAPTAIN_EMBEDDING_MODEL` | `text-embedding-3-small` | Embedding model for Help Center semantic search. |
| `CAPTAIN_FIRECRAWL_API_KEY` | _(blank)_ | FireCrawl API key for web crawling / knowledge ingestion. |
| `CAPTAIN_CLOUD_PLAN_LIMITS` | _(blank)_ | JSON blob defining per-plan Captain credit limits. |

The global `OPENAI_API_KEY` env var (`.env.example` line 271) is **not** used by Captain; only
`CAPTAIN_OPEN_AI_API_KEY` from InstallationConfig is. The raw env var may be used by other
integrations that call OpenAI directly.

**Available models** (`config/llm.yml`):

| Model key | Provider | Feature |
|---|---|---|
| `gpt-4.1` | OpenAI | editor, assistant, copilot, label_suggestion |
| `gpt-4.1-nano` | OpenAI | editor, label_suggestion |
| `gpt-4.1-mini` | OpenAI | editor, label_suggestion |
| `gpt-5.1`, `gpt-5.2`, `gpt-5-mini`, `gpt-5-nano` | OpenAI | assistant, copilot |
| `claude-haiku-4.5`, `claude-sonnet-4.5` | Anthropic | assistant, copilot _(coming soon)_ |
| `gemini-3-flash`, `gemini-3-pro` | Gemini | assistant, copilot _(coming soon)_ |
| `whisper-1` | OpenAI | audio_transcription |
| `text-embedding-3-small` | OpenAI | help_center_search |

---

## LLM Observability

Source: `config/installation_config.yml` (LLM Observability section)

| Key | Default | Description |
|---|---|---|
| `OTEL_PROVIDER` | _(blank)_ | Observability provider: `langfuse`, `langsmith`, etc. Leave blank to disable. |
| `LANGFUSE_PUBLIC_KEY` | _(blank)_ | Langfuse public key for tracing. |
| `LANGFUSE_SECRET_KEY` | _(blank)_ | Langfuse secret key. |
| `LANGFUSE_BASE_URL` | `https://us.cloud.langfuse.com` | Langfuse region endpoint. EU: `https://cloud.langfuse.com`. <!-- VERIFY: which region is used in production --> |

---

## Push Notifications

Source: `.env.example`, `config/installation_config.yml`

| Variable / Key | Default | Description |
|---|---|---|
| `VAPID_PUBLIC_KEY` | _(blank)_ | Web Push VAPID public key. Generate at https://d3v.one/vapid-key-generator/ |
| `VAPID_PRIVATE_KEY` | _(blank)_ | Web Push VAPID private key. |
| `FCM_SERVER_KEY` | _(blank)_ | FCM legacy server key for Android/iOS push (deprecated by Google; prefer FCM v1). |
| `FIREBASE_PROJECT_ID` | _(blank)_ | Firebase project ID for FCM v1 push notifications. |
| `FIREBASE_CREDENTIALS` | _(blank)_ | Full JSON contents of the Firebase service account credentials file. |
| `ENABLE_PUSH_RELAY_SERVER` | `true` | Relay push notifications through Chatwoot's official relay server for the official mobile apps. <!-- VERIFY: relay server URL --> |

---

## File Storage Backends

Source: `config/storage.yml`

Set `ACTIVE_STORAGE_SERVICE` to one of `local`, `amazon`, `google`, `microsoft`, or `s3_compatible`.

### Local (default)

No additional variables. Files are written to `storage/` in the project root.

### Amazon S3 (`amazon`)

| Variable | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM access key ID. |
| `AWS_SECRET_ACCESS_KEY` | IAM secret access key. |
| `AWS_REGION` | AWS region (e.g. `us-east-1`). |
| `S3_BUCKET_NAME` | Target S3 bucket name. <!-- VERIFY: production bucket name --> |

### Google Cloud Storage (`google`)

| Variable | Description |
|---|---|
| `GCS_PROJECT` | GCP project ID. |
| `GCS_CREDENTIALS` | Path to or contents of the GCS service account JSON. |
| `GCS_BUCKET` | Target GCS bucket name. <!-- VERIFY: production bucket name --> |

### Azure Blob Storage (`microsoft`)

| Variable | Description |
|---|---|
| `AZURE_STORAGE_ACCOUNT_NAME` | Azure storage account name. |
| `AZURE_STORAGE_ACCESS_KEY` | Azure storage account access key. |
| `AZURE_STORAGE_CONTAINER` | Azure Blob container name. <!-- VERIFY: production container name --> |

### S3-Compatible (`s3_compatible`)

For DigitalOcean Spaces, MinIO, Cloudflare R2, etc.

| Variable | Description |
|---|---|
| `STORAGE_ACCESS_KEY_ID` | Access key ID. |
| `STORAGE_SECRET_ACCESS_KEY` | Secret access key. |
| `STORAGE_REGION` | Region identifier. |
| `STORAGE_BUCKET_NAME` | Bucket / space name. |
| `STORAGE_ENDPOINT` | Custom endpoint URL (e.g. `https://nyc3.digitaloceanspaces.com`). |
| `STORAGE_FORCE_PATH_STYLE` | `true` to use path-style URLs (required for MinIO). |

---

## Observability & Error Tracking

Source: `.env.example`

### Sentry

| Variable | Default | Description |
|---|---|---|
| `SENTRY_DSN` | _(blank)_ | Sentry Data Source Name. Enables error tracking across Rails, Sidekiq, and JS. <!-- VERIFY: production DSN --> |

### Elastic APM

| Variable | Default | Description |
|---|---|---|
| `ELASTIC_APM_SERVER_URL` | _(blank)_ | Elastic APM server URL. <!-- VERIFY: production APM server --> |
| `ELASTIC_APM_SECRET_TOKEN` | _(blank)_ | APM secret token. |

### Scout APM

| Variable | Default | Description |
|---|---|---|
| `SCOUT_KEY` | _(blank)_ | Scout APM license key. |
| `SCOUT_NAME` | _(blank)_ | Application name shown in Scout dashboard. |
| `SCOUT_MONITOR` | _(blank)_ | Set `true` to enable Scout monitoring. |

### New Relic

| Variable | Default | Description |
|---|---|---|
| `NEW_RELIC_LICENSE_KEY` | _(blank)_ | New Relic license key. |
| `NEW_RELIC_APPLICATION_LOGGING_ENABLED` | _(blank)_ | Set `true` to forward logs to New Relic. |

### Datadog

| Variable | Default | Description |
|---|---|---|
| `DD_TRACE_AGENT_URL` | _(blank)_ | Datadog trace agent URL (e.g. `http://localhost:8126`). <!-- VERIFY: production agent URL --> |

---

## Search (OpenSearch)

Source: `config/initializers/searchkick.rb`

| Variable | Default | Description |
|---|---|---|
| `OPENSEARCH_URL` | _(blank)_ | OpenSearch / Elasticsearch endpoint URL. When set, full-text search uses OpenSearch; otherwise falls back to PostgreSQL. <!-- VERIFY: production cluster URL --> |
| `OPENSEARCH_AWS_ACCESS_KEY_ID` | _(blank)_ | AWS access key for OpenSearch Service (AWS-managed cluster). |
| `OPENSEARCH_AWS_SECRET_ACCESS_KEY` | _(blank)_ | AWS secret key for OpenSearch Service. |
| `OPENSEARCH_AWS_REGION` | `us-east-1` | AWS region of the OpenSearch Service cluster. |

---

## Geolocation

Source: `.env.example`

| Variable | Default | Description |
|---|---|---|
| `IP_LOOKUP_API_KEY` | _(blank)_ | MaxMind API key to download the GeoLite2 City database. Required for IP-to-location contact enrichment. The `ip_lookup` feature flag must also be enabled. |

---

## Rate Limiting (Rack::Attack)

Source: `.env.example`, `config/initializers/rack_attack.rb`

| Variable | Default | Description |
|---|---|---|
| `ENABLE_RACK_ATTACK` | _(blank)_ | Set `true` to activate request throttling. |
| `RACK_ATTACK_LIMIT` | `300` | Max requests per period per IP. |
| `ENABLE_RACK_ATTACK_WIDGET_API` | _(blank)_ | Set `true` to also throttle widget API endpoints. |
| `RACK_ATTACK_ALLOWED_IPS` | _(blank)_ | Comma-separated IPs / CIDRs that bypass all throttle rules (e.g. `127.0.0.1,10.0.0.0/8`). |

---

## Billing (Stripe — fork-specific)

Source: `.env.example`, `config/initializers/stripe.rb`

Stripe billing powers the Chatwoot BR SaaS subscription tiers.

| Variable | Required | Default | Description |
|---|---|---|---|
| `STRIPE_SECRET_KEY` | **Yes** (if billing enabled) | _(blank)_ | Stripe secret API key. <!-- VERIFY: which key (live vs test) is active in production --> |
| `STRIPE_WEBHOOK_SECRET` | **Yes** (if billing enabled) | _(blank)_ | Stripe webhook endpoint secret for signature verification. <!-- VERIFY: production webhook secret configured in Stripe dashboard --> |

Plan definitions are stored as the `CHATWOOT_CLOUD_PLANS` InstallationConfig key (JSON).

---

## Feature Flags

Feature flags are defined in `config/features.yml` and managed per-account via the database.
They can be toggled from the Super Admin dashboard.

| Flag | Default | Notes |
|---|---|---|
| `channel_email` | `true` | Email channel inbox. |
| `channel_facebook` | `true` | Facebook Messenger inbox. |
| `channel_instagram` | `true` | Instagram Direct inbox. |
| `channel_website` | `true` | Web widget inbox. |
| `channel_tiktok` | `true` | TikTok inbox. |
| `channel_twitter` | `true` | Twitter/X inbox. **Deprecated.** |
| `channel_voice` | `false` | Voice channel. Premium. |
| `inbound_emails` | `false` | Inbound email processing via Action Mailbox. |
| `ip_lookup` | `false` | IP-to-location enrichment (requires `IP_LOOKUP_API_KEY`). |
| `campaigns` | `false` | Outbound campaigns. |
| `sla` | `false` | SLA policies. Premium. |
| `audit_logs` | `false` | Audit log UI. Premium. |
| `captain_integration` | `false` | Captain AI assistant. Premium. |
| `captain_integration_v2` | `false` | Captain V2 (internal). Premium. |
| `captain_tasks` | `true` | Captain task tracking. |
| `saml` | `false` | SAML SSO login. Premium. |
| `advanced_search` | `false` | Full-text search with OpenSearch. Premium. |
| `whatsapp_campaign` | `false` | WhatsApp broadcast campaigns. |
| `whatsapp_embedded_signup` | `false` | WhatsApp Embedded Signup flow. **Deprecated.** |
| `companies` | `false` | Company CRM records. Premium. |
| `custom_roles` | `false` | Custom agent roles. Premium. |
| `disable_branding` | `false` | Remove Chatwoot branding. Premium. |
| `help_center` | `true` | Help Center / knowledge base. |
| `macros` | `true` | Conversation macros. |
| `automations` | `true` | Automation rules. |
| `reports` | `true` | Reporting dashboard. |

Flags marked **premium** are set via `INSTALLATION_PRICING_PLAN` in InstallationConfig.

---

## Installation Config Keys

`config/installation_config.yml` defines installation-wide defaults that are stored in the
`installation_configs` database table and editable via the Super Admin UI at `/super_admin`.
Keys marked `locked: false` are exposed there; `locked: true` (default) are seeded once and
not shown.

### Branding

| Key | Default | Description |
|---|---|---|
| `INSTALLATION_NAME` | `ChatWoot` | App name in dashboard title. |
| `BRAND_NAME` | `ChatWoot` | Name in emails and widget. |
| `BRAND_URL` | `https://chatwoot.app.br` | "Powered By" URL in emails. |
| `WIDGET_BRAND_URL` | `https://chatwoot.app.br` | "Powered By" URL in widget. |
| `TERMS_URL` | `https://chatwoot.app.br/terms-of-service` | Terms of Service link in Signup page. |
| `PRIVACY_URL` | `https://chatwoot.app.br/privacy-policy` | Privacy Policy link in app. |
| `LOGO` | `/brand-assets/logo.svg` | Dashboard / login logo path. |
| `LOGO_DARK` | `/brand-assets/logo_dark.svg` | Dark mode logo path. |
| `LOGO_THUMBNAIL` | `/brand-assets/logo_thumbnail.svg` | Favicon (512×512). |
| `DISPLAY_MANIFEST` | `false` | Show upstream Chatwoot metadata (favicons, upgrade notices). |

### Account Settings

| Key | Default | Description |
|---|---|---|
| `ENABLE_ACCOUNT_SIGNUP` | `false` | Allow public sign-ups. |
| `CREATE_NEW_ACCOUNT_FROM_DASHBOARD` | `false` | Allow creating additional accounts from inside the app. |
| `MAXIMUM_FILE_UPLOAD_SIZE` | `40` | Max attachment size in MB. |
| `WEBHOOK_TIMEOUT` | `5` | Seconds Chatwoot waits for an outgoing webhook response. |
| `INSTALLATION_EVENTS_WEBHOOK_URL` | _(blank)_ | URL that receives system events (e.g. new account created). |
| `HCAPTCHA_SITE_KEY` / `HCAPTCHA_SERVER_KEY` | _(blank)_ | hCaptcha keys for signup bot protection. |
| `ACCOUNT_EMAILS_LIMIT` | `100` | Daily non-channel email limit per account. |

### Deployment

| Key | Default | Description |
|---|---|---|
| `DEPLOYMENT_ENV` | `self-hosted` | `self-hosted` or `cloud`. Affects billing API calls. |
| `INSTALLATION_PRICING_PLAN` | `community` | Active plan: `community`, `pro`, `business`, etc. |
| `INSTALLATION_PRICING_PLAN_QUANTITY` | `0` | Number of purchased seats. |

### Compliance

| Key | Default | Description |
|---|---|---|
| `CHATWOOT_INSTANCE_ADMIN_EMAIL` | _(blank)_ | Admin email for compliance notifications. |

### Cloudflare

| Key | Default | Description |
|---|---|---|
| `CLOUDFLARE_API_KEY` | _(blank)_ | Cloudflare account API key. |
| `CLOUDFLARE_ZONE_ID` | _(blank)_ | Cloudflare zone ID for DNS management. |

---

## Active Record Encryption

Source: `config/application.rb` lines 69–102

Rails Active Record Encryption is used to encrypt sensitive channel credentials (IMAP/SMTP
passwords, OAuth tokens, bot tokens) in the database. Without these keys, credentials are stored
in plaintext.

| Variable | Required | Description |
|---|---|---|
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` | **Yes** (strongly recommended) | 32-byte primary encryption key. |
| `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` | **Yes** (strongly recommended) | 32-byte key for deterministic encryption (searchable). |
| `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | **Yes** (strongly recommended) | 32-byte salt for key derivation. |

Generate all three keys by running:

```bash
rails db:encryption:init
```

Use **different keys per environment** (development, staging, production). When all three
variables are present, `Chatwoot.encryption_configured?` returns `true` and the following
models encrypt their secrets automatically:

- `Channel::Email` — IMAP/SMTP passwords (`app/models/channel/email.rb:44`)
- `Channel::Instagram` — access token (`app/models/channel/instagram.rb:23`)
- `Channel::TikTok` — access token (`app/models/channel/tiktok.rb:25`)
- `Channel::TwilioSms` — auth token (`app/models/channel/twilio_sms.rb:32`)
- `Channel::Telegram` — bot token (`app/models/channel/telegram.rb:21`)
- `Channel::Line` — channel access token (`app/models/channel/line.rb:22`)
- `Channel::TwitterProfile` — API key/secret (`app/models/channel/twitter_profile.rb:23`)
- `Channel::FacebookPage` — access token (`app/models/channel/facebook_page.rb:25`)
- `Integrations::Hook` — access token (`app/models/integrations/hook.rb:25`)
- `Webhook` — webhook secret (`app/models/webhook.rb:25`)

> If these keys are absent on a production deployment, all the above secrets are stored
> unencrypted. Enabling encryption after the fact requires a data migration — do not rotate
> or delete these keys once set in production.
