<!-- generated-by: gsd-doc-writer -->
# System Architecture

> **Audience:** Engineers joining this fork. This document covers _how_ the system is built, not how to install or run it (see the upstream README and GETTING-STARTED for that).
>
> **Fork context:** This is a fork of Chatwoot 4.12.1 with WhatsApp-first customizations for a Brazilian SaaS product (Q2 2026 launch). The primary addition is a third WhatsApp provider — **WhatsApp Web via gowa** (QR-code authentication, no Meta Business Account required) — layered on top of upstream's Cloud API and 360dialog providers.

---

## High-Level Topology

```
                          ┌─────────────────────────────────────────┐
                          │               Browser Clients            │
                          │  Dashboard SPA │ Widget (embed) │ Portal │
                          └───────┬────────────────┬─────────────────┘
                                  │ HTTPS           │ ActionCable WS
                          ┌───────▼────────────────▼─────────────────┐
                          │              Puma (Rails 7.1)             │
                          │                                           │
                          │  ┌────────────────┐  ┌─────────────────┐ │
                          │  │  REST API       │  │  ActionCable    │ │
                          │  │ /api/v1/        │  │  RoomChannel    │ │
                          │  │  accounts/:id/  │  └────────┬────────┘ │
                          │  └───────┬────────┘           │          │
                          │          │                     │ pub/sub   │
                          │  ┌───────▼────────────────────▼────────┐ │
                          │  │  Redis (ActionCable adapter + cache) │ │
                          │  └──────────────────────────────────────┘ │
                          │                                           │
                          │  ┌────────────────────────────────────┐  │
                          │  │  Webhook Controllers               │  │
                          │  │  /webhooks/whatsapp                │  │
                          │  │  /webhooks/whatsapp_web  ◄── gowa  │  │
                          │  │  /webhooks/instagram, line, …      │  │
                          │  └───────────────┬────────────────────┘  │
                          └──────────────────┼────────────────────────┘
                                             │ enqueue
                          ┌──────────────────▼────────────────────────┐
                          │           Sidekiq Workers                  │
                          │  (queues: default, medium, low, mailers)    │
                          └──────────────────┬────────────────────────┘
                                             │
                          ┌──────────────────▼────────────────────────┐
                          │           PostgreSQL                       │
                          │  (accounts, conversations, messages, …)    │
                          └────────────────────────────────────────────┘

External providers (outbound):
  Meta WhatsApp Cloud API  ◄─── WhatsappCloudService
  360dialog API            ◄─── Whatsapp360DialogService
  gowa (localhost:3001)    ◄─── WhatsappWebService
  Facebook/Instagram       ◄─── facebook-messenger gem
  Twilio SMS, LINE, Telegram, TikTok, …
```

**Key facts:**
- Single Rails monolith — no microservices. Horizontal scaling is via multiple Puma workers + multiple Sidekiq processes.
- Redis serves two roles: ActionCable pub/sub adapter and Sidekiq job queue backend.
- Active Storage handles file attachments; production uses S3/GCS/Azure Blob.

---

## Rails Layer Stack

```
HTTP Request
     │
     ▼
app/controllers/                  ← authenticate, authorize, param validation
     │
     ▼
app/policies/                     ← Pundit (authorization)
     │
     ▼
app/finders/ + app/builders/      ← query + object construction
     │
     ▼
app/services/                     ← business logic
     │
     ▼
app/models/                       ← persistence, associations, validations
     │
     ▼
app/dispatchers/                  ← event dispatch (sync + async)
     │              │
     ▼              ▼
app/listeners/    app/jobs/       ← side-effects (ActionCable, outbound webhooks, notifications)
```

### Controllers

All dashboard-facing API lives under `app/controllers/api/v1/accounts/` and is scoped to an account by the `:account_id` URL segment. The `set_current_user` before-action populates `Current.account` and `Current.user` (thread-local) for every request. Webhook receivers live at `app/controllers/webhooks/` and are unauthenticated (provider-specific verification instead).

Key namespaces:
- `api/v1/accounts/` — conversations, messages, inboxes, contacts, teams, reports
- `api/v2/` — enterprise extensions
- `webhooks/` — WhatsApp, WhatsApp Web, Instagram, LINE, Telegram, TikTok, SMS, Shopify
- `super_admin/` — platform-level admin (Administrate-based)

### Services

