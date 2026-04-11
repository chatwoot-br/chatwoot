<!-- generated-by: gsd-doc-writer -->
# Getting Started

This guide is for engineers joining the **Chatwoot BR fork**. It covers running the application locally inside the devcontainer, creating a WhatsApp Web inbox backed by the `gowa` service, and verifying that an inbound WhatsApp message lands in a conversation. For system architecture context see `docs/ARCHITECTURE.md`; for environment variable reference see `docs/CONFIGURATION.md`.

---

## Prerequisites

### Devcontainer path (recommended)

| Tool | Minimum version | Notes |
|------|----------------|-------|
| Docker Desktop / Docker Engine | 24+ | Required for devcontainer |
| VS Code with Dev Containers extension | any | Or use the `devcontainer` CLI |
| `git` | any | For cloning |

`Dockerfile.devx` adds `libvips42` on top of `Dockerfile.base`, which provides Ruby 3.4.4, Node.js 24.x, pnpm 10.x, `overmind`, and `bundler`. You do not need to install any of these on your host.

### Bare-metal path

| Tool | Required version |
|------|-----------------|
| Ruby | `3.4.4` (see `.ruby-version`) |
| Node.js | `24.x` (see `.nvmrc` — `24.13.0`) |
| pnpm | `10.x` |
| PostgreSQL | 16 with `pgvector` extension |
| Redis | any recent stable |
| `libvips42` | system package — required by `image_processing` gem |
| `overmind` | any — manages `Procfile.dev` processes |

Bare-metal setup is not covered step-by-step here; the devcontainer handles all service wiring automatically.

---

## Quick Start (devcontainer)

### 1. Ensure bind-mount parent directories exist

The devcontainer mounts several sibling directories from the host (`.claude`, `.config`, `.agents`, `notebook`, etc.). The `initializeCommand` creates them automatically the first time, but if you are running the devcontainer CLI rather than VS Code, run it manually once:

```bash
cd /path/to/parent-of-chatwoot
mkdir -p .claude .config .local/share .local/state .claude-mem .codex .agents notebook
touch chatwoot/.env.devcontainer   # required by --env-file; may be empty
```

### 2. Open in devcontainer

In VS Code: **F1 → Dev Containers: Reopen in Container**.

The `postCreateCommand` runs automatically and executes three phases:

1. `setup.sh create` — copies `.env.example` → `.env`, patches `REDIS_URL` and `POSTGRES_HOST` to `localhost`, installs Claude CLI and Codex CLI, and bootstraps LazyVim.
2. `setup.sh db-prepare` — runs `bundle exec rake db:chatwoot_prepare`, which creates the database, loads the schema, seeds development data, and runs any pending migrations.
3. `pnpm install` — installs JavaScript dependencies.

> **If `db-prepare` fails and you want to proceed anyway**, add `DEVCONTAINER_DB_SOFT_FAIL=1` to `.env.devcontainer` before rebuilding. You can then run `bundle exec rake db:chatwoot_prepare` manually once services are up.

### 3. Install Ruby gems (if not already done)

```bash
bundle install
```

This is idempotent. The devcontainer image pre-installs gems at build time; this step catches any additions since the image was last built.

### 4. Start all services

```bash
overmind start -f Procfile.dev
```

`Procfile.dev` defines three processes:

| Process | Command | Port |
|---------|---------|------|
| `backend` | `bin/rails s -b 0.0.0.0 -p 3000` | 3000 |
| `worker` | `dotenv bundle exec sidekiq -C config/sidekiq.yml` | — |
| `vite` | `bin/vite dev` | 3036 |

Alternatively use `pnpm run dev` (mapped to `overmind start -f ./Procfile.dev`) or `pnpm run start:dev` (uses `foreman`).

Wait for the Rails boot message before proceeding:

```
backend | * Listening on http://0.0.0.0:3000
```

### 5. Verify first login

Open `http://localhost:3000` in a browser.

The seed data creates a SuperAdmin user and the "Acme Inc" account:

| Field | Value |
|-------|-------|
| Email | `john@acme.inc` |
| Password | `Password1!` |

After login you should see the Chatwoot dashboard for the **Acme Inc** account.

---

## Database Setup (manual / fresh clone without devcontainer)

If you need to (re-)set up the database outside the devcontainer lifecycle:

```bash
# Create DB, load schema, seed
bundle exec rake db:chatwoot_prepare

# Or the standard Rails approach (less safe on existing DBs):
bundle exec rails db:create db:schema:load db:seed
```

`db:chatwoot_prepare` is the recommended task — it detects whether the database already exists and runs `db:setup` vs `db:migrate` accordingly (see `lib/tasks/db_enhancements.rake`).

---

## Creating a WhatsApp Web Inbox

The WhatsApp Web provider routes messages through the `gowa` service (`go-whatsapp-web-multidevice`), which runs as a separate Docker Compose service on port 4000.

### 1. Confirm gowa is reachable

```bash
curl -s http://localhost:4000/health || echo "gowa not responding"
```

If gowa is not running, check the Docker Compose stack:

```bash
docker compose -f .devcontainer/docker-compose.yml ps gowa
docker compose -f .devcontainer/docker-compose.yml logs gowa --tail=30
```

### 2. Verify `WHATSAPP_WEB_API_URL` in `.env`

Open `.env` and confirm:

```
WHATSAPP_WEB_API_URL=http://localhost:4000
```

