# Codebase Structure

**Analysis Date:** 2026-04-11

## Directory Layout

```
/workspace/chatwoot/
├── app/                           # Rails application code (MVC + services)
├── lib/                           # Library code (utilities, constants, helpers)
├── config/                        # Rails configuration (routes, initializers, database.yml)
├── db/                            # Database migrations and seeds
├── spec/                          # RSpec test suite
├── app/javascript/                # Frontend code (Vue SPA + shared modules)
├── enterprise/                    # Enterprise features (optional license module)
├── swagger/                       # API documentation (OpenAPI/Swagger spec)
├── public/                        # Static assets (favicons, robots.txt)
├── bin/                           # Executable scripts (rails, rake, bundle)
├── storage/                       # Local file uploads (dev only)
├── .devcontainer/                 # Docker development environment configuration
├── docker/                        # Docker build files and entrypoints
├── config/locales/                # i18n translation files (EN, PT, etc.)
└── .github/                       # GitHub Actions workflows, issue templates
```

## Directory Purposes

**app/** - Core Rails application code

**app/controllers/**
- Purpose: HTTP request handlers, routing entry point
- Contains: Base controllers, API controllers (v1/v2), webhook handlers, dashboard, widget, public endpoints
- Key subdirectories:
  - `api/v1/accounts/` — Dashboard API (conversations, inboxes, contacts, messages)
  - `api/v2/` — Newer API version (enterprise)
  - `webhooks/` — External provider webhooks (WhatsApp, Instagram, SMS, etc.)
  - `concerns/` — Shared controller concerns (auth helpers, response handling)
  - `devise_overrides/` — Devise authentication customization
  - `super_admin/` — Super admin panel controllers

**app/models/**
- Purpose: Data models and business logic associations
- Contains: 56 model files
- Key models:
  - `account.rb` — Account (tenant) root model
  - `user.rb` — User account member
  - `conversation.rb` — Message thread
  - `message.rb` — Individual message
  - `contact.rb` — External entity (customer)
  - `contact_inbox.rb` — Contact-to-channel association
  - `inbox.rb` — Channel instance (scoped per account)
  - `channel/` — Channel provider subclasses (WhatsApp, Email, SMS, Facebook, Instagram, TikTok, Telegram, Line, WebWidget)
  - `application_record.rb` — Base class (multi-tenancy validations, length constraints)
- Subdirectories:
  - `channel/` — STI subclasses for different communication channels
  - `concerns/` — Model concerns (scopes, associations, callbacks)
  - `integrations/` — Integration model associations

**app/services/**
- Purpose: Business logic layer, service objects
- Contains: 51 service directories
- Pattern: Classes ending in `Service`, single responsibility, dependency injection
- Key services:
  - `conversations/` — Conversation operations (filter, assignment, message_window)
  - `contacts/` — Contact sync, bulk operations
  - `channels/` — Channel-specific logic (WhatsApp message formatting, Facebook polling)
  - `conversations_` — Message parsing, conversation creation
  - `internal/` — Platform integrations (Slack, Slack Channel, Slack Contact)
  - `email/` — Email parsing and sending
  - `facebook/` — Facebook Graph API operations
  - `instagram/` — Instagram webhooks and sync
  - `whatsapp/` — WhatsApp message formatting, media handling
- Example files:
  - `app/services/whatsapp/incoming_message_base_service.rb` — Parse WhatsApp webhook message
  - `app/services/conversations/filter_service.rb` — Apply filters to conversation queries

**app/builders/**
- Purpose: Complex object construction, creation logic
- Contains: Builder classes for account, contact, conversation, message creation
- Key builders:
  - `account_builder.rb` — Create account with initial user
  - `contact_inbox_with_contact_builder.rb` — Create contact + contact_inbox + associations
  - `conversation_builder.rb` — Create conversation from message
  - `messages/message_builder.rb` — Build message from webhook payload
- Pattern: `.perform` method returns created object(s)
- Location: `app/builders/`

**app/listeners/**
- Purpose: Event handlers that react to domain events
- Contains: Singleton listener classes
- Key listeners:
  - `action_cable_listener.rb` — Broadcast messages/conversation updates to WebSocket clients
  - `webhook_listener.rb` — Queue external webhooks when conversation/message changes
  - `notification_listener.rb` — Create notifications for mentions/assignments
  - `automation_rule_listener.rb` — Trigger automation rules
  - `reporting_event_listener.rb` — Log reporting events for analytics
- Pattern: Inherit from `BaseListener`, register with dispatcher, called on model events
- Location: `app/listeners/`

**app/dispatchers/**
- Purpose: Event hub, route model change events to listeners
- Contains: Dispatcher singleton, sync/async routing
- Key files:
  - `dispatcher.rb` — Main dispatcher, loads listeners
  - `sync_dispatcher.rb` — Call listeners synchronously
  - `async_dispatcher.rb` — Queue listeners as Sidekiq jobs
- Pattern: Called from model callbacks, invokes all registered listeners for event type
- Location: `app/dispatchers/`

**app/jobs/**
- Purpose: Asynchronous background job workers
- Contains: 35+ Sidekiq job classes
- Key jobs:
  - `webhooks/whatsapp_events_job.rb` — Process WhatsApp webhook payloads
  - `webhooks/whatsapp_web_events_job.rb` — Process WhatsApp Web provider events
  - `action_cable_broadcast_job.rb` — Realtime message broadcast
  - `conversations/` — Message send, conversation update jobs
  - `channels/` — Channel sync, webhook setup jobs
  - `inboxes/` — Inbox setup, status sync
  - `notification/` — Notification creation and delivery
- Location: `app/jobs/`

**app/channels/**
- Purpose: ActionCable WebSocket channel subscriptions
- Contains: Realtime connection and room channel management
- Key files:
  - `room_channel.rb` — Subscribe/unsubscribe to conversation updates
  - `application_cable/connection.rb` — Authenticate WebSocket connections
  - `application_cable/channel.rb` — Base channel behavior
- Pattern: WebSocket channels for dashboard/portal realtime updates
- Location: `app/channels/`

**app/policies/**
- Purpose: Authorization rules (Pundit)
- Contains: Policy class for each model
- Key policies:
  - `application_policy.rb` — Base policy (admin/account membership checks)
  - `conversation_policy.rb` — Conversation access (assignee, inbox member)
  - `inbox_policy.rb` — Inbox access (admin, inbox member)
- Pattern: `allow?` methods check `current_user`, `current_account`
- Location: `app/policies/`

**app/presenters/**
- Purpose: Format data for API/realtime responses
- Contains: Presenter wrapper classes
- Examples:
  - `message_content_presenter.rb` — Format message body (render links, mentions)
  - `mail_presenter.rb` — Parse email headers, extract body from MIME
  - `conversations/conversation_presenter.rb` — List conversation data
- Location: `app/presenters/`

**app/finders/**
- Purpose: Query builders, search optimization
- Contains: Finder classes for expensive queries
- Examples:
  - `conversation_finder.rb` — Search, filter, sort conversations
  - `message_finder.rb` — Find messages with eager loading
  - `notification_finder.rb` — List notifications with unread counts
- Location: `app/finders/`

**app/mailers/**
- Purpose: Email sending (ActionMailer)
- Contains: Mailer classes for notifications, password reset, etc.
- Location: `app/mailers/`

**app/helpers/**
- Purpose: View helpers and utility methods
- Contains: Helper modules for controllers/views
- Location: `app/helpers/`

**app/views/**
- Purpose: ERB templates for non-SPA endpoints
- Contains: Email templates, error pages, Devise views
- Location: `app/views/`

**app/javascript/** - Frontend code (Vue 3 + TypeScript)

**app/javascript/dashboard/**
- Purpose: Agent dashboard SPA
- Contains: Vue components, API client, Vuex store, i18n
- Structure:
  - `App.vue` — Root component
  - `api/` — API client classes (conversations, messages, inboxes, contacts, etc.)
  - `components/` — Reusable Vue components (ChatList, ConversationItem, etc.)
  - `components-next/` — Next-gen component library (gradual migration)
  - `composables/` — Vue 3 composables (state management, hooks)
  - `helper/` — Utility functions (date formatting, URL parsing, etc.)
  - `store/` — Vuex store modules (conversations, inboxes, messages, contacts)
  - `routes/` — Vue Router configuration
  - `i18n/` — Translation strings (EN, PT, ES, etc.)
- Key files:
  - `app/javascript/dashboard/App.vue` — Main app layout
  - `app/javascript/dashboard/api/conversations.js` — Conversation API client
  - `app/javascript/dashboard/store/modules/conversations.js` — Conversation state

**app/javascript/widget/**
- Purpose: Embeddable chat widget for websites
- Contains: Widget component, minimal API client, iframe delivery
- Structure:
  - `App.vue` — Widget UI
  - `api/` — Widget API client (limited endpoints)
  - `components/` — Widget UI elements
  - `store/` — Widget state (messages, conversation, visitor info)
  - `router.js` — Widget internal routing
- Pattern: Bundled as standalone asset, inserted into 3rd-party websites via `<script>` tag

**app/javascript/portal/**
- Purpose: Customer self-service portal
- Contains: Portal SPA for customers to view conversations
- Structure:
  - `components/` — Portal UI components
  - `api/` — Portal API client
  - `portalHelpers.js` — Portal configuration helpers
  - `specs/` — Portal tests
- Pattern: Lightweight, read-only interface for customers

**app/javascript/shared/**
- Purpose: Shared code (components, utilities, design system)
- Contains: Reusable components, constants, helpers
- Location: `app/javascript/shared/`

**app/javascript/sdk/**
- Purpose: Standalone SDK for third-party integration
- Contains: SDK bundled separately from dashboard
- Usage: `import Chatwoot from '@chatwoot/web-widget'`

**app/javascript/v3/**
- Purpose: Next-gen component library (Vue 3 + Tailwind)
- Contains: Refactored components for future use
- Pattern: Gradual migration from older component patterns

**app/javascript/survey/**
- Purpose: CSAT/survey widget
- Contains: Survey builder components, form submission logic
- Location: `app/javascript/survey/`

**app/javascript/entrypoints/**
- Purpose: Webpack entry points for each frontend app
- Contains: Separate bundles for dashboard, widget, portal, SDK
- Files:
  - `dashboard.js` — Dashboard SPA entry
  - `widget.js` — Chat widget entry
  - `portal.js` — Customer portal entry
  - `sdk.js` — Standalone SDK entry
  - `v3app.js` — Next-gen components entry
  - `survey.js` — Survey widget entry
- Pattern: Each entrypoint bundles independently

**lib/** - Ruby library code

**lib/current.rb**
- Purpose: Thread-local context for multi-tenancy
- Pattern: `Current.account`, `Current.user`, `Current.account_user` thread attributes
- Usage: Set in controller before_action, reset after request

**lib/custom_exceptions/**
- Purpose: Custom exception classes
- Contains: Namespaced exceptions (Account, Channel, etc.)
- Location: `lib/custom_exceptions/`

**lib/integrations/**
- Purpose: Third-party service integration adapters
- Contains: Adapters for external APIs (Linear, Slack, Dyte, etc.)
- Location: `lib/integrations/`

**lib/events/**
- Purpose: Event types and event system
- Location: `lib/events/`

**config/** - Rails configuration

**config/routes.rb**
- Purpose: Define HTTP routes
- Contains: API routes, webhook routes, mounted engines
- Pattern: Namespaced under `/api/v1/accounts/:account_id/` for dashboard API

**config/initializers/**
- Purpose: Boot-time initialization
- Contains: Sidekiq config, ActionCable config, AWS S3, Redis, Devise setup
- Location: `config/initializers/`

**db/** - Database

**db/migrate/**
- Purpose: Database schema migrations
- Contains: 120+ migration files
- Pattern: Timestamped files, one schema change per file

**db/seeds.rb**
- Purpose: Seed initial data (dev environment)

**spec/** - Test suite

**spec/models/**
- Purpose: Model unit tests
- Pattern: RSpec tests, one spec file per model
- Examples: `spec/models/conversation_spec.rb`, `spec/models/message_spec.rb`

**spec/services/**
- Purpose: Service class unit tests
- Pattern: RSpec tests with mocks/stubs

**spec/jobs/**
- Purpose: Background job tests

**spec/requests/**
- Purpose: API integration tests
- Pattern: Test full request/response cycle

**spec/policies/**
- Purpose: Authorization policy tests

**enterprise/** - Enterprise features (optional)

**enterprise/app/**
- Purpose: Enterprise-only features
- Contains: Controllers, models, services for licensed features
- Pattern: Prepended into app via Rails engines (enterprise features override/extend base)

**swagger/** - API documentation

**swagger/v1/**
- Purpose: OpenAPI/Swagger specification files
- Contains: YAML definitions for API endpoints
- Usage: Auto-generated API docs, used by Swagger UI

## Key File Locations

**Entry Points:**

- **Dashboard API Routes:** `config/routes.rb` → `/api/v1/accounts/:account_id/*`
- **Webhook Handler:** `app/controllers/webhooks/whatsapp_controller.rb` → `POST /webhooks/whatsapp`
- **Dashboard App:** `app/javascript/dashboard/App.vue`
- **Widget App:** `app/javascript/widget/App.vue`
- **Portal App:** `app/javascript/portal/`
- **Dashboard Entrypoint:** `app/javascript/entrypoints/dashboard.js`

**Core Models:**

- **Conversation Logic:** `app/models/conversation.rb`
- **Message Logic:** `app/models/message.rb`
- **Channel Definition:** `app/models/channel.rb` + `app/models/channel/*.rb`
- **Inbox Setup:** `app/models/inbox.rb`
- **Account/Tenant:** `app/models/account.rb`
- **Contact/Visitor:** `app/models/contact.rb`

**Business Logic:**

- **Webhook Processing:** `app/jobs/webhooks/whatsapp_events_job.rb`
- **Message Creation:** `app/builders/messages/message_builder.rb`
- **WhatsApp Formatting:** `app/services/whatsapp/incoming_message_base_service.rb`
- **Conversation Filtering:** `app/services/conversations/filter_service.rb`
- **Notification Publishing:** `app/listeners/action_cable_listener.rb`

**Realtime:**

- **WebSocket Channel:** `app/channels/room_channel.rb`
- **ActionCable Config:** `config/cable.yml`
- **Realtime Listener:** `app/listeners/action_cable_listener.rb`

**Configuration:**

- **Database:** `config/database.yml`
- **Sidekiq:** `config/sidekiq.yml`
- **Rails:** `config/application.rb`, `config/environments/*.rb`
- **Environment Variables:** `.env.example`

## Naming Conventions

**Files:**

- Controllers: `[resource]_controller.rb` (e.g., `conversations_controller.rb`)
- Models: `[singular_noun].rb` (e.g., `conversation.rb`, `message.rb`)
- Services: `[domain]_service.rb` or `[action]_service.rb` (e.g., `filter_service.rb`, `sync_service.rb`)
- Builders: `[resource]_builder.rb` (e.g., `contact_inbox_builder.rb`)
- Jobs: `[action]_job.rb` (e.g., `whatsapp_events_job.rb`)
- Listeners: `[event]_listener.rb` (e.g., `action_cable_listener.rb`)
- Policies: `[model]_policy.rb` (e.g., `conversation_policy.rb`)
- Vue Components: `PascalCase.vue` (e.g., `ChatList.vue`, `ConversationItem.vue`)

**Directories:**

- By feature domain: `conversations/`, `contacts/`, `channels/`, `inboxes/`
- By layer: `app/controllers/`, `app/services/`, `app/builders/`, etc.
- By channel type: `app/models/channel/`, `app/services/whatsapp/`, `app/services/instagram/`, etc.
- By API version: `app/controllers/api/v1/`, `app/controllers/api/v2/`

## Where to Add New Code

**New Feature (e.g., incoming SMS message handling):**

- Model migration: `db/migrate/[timestamp]_add_sms_fields.rb`
- Service logic: `app/services/sms/incoming_message_service.rb`
- Webhook controller: `app/controllers/webhooks/sms_controller.rb`
- Job processor: `app/jobs/webhooks/sms_events_job.rb`
- Builder: `app/builders/messages/sms_builder.rb` (if complex)
- Listener (if needs realtime): `app/listeners/` (extend `ActionCableListener`)
- Tests: `spec/services/sms/incoming_message_service_spec.rb`
- Frontend API client: `app/javascript/dashboard/api/sms.js` (if dashboard needs it)

**New Component/Module (e.g., conversation filter panel):**

- Vue Component: `app/javascript/dashboard/components/ConversationFilterPanel.vue`
- API Client: `app/javascript/dashboard/api/filters.js` (if backend endpoint needed)
- Controller: `app/controllers/api/v1/accounts/conversations_controller.rb#filter_action`
- Service: `app/services/conversations/filter_service.rb` (if complex logic)
- Vuex Store: `app/javascript/dashboard/store/modules/conversations.js` (state management)

**Utility/Helper:**

- Ruby utilities: `lib/[feature].rb` or `lib/[feature]/` directory
- Vue composables: `app/javascript/dashboard/composables/[feature].ts`
- Vue helpers: `app/javascript/shared/helpers/[feature].js`
- Controller concerns: `app/controllers/concerns/[feature]_concern.rb`
- Model concerns: `app/models/concerns/[feature]_concern.rb`

**Tests:**

- RSpec model tests: `spec/models/[model]_spec.rb`
- RSpec service tests: `spec/services/[domain]/[service]_spec.rb`
- RSpec request tests: `spec/requests/api/v1/[resource]_spec.rb`
- Vue unit tests: `spec/javascript/[component]_spec.js`
- Vue integration tests: `spec/features/[feature]_spec.rb` (Capybara)

## Special Directories

**storage/**
- Purpose: Local file uploads (development only)
- Generated: Yes (ActiveStorage local storage)
- Committed: No (in .gitignore)

**.devcontainer/**
- Purpose: Docker development environment configuration
- Generated: No
- Committed: Yes
- Contents: Dockerfile.devx, docker-compose.yml, setup.sh scripts

**docker/**
- Purpose: Production Dockerfile and entrypoint scripts
- Contents: `dockerfiles/Dockerfile` (production image), `entrypoints/` (startup scripts)
- Committed: Yes

**public/**
- Purpose: Static assets (favicons, robots.txt, sitemap)
- Generated: No (some assets may be built here)
- Committed: Mostly (except compiled assets)

**enterprise/**
- Purpose: Enterprise-only features (licensed module)
- Generated: No
- Committed: Yes (separate repo history may be merged)

**swagger/**
- Purpose: API documentation (OpenAPI spec)
- Generated: Partially (manually maintained)
- Committed: Yes

---

*Structure analysis: 2026-04-11*