Classes under `app/services/` hold all non-trivial business logic. They follow the convention of a `#perform` method returning a result. Domains:
- `app/services/whatsapp/` — incoming message parsing, provider abstraction, template sync
- `app/services/conversations/` — filtering, assignment, message window
- `app/services/contacts/` — bulk import, sync, deduplication
- `app/services/email/` — inbound parsing, outbound delivery
- `app/services/facebook/`, `app/services/instagram/` — Graph API operations

### Builders

Builders in `app/builders/` encapsulate the creation of objects that span multiple models:

| Builder | What it creates |
|---|---|
| `account_builder.rb` | Account + initial User |
| `contact_inbox_with_contact_builder.rb` | Contact + ContactInbox + associations |
| `conversation_builder.rb` | Conversation thread from first message |
| `messages/message_builder.rb` | Message from webhook payload |

Each builder exposes a `.perform` or `.new(...).perform` interface.

### Finders

`app/finders/` contains chainable query builders for expensive reads: `ConversationFinder`, `MessageFinder`, `NotificationFinder`. Controllers call finders rather than building ActiveRecord chains inline.

---

## Builders / Listeners / Dispatchers Pattern

This is the core event-driven wiring. Understanding it is essential for tracing any message through the system.

```
Model.save
    │
    └─► Dispatcher.dispatch(:message_created, timestamp, data)
              │
    ┌─────────┴──────────┐
    ▼                    ▼
SyncDispatcher       AsyncDispatcher
(inline, same req)   (Sidekiq job)
    │                    │
    ▼                    ▼
ActionCableListener  WebhookListener (outbound)
NotificationListener AutomationRuleListener
ReportingEventListener
```

**`app/dispatchers/dispatcher.rb`** — Singleton. Delegates to `SyncDispatcher` and `AsyncDispatcher` simultaneously.

**`app/dispatchers/sync_dispatcher.rb`** — Calls listeners inline in the request/job thread. Used for `ActionCableListener` (realtime broadcast must happen quickly).

**`app/dispatchers/async_dispatcher.rb`** — Enqueues listeners as Sidekiq jobs, keeping the main thread fast.

**`app/listeners/action_cable_listener.rb`** — Formats model data via presenters and broadcasts to `RoomChannel` subscribers.

**`app/listeners/webhook_listener.rb`** — Calls `WebhookJob.perform_later` to deliver event payloads to account-configured outbound webhooks.

**`app/listeners/notification_listener.rb`** — Creates `Notification` records for assignments, mentions, and replies.

**`app/listeners/automation_rule_listener.rb`** — Evaluates automation rules against the event.

---

## Multi-Tenancy Model

Every row in the database carries an `account_id` foreign key. The tenant context is established in `lib/current.rb` via Rails `CurrentAttributes`:

```ruby
# lib/current.rb
class Current < ActiveSupport::CurrentAttributes
  attribute :account, :user, :account_user
end
```

`ApplicationController#set_current_user` populates these before every action. All queries in controllers and services are implicitly or explicitly scoped to `Current.account`.

### Core Domain Models

```
Account (tenant)
 ├── User (agent/admin, many-to-many via AccountUser)
 ├── Team (group of Users)
 ├── Inbox  (channel instance, belongs to one Channel record)
 │    └── Channel::* (WhatsApp, Email, WebWidget, FacebookPage, …)
 ├── Contact
 │    └── ContactInbox  (joins Contact ↔ Inbox, holds source_id)
 └── Conversation
      ├── belongs_to Contact, Inbox
      ├── has_many Message
      └── has_many Attachment (via Active Storage)
```

**`app/models/account.rb`** — Root tenant model. Holds plan metadata, custom attributes config, feature flags.

**`app/models/inbox.rb`** — An account-scoped instance of a channel. Stores auto-reply settings, team assignments, operating hours. Points to a polymorphic `channel` record.

**`app/models/contact.rb`** — External entity (customer). Has `phone`, `email`, `identifier`, `custom_attributes`. One contact can be present across multiple inboxes via `ContactInbox`.

**`app/models/contact_inbox.rb`** — Junction between `Contact` and `Inbox`. The `source_id` column holds the channel-specific identifier (e.g., WhatsApp phone number, Facebook PSID).

**`app/models/conversation.rb`** — A thread of messages. Attributes: `status` (`open`/`resolved`/`snoozed`/`pending`), `assignee_id`, `team_id`, `inbox_id`, `contact_id`. 348 lines — contains callbacks that fire dispatcher events.

**`app/models/message.rb`** — Individual message. `message_type` distinguishes incoming (0), outgoing (1), activity (2), template (3). Has `default_scope { order(created_at: :asc) }` — note the TODO in source to remove this.

---

## Channel Abstraction