The setup script sets `REDIS_URL` and `POSTGRES_HOST` but does **not** patch `WHATSAPP_WEB_API_URL` — you must set this manually if the value differs from the example. The `.env.example` default is `http://localhost:3001` (legacy value); the devcontainer's gowa service listens on **4000**, so update it:

```bash
sed -i 's|WHATSAPP_WEB_API_URL=.*|WHATSAPP_WEB_API_URL=http://localhost:4000|' .env
```

Restart the Rails process after changing `.env`:

```bash
overmind restart backend
```

### 3. Create the inbox via the Chatwoot UI

1. Log in as `john@acme.inc`.
2. Go to **Settings → Inboxes → Add Inbox**.
3. Choose **WhatsApp** as the channel type.
4. Select **WhatsApp Web** as the provider.
5. Enter the phone number associated with the WhatsApp account you will scan (international format, digits only, e.g. `5511999990000`).
6. Submit. Chatwoot calls `POST /api/v1/accounts/:account_id/whatsapp_web/devices` to register the device ID with gowa.

### 4. Scan the QR code

After inbox creation the UI shows a QR code. The QR is fetched from gowa via:

```
GET /api/v1/accounts/:account_id/whatsapp_web/devices/:id/qr_code
```

which proxies to `GET http://localhost:4000/app/login` with an `X-Device-Id` header.

1. Open WhatsApp on your phone.
2. Tap **Linked Devices → Link a Device**.
3. Scan the QR code displayed in the Chatwoot inbox settings page.

On successful scan, the device state transitions to `logged_in`. Refresh the inbox settings page to confirm — the QR code is replaced by connection status.

### 5. Verify inbound message flow

Send a WhatsApp message **to** the phone number you linked. The expected flow is:

```
WhatsApp network
  → gowa (port 4000, receives message)
  → POST http://localhost:3000/webhooks/whatsapp_web  (WHATSAPP_WEBHOOK env in docker-compose.yml)
  → Sidekiq job: Webhooks::WhatsappWebEventsJob
  → IncomingMessageWhatsappWebService
  → Conversation created / message appended
```

Open the **Conversations** view in Chatwoot and confirm the message appears. If Sidekiq is not running, the job will queue but not process — verify `overmind` shows the `worker` process running.

---

## gowa Webhook Secret Caveat

In the devcontainer, `gowa` is configured with `WHATSAPP_WEBHOOK_SECRET=dev-secret` (see `.devcontainer/docker-compose.yml`). gowa signs its outbound webhook requests with an `X-Hub-Signature-256` HMAC header.

Chatwoot's webhook controller (`app/controllers/webhooks/whatsapp_web_controller.rb`) currently checks the plain `X-Webhook-Secret` header, **not** the HMAC header. This means:

- **Leave `WHATSAPP_WEB_WEBHOOK_SECRET` blank in `.env`** for local dev — this disables secret verification and lets all gowa webhooks through.
- In production, the controller must be updated to verify the HMAC before setting a webhook secret.

The `.env.example` documents this caveat at the `WHATSAPP_WEB_WEBHOOK_SECRET` line.

---

## Common Pitfalls

### `LoadError: libvips.so.42` on bare metal

The `image_processing` gem requires `libvips42`. Install it:

```bash
# Debian/Ubuntu
sudo apt-get install libvips42

# macOS
brew install vips
```

The devcontainer image installs `libvips42` in `Dockerfile.devx` — this error only occurs on bare-metal setups.

### Stale Rails PID / overmind socket

If `overmind start` fails with "address already in use" or Rails refuses to start citing a stale PID:

```bash
# Remove stale PID
rm -f /workspace/chatwoot/tmp/pids/server.pid

# Remove stale overmind socket (created in project root by default)
rm -f /workspace/chatwoot/.overmind.sock

overmind start -f Procfile.dev
```

### Port conflicts (3000, 3036, 4000)

The devcontainer Docker Compose stack maps ports from the `db` service container to the host (see `docker-compose.yml` lines 32–37). If a host process is already using port 3000 or 4000, stop it before starting the devcontainer. Check with:

```bash
lsof -i :3000 -i :4000 -i :3036
```

### `db:chatwoot_prepare` fails during devcontainer build

This usually means Postgres is not yet accepting connections. The `app` container shares `network_mode: service:db`, so if the `db` container is slow to start, the setup script may run before Postgres is ready. Either:

- Add `DEVCONTAINER_DB_SOFT_FAIL=1` to `.env.devcontainer` and run `bundle exec rake db:chatwoot_prepare` manually after confirming Postgres is up.
- Rebuild the container once Postgres is healthy.

### `WHATSAPP_WEB_API_URL` pointing to wrong port

The `.env.example` ships with `http://localhost:3001` (a legacy placeholder). The devcontainer gowa service runs on **port 4000**. Always verify this value in `.env` matches the actual gowa port before testing the WhatsApp Web flow.

### Vite HMR not connecting

The Vite dev server runs on port 3036. If hot module replacement does not work, confirm the `vite` process is running in `overmind` and that the port is forwarded in your devcontainer client. In VS Code the port is forwarded automatically (see `devcontainer.json` `forwardPorts`).

---

## Next Steps

- `docs/ARCHITECTURE.md` — Component diagram and data flow through Rails, Sidekiq, and gowa.
- `docs/CONFIGURATION.md` — Full environment variable reference with required/optional status and defaults.
- `docs/DEVELOPMENT.md` — Build commands, code style, and branch conventions (if present).
- `docs/TESTING.md` — Running the test suite and coverage requirements (if present).
