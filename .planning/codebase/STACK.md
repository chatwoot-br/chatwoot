# Technology Stack

**Analysis Date:** 2026-04-11

## Languages

**Primary:**
- Ruby 3.4.4 - Backend application framework
- JavaScript (ES6+) - Frontend and build tooling
- Vue.js 3.5.12 - Frontend UI framework

**Secondary:**
- SQL (PostgreSQL) - Database queries
- YAML - Configuration files

## Runtime

**Environment:**
- Ruby on Rails 7.1 - Web framework
- Node.js 24.13.0 - JavaScript runtime and build tools (via .nvmrc)
- Puma - Rails application server

**Package Manager:**
- Bundler - Ruby dependency management
- npm - JavaScript dependency management
- Lockfiles: `Gemfile.lock`, `package-lock.json`

## Frameworks

**Core Rails:**
- Rails 7.1 - Full-stack web framework (`Gemfile`)
- Action Cable 6.1.3 - WebSocket support for real-time messaging (`package.json`)
- Active Storage - File attachment handling
- Active Mailbox - Incoming email processing

**Frontend:**
- Vue 3.5.12 - Progressive JavaScript framework
- Vue Router 4.4.5 - Client-side routing
- Vuex 4.1.0 - State management
- Pinia 3.0.4 - Alternative state management
- Vite 5.4.21 - Build tool and development server
- Vite Rails - Rails/Vite integration (`Gemfile`)

**UI & Styling:**
- Tailwind CSS 3.4.19 - Utility-first CSS framework
- PostCSS 8.4.47 - CSS processing
- Chart.js 4.4.4 - Data visualization
- Vue-ChartJS 5.3.1 - Vue chart wrapper

**Editor & Rich Text:**
- ProseMirror Schema 1.3.7 - Collaborative document editing
- Markdown-it 14.1.1 - Markdown parsing
- DOMPurify 3.3.2 - HTML sanitization

**Form & Validation:**
- FormKit 1.7.2 - Vue form framework with validation
- Vuelidate 2.0.4 - Form validation library
- JSON Schema validation via `json_schemer` gem

**Testing:**
- Vitest 3.0.5 - Unit/integration test runner
- Vue Test Utils 2.4.6 - Vue component testing
- jsdom 27.2.0 - DOM simulation for tests
- fake-indexeddb 6.0.0 - IndexedDB mocking
- Faker - Test data generation (`Gemfile`)

**Build/Dev:**
- Vite 5.4.21 - Next-generation bundler
- Vite Plugin Vue - Vue 3 support for Vite
- Husky 7.0.0 - Git hooks for linting
- Lint-staged 16.2.7 - Pre-commit linting

**Code Quality:**
- ESLint 8.57.0 - JavaScript linting
- Prettier 3.3.3 - Code formatter (`.prettierrc`)
- RuboCop - Ruby linting (`.rubocop.yml`)
- Size-limit 8.2.4 - Bundle size tracking

**Documentation:**
- Histoire 0.17.15 - Component documentation tool

## Key Dependencies

**Critical Rails Gems:**

- `devise` 4.9.4+ - User authentication and session management
- `devise_token_auth` 1.2.3+ - Token-based authentication for APIs
- `devise-two-factor` 5.0.0+ - Two-factor authentication (MFA)
- `pundit` - Authorization and role-based access control
- `administrate` 0.20.1+ - Admin dashboard generation

**Data & Storage:**

- `pg` - PostgreSQL adapter
- `redis` - Redis client for caching and pub/sub
- `redis-namespace` - Redis key namespacing
- `activerecord-import` - Bulk record insertion
- `searchkick` - Full-text search via Elasticsearch/OpenSearch
- `opensearch-ruby` - OpenSearch client
- `pgvector` - PostgreSQL vector type support for embeddings
- `neighbor` - Cosine similarity via pgvector
- `pg_search` - Full-text search using PostgreSQL
- `hairtrigger` - Database trigger management

**Background Jobs & Async:**

- `sidekiq` 7.3.1+ - Background job processing
- `sidekiq-cron` 1.12.0+ - Cron job scheduling
- `sidekiq_alive` - Sidekiq health check endpoint
- `wisper` 2.0.0 - Pub/Sub event pattern for domain events