All communication channels follow the same abstraction:

```
Inbox (account-scoped instance)
  └── channel_type: "Channel::Whatsapp"
       └── channel record in channel_whatsapp table
            └── #provider_service → Whatsapp::Providers::*
```

Channel models live in `app/models/channel/` and include the `Channelable` concern. The `Inbox` model delegates provider-specific operations to the channel's `#provider_service` method.

**Channel model files:**

| File | Channel type |
|---|---|
| `app/models/channel/whatsapp.rb` | WhatsApp (all three providers) |
| `app/models/channel/email.rb` | Email (IMAP/SMTP) |
| `app/models/channel/facebook_page.rb` | Facebook Messenger |
| `app/models/channel/instagram.rb` | Instagram DMs |
| `app/models/channel/web_widget.rb` | Embeddable chat widget |
| `app/models/channel/api.rb` | REST API channel |
| `app/models/channel/sms.rb` | Generic SMS |
| `app/models/channel/twilio_sms.rb` | Twilio SMS |
| `app/models/channel/telegram.rb` | Telegram bot |
| `app/models/channel/line.rb` | LINE Messaging |
| `app/models/channel/tiktok.rb` | TikTok |
| `app/models/channel/twitter_profile.rb` | Twitter/X |

Each channel model includes `Channelable` and exposes a `#provider_service` that handles send/receive. Sensitive credentials (API keys, tokens) are stored in encrypted columns or in the `provider_config` JSONB field — see CONCERNS.md for the known encryption guard issue.

---

## WhatsApp Providers and the gowa Integration

`Channel::Whatsapp` (in `app/models/channel/whatsapp.rb`) supports three providers via the `provider` string column:

| `provider` value | Class | Auth mechanism |
|---|---|---|
| `"default"` (360dialog) | `Whatsapp::Providers::Whatsapp360DialogService` | API key |
| `"whatsapp_cloud"` | `Whatsapp::Providers::WhatsappCloudService` | Meta Graph API token |
| `"whatsapp_web"` | `Whatsapp::Providers::WhatsappWebService` | QR code via gowa |

The `provider_service` method on the channel model returns the right service object:

```ruby
# app/models/channel/whatsapp.rb
def provider_service
  case provider
  when 'whatsapp_cloud'
    Whatsapp::Providers::WhatsappCloudService.new(whatsapp_channel: self)
  when WHATSAPP_WEB_PROVIDER          # 'whatsapp_web'
    Whatsapp::Providers::WhatsappWebService.new(whatsapp_channel: self)
  else
    Whatsapp::Providers::Whatsapp360DialogService.new(whatsapp_channel: self)
  end
end
```

### gowa (WhatsApp Web) Data Flow

gowa is an external Go service (`go-whatsapp-web-multidevice`) running at `WHATSAPP_WEB_API_URL` (default `http://localhost:3001`). It maintains the WhatsApp Web multi-device session and delivers events to Chatwoot via webhooks.

**Inbound message path (gowa → Chatwoot → agent dashboard):**

```
gowa service
  POST /webhooks/whatsapp_web
  headers: X-Webhook-Secret (plain string, HMAC mismatch — see CONCERNS.md)
  body: { device_id, type, message, … }
        │
        ▼
Webhooks::WhatsappWebController#process_payload
  app/controllers/webhooks/whatsapp_web_controller.rb
  1. verify_webhook_secret (env var WHATSAPP_WEB_WEBHOOK_SECRET)
  2. extract device_id
  3. find Channel::Whatsapp via WhatsappWebChannelFinder concern
        │
        ▼
Webhooks::WhatsappWebEventsJob (Sidekiq, :low queue)
  app/jobs/webhooks/whatsapp_web_events_job.rb
        │
        ▼
Whatsapp::IncomingMessageWhatsappWebService
  app/services/whatsapp/incoming_message_whatsapp_web_service.rb
  (1374-line monolith — refactor tracked in CONCERNS.md)
  1. parse message type (text, image, video, audio, document, reaction, …)
  2. extract/create Contact from JID phone number
  3. find/create ContactInbox (source_id = phone number)
  4. find/create Conversation
  5. create Message
        │
        ▼
Message.save triggers Dispatcher.dispatch(:message_created, …)
        │
   ┌────┴───────────────────┐
   ▼                        ▼
ActionCableListener     WebhookListener
broadcasts to           queues outbound
RoomChannel             webhook HookJobs
        │
        ▼
Dashboard Vue SPA receives
message via ActionCable WS
```

**Outbound message path (agent → gowa → WhatsApp):**

