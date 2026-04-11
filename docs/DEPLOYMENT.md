<!-- generated-by: gsd-doc-writer -->
# Deployment

This document covers everything that lives **inside this repository** related to shipping the fork to production: the Docker build, the GitHub Actions CI/CD pipeline, and the auto-release tagging scheme. Kubernetes manifests, Hetzner cluster configuration, and production secrets live in the **external devops repo** described at the end of this file.

---

## 1. Build Artifacts

### Production Dockerfile

**File:** `docker/Dockerfile`

The production image uses a two-stage multi-platform build:

| Stage | Base image | Purpose |
|---|---|---|
| `node` (helper) | `node:24-alpine` | Provides the Node binary for copying into later stages |
| `pre-builder` | `ruby:3.4.4-alpine3.21` | Installs gems and pnpm packages, compiles assets |
| Final | `ruby:3.4.4-alpine3.21` | Lean runtime image; copies `/gems/` and `/app` from pre-builder |

Key build details:
- Ruby `3.4.4`, Bundler `2.5.16`, Node `24.13.0`, pnpm `10.2.0`
- Production gems only (`BUNDLE_WITHOUT="development:test"`)
- Assets precompiled during build (`rake assets:precompile`) with `spec/`, `node_modules/`, and `tmp/cache/` pruned afterward
- Enterprise directories (`enterprise/`, `spec/enterprise/`) are **stripped at CI time** (not in the Dockerfile itself) before the build step
- `CW_EDITION="ce"` injected as a final `ENV` line by CI before build
- `EXPOSE 3000`
- `.git_sha` written from `git rev-parse HEAD` during the pre-builder stage and copied to the final image; the release entrypoint overwrites it with `$SOURCE_VERSION` at startup

### Dev-only Dockerfiles

These are used by the devcontainer only and are **not** used in production builds:

- `docker/dockerfiles/rails.Dockerfile` — extends `chatwoot:development`, exposes `3000`
- `docker/dockerfiles/vite.Dockerfile` — extends `chatwoot:development`, exposes `3036`

### Entrypoints

- `docker/entrypoints/rails.sh` — waits for Postgres readiness, runs `bundle install` (dev only), then `exec "$@"`
- `docker/entrypoints/vite.sh` — prunes and reinstalls pnpm store, then `exec "$@"` (dev only)

---

## 2. Runtime Topology

Defined in `Procfile`:

| Process | Command | Purpose |
|---|---|---|
| `release` | `bundle exec rails db:chatwoot_prepare` | One-shot migration/seed runner; also writes `$SOURCE_VERSION` to `.git_sha` |
| `web` | `bundle exec rails ip_lookup:setup && bin/rails server -p $PORT -e $RAILS_ENV` | HTTP server on `$PORT` |
| `worker` | `bundle exec rails ip_lookup:setup && bundle exec sidekiq -C config/sidekiq.yml` | Background job processor |

There is no separate `scheduler` process declared in `Procfile`. <!-- VERIFY: whether a cron/scheduler process (e.g. Sidekiq cron or a dedicated scheduler dyno) is configured in the K8s manifests in the devops repo -->

---

## 3. Database Migrations on Deploy

The `release` process in `Procfile` runs `db:chatwoot_prepare` (defined in `lib/tasks/db_enhancements.rake`). This task:

1. If the database has no `ar_internal_metadata` table (fresh DB): loads `db/schema.rb` and runs seeds — this prefix step runs BEFORE migrate, not instead of it.
2. Always invokes `db:migrate` — regardless of whether the prefix step ran.
3. After every migration, triggers `ConfigLoader.new.process` to reload `installation_configs`.

`POSTGRES_STATEMENT_TIMEOUT=600s` is set for this step to allow long-running migrations without being killed.

---

## 4. CI/CD Pipeline

### 4.1 Test — `run_foss_spec.yml`

**Trigger:** push to `next`, pull_request, `workflow_dispatch`

Steps run in parallel:
- `lint-backend` — Rubocop (`bundle exec rubocop --parallel`)
- `lint-frontend` — ESLint (`pnpm run eslint`)
- `frontend-tests` — Vitest coverage (`pnpm run test:coverage`)
- `backend-tests` — RSpec, parallelised across **16 matrix nodes** against `pgvector/pgvector:pg16` and `redis:alpine`