**Messaging & Communication:**

- `facebook-messenger` - Facebook Messenger Bot API
- `line-bot-api` - LINE messaging integration
- `twilio-ruby` - Twilio SMS and voice
- `twitty` 0.1.5 - Twitter/X streaming and API
- `koala` - Facebook Graph API client
- `slack-ruby-client` 2.7.0 - Slack API integration
- `telegram-bot-ruby` (implied from webhook) - Telegram bot integration

**Email & Mailbox:**

- `action_mailbox` - Incoming email processing
- `aws-actionmailbox-ses` 0.x - Amazon SES integration for incoming emails
- `gmail_xoauth` - Gmail OAuth2 authentication for sending
- `net-smtp` 0.3.4 - SMTP mail delivery
- `email_reply_trimmer` - Parse quoted replies in emails
- `html2text` - Convert HTML emails to plain text
- `email-provider-info` - Email domain information lookup

**AI & Language Models:**

- `ruby-openai` - OpenAI API client for GPT models
- `ai-agents` 0.9.1+ - Agent framework for autonomous tasks
- `ruby_llm` 1.8.2+ - Language model abstraction
- `ruby_llm-schema` - LLM schema validation
- `google-cloud-dialogflow-v2` 0.24.0+ - Google Dialogflow NLU
- `google-cloud-translate-v3` 0.7.0+ - Google Translate integration
- `cld3` 3.7 - Compact Language Detection 3

**Cloud Storage & CDN:**

- `aws-sdk-s3` - Amazon S3 storage
- `google-cloud-storage` 1.48.0+ - Google Cloud Storage
- `azure-storage-blob` - Azure Blob Storage (custom fork)
- `image_processing` - Image resizing and optimization

**Authentication & OAuth:**

- `omniauth` 2.1.2+ - Multi-provider authentication framework
- `omniauth-oauth2` - Generic OAuth2 strategy
- `omniauth-google-oauth2` 1.1.3+ - Google OAuth2
- `omniauth-saml` - SAML single sign-on
- `jwt` - JSON Web Token signing and verification
- `devise-secure_password` - Password strength validation (custom fork)

**Phone & Internationalization:**

- `libphonenumber-js` 1.11.9 - Phone number parsing and validation
- `telephone_number` - Phone number formatting
- `iso-639` - ISO 639 language code lookup
- `geocoder` - IP geolocation and address geocoding
- `maxminddb` - MaxMind GeoIP2 database parsing

**CRM & Integrations:**

- `shopify_api` - Shopify Admin API integration
- `stripe` 18.0 - Stripe payment processing

**Observability & Monitoring:**

- `sentry-rails` 5.19.0+ - Sentry error tracking (Rails)
- `sentry-ruby` - Sentry error tracking (Core)
- `sentry-sidekiq` 5.19.0+ - Sentry integration for Sidekiq
- `datadog` 2.0 - Datadog APM and monitoring
- `elastic-apm` - Elastic APM monitoring
- `newrelic_rpm` - New Relic APM monitoring
- `newrelic-sidekiq-metrics` 1.6.2+ - New Relic Sidekiq metrics
- `scout_apm` - Scout APM monitoring
- `lograge` 0.14.0 - Structured logging
- `barnes` - Heroku metrics reporting

**Utilities & Helpers:**

- `jbuilder` - JSON API template builder
- `kaminari` - Pagination
- `responders` 3.1.1+ - Responder pattern for controllers
- `rest-client` - HTTP client
- `down` - Safe remote file downloading
- `liquid` - Liquid template language for user-editable templates
- `commonmarker` - CommonMark Markdown processing
- `json_schemer` - JSON Schema validation
- `json_refs` - JSON reference resolution
- `rack-attack` 6.7.0+ - Request rate limiting and throttling
- `csv-safe` - CSV injection prevention
- `html_truncator` - HTML-aware text truncation
- `flag_shih_tzu` - Single-column binary flags for feature flags
- `haikunator` - Random name generation
- `audited` 5.4.1+ - Model audit logging
- `working_hours` - Business hours calculations
- `reverse_markdown` - HTML to Markdown conversion
- `time_diff` - Calculate time differences
- `tzinfo-data` - Timezone data
- `valid_email2` - Email validation
- `attr_extras` - Attribute accessors
- `hashie` - Hash utilities
- `acts-as-taggable-on` - Tagging support
- `browser` - User agent parsing

