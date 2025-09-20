# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Chatwoot is a full-stack customer support platform built with **Rails 7.1** (backend) and **Vue 3** (frontend). The application provides omnichannel customer support with real-time messaging, team collaboration, and AI-powered assistance.

### Architecture

- **Backend**: Rails API with PostgreSQL, Redis, Sidekiq for background jobs
- **Frontend**: Vue 3 with Composition API, Vite build system, Tailwind CSS
- **Enterprise Edition**: `enterprise/` directory overlays and extends OSS functionality
- **Multi-app Structure**: Dashboard, Widget, SDK, Portal, Survey components

## Common Development Commands

### Setup
```bash
# Initial setup
bundle install && pnpm install
# or
make setup
```

### Development
```bash
# Start all services (preferred)
pnpm dev
# or
overmind start -f ./Procfile.dev
# or
make run

# Individual services
bundle exec rails server -p 3000    # Backend only
bin/vite dev                         # Frontend only
```

### Database
```bash
make db                              # Setup database (create + migrate + seed)
bundle exec rails db:create         # Create database
bundle exec rails db:migrate        # Run migrations
bundle exec rails db:seed           # Seed data
bundle exec rails db:reset          # Reset database
```

### Testing
```bash
# Frontend tests
pnpm test                           # Run all tests
pnpm test:watch                     # Watch mode
pnpm test:coverage                  # With coverage

# Backend tests
bundle exec rspec                   # All specs
bundle exec rspec spec/models/      # Specific directory
bundle exec rspec spec/path/to/file_spec.rb:42  # Single test at line
```

### Linting & Code Quality
```bash
# Frontend (ESLint)
pnpm eslint                         # Check JS/Vue files
pnpm eslint:fix                     # Auto-fix issues

# Backend (RuboCop)
bundle exec rubocop -a              # Check and auto-correct Ruby
pnpm ruby:prettier                  # Same as above
```

### Build & Assets
```bash
# Build SDK only
BUILD_MODE=library pnpm build:sdk

# Build all assets
bin/vite build

# Check bundle sizes
pnpm size
```

## Code Architecture

### Frontend Structure (`app/javascript/`)
- **`dashboard/`**: Main admin interface (Vue 3 components)
- **`widget/`**: Customer-facing chat widget
- **`sdk/`**: JavaScript SDK for embedding
- **`portal/`**: Customer self-service portal
- **`survey/`**: Customer feedback surveys
- **`shared/`**: Reusable utilities and helpers
- **`v3/`**: New component library (preferred for new development)
- **`entrypoints/`**: Vite entry points for different apps

### Backend Structure (`app/`)
- **`controllers/`**: API endpoints (follows Rails conventions)
- **`models/`**: ActiveRecord models with business logic
- **`services/`**: Business logic encapsulation (prefer over fat models)
- **`jobs/`**: Sidekiq background jobs
- **`policies/`**: Authorization logic (Pundit)
- **`builders/`**: Object construction and factory patterns
- **`listeners/`**: Event handling (Wisper pub/sub)
- **`finders/`**: Query object patterns

### Enterprise Edition (`enterprise/`)
- Overlays and extends OSS functionality
- Mirror OSS directory structure where applicable
- Always check for enterprise equivalents when modifying core features

## Development Guidelines

### Code Style Requirements

#### Ruby
- Follow RuboCop rules (150 character max line length)
- Use compact module/class definitions
- Validate presence/uniqueness in models, add proper indexes
- Use custom exceptions (`lib/custom_exceptions/`)
- Strong params in controllers

#### Vue/JS
- **Vue 3 Composition API only** with `<script setup>` at the top
- Use ESLint (Airbnb base + Vue 3 recommended)
- PascalCase for Vue components, camelCase for events
- PropTypes for type safety
- No bare strings in templates - use i18n

#### Styling
- **Tailwind CSS only** - do not write custom CSS or use scoped styles
- Use utility classes exclusively
- Refer to `tailwind.config.js` for color definitions
- Prefer `components-next/` for new message bubble components

### Testing
- Vitest for frontend tests (`app/**/*.{test,spec}.?(c|m)[jt]s?(x)`)
- RSpec for backend tests
- Add tests for new functionality
- Use `fake-indexeddb` for frontend storage tests

### Internationalization
- Backend: Update `config/locales/en.yml` only
- Frontend: Update `app/javascript/dashboard/i18n/locale/en.json` only
- Other languages handled by community via Crowdin

### Enterprise Compatibility
When modifying core functionality:
1. Search for related files in `enterprise/` directory
2. Use `rg -n "ServiceName|ControllerName|ModelName" app enterprise`
3. Maintain compatibility with enterprise overlays
4. Prefer configuration/feature flags over hardcoded behavior
5. Keep request/response contracts stable

### General Practices
- MVP focus: minimal code changes, happy-path implementation
- Break complex tasks into small, testable units
- Remove dead/unused code
- No defensive programming unless necessary
- Clear, descriptive naming with consistent casing

## Process Management

The application uses **Overmind** (preferred) or **Foreman** to manage multiple processes:

- `backend`: Rails server (port 3000)
- `worker`: Sidekiq for background jobs
- `vite`: Frontend asset building and hot reload

Debug individual processes:
```bash
make debug        # Connect to backend
make debug_worker # Connect to worker
```

## Environment & Dependencies

- **Node.js**: 23.x with pnpm 10.x
- **Ruby**: 3.4.4
- **Database**: PostgreSQL with Redis
- **Package Management**: Bundle (Ruby) + pnpm (Node.js)

## Key Configuration Files

- `package.json`: Frontend dependencies and scripts
- `Gemfile`: Ruby dependencies
- `vite.config.ts`: Frontend build configuration with special SDK mode
- `config/routes.rb`: API and frontend routing
- `Procfile.dev`: Development process definitions
- `Makefile`: Common development shortcuts