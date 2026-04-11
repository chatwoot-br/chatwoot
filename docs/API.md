<!-- generated-by: gsd-doc-writer -->
# API Map

Chatwoot exposes a large HTTP API surface divided into several groups. This document is a **navigable map** — it describes what exists, how authentication works, and where to find source code. It does not enumerate every endpoint. The canonical endpoint reference is the OpenAPI spec in `swagger/`.

---

## Swagger / OpenAPI Reference

The machine-readable API spec lives at `swagger/swagger.json` (OpenAPI 3.1.0). A browsable HTML UI is served at `/swagger` when the Rails server is running.

Key swagger source files:

| File | Purpose |
|------|---------|
| `swagger/index.yml` | Root spec: servers, security schemes, tag groups |
| `swagger/paths/application/` | Dashboard API (v1 account-scoped) path definitions |
| `swagger/paths/platform/` | Platform API path definitions |
| `swagger/paths/profile/` | Profile API path definitions |
| `swagger/paths/public/` | Public widget/contact API path definitions |
| `swagger/paths/survey/` | CSAT survey path definitions |
| `swagger/definitions/` | Shared schema objects (resources, errors, requests) |
| `swagger/parameters/` | Reusable parameter objects |
| `swagger/tag_groups/` | Sidebar groupings for the Swagger UI |

To browse locally:

```bash
rails server
# then open http://localhost:3000/swagger
```

---

## Authentication

All authenticated API groups use the same header name but different token types. The header is always:

```
api_access_token: <token>
```

### Token types

| Token type | Swagger security scheme | Who holds it | Source |
|-----------|------------------------|-------------|--------|
| User API key | `userApiKey` | Individual agent/admin — obtain from profile settings page or `User#access_token` | `app/controllers/concerns/access_token_auth_helper.rb` |
| Agent Bot API key | `agentBotApiKey` | Agent bot records — obtained via rails console or POST `/api/v1/accounts/:id/agent_bots` | `app/controllers/concerns/access_token_auth_helper.rb` |
| Platform App API key | `platformAppApiKey` | System admin — created in Super Admin under Platform Apps | `app/controllers/platform/` (validated via `validate_platform_app_permissible`) |

The `AccessTokenAuthHelper` concern (`app/controllers/concerns/access_token_auth_helper.rb`) resolves the `api_access_token` header to an `AccessToken` record and sets `Current.user`. Platform controllers run a separate `validate_platform_app_permissible` before-action instead.

### Session-based auth (dashboard frontend)

The frontend uses `devise_token_auth` mounted at `/auth`. Session tokens (`access-token`, `uid`, `client` headers) are issued on sign-in and are not interchangeable with API access tokens.

### Bot endpoint restrictions

Agent Bot tokens are restricted to a hard-coded allow-list in `AccessTokenAuthHelper::BOT_ACCESSIBLE_ENDPOINTS`:

- `api/v1/accounts/conversations` — `toggle_status`, `toggle_typing_status`, `toggle_priority`, `create`, `update`, `custom_attributes`
- `api/v1/accounts/conversations/messages` — `create`
- `api/v1/accounts/conversations/assignments` — `create`

---

## API Groups

### 1. Dashboard API — `/api/v1/accounts/:account_id/`

The primary application API. All routes are scoped under an account ID. Requires a `userApiKey` or `agentBotApiKey` token. Controllers live in `app/controllers/api/v1/accounts/`.

**Base controller:** `app/controllers/api/v1/accounts/base_controller.rb`

Representative resource groups and their controller paths:

