# E2E Testing with Docker Compose

Run a full Chatwoot production stack locally to validate features end-to-end before pushing.

## Prerequisites

- Docker and Docker Compose v2+
- The feature branch checked out (main repo or worktree)

## Quick Start

```bash
# Build the production image
docker compose -f docker-compose.e2e.yaml build

# Start all services (postgres, redis, rails)
docker compose -f docker-compose.e2e.yaml up -d

# Watch rails boot (db:prepare + server start)
docker compose -f docker-compose.e2e.yaml logs -f rails

# When you see "Rails 7.x application starting in production", it's ready
```

## Verify

```bash
# Check all containers are up
docker compose -f docker-compose.e2e.yaml ps

# Hit the app
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/
```

## Tear Down

```bash
# Stop and remove containers + volumes (clean slate for next run)
docker compose -f docker-compose.e2e.yaml down -v
```

## Architecture

```
docker-compose.e2e.yaml
├── postgres (pgvector/pgvector:pg16)
│   └── healthcheck: pg_isready
├── redis (redis:alpine)
└── rails (chatwoot:e2e — built from docker/Dockerfile)
    ├── env_file: .env.e2e
    ├── depends_on: postgres (healthy), redis (started)
    └── entrypoint: db:prepare → rails server
```

The rails container runs `bundle exec rails db:prepare` on startup, which:
1. Creates/migrates the database
2. Runs `db/seeds.rb` (where env-var-driven features like auto-onboard execute)
3. Starts the Puma web server on port 3000

## Environment Variables

Edit `.env.e2e` to configure the stack. Key variables:

| Variable | Purpose | Default |
|----------|---------|---------|
| `SECRET_KEY_BASE` | Rails session signing | Set in `.env.e2e` |
| `POSTGRES_HOST` | DB hostname | `postgres` (compose service) |
| `REDIS_URL` | Redis connection | `redis://redis:6379` |
| `CHATWOOT_ADMIN_EMAIL` | Auto-onboard admin email | `suporte@chatwoot.app.br` |
| `CHATWOOT_ADMIN_PASSWORD` | Auto-onboard admin password | `TestPass1!` |

Add any feature-specific env vars to `.env.e2e` for your test scenario.

## Testing Patterns

### Verify a seed-time feature (e.g., auto-onboard)

```bash
# Check logs for seed output
docker compose -f docker-compose.e2e.yaml logs rails | grep -i "enqueued\|seed\|error"

# Verify no onboarding redirect
curl -s -o /dev/null -w "%{http_code} %{redirect_url}" http://localhost:3000/

# Test API login
curl -s -X POST http://localhost:3000/auth/sign_in \
  -H 'Content-Type: application/json' \
  -d '{"email":"suporte@chatwoot.app.br","password":"TestPass1!"}' | python3 -m json.tool
```

### Verify a Rails endpoint or API

```bash
# Get an auth token first
TOKEN=$(curl -s -X POST http://localhost:3000/auth/sign_in \
  -H 'Content-Type: application/json' \
  -d '{"email":"suporte@chatwoot.app.br","password":"TestPass1!"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['access_token'])")

# Use the token for authenticated requests
curl -s http://localhost:3000/api/v1/accounts/1/agents \
  -H "api_access_token: $TOKEN" | python3 -m json.tool
```

### Inspect the database

```bash
docker compose -f docker-compose.e2e.yaml exec postgres \
  psql -U postgres chatwoot_production -c "SELECT id, email, type FROM users;"
```

### Run a rails console

```bash
docker compose -f docker-compose.e2e.yaml exec rails bundle exec rails console
```

## Building from a Git Worktree

The Dockerfile runs `git rev-parse HEAD` to record the commit SHA. In worktrees, the `.git` entry is a file (not a directory), which can cause this step to fail. The Dockerfile includes a fallback:

```dockerfile
RUN git rev-parse HEAD > /app/.git_sha 2>/dev/null || echo "unknown" > /app/.git_sha
```

If you see build failures related to `.git`, ensure this fallback is present in `docker/Dockerfile`.

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `db:prepare` hangs | Postgres not ready | Check `docker compose ps` — postgres must be `healthy` |
| Port 3000 already in use | Another service on 3000 | Stop it or change the port mapping in `docker-compose.e2e.yaml` |
| `.env.e2e` not loaded | `.dockerignore` excludes `.env.*` | This is fine — compose reads `env_file` from the host, not the build context |
| `git rev-parse HEAD` fails during build | Building from a worktree | Ensure the Dockerfile fallback is in place (see above) |
| `index.lock` errors on commit | Stale lock from prior git operation | `rm /path/to/.git/.../index.lock` |
