# Project Context

## Purpose

Chatwoot is an open-source customer support platform and alternative to Intercom, Zendesk, and Salesforce Service Cloud. The platform helps businesses deliver exceptional customer support by centralizing conversations across multiple channels (web chat, email, Facebook, Instagram, Twitter, WhatsApp, Telegram, Line, SMS, etc.) into a unified inbox.

**Key Features:**
- **Omnichannel Support Desk**: Centralized inbox for all customer conversations
- **Captain AI Agent**: Automated AI-powered support to handle common queries
- **Help Center Portal**: Self-service knowledge base with articles, FAQs, and guides
- **Team Collaboration**: Private notes, @mentions, labels, canned responses, auto-assignment
- **Customer Management**: Contact profiles, segmentation, custom attributes, interaction history
- **Integrations**: Slack, Dialogflow, Shopify, Linear, Google Translate, and more
- **Reporting & Analytics**: Real-time monitoring, CSAT reports, conversation/agent/team reports

## Tech Stack

### Backend
- **Framework**: Ruby on Rails 7.1 on Ruby 3.4.4
- **Database**: PostgreSQL with pgvector extension (vector similarity for AI/ML)
- **Cache/Queue**: Redis + Sidekiq 7.3.1+ for background jobs
- **Search**: Searchkick with OpenSearch/Elasticsearch
- **Authentication**: Devise 4.9.4+, JWT, OAuth2, SAML, 2FA
- **Authorization**: Pundit (role-based access control)
- **Server**: Puma
- **Monitoring**: Sentry, Datadog, New Relic, Scout APM, Elastic APM

### Frontend
- **Framework**: Vue 3.5.12 (Composition API with `<script setup>`)
- **Build Tool**: Vite 5.4.20 with vite-plugin-ruby
- **Styling**: Tailwind CSS 3.4.13 (utility-first, no custom CSS)
- **State**: Vuex 4.1.0
- **Routing**: Vue Router 4.4.5
- **Testing**: Vitest 3.0.5 + @vue/test-utils
- **Component Stories**: Histoire 0.17.15
- **Linting**: ESLint (Airbnb base + Vue 3 recommended)
- **Package Manager**: pnpm 10.x on Node 23.x

### Key Integrations & Libraries
- **Communication Channels**: Facebook Messenger, Twilio, Line Bot, Slack, Twitter
- **AI/ML**: ruby-openai, ai-agents, pgvector (neighbor gem)
- **Storage**: AWS S3, Azure Blob, Google Cloud Storage (ActiveStorage)
- **Email**: Gmail xOAuth, net-smtp
- **Billing**: Stripe
- **Templating**: Liquid
- **Markdown**: Commonmarker
- **Event System**: Wisper (pub/sub)

## Project Conventions

### Code Style

**Ruby:**
- Follow RuboCop rules (150 character max line length)
- Use compact `module/class` definitions (avoid nested styles)
- Strong params for controllers
- Custom exceptions in `lib/custom_exceptions/`
- Models: validate presence/uniqueness, add proper indexes

**Vue/JavaScript:**
- Use ESLint (Airbnb base + Vue 3 recommended)
- **Always use Vue 3 Composition API** with `<script setup>` at the top
- PascalCase for component names
- camelCase for events
- Mandatory i18n: No bare strings in templates
- PropTypes validation required

**Styling:**
- **Tailwind Only**: Do NOT write custom CSS, scoped CSS, or inline styles
- Always use Tailwind utility classes
- Refer to `tailwind.config.js` for color definitions

**Naming & Structure:**
- Clear, descriptive names with consistent casing
- Break down complex tasks into small, testable units
- Remove dead/unreachable/unused code
- No defensive programming unless necessary (MVP focus)

### Architecture Patterns

**1. Monolithic Rails API + Vue SPA**
- Rails serves JSON API (versioned: v1, v2)
- Multiple Vue 3 frontend applications:
  - `app/javascript/dashboard/` - Agent dashboard
  - `app/javascript/widget/` - Live chat widget
  - `app/javascript/portal/` - Knowledge base
  - `app/javascript/survey/` - Customer surveys
- Vite handles frontend bundling for all apps

**2. Enterprise Edition Pattern**
- OSS core functionality in `/app`
- Enterprise overrides/extensions in `/enterprise/app`
- Use `prepend_mod_with` hooks for extensions
- Keep request/response contracts stable across OSS and EE
- Avoid hardcoding instance-specific behavior in OSS

