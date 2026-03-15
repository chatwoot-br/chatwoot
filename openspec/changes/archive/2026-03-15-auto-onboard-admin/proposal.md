## Why

Every new Chatwoot instance boots into a manual onboarding screen (`/installation/onboarding`) that requires someone to fill out a browser form to create the first SuperAdmin user. For operator-provisioned instances, this blocks automation — the instance sits idle until a human completes the form. We need the internal support user (`suporte@chatwoot.app.br`) to be auto-created as SuperAdmin at deploy time so instances are immediately operational.

## What Changes

- Modify `db/seeds.rb` production block to detect `CHATWOOT_ADMIN_EMAIL` env var
- When present: create SuperAdmin user + Account via `AccountBuilder`, skip the Redis onboarding flag
- When absent: preserve current behavior (show onboarding screen)
- Idempotent: guard with `User.exists?(email:)` so re-runs of `db:prepare` are safe

## Capabilities

### New Capabilities
- `auto-onboard-admin`: Automatic SuperAdmin provisioning from environment variables during database seed, bypassing the browser-based onboarding flow

### Modified Capabilities

None — the existing onboarding flow is untouched when env vars are not set.

## Impact

- **Code**: `db/seeds.rb` (production block only, ~10 lines)
- **Dependencies**: None new — uses existing `AccountBuilder`
- **Config**: New optional env vars: `CHATWOOT_ADMIN_EMAIL`, `CHATWOOT_ADMIN_PASSWORD`, `CHATWOOT_ADMIN_NAME`, `CHATWOOT_ADMIN_COMPANY`
- **Operator**: No code changes — uses existing `spec.env` + `spec.envSecret`
- **Infisical**: New shared secret `CHATWOOT_ADMIN_PASSWORD` synced via ESO to instance namespaces
