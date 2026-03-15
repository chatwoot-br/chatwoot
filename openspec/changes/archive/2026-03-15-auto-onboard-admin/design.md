## Context

New Chatwoot instances provisioned by the operator boot into a browser-based onboarding screen that requires manual SuperAdmin creation. The init container runs `rails db:prepare` which executes `db/seeds.rb`, setting a Redis flag that redirects all requests to `/installation/onboarding`. The instance is unusable until someone fills out the form.

The operator manages instances via `ChatwootInstance` CRs and already supports `spec.env` (plain env vars) and `spec.envSecret` (external Secret references). Credentials are managed in Infisical and synced to K8s Secrets via External Secrets Operator (ESO).

## Goals / Non-Goals

**Goals:**
- Auto-create a SuperAdmin user during `db:prepare` when admin env vars are present
- Skip the onboarding screen entirely — instance boots straight to dashboard
- Use a shared support identity (`suporte@chatwoot.app.br`) across all operator-managed instances
- Password sourced from a shared Infisical secret, synced via ESO

**Non-Goals:**
- Auto-creating PlatformApp or API tokens (future work)
- Changing the onboarding flow when env vars are absent (existing behavior preserved)
- Per-instance unique admin credentials (shared secret is sufficient)

## Decisions

### 1. Seed-time injection over post-deploy Job

Create the SuperAdmin in `db/seeds.rb` rather than a post-deploy HTTP call to `/installation/onboarding`.

**Why:** Seeds run during `db:prepare` (init container), before the web process starts. No timing dependency, no need to wait for web health, no HTTP call to orchestrate. The dev seeds already demonstrate this exact pattern (line 28-36 of current `seeds.rb`).

**Alternative rejected:** Operator post-deploy Job — fragile timing (web must be up, DB migrated, Redis connected), adds Go code and a new Job resource to manage.

### 2. Guard with `User.exists?` for idempotency

Check `User.exists?(email: admin_email)` before creating. The init container runs `rails db:prepare` on every pod start, so seeds must be re-runnable.

**Why:** `db:prepare` is idempotent for schema (runs pending migrations only), but seeds run every time. The guard ensures no duplicate user errors on pod restarts.

### 3. Skip Redis onboarding flag when auto-onboarding

When env vars are present and the user is created, don't set `CHATWOOT_INSTALLATION_ONBOARDING` in Redis. This means the onboarding screen never appears.

**Why:** The flag's only purpose is to redirect to the onboarding form. If the SuperAdmin already exists, showing the form is wrong — it would fail with "user already exists".

### 4. Reuse existing `AccountBuilder`

Call `AccountBuilder.new(..., super_admin: true, confirmed: true).perform` — the same service the onboarding controller uses.

**Why:** Proven path. Creates Account + User + AccountUser link in a transaction. No new code paths to test.

## Risks / Trade-offs

- **[Password in env var]** → The admin password is passed as an env var (via `envSecret`). This is standard K8s practice — the Secret is encrypted at rest (etcd encryption) and sourced from Infisical. Same pattern used for DB passwords, SMTP credentials, and S3 keys already.

- **[Shared password across instances]** → All instances share the same support user password. Acceptable for internal support access. If compromised, rotate in Infisical and restart pods. Future: per-instance generated passwords if needed.

- **[Seeds run on every pod start]** → The `User.exists?` guard makes this safe, but it's a DB query on every restart. Negligible cost — seeds already run `ConfigLoader` and Redis operations on every start.