### 4.2 Auto-Release — `auto-release.yaml`

**Trigger:** push to `next`

Steps:
1. Reads `VERSION_CW` file (current value: `4.12.1`)
2. Takes the 7-character short SHA of `HEAD`
3. Converts the hex SHA to its decimal-octal representation: `OCTAL=$(printf '%o' "0x${SHA}")`
4. Constructs tag: `v${CW_VERSION}${OCTAL}`
5. Creates an annotated git tag and pushes it using the default `GITHUB_TOKEN` (workflow has `permissions: contents: write`)
6. Creates a GitHub Release with auto-generated notes (`gh release create … --generate-notes --latest`)

The downstream `build-docker-image.yaml` is triggered via `workflow_run` on "Auto Release", which fires regardless of whether `GITHUB_TOKEN` or a PAT pushed the tag — no PAT is needed for this handoff.

### 4.3 Docker Build — `build-docker-image.yaml`

**Trigger:** `workflow_run` on "Auto Release" completing successfully, or `workflow_dispatch` (manual tag input)

Pipeline:

1. **`resolve-tag`** — Determines the tag to build: uses manual input if provided, otherwise calls `git describe --tags --abbrev=0`
2. **`create-runner-amd` / `create-runner-arm`** (parallel) — Provisions ephemeral Hetzner Cloud runners using `Cyclenerd/hcloud-github-runner@v1`:
   - AMD: `cx53` server type, tried in order: `hel1` → `fsn1` → `nbg1`
   - ARM: `cax41` server type, same location fallback order
3. **`build-and-push-amd` / `build-and-push-arm`** (parallel, `environment: production`) — On each dedicated runner:
   - Strips `enterprise/` and `spec/enterprise/`
   - Appends `ENV CW_EDITION="ce"` to `docker/Dockerfile`
   - Builds from `docker/Dockerfile` and pushes to `ghcr.io`
   - AMD tags: `latest`, `latest-amd`, `{tag}-amd`
   - ARM tags: `latest-arm`, `{tag}-arm`
4. **`merge-manifest`** — Runs on `ubuntu-latest`, merges arch-specific images into:
   - `ghcr.io/{owner}/chatwoot:{tag}` (versioned multi-arch manifest)
   - `ghcr.io/{owner}/chatwoot:latest` (latest multi-arch manifest)
5. **`delete-runner-amd` / `delete-runner-arm`** — Always runs (`if: always()`) to tear down ephemeral runners

Image registry: `ghcr.io` (GitHub Container Registry). <!-- VERIFY: exact GHCR org/owner path and whether images are public or require token pull -->

Secrets required by this workflow:
- `secrets.PERSONAL_ACCESS_TOKEN` — PAT with `repo` scope (used for Hetzner runner provisioning and tag pushes)
- `secrets.HCLOUD_TOKEN` — Hetzner Cloud API token
- `secrets.GITHUB_TOKEN` — standard Actions token (packages:write for GHCR push)

### 4.4 Docker Build Test — `test_docker_build.yml`

**Trigger:** pull_request to `next`, `workflow_dispatch`

Builds `docker/Dockerfile` (no push) against both `linux/amd64` and `linux/arm64` to verify the image compiles. Uses GHA cache per platform.

### 4.5 Disabled Upstream Workflow

`deploy_check.yml` — Originally a Heroku review-app health check (upstream Chatwoot). The `pull_request` trigger is disabled; it can only run via `workflow_dispatch`. Not used by this fork.

---

## 5. Auto-Release Tag Format

Every push to `next` that passes produces a tag in the format:

```
v{VERSION_CW}{OCTAL}
```

Where:
- `VERSION_CW` is the content of the `VERSION_CW` file (e.g. `4.12.1`)
- `OCTAL` is `printf '%o' "0x${SHORT_SHA}"` — the 7-char hex SHA converted to its octal representation

Example: for `VERSION_CW=4.12.1` and SHA `abc1234`, the tag would be `v4.12.1{decimal-octal of 0xabc1234}`.