| Resource group | Example endpoints | Controller |
|---------------|-------------------|------------|
| Conversations | `GET /conversations`, `POST /conversations`, `POST /conversations/:id/toggle_status` | `app/controllers/api/v1/accounts/conversations_controller.rb` |
| Messages | `GET /conversations/:id/messages`, `POST /conversations/:id/messages` | `app/controllers/api/v1/accounts/conversations/messages_controller.rb` |
| Contacts | `GET /contacts`, `POST /contacts/filter`, `POST /contacts/import` | `app/controllers/api/v1/accounts/contacts_controller.rb` |
| Inboxes | `GET /inboxes`, `POST /inboxes/:id/register_webhook`, `GET /inboxes/:id/health` | `app/controllers/api/v1/accounts/inboxes_controller.rb` |
| Agents | `GET /agents`, `POST /agents/bulk_create` | `app/controllers/api/v1/accounts/agents_controller.rb` |
| Labels | `GET /labels`, `POST /labels` | `app/controllers/api/v1/accounts/labels_controller.rb` |
| Automation rules | `GET /automation_rules`, `POST /automation_rules/:id/clone` | `app/controllers/api/v1/accounts/automation_rules_controller.rb` |
| Macros | `GET /macros`, `POST /macros/:id/execute` | `app/controllers/api/v1/accounts/macros_controller.rb` |
| Search | `GET /search`, `GET /search/conversations`, `GET /search/contacts` | `app/controllers/api/v1/accounts/search_controller.rb` |
| CSAT responses | `GET /csat_survey_responses`, `GET /csat_survey_responses/metrics` | `app/controllers/api/v1/accounts/csat_survey_responses_controller.rb` |
| Portals (Help Center) | `GET /portals`, `GET /portals/:slug/articles` | `app/controllers/api/v1/accounts/portals_controller.rb` |
| Captain (AI) | `GET /captain/assistants`, `POST /captain/tasks/summarize` | `app/controllers/api/v1/accounts/captain/` |
| Integrations | `GET /integrations/apps`, `POST /integrations/hooks`, `GET /integrations/slack/list_all_channels` | `app/controllers/api/v1/accounts/integrations/` |
| Webhooks (outbound) | `GET /webhooks`, `POST /webhooks` | `app/controllers/api/v1/accounts/webhooks_controller.rb` (not to be confused with inbound webhook ingress) |
| WhatsApp Web devices | `POST /integrations/whatsapp_web/devices`, `GET /integrations/whatsapp_web/devices/:id/qr_code` | `app/controllers/api/v1/accounts/` (namespace `whatsapp_web`) |

The full route tree for this group starts at line ~43 of `config/routes.rb` under `namespace :api > namespace :v1 > resources :accounts`.

### 2. Reports API — `/api/v2/accounts/:account_id/`

Reporting endpoints split into a separate v2 namespace for independent versioning. Controllers live in `app/controllers/api/v2/accounts/`.

| Endpoint | Controller |
|----------|------------|
| `GET /api/v2/accounts/:id/reports` | `app/controllers/api/v2/accounts/reports_controller.rb` |
| `GET /api/v2/accounts/:id/reports/summary` | `app/controllers/api/v2/accounts/summary_reports_controller.rb` |
| `GET /api/v2/accounts/:id/reports/agents/live` | `app/controllers/api/v2/accounts/live_reports_controller.rb` |
| `GET /api/v2/accounts/:id/reports/year_in_review` | `app/controllers/api/v2/accounts/year_in_reviews_controller.rb` |

### 3. Platform API — `/platform/api/v1/`

Provisioning API for system integrators building multi-tenant deployments. Requires a `platformAppApiKey` token issued to a Platform App record. Controllers live in `app/controllers/platform/api/v1/`.

| Resource | Example endpoints | Controller |
|----------|-------------------|------------|
| Accounts | `GET /accounts`, `POST /accounts`, `DELETE /accounts/:id` | `app/controllers/platform/api/v1/accounts_controller.rb` |
| Account Users | `GET /accounts/:id/account_users`, `POST /accounts/:id/account_users` | `app/controllers/platform/api/v1/account_users_controller.rb` |
| Users | `POST /users`, `GET /users/:id/login` | `app/controllers/platform/api/v1/users_controller.rb` |
| Agent Bots | `GET /agent_bots`, `POST /agent_bots` | `app/controllers/platform/api/v1/agent_bots_controller.rb` |

Routes defined at line ~504 of `config/routes.rb` under `namespace :platform`.

### 4. Public / Widget API — `/public/api/v1/`

Unauthenticated (or contact-token-authenticated) API consumed by the live-chat widget and CSAT survey pages. Controllers live in `app/controllers/public/api/v1/`.

