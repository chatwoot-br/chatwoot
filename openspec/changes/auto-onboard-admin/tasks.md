## 1. Core Implementation

- [ ] 1.1 Modify `db/seeds.rb` production block: detect `CHATWOOT_ADMIN_EMAIL`, create SuperAdmin via `AccountBuilder`, skip Redis onboarding flag
- [ ] 1.2 Use `ENV.fetch('CHATWOOT_ADMIN_PASSWORD')` (raises `KeyError` if missing when email is set)
- [ ] 1.3 Guard with `User.exists?(email: admin_email)` for idempotency

## 2. Validation

- [ ] 2.1 Add spec for auto-onboard path: env vars present, fresh DB → SuperAdmin created, no onboarding flag
- [ ] 2.2 Add spec for idempotency: env vars present, user already exists → no error, no duplicate
- [ ] 2.3 Add spec for missing password: email set without password → KeyError raised
- [ ] 2.4 Add spec for fallback: no env vars → Redis onboarding flag set (existing behavior)