The resulting Docker image tag replaces any `+` with `-` (the `${RELEASE_TAG//+/-}` substitution in the workflow).

---

## 6. Health Checks

A health endpoint is registered at `GET /health` (mapped to `health#show` in `config/routes.rb`). This is the canonical liveness check used by load balancers and container orchestrators.

The `deploy_check.yml` (disabled for this fork, but illustrative) polls `GET /api` and expects a JSON response containing `version`, `timestamp`, `queue_services: "ok"`, and `data_services: "ok"`.

No `HEALTHCHECK` instruction is present in `docker/Dockerfile`. <!-- VERIFY: whether the K8s liveness/readiness probes in the devops repo target /health or /api -->

---

## 7. Observability

The following monitoring libraries are present in `Gemfile` and `package.json`:

| Library | Scope | Activation |
|---|---|---|
| `sentry-rails`, `sentry-ruby`, `sentry-sidekiq` | Error tracking | `require: false` — must be configured via env vars |
| `datadog` (`~> 2.0`) | APM / metrics | `require: false` |
| `newrelic_rpm`, `newrelic-sidekiq-metrics` | APM | `require: false` |
| `opentelemetry-sdk`, `opentelemetry-exporter-otlp` | Tracing | Listed in Gemfile |
| `@sentry/vue` (`^8.55.0`) | Frontend error tracking | npm dependency |

All libraries are gated behind `require: false`; none are activated unless the corresponding environment variables (e.g. `SENTRY_DSN`, `DD_AGENT_HOST`) are set at runtime.

<!-- VERIFY: which observability backend is active in production (Sentry DSN, Datadog agent endpoint, OTLP collector URL) — these are configured in the devops repo secrets, not in this repository -->

---

## 8. Rollback

No automated rollback step is defined in the GitHub Actions workflows in this repository. Rollback options:

1. **Re-tag and re-release** — Push a new commit to `next`; the auto-release pipeline creates a new tag and rebuilds the image. <!-- VERIFY: whether the devops repo K8s manifests use `image: ghcr.io/.../chatwoot:latest` (pulled automatically) or a pinned versioned tag requiring a manifest update -->
2. **Manual image pin** — Update the image tag in the K8s deployment manifest in the devops repo to a previously built `{tag}-amd`/`{tag}-arm` or the versioned multi-arch manifest tag, then apply.
3. **`workflow_dispatch` rebuild** — The build workflow accepts a manual `tag` input, allowing any previously released tag to be rebuilt and pushed as `latest`.

<!-- VERIFY: exact rollback procedure documented in the devops repo, including kubectl commands or Flux/ArgoCD reconciliation steps -->

---

## 9. External Devops Repo

Production Kubernetes manifests, Hetzner K3s cluster configuration, Helm values, and secrets management live **outside this repository** in:

```
/workspace/code/chatwoot-br/devops
```

<!-- VERIFY: Git remote URL and branch of the devops repo -->
<!-- VERIFY: K3s namespace(s) used for the chatwoot-br deployment (e.g. dev, staging, production) -->
<!-- VERIFY: whether the cluster pulls images via imagePullPolicy: Always on :latest or via a GitOps operator watching for new tags -->
<!-- VERIFY: production domain name(s), ingress/TLS configuration, CDN or reverse proxy configuration -->
<!-- VERIFY: database cluster details (managed Postgres on Hetzner, RDS, or in-cluster) -->
<!-- VERIFY: Redis topology (in-cluster vs managed) -->

The devops repo is the authoritative source for:
- Namespace and resource quota definitions
- Secret references (sealed secrets, external-secrets, or vault)
- Ingress, TLS, and DNS configuration
- PersistentVolumeClaim definitions for storage (attachments, etc.)
- Any Sidekiq replica count or resource limit tuning

---

## 10. Environment Setup Reference

See `docs/CONFIGURATION.md` for the full list of required environment variables. The `Procfile` `release` step requires at minimum a reachable `DATABASE_URL` (or `POSTGRES_HOST` / `POSTGRES_PORT` / `POSTGRES_USERNAME` individually) before `db:chatwoot_prepare` can proceed.

<!-- VERIFY: whether DATABASE_URL or individual POSTGRES_* vars are used in the production K8s secret -->