**Server & Infrastructure:**

- `foreman` - Procfile-based process management
- `dotenv-rails` 3.0.0+ - Environment variable loading
- `bootsnap` - Boot time optimization
- `uglifier` - JavaScript minification
- `rack-cors` 2.0.0 - CORS middleware

**OpenTelemetry & Observability:**

- `opentelemetry-sdk` - OpenTelemetry SDK
- `opentelemetry-exporter-otlp` - OTLP exporter for observability

## Configuration

**Environment Variables:**

Environment configuration via `.env.example` (289 lines). Key required variables:
- `SECRET_KEY_BASE` - Rails encryption key
- `FRONTEND_URL` - Application frontend URL
- `RAILS_ENV` - Application environment (development, test, production)
- `REDIS_URL` - Redis connection string
- `POSTGRES_HOST`, `POSTGRES_USERNAME`, `POSTGRES_PASSWORD` - Database credentials
- Channel-specific: `FB_VERIFY_TOKEN`, `FB_APP_SECRET`, `TWITTER_CONSUMER_KEY`, `SLACK_CLIENT_ID`, etc.
- Storage: `AWS_ACCESS_KEY_ID`, `GCS_PROJECT`, `AZURE_STORAGE_ACCOUNT_NAME`
- LLM: `OPENAI_API_KEY`
- Monitoring: `SENTRY_DSN`, `DATADOG_AGENT_URL`, `NEW_RELIC_LICENSE_KEY`
- WhatsApp Web: `WHATSAPP_WEB_API_URL`, `WHATSAPP_WEB_WEBHOOK_SECRET`

**Configuration Files:**

- `config/cable.yml` - ActionCable (WebSocket) configuration for real-time updates
- `config/storage.yml` - Active Storage backends (S3, GCS, Azure, local disk)
- `config/llm.yml` - LLM provider configuration (OpenAI, Anthropic, Gemini)
- `config/sidekiq.yml` - Sidekiq background job worker configuration
- `config/schedule.yml` - Scheduled job definitions
- `config/database.yml` - PostgreSQL database configuration
- `config/features.yml` - Feature flag definitions
- `config/newrelic.yml` - New Relic APM configuration
- `config/elastic_apm.yml` - Elastic APM configuration
- `config/scout_apm.yml` - Scout APM configuration
- `.env.example` - Environment variable template (289 lines)
- `.rubocop.yml` - Ruby code style linting rules
- `.eslintrc.js` - JavaScript/Vue linting rules
- `.prettierrc` - Code formatting rules
- `.nvmrc` - Node.js version specification (24.13.0)
- `package.json` - npm dependencies and scripts (179 lines)
- `Gemfile` - Ruby dependencies (274 lines)

## Build & Development

**Procfiles:**

- `Procfile` - Production process management (release, web, worker)
- `Procfile.dev` - Development process definitions
- `Procfile.test` - Test environment process definitions
- `Procfile.tunnel` - Tunneling for external integrations

**Scripts:**

From `package.json`:
- `npm test` - Run tests with Vitest
- `npm test:watch` - Watch mode for tests
- `npm test:coverage` - Coverage reporting
- `npm run dev` - Start development with Overmind
- `npm run start:dev` - Start with Foreman
- `npm run eslint:fix` - Auto-fix JavaScript linting issues
- `npm run ruby:prettier` - Auto-fix Ruby linting with RuboCop
- `npm run build:sdk` - Build SDK library output

## Platform Requirements

**Development:**
- Ruby 3.4.4
- Node.js 24.13.0
- PostgreSQL 13+ (recommended)
- Redis 6.0+ (for caching and pub/sub)
- Optional: Elasticsearch/OpenSearch (for full-text search)

**Production:**
- Ruby 3.4.4
- PostgreSQL (tested on 13+)
- Redis (for Sidekiq and Action Cable)
- Storage backend: AWS S3, Google Cloud Storage, Azure Blob Storage, or local filesystem
- Supported platforms: Linux (Docker), Heroku, self-hosted

---

*Stack analysis: 2026-04-11*
