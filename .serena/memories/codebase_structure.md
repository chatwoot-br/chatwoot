# Chatwoot Codebase Structure

## Root Directory Structure

### Core Application Directories
- **`app/`** - Main Rails application code
  - `assets/` - Static assets (images, fonts)
  - `controllers/` - Rails controllers for handling requests
  - `models/` - ActiveRecord models for database entities
  - `views/` - Server-rendered views and templates
  - `javascript/` - Vue.js frontend application
  - `services/` - Service objects for business logic
  - `jobs/` - ActiveJob background jobs
  - `workers/` - Sidekiq workers for async processing
  - `mailers/` - Email templates and mailer classes
  - `channels/` - ActionCable channels for WebSocket
  - `helpers/` - Rails view helpers
  - `policies/` - Pundit authorization policies
  - `presenters/` - Presenter objects for view logic
  - `builders/` - Builder pattern implementations
  - `finders/` - Complex query objects
  - `listeners/` - Event listeners (wisper)
  - `dispatchers/` - Event dispatchers
  - `drops/` - Liquid template drops
  - `mailboxes/` - ActionMailbox for incoming emails
  - `dashboards/` - Administrate dashboard configs
  - `fields/` - Custom Administrate fields

### Configuration & Setup
- **`config/`** - Rails configuration files
  - `routes.rb` - Application routing
  - `database.yml` - Database configuration
  - `application.rb` - Main application config
  - `environments/` - Environment-specific configs
  - `locales/` - Backend i18n translations

### Database
- **`db/`** - Database related files
  - `migrate/` - Database migrations
  - `seeds.rb` - Seed data for development
  - `schema.rb` - Current database schema

### Tests
- **`spec/`** - RSpec test suite
  - `models/` - Model specs
  - `controllers/` - Controller specs
  - `services/` - Service specs
  - `jobs/` - Job specs
  - `factories/` - FactoryBot factories
  - `support/` - Test helpers and configuration
  - `enterprise/` - Enterprise edition specs

### Libraries & Extensions
- **`lib/`** - Custom libraries and modules
  - `custom_exceptions/` - Custom exception classes
  - `integrations/` - Third-party integrations
  - `tasks/` - Rake tasks

### Enterprise Edition
- **`enterprise/`** - Enterprise edition overlay
  - Mirrors main app structure
  - Overrides and extends OSS functionality
  - Contains premium features

### Frontend Assets
- **`public/`** - Static public files
  - `vite/` - Vite build output
  - `packs/` - Webpack bundles (legacy)

### Development Tools
- **`bin/`** - Executable scripts
- **`.github/`** - GitHub configuration and workflows
- **`.circleci/`** - CircleCI configuration
- **`docker/`** - Docker configurations
- **`deployment/`** - Deployment scripts and configs

### Documentation & Config Files
- **Root config files**:
  - `package.json` - Node.js dependencies
  - `Gemfile` - Ruby dependencies
  - `Procfile.dev` - Development process manager
  - `.env.example` - Environment variables template
  - `.rubocop.yml` - Ruby linting rules
  - `.eslintrc.js` - JavaScript linting rules
  - `tailwind.config.js` - Tailwind CSS configuration
  - `vite.config.ts` - Vite build configuration

### Special Directories
- **`openspec/`** - OpenSpec change proposals
- **`.serena/`** - Serena tool configuration
- **`.claude/`** - Claude AI assistant instructions
- **`vendor/`** - Vendored dependencies
- **`tmp/`** - Temporary files (gitignored)
- **`log/`** - Application logs (gitignored)

## Key File Patterns

### Ruby Files
- Controllers: `app/controllers/*_controller.rb`
- Models: `app/models/*.rb`
- Services: `app/services/*_service.rb`
- Jobs: `app/jobs/*_job.rb`
- Workers: `app/workers/*_worker.rb`

### Vue/JavaScript Files
- Components: `app/javascript/dashboard/components/**/*.vue`
- Store modules: `app/javascript/dashboard/store/modules/*.js`
- API services: `app/javascript/dashboard/api/*.js`
- Routes: `app/javascript/dashboard/routes/*.js`

### Test Files
- Ruby specs: `spec/**/*_spec.rb`
- JavaScript tests: `app/javascript/**/*.spec.js`

## Important Notes

1. **Dual Architecture**: Backend is Rails MVC, Frontend is Vue.js SPA
2. **API-First**: Most features exposed via JSON API
3. **Real-time**: Uses ActionCable for WebSocket connections
4. **Background Processing**: Heavy use of Sidekiq for async tasks
5. **Multi-tenant**: Built for SaaS with account-based isolation
6. **Extensible**: Enterprise edition uses overlay pattern
7. **Component Library**: Moving to `components-next/` for new UI components