| Resource | Example endpoints | Controller |
|----------|-------------------|------------|
| Contacts | `POST /inboxes/:id/contacts`, `GET /inboxes/:id/contacts/:contact_id` | `app/controllers/public/api/v1/inboxes/contacts_controller.rb` |
| Conversations | `GET /inboxes/:id/contacts/:contact_id/conversations`, `POST /conversations/:id/toggle_typing` | `app/controllers/public/api/v1/inboxes/conversations_controller.rb` |
| Messages | `GET /conversations/:id/messages`, `POST /conversations/:id/messages` | `app/controllers/public/api/v1/inboxes/messages_controller.rb` |
| CSAT survey | `GET /csat_survey/:id`, `PUT /csat_survey/:id` | `app/controllers/public/api/v1/csat_survey_controller.rb` |

Help Center (portal) public routes follow the pattern `GET /hc/:slug/:locale/articles/:slug` and are handled by `app/controllers/public/api/v1/portals/` controllers.

Widget-specific routes (live-chat widget session management) are under `/api/v1/widget/` — see `namespace :widget` in `config/routes.rb` around line 406.

### 5. Profile API — `/api/v1/profile`

Per-user profile management. Requires a `userApiKey`. Source: `app/controllers/api/v1/profiles_controller.rb`.

Example endpoints: `GET /api/v1/profile`, `PUT /api/v1/profile`, `POST /api/v1/profile/availability`, `POST /api/v1/profile/reset_access_token`.

### 6. Inbound Webhook Ingress — `POST /webhooks/*`

These routes receive payloads from third-party channel providers. They are **not** authenticated with `api_access_token` — each has its own verification scheme. Controllers live in `app/controllers/webhooks/`.

| Route | Controller | Channel |
|-------|-----------|---------|
| `POST /webhooks/whatsapp/:phone_number` | `app/controllers/webhooks/whatsapp_controller.rb` | WhatsApp Cloud API (Meta) |
| `POST /webhooks/whatsapp_web` | `app/controllers/webhooks/whatsapp_web_controller.rb` | WhatsApp Web / gowa (fork addition — see below) |
| `POST /webhooks/telegram/:bot_token` | `app/controllers/webhooks/telegram_controller.rb` | Telegram |
| `POST /webhooks/line/:line_channel_id` | `app/controllers/webhooks/line_controller.rb` | LINE |
| `POST /webhooks/sms/:phone_number` | `app/controllers/webhooks/sms_controller.rb` | SMS (Twilio/Bandwidth) |
| `GET /webhooks/instagram` / `POST /webhooks/instagram` | `app/controllers/webhooks/instagram_controller.rb` | Instagram |
| `POST /webhooks/tiktok` | `app/controllers/webhooks/tiktok_controller.rb` | TikTok |
| `POST /webhooks/shopify` | `app/controllers/webhooks/shopify_controller.rb` | Shopify |
| `GET /webhooks/twitter` / `POST /webhooks/twitter` | Handled via `api/v1/webhooks_controller.rb` | Twitter/X |
| `POST /enterprise/webhooks/stripe` | `webhooks/stripe` controller | Stripe (enterprise only) |

---

## Rate Limiting

Rate limiting is implemented with `Rack::Attack` (`config/initializers/rack_attack.rb`). It is **enabled only in production** (`Rails.env.production?`) and can be toggled with `ENABLE_RACK_ATTACK=false`.

The backing store is Redis (`$velma` connection pool).

### Throttle rules

