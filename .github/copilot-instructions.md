# Copilot Instructions — Chatwoot (BR)

These instructions guide GitHub Copilot (Chat and Code Review) when used in this repository.

## Scope & stack
- **Backend:** Ruby on Rails. Version set in `.ruby-version`. Asynchronous jobs via Active Job + Sidekiq/Redis (when needed).
- **Frontend:** Vue 3 + Vite + TypeScript, Tailwind CSS and PostCSS. Build config in `vite.config.ts`, `tailwind.config.js`, `postcss.config.js`.
- **JS bundling:** **Vite**. Avoid Webpack/webpacker.
- **Package manager:** use the one indicated by the lockfile **(`pnpm-lock.yaml`)**. Prefer `pnpm`.
- **API documentation:** OpenAPI under `swagger/`.
- **Environment configuration:** see `.env.example`.

## How to run & test (defaults)
- **Setup:** `bundle install` + `pnpm install` (or `pnpm i`).
- **Dev:** if available, use `Procfile.dev` (e.g., `foreman start -f Procfile.dev` / `overmind start -f Procfile.dev`). Otherwise, use `rails s` and `pnpm dev` in separate terminals.
- **Backend tests:** `bundle exec rspec`.
- **Frontend tests:** `pnpm test` (Vitest). For stories/visual docs, use **Histoire** where applicable.
- **Lint/format:** `bundle exec rubocop`, `pnpm lint`, `pnpm format`.

## Code standards
- **Rails:**
  - Keep controllers thin; move domain rules into services/POROs under `app/` (e.g., `services`, `workers`, `commands`).
  - Data access via ActiveRecord/Query Objects. Avoid raw SQL where possible.
  - Use **Active Job** for async work; enqueue to **Sidekiq** (do not spawn manual threads).
  - When changing models/public attributes, **create migrations** and keep `schema.rb` consistent.
- **Vue 3 / TS:**
  - Use **Composition API** with `<script setup lang="ts">`.
  - Components must be accessible (ARIA), responsive, and testable.
  - Local state via composables. Avoid DOM coupling; use refs/events.
  - Requests: use existing utilities; handle errors and loading states.
- **Style & quality:**
  - Follow `.eslintrc.js`, `.prettierrc`, `.rubocop.yml`, and `.browserslistrc`.
  - Types: prefer strict typing in TS; avoid `any`. In Ruby, document public interfaces (YARD optional) and return predictable objects.
  - Small commits and PRs with clear descriptions. Include tests and usage snippets.

## API & contracts
- If a change affects endpoints, **update `swagger/`** and examples. Include request tests and corresponding migrations.
- Do not expose internal fields or sensitive data in serializers.

## Security
- **Never** commit secrets. Use environment variables and `*.example` files.
- Validate external input (backend and frontend). Apply sanitization and rate limiting where appropriate.

## Language & communication
- Comments, commit messages, and PRs always in **English**.
- Explain assumptions and trade-offs when generating code that impacts performance/security.

## What to **avoid**
- Generating code with `npm`/`yarn` when the project uses `pnpm`.
- Introducing new state-management or CSS libraries without need.
- Running long tasks on the web thread.