**3. Multi-Channel Abstraction**
- Unified channel interface for messaging platforms
- Individual channel implementations (`app/models/channel/`)
- Event-driven architecture using Wisper pub/sub
- Channel-specific controllers and services

**4. Background Processing**
- Sidekiq for async jobs (`app/jobs/`, `app/workers/`)
- Sidekiq-cron for scheduled tasks (`config/schedule.yml`)
- Redis for job storage
- Separate worker process in development

**5. Service-Oriented Architecture**
- Business logic in `app/services/`
- Query builders in `app/finders/`
- Object builders in `app/builders/`
- Event listeners in `app/listeners/`
- Presenters in `app/presenters/`

**6. Real-time Communication**
- ActionCable for WebSocket connections (`app/channels/`)
- Redis as ActionCable adapter
- Live updates for conversations, notifications, presence

### Testing Strategy

**Ruby (RSpec):**
- Test files in `spec/` mirror `app/` structure
- Run: `bundle exec rspec spec/path/to/file_spec.rb`
- Single test: `bundle exec rspec spec/path/to/file_spec.rb:LINE_NUMBER`
- **Do NOT write specs unless explicitly asked**
- Focus on integration tests for API endpoints
- Enterprise-specific specs in `spec/enterprise/`

**JavaScript (Vitest):**
- Test files: `*.spec.js` or `*.test.js`
- Run: `pnpm test` or `pnpm test:watch`
- Coverage: `pnpm test:coverage`
- Use `@vue/test-utils` for component testing
- Mock API calls with Vitest mocks
- **Do NOT write tests unless explicitly asked**

**General Testing Principles:**
- Focus on happy-path scenarios (MVP approach)
- Avoid over-testing edge cases unless critical
- Break down complex logic into testable units
- Integration tests for API contracts

### Git Workflow

**Branching Model:**
- Base branch: `next` (for PRs and feature development)
- Stable branch: `master` (production-ready code)
- Release branches: `release/v4.7` (current release)
- Feature branches: `username/feature-name` format
- Follow git-flow model