```
Agent sends message via dashboard
  POST /api/v1/accounts/:id/conversations/:id/messages
        │
        ▼
Api::V1::Accounts::Conversations::MessagesController
        │
        ▼
Messages::OutgoingMessagesService (or equivalent)
        │
        ▼
Channel::Whatsapp#provider_service
  → Whatsapp::Providers::WhatsappWebService#send_message
        │
        ▼
HTTP POST to gowa at WHATSAPP_WEB_API_URL
  /api/send-message (text) or /api/send-file (attachment)
```

**Device lifecycle (QR pairing):**

The fork adds `app/controllers/api/v1/accounts/whatsapp_web/devices_controller.rb` (287 lines) to handle device registration, QR code generation, status polling, and unpairing. The controller calls `WhatsappWebService` which calls gowa's REST API. Known issue: GoWA webhook registration is not automated — admins must configure the callback URL in gowa manually after pairing (tracked in CONCERNS.md).

**Key files for gowa integration (all fork-specific, not in upstream):**

- `app/models/channel/whatsapp.rb` — `WHATSAPP_WEB_PROVIDER` constant and `whatsapp_web?` predicate
- `app/models/concerns/whatsapp_web_channel_finder.rb` — JID-to-channel lookup concern
- `app/services/whatsapp/providers/whatsapp_web_service.rb` — 387-line provider (send, validate, device management)
- `app/services/whatsapp/incoming_message_whatsapp_web_service.rb` — 1374-line inbound message handler
- `app/controllers/webhooks/whatsapp_web_controller.rb` — webhook receiver
- `app/controllers/api/v1/accounts/whatsapp_web/devices_controller.rb` — device lifecycle API
- `app/jobs/webhooks/whatsapp_web_events_job.rb` — async job enqueued by webhook controller

**Known security note:** gowa signs webhooks with `X-Hub-Signature-256` (HMAC-SHA256), but the controller currently checks `X-Webhook-Secret` (plain string). In development, setting `WHATSAPP_WEB_WEBHOOK_SECRET` to blank bypasses all verification. See `CONCERNS.md` for the full issue and fix approach.

---

## Realtime (ActionCable)

The dashboard and portal receive live updates over a single persistent WebSocket connection per browser tab.

**Connection establishment (`app/channels/application_cable/connection.rb`):**
- Client sends `pubsub_token` on connect
- Rails authenticates the token against `User#pubsub_token` or `ContactInbox#pubsub_token`

**`app/channels/room_channel.rb`:**
- On `subscribed`, client streams from its personal `pubsub_token` channel and from the account-scoped `account_:id` channel
- `ensure_stream` sets up both stream subscriptions
- `broadcast_presence` pushes current online user list on connect and on explicit `update_presence` calls

**Broadcast flow:**
1. `ActionCableListener` (called from `SyncDispatcher`) invokes `ActionCable.server.broadcast(pubsub_token, payload)`
2. Rails forwards via Redis pub/sub to all Puma processes
3. The correct process delivers to the subscribed WebSocket client

**Event names broadcast** (sample): `message.created`, `message.updated`, `conversation.created`, `conversation.status_changed`, `presence.update`, `notification.created`.

Redis is configured in `config/cable.yml`. In production, the same Redis instance serves both ActionCable and Sidekiq — use `REDIS_URL` or separate `ACTION_CABLE_REDIS_URL` if splitting.

---

## Background Jobs (Sidekiq)

`config/sidekiq.yml` defines queues. All job classes extend `ApplicationJob` (`ActiveJob::Base` + Sidekiq adapter).

**Queues (approximate priority order):**

| Queue | Purpose |
|---|---|
| `default` | General jobs (conversation updates, notifications) |
| `mailers` | ActionMailer deliveries |
| `low` | Webhook ingestion jobs (`WhatsappWebEventsJob`, `WhatsappEventsJob`) |
| `medium` | Outbound webhook delivery (`WebhookJob`, `HookJob`) |

**Recurring jobs** are defined via `sidekiq-cron` in `config/schedule.yml` (template sync, report aggregation, channel health checks).

**Key job files:**

- `app/jobs/webhooks/whatsapp_events_job.rb` — Cloud API / 360dialog webhook processing
- `app/jobs/webhooks/whatsapp_web_events_job.rb` — gowa webhook processing (fork-specific)
- `app/jobs/action_cable_broadcast_job.rb` — deferred ActionCable broadcast
- `app/jobs/conversations/` — message send, assignment, status update jobs
- `app/jobs/notification/` — notification fan-out

