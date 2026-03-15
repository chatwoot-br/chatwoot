## 1. Core Implementation

- [x] 1.1 Modify `db/seeds.rb` production block: detect `CHATWOOT_ADMIN_EMAIL`, create SuperAdmin via `AccountBuilder`, skip Redis onboarding flag
- [x] 1.2 Use `ENV.fetch('CHATWOOT_ADMIN_PASSWORD')` (raises `KeyError` if missing when email is set)
- [x] 1.3 Guard with `User.exists?(email: admin_email)` for idempotency

## 2. Validation

- [x] 2.1 Add spec for auto-onboard path: env vars present, fresh DB → SuperAdmin created, no onboarding flag
- [x] 2.2 Add spec for idempotency: env vars present, user already exists → no error, no duplicate
- [x] 2.3 Add spec for missing password: email set without password → KeyError raised
- [x] 2.4 Add spec for fallback: no env vars → Redis onboarding flag set (existing behavior)
