# Chatwoot Development Commands

## Initial Setup
```bash
# Install dependencies
bundle install
pnpm install

# Setup database
bundle exec rails db:create db:migrate db:seed
```

## Development Server
```bash
# Start development server (recommended)
pnpm dev
# OR
overmind start -f ./Procfile.dev

# Alternative with foreman
foreman start -f ./Procfile.dev
```

## Testing Commands

### Ruby/Rails Tests
```bash
# Run all Ruby tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/path/to/file_spec.rb

# Run specific test at line number
bundle exec rspec spec/path/to/file_spec.rb:42

# Run with coverage
bundle exec rspec --format documentation
```

### JavaScript/Vue Tests
```bash
# Run all JavaScript tests (no watch)
pnpm test

# Run tests in watch mode
pnpm test:watch

# Run tests with coverage
pnpm test:coverage
```

## Linting & Formatting

### Ruby Linting
```bash
# Check Ruby code style
bundle exec rubocop

# Auto-fix Ruby style issues
bundle exec rubocop -a
# OR
pnpm ruby:prettier
```

### JavaScript/Vue Linting
```bash
# Check JS/Vue code style
pnpm eslint

# Auto-fix JS/Vue style issues
pnpm eslint:fix
```

## Build Commands
```bash
# Build SDK library
pnpm build:sdk

# Build Storybook
pnpm story:build

# Size checking
pnpm size
```

## Git Commands
```bash
# Check files before push
sh bin/validate_push

# Sync i18n files
pnpm sync:i18n
# OR
bin/sync_i18n_file_change
```

## Database Commands
```bash
# Create database
bundle exec rails db:create

# Run migrations
bundle exec rails db:migrate

# Seed database
bundle exec rails db:seed

# Reset database (drop, create, migrate, seed)
bundle exec rails db:reset
```

## Console & Debugging
```bash
# Rails console
bundle exec rails console

# Rails server only
bundle exec rails server

# Sidekiq worker only
bundle exec sidekiq
```

## Storybook Development
```bash
# Start Storybook dev server
pnpm story:dev

# Build Storybook
pnpm story:build

# Preview built Storybook
pnpm story:preview
```

## System Commands (Darwin/macOS)
```bash
# List files
ls -la

# Search for files
find . -name "*.rb"

# Search in files (use ripgrep if available)
grep -r "pattern" .
# OR better
rg "pattern"

# Git status
git status

# Git diff
git diff

# Create branch
git checkout -b username/feature-name

# Stage changes
git add .

# Commit with conventional format
git commit -m "feat(scope): description"
```

## Docker Commands (if using Docker)
```bash
# Build and start containers
docker-compose up

# Run tests in Docker
docker-compose -f docker-compose.test.yaml up

# Production setup
docker-compose -f docker-compose.production.yaml up
```

## Environment Setup
```bash
# Copy environment variables
cp .env.example .env

# Edit environment variables
nano .env  # or use your preferred editor
```

## Useful Rake Tasks
```bash
# List all rake tasks
bundle exec rake -T

# Generate ERD diagram
bundle exec rake erd

# Check for security vulnerabilities
bundle exec bundle-audit

# Run brakeman security scan
bundle exec brakeman
```