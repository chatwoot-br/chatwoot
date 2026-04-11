# Architecture

**Analysis Date:** 2026-04-11

## Pattern Overview

**Overall:** Rails MVC monolith with service-oriented architecture, event-driven message processing, and decoupled realtime synchronization

**Key Characteristics:**
- Multi-tenant account scoping via `Current` thread-local context
- Request flow separation: dashboard (Vue SPA) vs webhook handlers vs public widget/portal
- Event-driven architecture with sync/async dispatchers and listeners
- Background job queue (Sidekiq) for async tasks
- Realtime updates via ActionCable WebSocket channels
- Builder pattern for complex object creation
- Service objects for business logic isolation
- Policy objects for authorization
- Multiple channel providers (WhatsApp, email, SMS, Facebook, Instagram, etc.)

## Layers

**Controller Layer:**
- Purpose: HTTP request handling, parameter validation, authentication
- Location: `app/controllers/`
- Contains: API controllers (`api/v1/`, `api/v2/`), webhook handlers (`webhooks/`), dashboard controller, widget controller, public endpoints
- Depends on: Services, Models, Policies
- Used by: HTTP clients (frontend SPAs, external webhooks, mobile apps)

**Service Layer:**
- Purpose: Encapsulate business logic, transaction coordination, external service integration
- Location: `app/services/`
- Contains: Service classes organized by domain (conversations, contacts, channels, etc.)
- Depends on: Models, external APIs, builders, dispatchers
- Used by: Controllers, Jobs, other services

**Model Layer:**
- Purpose: Data persistence and relationships
- Location: `app/models/`
- Contains: Active Record models, validations, associations, scopes, callbacks
- Depends on: Database, validators, concerns
- Used by: Controllers, Services, Jobs, Builders

**Builder Layer:**
- Purpose: Complex object construction with business logic
- Location: `app/builders/`
- Contains: Account builder, contact builders, message builders, conversation builder
- Pattern: Encapsulates creation of related objects (e.g., `ContactInboxWithContactBuilder` creates contact, contact_inbox, and associations)
- Depends on: Models, Services
- Used by: Controllers, Services, Jobs

**Listeners (Event Handlers):**
- Purpose: React to domain events, coordinate side effects
- Location: `app/listeners/`
- Contains: `ActionCableListener` (realtime broadcast), `WebhookListener` (send webhooks), `NotificationListener`, `AutomationRuleListener`
- Pattern: Registered with event dispatcher, called sync/async after model changes
- Depends on: Models, Services, Presenters
- Used by: Dispatcher (event hub)

**Dispatchers (Event Hub):**
- Purpose: Publish domain events and route to listeners
- Location: `app/dispatchers/`
- Contains: `Dispatcher` (singleton), `SyncDispatcher`, `AsyncDispatcher`
- Pattern: Singleton dispatchers load listeners and invoke them on events (e.g., message.created)
- Depends on: Listeners, services
- Used by: Models (via ActiveSupport callbacks)

**Background Jobs:**
- Purpose: Asynchronous task execution
- Location: `app/jobs/`
- Contains: Job classes for webhooks, channel sync, message processing, notifications, background tasks
- Pattern: Sidekiq workers extending `ApplicationJob`
- Depends on: Models, Services
- Used by: Controllers, Services, Listeners, Delayed actions

**Realtime Layer (ActionCable):**
- Purpose: WebSocket-based realtime updates to dashboard/portal
- Location: `app/channels/`
- Contains: `RoomChannel` (conversation updates), `ApplicationCable::Connection/Channel`
- Depends on: Models, Presenters
- Used by: Frontend (dashboard, portal via ActionCable JS)

**Authorization Layer:**
- Purpose: Access control
- Location: `app/policies/`
- Contains: Pundit policy classes (one per model)
- Pattern: `CanCanCan`-style policies with `allow?` methods
- Depends on: Models, Current user/account context
- Used by: Controllers, API endpoints

**Presenters:**
- Purpose: Format data for API responses or realtime broadcast
- Location: `app/presenters/`
- Contains: Message presenter, mail presenter, conversation presenters
- Pattern: Wrap model with presentation logic (format fields, compute derived data)
- Depends on: Models
- Used by: Listeners, Controllers, Serializers

**Finders:**
- Purpose: Query optimization and filtering
- Location: `app/finders/`
- Contains: `ConversationFinder`, `MessageFinder`, `NotificationFinder`
- Pattern: Chainable query builders with filters applied via services
- Depends on: Models, scopes
- Used by: Controllers, Services

## Data Flow

### Inbound WhatsApp Message (Webhook → Chat)

1. **Webhook Entry:** `Webhooks::WhatsappController.process_payload`
   - Validates webhook token against `Channel::Whatsapp` provider config
   - Enqueues `Webhooks::WhatsappEventsJob` with payload

2. **Background Job Processing:** `Webhooks::WhatsappEventsJob`
   - Receives webhook event (message, status, read receipt)
   - Routes to message/status handler based on event type
   - Calls `Whatsapp::ReceiveMessageService` or status service

3. **Message Builder:** Message builders parse channel-specific format into `Conversation` and `Message`
   - `Whatsapp::IncomingMessageBaseService` extracts body, media, contact
   - Creates/finds `Contact` via phone number
   - Creates/finds `ContactInbox` (association of contact to inbox)
   - Creates/finds `Conversation` thread
   - Creates `Message` record with attachment metadata

4. **Event Dispatch:** Model save triggers dispatcher
   - `Message.created` event triggers `Dispatcher.dispatch`
   - Loads sync listeners: `ActionCableListener`, `WebhookListener`, `NotificationListener`
   - Loads async listeners via `AsyncDispatcher` → Sidekiq

