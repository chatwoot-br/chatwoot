# Chatwoot Tech Stack

## Backend (Ruby on Rails)
- **Framework**: Rails ~7.1
- **Language**: Ruby 3.4.4
- **Database**: PostgreSQL with Redis for caching
- **Background Jobs**: Sidekiq with sidekiq-cron for scheduled jobs
- **API**: REST with Jbuilder for JSON responses
- **Authentication**: Devise, Devise Token Auth, JWT, Devise Two-Factor
- **Authorization**: Pundit
- **Admin Panel**: Administrate
- **Search**: Searchkick with OpenSearch/Elasticsearch

## Frontend (Vue.js)
- **Framework**: Vue 3.5.x with Composition API
- **Build Tool**: Vite 5.4.x with vite-plugin-ruby
- **Router**: Vue Router 4.4.x
- **State Management**: Vuex 4.1.x
- **UI Components**: Custom components with Vue Multiselect, Vue Datepicker
- **Styling**: Tailwind CSS 3.x (NO custom CSS allowed)
- **Icons**: @iconify-json packages
- **Forms**: @formkit/vue with @vuelidate for validation
- **Command Palette**: @chatwoot/ninja-keys

## Communication & Integrations
- **WebSocket**: ActionCable for real-time updates
- **Push Notifications**: FCM, Web Push API
- **Email**: ActionMailer with various providers
- **SMS**: Twilio
- **Social Media**: Facebook Messenger, Twitter, Instagram, WhatsApp, Telegram, Line
- **Chatbots**: Dialogflow integration
- **Translations**: Google Cloud Translate

## Development Tools
- **Package Manager**: pnpm 10.x for JavaScript, Bundler for Ruby
- **Testing**: RSpec (Ruby), Vitest (JavaScript)
- **Linting**: RuboCop (Ruby), ESLint with Airbnb config (JavaScript)
- **Code Formatting**: Prettier (JavaScript), RuboCop auto-correct (Ruby)
- **Process Management**: Overmind/Foreman for development
- **Git Hooks**: Husky with lint-staged

## Monitoring & Performance
- **APM**: Support for Datadog, New Relic, Scout, Elastic APM
- **Error Tracking**: Sentry
- **Analytics**: PostHog
- **Metrics**: Barnes (Heroku), Lograge for structured logging

## Infrastructure
- **File Storage**: Active Storage with S3, Azure Blob, Google Cloud Storage support
- **Image Processing**: image_processing gem with libvips
- **Rate Limiting**: rack-attack
- **CORS**: rack-cors
- **Deployment**: Docker support, Heroku, DigitalOcean marketplace

## AI & ML
- **AI Agents**: ai-agents gem for Captain AI feature
- **Vector Database**: pgvector with neighbor gem for similarity search
- **LLM Integration**: ruby-openai for OpenAI integration
- **Text Processing**: Markdown parsing, HTML to text conversion