| Rule | Limit | Window | Key |
|------|-------|--------|-----|
| Global per IP | `RACK_ATTACK_LIMIT` (default 3000) | 1 minute | IP address |
| Login by IP | 5 attempts | 5 minutes | IP address |
| Login by email | 10 attempts | 15 minutes | Email (lowercased) |
| Super admin login by IP | 5 attempts | 5 minutes | IP address |
| Super admin login by email | 5 attempts | 15 minutes | Email |
| Password reset by IP | 5 attempts | 30 minutes | IP address |
| Password reset by email | 5 attempts | 1 hour | Email |
| Resend confirmation by IP | 5 attempts | 30 minutes | IP address |
| MFA verification by IP | 5 attempts | 1 minute | IP address |
| MFA login by IP | 10 attempts | 1 minute | IP address |
| Account creation (signup) | 5 | 30 minutes | IP address |
| Widget conversation creation | 6 | 12 hours | IP address |
| Widget contact update | 60 | 1 hour | IP address |
| `GET /conversations/meta` | `RATE_LIMIT_CONVERSATIONS_META` (default 30) | 1 minute | User identifier + account ID |
| `POST /conversations/:id/transcript` | `RATE_LIMIT_CONVERSATION_TRANSCRIPT` (default 1000) | 1 hour | Account ID |
| `POST /upload` | 60 | 1 hour | Account ID |
| `GET /contacts/search` | `RATE_LIMIT_CONTACT_SEARCH` (default 100) | 1 minute | Account ID |
| Reports API (per user) | `RATE_LIMIT_REPORTS_API_USER_LEVEL` (default 100) | 1 minute | User identifier + account ID |
| Reports API (per account) | `RATE_LIMIT_REPORTS_API_ACCOUNT_LEVEL` (default 1000) | 1 minute | Account ID |

Widget API throttling can be disabled entirely with `ENABLE_RACK_ATTACK_WIDGET_API=false`.

Trusted IPs bypass all throttles: `127.0.0.1`, `::1`, and any addresses in `RACK_ATTACK_ALLOWED_IPS` (comma-separated). The `/health` endpoint is also safelisted unconditionally.

Blocked requests are logged at `WARN` level with IP, path, user identifier (masked token), and account ID.

---

## Fork-Specific Additions

The following routes and controllers are additions in this fork and are not present in upstream Chatwoot.

### WhatsApp Web webhook ingress

**Route:** `POST /webhooks/whatsapp_web`
**Controller:** `app/controllers/webhooks/whatsapp_web_controller.rb`

This endpoint receives events from [gowa](https://github.com/aldinokemal/go-whatsapp-web-multidevice) (the Go-based WhatsApp Web gateway). It is the inbound counterpart to the WhatsApp Web channel provider added in this fork.

**Authentication:** Shared secret checked via `X-Webhook-Secret` header (or `webhook_secret` query param). Secret is read from `WHATSAPP_WEB_WEBHOOK_SECRET` environment variable. If the variable is unset, verification is skipped (dev/test mode).

**Behaviour:**
1. Extracts `device_id` from the payload.
2. Resolves the `Channel::WhatsappWeb` record via `WhatsappWebChannelFinder`.
3. Rejects payloads for unknown or inactive channels (returns 404 / 422 respectively).
4. Enqueues `Webhooks::WhatsappWebEventsJob` for async processing.
5. Returns `200 OK` immediately.

### WhatsApp Web device management API

**Routes** (under `/api/v1/accounts/:account_id/integrations/whatsapp_web/devices`):

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/devices` | Register a new WhatsApp Web device (inbox) |
| `GET` | `/devices/:id/qr_code` | Retrieve QR code for device pairing |
| `GET` | `/devices/:id/status` | Check device connection status |
| `POST` | `/devices/:id/reconnect` | Trigger reconnection to gowa |
| `POST` | `/devices/:id/logout` | Log out and deregister device |
| `POST` | `/devices/:id/sync_history` | Initiate history sync for the device |

Routes are defined in `config/routes.rb` under `namespace :whatsapp_web` inside the `accounts` scope (lines ~300-310).

---

## Finding an Endpoint's Source

1. Identify the URL pattern (e.g., `PATCH /api/v1/accounts/5/conversations/12/toggle_status`).
2. Search `config/routes.rb` for the resource name or action (`toggle_status`).
3. The route entry maps to a controller — e.g., `scope module: :conversations` inside `resources :accounts` means the controller is `app/controllers/api/v1/accounts/conversations_controller.rb`.
4. Cross-reference `swagger/paths/` for the documented request/response schema.

Quick grep shortcut:

```bash
grep -n "toggle_status" /workspace/chatwoot/config/routes.rb
grep -rn "def toggle_status" /workspace/chatwoot/app/controllers/
```