5. **Realtime Broadcast:** `ActionCableListener.message_created`
   - Formats `Message` via `MessageContentPresenter`
   - Broadcasts to `RoomChannel` (conversation participants subscribed)
   - Frontend receives via ActionCable, updates message list

6. **External Webhooks:** `WebhookListener` queues `HookJob`
   - Finds account webhooks for `message.created` event
   - Enqueues async dispatch to external webhook URLs

**State Management:**
- **Conversation State:** `status` (open/resolved/snoozed), `assignee`, `labels`, `priority`
- **Message State:** `message_type` (incoming/outgoing), `status` (sent/delivered/read)
- **Contact State:** `name`, `email`, `phone`, `custom attributes`, `labels`
- Account isolation via `account_id` foreign key + `Current.account` validation

## Key Abstractions

**Channel (Provider):**
- Purpose: Abstract communication channel (WhatsApp, Email, SMS, etc.)
- Examples: `Channel::Whatsapp`, `Channel::Email`, `Channel::FacebookPage`, `Channel::WebWidget`
- Pattern: Single-table inheritance (STI) on `Channel` model
- Location: `app/models/channel/`

**Inbox (Channel Instance):**
- Purpose: Account-specific instance of a channel (1 account may have multiple WhatsApp numbers)
- Examples: `Inbox` records with `channel_id`, `account_id`, `name`
- Pattern: Many-to-one with Channel, scoped per Account
- Responsibilities: Configuration storage (e.g., auto-reply settings), team member assignment
- Location: `app/models/inbox.rb`

**Conversation:**
- Purpose: Thread of messages between contact and account
- Location: `app/models/conversation.rb`
- Attributes: `contact_id`, `inbox_id`, `account_id`, `status`, `assignee`, `subject`
- Relationships: Has many Messages, belongs to Contact, Inbox, Account

**Message:**
- Purpose: Individual message in conversation
- Location: `app/models/message.rb`
- Attributes: `conversation_id`, `account_id`, `body`, `message_type` (incoming/outgoing), `source_id`
- Relationships: Belongs to Conversation, optional Attachments

**Contact:**
- Purpose: External entity (customer/user) communicating via channels
- Location: `app/models/contact.rb`
- Attributes: `name`, `email`, `phone`, `identifier`, `custom attributes`
- Relationships: Has many ContactInbox (associations to channels), Conversations

**ContactInbox:**
- Purpose: Association of Contact to Inbox (phone number mapped to WhatsApp inbox)
- Location: `app/models/contact_inbox.rb`
- Attributes: `contact_id`, `inbox_id`, `source_id` (channel-specific identifier like phone_number)
- Pattern: Junction table enabling multi-channel contact identification

## Entry Points

**API Endpoints (Dashboard):**
- Location: `config/routes.rb` + `app/controllers/api/v1/accounts/`
- Pattern: RESTful JSON API under `/api/v1/accounts/{account_id}/`
- Examples: 
  - `GET /api/v1/accounts/:account_id/conversations` (list)
  - `POST /api/v1/accounts/:account_id/conversations/:conversation_id/messages` (send)
  - `PATCH /api/v1/accounts/:account_id/conversations/:conversation_id` (update status)

**Webhook Entry Points:**
- Location: `app/controllers/webhooks/`
- Pattern: POST endpoints for external provider webhooks
- Examples:
  - `POST /webhooks/whatsapp` (WhatsApp messages, status updates)
  - `POST /webhooks/instagram` (Instagram DM events)
  - `POST /webhooks/line` (LINE platform webhook)

**Frontend Entrypoints:**
- Location: `app/javascript/entrypoints/`
- Examples:
  - `dashboard.js` → `app/javascript/dashboard/App.vue` (agent dashboard SPA)
  - `widget.js` → `app/javascript/widget/App.vue` (chat widget for website)
  - `portal.js` → `app/javascript/portal/` (customer portal)
  - `sdk.js` → standalone SDK for third-party sites

**Realtime Subscriptions:**
- Location: `app/channels/room_channel.rb`
- Pattern: ActionCable channel subscriptions scoped by conversation/account
- Usage: Dashboard and portal subscribe to room channels for live message updates

## Error Handling

**Strategy:** Rails exception rescue in controllers, custom exception classes, event dispatching for critical errors

**Patterns:**
- `CustomExceptions::*` (namespaced exception classes in `lib/custom_exceptions/`)
- `rescue_from` in controllers with custom error responses
- `handle_with_exception` before_action wraps controller methods
- Sentry integration for error tracking (via `ChatwootExceptionTracker`)
- Graceful degradation: webhook failures logged but don't crash (enqueued as job)

## Cross-Cutting Concerns

**Logging:** 
- Standard Rails logger + Sentry integration
- Request logging via middleware
- Job logging via Sidekiq

**Validation:** 
- Active Record validations in models
- Custom validators in `app/validators/`
- Pundit policies for authorization
- Request-level validation in controllers

**Authentication:** 
- Session-based (Devise) for dashboard
- JWT tokens for API (Bearer tokens in headers)
- Webhook verification (HMAC or provider-specific tokens)
- Multi-account scoping via `set_current_user` before_action + `Current.account` context

**Tenant Isolation:** 
- All models have `account_id` foreign key
- `Current.account` thread-local set in controller before_action
- Scope queries via `.where(account: Current.account)` or association filters
- Policy objects validate account membership before allowing access

---

*Architecture analysis: 2026-04-11*
