## ADDED Requirements

### Requirement: Auto-create SuperAdmin from environment variables
The system SHALL create a SuperAdmin user during database seeding when `CHATWOOT_ADMIN_EMAIL` and `CHATWOOT_ADMIN_PASSWORD` environment variables are present in production.

#### Scenario: Admin env vars present on fresh instance
- **WHEN** `CHATWOOT_ADMIN_EMAIL` and `CHATWOOT_ADMIN_PASSWORD` are set and no user with that email exists
- **THEN** the system creates a SuperAdmin user with the given email, password, name (`CHATWOOT_ADMIN_NAME`, default "Admin"), and an Account named from `CHATWOOT_ADMIN_COMPANY` (default "ChatWoot BR"), and does NOT set the Redis onboarding flag

#### Scenario: Admin env vars present but user already exists
- **WHEN** `CHATWOOT_ADMIN_EMAIL` is set and a user with that email already exists
- **THEN** the system skips user creation and does NOT set the Redis onboarding flag

#### Scenario: Admin env vars absent
- **WHEN** `CHATWOOT_ADMIN_EMAIL` is not set
- **THEN** the system sets the Redis onboarding flag (existing behavior preserved)

### Requirement: SuperAdmin user is confirmed and functional
The SuperAdmin created via auto-onboarding SHALL be immediately usable — no email confirmation required, full dashboard access on first login.

#### Scenario: Auto-created admin logs in
- **WHEN** the auto-created SuperAdmin navigates to the instance URL
- **THEN** the system shows the login page (not the onboarding screen) and the user can sign in with the configured email and password

### Requirement: Password is required when email is set
The system SHALL raise an error during seeding if `CHATWOOT_ADMIN_EMAIL` is set but `CHATWOOT_ADMIN_PASSWORD` is missing.

#### Scenario: Email set without password
- **WHEN** `CHATWOOT_ADMIN_EMAIL` is set but `CHATWOOT_ADMIN_PASSWORD` is not set
- **THEN** the system raises a `KeyError` during seed execution, preventing the instance from starting with an incomplete admin configuration
