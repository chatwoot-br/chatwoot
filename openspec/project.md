# Project Context

## Purpose

Chatwoot is an open-source customer engagement platform that provides:
- Omnichannel live chat and support inbox
- Multi-channel messaging (web widget, email, social media, SMS)
- Team collaboration for customer support
- AI-powered response assistance and automation
- Help center / knowledge base
- Reporting and analytics

This is the **Chatwoot Brazil** fork, customized for Brazilian deployment.

## Tech Stack

### Backend
- **Ruby**: 3.4.4 (managed via rbenv)
- **Rails**: 7.1.x
- **Database**: PostgreSQL with pgvector extension (vector search)
- **Cache/Pub-Sub**: Redis with redis-namespace
- **Background Jobs**: Sidekiq with sidekiq-cron
- **Search**: OpenSearch via Searchkick
- **Full-text Search**: pg_search (articles)

### Frontend
- **Framework**: Vue 3 (Composition API with `<script setup>`)
- **Build Tool**: Vite 5.x via vite_rails
- **State Management**: Pinia (migrating from Vuex)
- **Styling**: Tailwind CSS 3.x (no custom CSS)
- **Testing**: Vitest 3.x
- **Package Manager**: pnpm 10.x
- **Node.js**: 23.x

### Real-time
- **WebSockets**: Action Cable (@rails/actioncable)

### Key Libraries
- **Authentication**: Devise with devise_token_auth, devise-two-factor
- **Authorization**: Pundit
- **API Documentation**: Jbuilder
- **Pagination**: Kaminari
- **Tagging**: acts-as-taggable-on
- **AI/LLM**: ruby-openai, ai-agents, ruby_llm
- **Templating**: Liquid

## Project Conventions

### Code Style

**Ruby:**
- Follow RuboCop rules (150 char max line length)
- Use compact `module/class` definitions (avoid nested styles)
- Custom exceptions in `lib/custom_exceptions/`
- Validate presence/uniqueness in models; add proper indexes

**Vue/JS:**
- ESLint (Airbnb base + Vue 3 recommended)
- Component names: PascalCase
- Events: camelCase
- Always use Composition API with `<script setup>` at top
- No bare strings in templates; use i18n

**CSS:**
- Tailwind utility classes ONLY
- No custom CSS, scoped CSS, or inline styles
- Color definitions in `tailwind.config.js`

### Architecture Patterns

**Backend:**
- Standard Rails MVC with service objects (`app/services/`)
- Builders for complex object construction (`app/builders/`)
- Finders for complex queries (`app/finders/`)
- Listeners for event-driven logic (`app/listeners/`)
- Dispatchers for notification routing (`app/dispatchers/`)
- Presenters for view logic (`app/presenters/`)
- Policies for authorization (Pundit)
- Pub/sub via Wisper gem

**Frontend:**
- Components in `app/javascript/dashboard/` and `app/javascript/widget/`
- New message components in `components-next/` (legacy being deprecated)
- Store modules in `app/javascript/dashboard/store/`
- API helpers in `app/javascript/dashboard/api/`

**Enterprise Overlay:**
- Enterprise features under `enterprise/` directory
- Extends OSS code via `prepend_mod_with` / `include_mod_with`
- Check both `app/` and `enterprise/app/` when modifying core logic
- Enterprise specs go under `spec/enterprise/`

### Testing Strategy

**Ruby (RSpec):**
- Run: `bundle exec rspec spec/path/to/file_spec.rb`
- Single test: `bundle exec rspec spec/path/to/file_spec.rb:LINE_NUMBER`
- Use `with_modified_env` over stubbing `ENV` directly
- Enterprise specs mirror OSS layout under `spec/enterprise/`

**JavaScript (Vitest):**
- Run: `pnpm test` or `pnpm test:watch`
- Coverage: `pnpm test:coverage`

### Git Workflow

- **Branch naming**: `username/feature-name`
- **Commits**: Conventional commits - `type(scope): description`
  - Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`
  - Example: `feat(auth): add two-factor authentication`
- **Main branch**: `next`
- No Claude/AI attribution in commit messages

## Domain Context

### Core Concepts
- **Account**: Top-level organization container
- **Inbox**: A channel endpoint (web widget, email, Facebook, etc.)
- **Conversation**: Thread between contact and agents
- **Contact**: Customer/end-user
- **Agent**: Support team member
- **Team**: Group of agents
- **Label**: Tag for categorizing conversations
- **Canned Response**: Saved reply templates
- **Automation Rule**: Workflow automation triggers
- **SLA Policy**: Service level agreements
- **Portal**: Help center / knowledge base
- **Article**: Knowledge base content

### Channel Integrations
- Web widget (live chat SDK)
- Email (IMAP/SMTP, Microsoft, Google)
- Facebook Messenger
- Twitter/X
- WhatsApp (via Twilio, 360dialog)
- Telegram
- Line
- SMS (Twilio)
- API channel

## Important Constraints

- **Translations**: Only modify `en.yml` (backend) and `en.json` (frontend); other languages are community-maintained
- **Enterprise Compatibility**: Always check `enterprise/` for related files when modifying core functionality
- **MVP Focus**: Ship happy path first; avoid unnecessary defensive programming
- **No Over-engineering**: Minimal code changes; avoid premature abstraction
- **Process Management**: Use `overmind start -f Procfile.dev` for development

## External Dependencies

### Cloud Storage
- AWS S3
- Azure Blob Storage
- Google Cloud Storage

### Messaging Channels
- Twilio (SMS, WhatsApp, Voice)
- Facebook Graph API
- Slack API
- Line Bot API
- Telegram Bot API

### AI/ML Services
- OpenAI API (GPT models)
- Google Dialogflow
- Google Translate
- Vector embeddings (pgvector)

### Monitoring/APM
- Sentry (error tracking)
- NewRelic
- Datadog
- Scout APM
- Elastic APM

### Authentication
- Google OAuth
- Microsoft OAuth (OIDC)
- SAML SSO

### Payments
- Stripe (subscriptions/billing)

### Push Notifications
- Firebase Cloud Messaging (FCM)
- Web Push (VAPID)