Sidekiq Web UI is mounted at `/monitoring/sidekiq` for super admins (check `config/routes.rb`).

---

## Frontend / Backend Boundary

The frontend is a collection of independent Vue 3 SPAs bundled by Vite.

**Entrypoints** (`app/javascript/entrypoints/`):

| Bundle | Purpose |
|---|---|
| `dashboard.js` | Agent dashboard (`App.vue` in `dashboard/`) |
| `widget.js` | Embeddable chat widget for 3rd-party sites |
| `portal.js` | Customer self-service portal |
| `sdk.js` | Standalone SDK library |
| `survey.js` | CSAT survey widget |

**State management:**
- Vuex 4 store modules in `app/javascript/dashboard/store/modules/` (conversations, inboxes, messages, contacts, etc.)
- Pinia 3 used in newer components (`app/javascript/dashboard/components-next/`)
- Vue 3 composables in `app/javascript/dashboard/composables/`

**API communication:**
- REST clients in `app/javascript/dashboard/api/` — one file per resource domain (e.g., `conversations.js`, `inbox/message.js`)
- All calls target `/api/v1/accounts/:account_id/` with a Bearer token from `deviseTokenAuth`
- ActionCable subscription via `@rails/actioncable` (configured in `dashboard/store` on auth)

**Realtime wiring in the frontend:**
- On login, the store subscribes to `RoomChannel` with `pubsub_token`
- Incoming ActionCable messages are dispatched as Vuex mutations / Pinia actions
- No polling — all live updates come through the WebSocket

**Assets and Vite Rails:**
- `vite.config.ts` at project root controls the build
- `app/views/layouts/vueapp.html.erb` includes Vite tag helpers
- In development, Vite dev server runs on port 3036 (see `Procfile.dev`)

---

## Authorization

**Pundit** policies in `app/policies/` enforce access control. `ApplicationPolicy` establishes the base rules (account membership, admin vs agent). Controllers call `authorize` before acting on records.

Key patterns:
- `current_user` and `current_account` injected by `ApplicationController`
- `ConversationPolicy` checks inbox membership and assignee status
- `InboxPolicy` checks admin role or `InboxMember` record
- `authorize` raises `Pundit::NotAuthorizedError` which controllers rescue into a 403

---

## Authentication

| Context | Mechanism |
|---|---|
| Dashboard (browser) | `devise_token_auth` — token in `access-token`, `client`, `uid` headers |
| Widget / Portal | `ContactInbox#pubsub_token` for WebSocket; separate widget API key |
| Webhook receivers | Provider-specific token/HMAC (not Devise) |
| Super admin | Devise session cookie |

Two-factor authentication is supported via `devise-two-factor`.

---

## Configuration Reference

Key environment variables for the fork-specific gowa provider:

| Variable | Purpose |
|---|---|
| `WHATSAPP_WEB_API_URL` | Base URL for gowa service (default `http://localhost:3001`) |
| `WHATSAPP_WEB_WEBHOOK_SECRET` | Shared secret for webhook verification (blank disables) |

Full environment variable reference: `.env.example` (289 lines in repo root).

Configuration files that affect architecture:
- `config/cable.yml` — ActionCable Redis adapter
- `config/sidekiq.yml` — queue definitions and concurrency
- `config/schedule.yml` — cron jobs
- `config/storage.yml` — Active Storage backend selection
- `config/llm.yml` — AI provider and model selection

---

## Known Architectural Issues (Fork-Specific)

See `CONCERNS.md` in `.planning/codebase/` for the full list. The highest-priority items for new engineers:

1. **Global phone number uniqueness** — `Channel::Whatsapp` has a database-level `UNIQUE` index on `phone_number` with no `account_id` scope (`app/models/channel/whatsapp.rb:33`, migration `20230426130150`). This blocks multi-tenant WhatsApp inbox creation with the same number across accounts.

2. **Webhook HMAC mismatch** — gowa sends `X-Hub-Signature-256`; `Webhooks::WhatsappWebController` checks `X-Webhook-Secret` (plain string). Cryptographic verification is absent in production unless manually implemented.

3. **Large inbound message service** — `app/services/whatsapp/incoming_message_whatsapp_web_service.rb` is 1374 lines handling all WhatsApp Web message types. It is a decomposition candidate but must be carefully tested due to its many code paths.

4. **Missing gowa webhook registration** — Device pairing does not auto-register the Chatwoot webhook URL with gowa. Admins must configure `gowa`'s callback URL manually post-pairing.

---

*Last updated: 2026-04-11 — covers fork state at commit `992589bc`*
