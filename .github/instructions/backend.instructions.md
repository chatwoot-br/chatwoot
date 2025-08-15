---
paths:
  - "app/**/*.rb"
  - "config/**/*.rb"
  - "lib/**/*.rb"
  - "db/**"
  - "swagger/**"
---

# Guidelines — Backend (Rails)

- **Patterns:**
  - Keep controllers thin; move business rules to POROs/Services/Interactors inside `app/`.
  - Heavy queries: use scopes/Query Objects; avoid N+1 (add `includes` where needed).
  - Background jobs: use **Active Job** with **Sidekiq**. Do not spawn manual threads. Configure queues by priority when appropriate.
- **Integrations & events:** prefer Webhooks/Jobs for slow processes. Apply timeouts and idempotent retries.
- **API:** update **OpenAPI** under `swagger/` when endpoints change. Ensure versioning and compatibility.
- **Testing:** RSpec with factories. Cover services, requests, and serializers. Use `:vcr`/stubs for external integrations.
- **Security:** sanitize params, authorize resources, protect against mass-assignment. Never log secrets.
- **Migrations:** one per logical change; write `up/down` when needed. Do not break production data.
- **Style:** follow `rubocop.yml`. Prefer immutable objects where it makes sense and name methods clearly.