**Commit Conventions:**
- Use Conventional Commits: `type(scope): description`
- Types: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`
- Example: `feat(inbox): add multi-select for conversations`
- **IMPORTANT**: Do NOT include Claude attribution in commit messages
- Keep commits focused and atomic
- Write clear, descriptive commit messages focusing on "why" not "what"

**PR Workflow:**
1. Create feature branch from `next`
2. Make changes with conventional commits
3. Run linters: `pnpm eslint:fix` and `bundle exec rubocop -a`
4. Create PR targeting `next` branch
5. Include test plan and summary in PR description

## Domain Context

**Customer Support Domain:**
- **Conversations**: Central entity representing a customer interaction across any channel
- **Inbox**: Logical grouping of conversations by channel or team
- **Contacts**: Customer profiles with history, attributes, and segments
- **Agents**: Support team members who respond to conversations
- **Teams**: Groups of agents organized by function or product
- **Labels**: Tags for categorizing conversations
- **Canned Responses**: Pre-written replies for common questions
- **SLA (Service Level Agreement)**: Response time expectations
- **CSAT (Customer Satisfaction)**: Post-conversation ratings
- **Business Hours**: Operating hours for automated responses

**Multi-Channel Support:**
- Each channel (email, web chat, WhatsApp, etc.) has its own adapter
- Messages normalized into common format across channels
- Channel-specific features (attachments, media, quick replies) abstracted
- Webhooks for incoming messages from external platforms

**AI/ML Integration:**
- **Captain**: AI agent that handles common queries automatically
- Vector embeddings for semantic search and similarity matching
- Dialogflow integration for chatbot automation
- OpenAI integration for response suggestions

## Important Constraints

**Technical Constraints:**
- PostgreSQL required (uses pgvector extension)
- Redis required (for Sidekiq and ActionCable)
- Node 23.x and pnpm 10.x for frontend builds
- Ruby 3.4.4 for backend
- No custom CSS (Tailwind only)
- All Vue components must use Composition API with `<script setup>`

**Translation Constraints:**
- **ONLY update `en.yml` (backend) and `en.json` (frontend)**
- Other languages managed by community via Crowdin
- Never modify non-English translation files directly

**Enterprise Edition Constraints:**
- Keep OSS/EE contracts stable (API compatibility)
- Check for `enterprise/` overrides before modifying core files
- Use extension points (hooks, feature flags) for EE-specific logic
- Mirror OSS file structure in `enterprise/` tree

**Performance Constraints:**
- Widget bundle size limit: 300 KB
- SDK bundle size limit: 40 KB
- Use lazy loading for non-critical components
- Optimize database queries (add indexes, use includes/joins)

**Security Constraints:**
- No secrets in `.env` files committed to git
- Use strong params for all controller actions
- Validate user input with Pundit policies
- Sanitize HTML content with DOMPurify
- CSRF protection enabled

## External Dependencies

**Required Services:**
- PostgreSQL 12+ (with pgvector extension)
- Redis 6+ (cache, Sidekiq, ActionCable)
- OpenSearch/Elasticsearch (search functionality)
- SMTP server (email notifications)
- Storage provider (AWS S3, Azure Blob, or GCS)

**Optional Integrations:**
- **Messaging Platforms**: Facebook, Instagram, Twitter, WhatsApp (via Twilio), Telegram, Line, SMS
- **AI/ML**: OpenAI (GPT models), Google Dialogflow
- **Monitoring**: Sentry, Datadog, New Relic, Scout APM, Elastic APM
- **Translation**: Google Translate API
- **Authentication**: Google OAuth2, SAML SSO
- **Billing**: Stripe
- **E-commerce**: Shopify
- **Project Management**: Linear
- **Team Chat**: Slack

**Development Tools:**
- Overmind or Foreman (process management)
- Docker & Docker Compose (optional local setup)
- Heroku or DigitalOcean (deployment options)

## MCP Tool Integration

### Serena MCP Tools
When working with the codebase, use Serena MCP tools for intelligent, semantic code exploration and editing:

**Code Navigation & Search:**
- `mcp__serena__get_symbols_overview` - Get high-level overview of symbols in a file
- `mcp__serena__find_symbol` - Search for symbols by name/path with depth control
- `mcp__serena__find_referencing_symbols` - Find all references to a symbol
- `mcp__serena__search_for_pattern` - Flexible pattern search across codebase
- `mcp__serena__list_dir` - List files and directories efficiently
- `mcp__serena__find_file` - Find files matching patterns

**Code Editing (Symbol-based):**
- `mcp__serena__replace_symbol_body` - Replace entire symbol definitions precisely
- `mcp__serena__insert_before_symbol` - Insert code before a symbol
- `mcp__serena__insert_after_symbol` - Insert code after a symbol
- `mcp__serena__rename_symbol` - Rename symbols across entire codebase

**Project Memory:**
- `mcp__serena__write_memory` - Store project-specific knowledge for future tasks
- `mcp__serena__read_memory` - Retrieve stored project knowledge
- `mcp__serena__list_memories` - View available project memories

**Onboarding & Setup:**
- `mcp__serena__check_onboarding_performed` - Check if project setup is complete
- `mcp__serena__onboarding` - Initialize project understanding
- `mcp__serena__think_about_collected_information` - Verify gathered context is complete
- `mcp__serena__think_about_task_adherence` - Ensure staying on track with requirements

### Context7 MCP Tools
For library documentation and code examples:

**Library Documentation:**
- `mcp__context7__resolve-library-id` - Find the correct library ID from package name
- `mcp__context7__get-library-docs` - Retrieve up-to-date documentation for any library
  - Useful for Rails, Vue 3, Tailwind CSS, and all project dependencies
  - Provides code examples and best practices

### Tool Usage Best Practices

**For Code Exploration:**
1. Start with `mcp__serena__get_symbols_overview` to understand file structure
2. Use `mcp__serena__find_symbol` with appropriate depth to explore specific symbols
3. Track references with `mcp__serena__find_referencing_symbols`
4. Only read full files when absolutely necessary (token efficiency)

**For Code Editing:**
1. Prefer symbol-based editing tools over line-based when modifying entire functions/classes
2. Use `mcp__serena__replace_symbol_body` for complete symbol replacements
3. Use `mcp__serena__insert_before_symbol` for imports and top-level additions
4. Always check for Enterprise Edition overrides before modifying core files

**For Documentation:**
1. Use `mcp__context7__resolve-library-id` first to get the correct library ID
2. Then use `mcp__context7__get-library-docs` with specific topics for targeted docs
3. Reference documentation when implementing framework-specific features
