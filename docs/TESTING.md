<!-- generated-by: gsd-doc-writer -->
# Testing

This document covers the test setup, conventions, and run commands for the Chatwoot fork. The project has two independent test stacks: **RSpec** for the Rails backend and **Vitest** for the Vue/JavaScript frontend.

---

## Test Frameworks and Versions

| Stack | Framework | Version |
|-------|-----------|---------|
| Ruby/Rails | RSpec | >= 6.1.5 |
| Ruby/Rails | factory_bot | (via `factory_bot_rails`) |
| Ruby/Rails | Faker | (via `faker`) |
| Ruby/Rails | WebMock | HTTP stubbing |
| Ruby/Rails | Shoulda::Matchers | Rails association/validation matchers |
| Ruby/Rails | test-prof | `let_it_be` / `before_all` optimizations |
| Ruby/Rails | SimpleCov | Coverage reporting |
| Ruby/Rails | Skooma | OpenAPI response validation |
| JavaScript/Vue | Vitest | (globals enabled) |
| JavaScript/Vue | jsdom | Browser environment simulation |
| JavaScript/Vue | Vue Test Utils | Component mounting |

Configuration files:
- `spec/spec_helper.rb` — RSpec core configuration
- `spec/rails_helper.rb` — Rails integration, helper includes, Skooma setup
- `vite.config.ts` — Vitest config (test section)
- `vitest.setup.js` — Vitest global setup

---

## Directory Layout

```
spec/
├── controllers/          # Controller/request specs (HTTP layer)
│   └── api/v1/accounts/conversations_controller_spec.rb
├── factories/            # factory_bot definitions
│   ├── accounts.rb
│   ├── contacts.rb
│   ├── conversations.rb
│   ├── inboxes.rb
│   ├── messages.rb
│   ├── users.rb
│   └── channel/
│       └── channel_whatsapp.rb  (handles whatsapp_web via provider conditional)
│       ├── channel_widget.rb
│       └── ...
├── fixtures/             # File fixtures (CSVs, images, binary assets)
│   └── files/sample.pdf
├── jobs/                 # Sidekiq/ActiveJob specs
│   ├── bulk_actions_job_spec.rb
│   └── conversation_reply_email_job_spec.rb
├── models/               # Model validation/association specs
│   ├── channel/
│   │   └── whatsapp_spec.rb
│   └── concerns/
├── services/             # Service object specs
│   └── whatsapp/
│       ├── incoming_message_whatsapp_web_service_spec.rb
│       ├── incoming_message_whatsapp_cloud_service_spec.rb
│       ├── webhook_setup_service_spec.rb
│       ├── webhook_teardown_service_spec.rb
│       ├── send_on_whatsapp_service_spec.rb
│       └── ...
├── support/              # Shared helpers and stubs (auto-required)
│   ├── slack_stubs.rb
│   ├── file_upload_helpers.rb
│   ├── csv_spec_helpers.rb
│   ├── instagram_spec_helpers.rb
│   ├── negated_matchers.rb
│   └── opensearch_check.rb
├── integration/          # Full request/response cycle specs
└── swagger/              # OpenAPI spec validation

app/javascript/
├── dashboard/composables/spec/    # Composable unit tests
├── dashboard/store/modules/       # Vuex store specs (*.spec.js alongside source)
└── dashboard/helper/specs/        # Helper function tests
```

JavaScript tests are co-located with source files using the naming convention `filename.spec.js`. The Vitest glob pattern is `app/**/*.{test,spec}.?(c|m)[jt]s?(x)`.

---

## Running Tests

### Full Backend Suite

```bash
bundle exec rspec
```

### Subset by Directory

```bash
bundle exec rspec spec/models/
bundle exec rspec spec/services/
bundle exec rspec spec/controllers/
bundle exec rspec spec/jobs/
bundle exec rspec spec/services/whatsapp/
```

### Single Spec File

```bash
bundle exec rspec spec/models/channel/whatsapp_spec.rb
bundle exec rspec spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb
```

### Single Example by Line Number

```bash
bundle exec rspec spec/models/channel/whatsapp_spec.rb:57
```

### Run by Pattern

```bash
bundle exec rspec --pattern "spec/jobs/*_spec.rb"
```

### With Profiling (show 10 slowest examples)

```bash
bundle exec rspec --profile=10
```

### Full Frontend Suite

```bash
pnpm test            # Run all Vitest tests (no watch, no cache)
pnpm test:watch      # Watch mode
pnpm test:coverage   # Coverage report (lcov + text)
```

### Single Frontend Spec

```bash
pnpm test -- app/javascript/dashboard/composables/spec/useAgentsList.spec.js
```

### Lint

```bash
bundle exec rubocop --parallel    # Ruby lint
pnpm run eslint                   # JavaScript lint
```

---

## Support Helpers

All files under `spec/support/` are auto-required by `spec/rails_helper.rb` via:

```ruby
Dir[Rails.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }
```

Helpers included globally in every spec:

| Module | File | Purpose |
|--------|------|---------|
| `SlackStubs` | `spec/support/slack_stubs.rb` | Stub Slack API calls |
| `FileUploadHelpers` | `spec/support/file_upload_helpers.rb` | Active Storage test helpers |
| `CsvSpecHelpers` | `spec/support/csv_spec_helpers.rb` | CSV import/export helpers |
| `InstagramSpecHelpers` | `spec/support/instagram_spec_helpers.rb` | Instagram channel stubs |
| `Devise::Test::IntegrationHelpers` | — | `sign_in`/`sign_out` in request specs |
| `ActiveSupport::Testing::TimeHelpers` | — | `travel_to`, `freeze_time` |
| `ActionCable::TestHelper` | — | ActionCable assertions |
| `ActiveJob::TestHelper` | — | `have_enqueued_job` matcher |
| `Skooma::RSpec[swagger/swagger.json]` | — | `conform_schema(200)` OpenAPI validation |

### Environment Variable Overrides

Use `with_modified_env` (via ClimateControl) to change ENV during a test:

```ruby
with_modified_env FRONTEND_URL: 'https://app.chatwoot.com' do
  service.perform
  expect(api_client).to have_received(:subscribe_waba_webhook)
    .with(waba_id, 'https://app.chatwoot.com/webhooks/whatsapp/+1234567890', anything)
end
```

---

## Factories

Factories live in `spec/factories/`. Key factories:

| Factory | File | Notes |
|---------|------|-------|
| `:account` | `spec/factories/accounts.rb` | Base tenant; sequences `name` |
| `:user` | `spec/factories/users.rb` | Devise user; traits `:agent`, `:administrator` |
| `:contact` | `spec/factories/contacts.rb` | Traits `:with_email`, `:with_phone_number`, `:with_avatar` |
| `:conversation` | `spec/factories/conversations.rb` | Auto-builds account, inbox, contact, contact_inbox; traits `:with_team`, `:with_assignee` |
| `:message` | `spec/factories/messages.rb` | Traits `:with_attachment`, `:bot_message`, `:instagram_story_mention` |
| `:inbox` | `spec/factories/inboxes.rb` | Defaults to `channel_widget`; trait `:with_email` |
| `:channel_whatsapp` | `spec/factories/channel/channel_whatsapp.rb` | See WhatsApp section below |
| `:contact_inbox` | `spec/factories/contact_inbox.rb` | Joins contact to inbox with `source_id` |
| `:team` | `spec/factories/teams.rb` | |
| `:label` | `spec/factories/labels.rb` | |
| `:webhook` | `spec/factories/webhooks.rb` | |

**Common factory patterns:**

```ruby
let(:account) { create(:account) }
let(:user)    { create(:user, account: account, role: :agent) }
let(:contact) { create(:contact, :with_email, account: account) }

# Multiple records
let(:agents)  { create_list(:user, 3, account: account, role: :agent) }

# In-memory only (not persisted)
let(:channel) { build(:channel_whatsapp, account: account) }
```

---

## Mocking and Stubbing

### WebMock (HTTP)

WebMock is active in all specs. Real HTTP connections are blocked (localhost allowed). Stub external calls explicitly:

```ruby
# Stub a GET with JSON response
stub_request(:get, 'https://graph.facebook.com/v14.0//message_templates?access_token=test_key')
  .to_return(status: 200, body: { data: [{ id: '123', name: 'template' }] }.to_json)

# Stub to return an error
stub_request(:get, 'https://graph.facebook.com/v14.0//message_templates?access_token=test_key')
  .to_return(status: 401)

# Stub a broad pattern (used in webhook tests)
stub_request(:delete, /graph.facebook.com/).to_return(status: 200, body: '{}', headers: {})
```

WebMock config in `spec/spec_helper.rb`:
```ruby
WebMock.disable_net_connect!(allow_localhost: true)
```

### RSpec Doubles

```ruby
# Instance double (type-checked)
let(:api_client) { instance_double(Whatsapp::FacebookApiClient) }
allow(Whatsapp::FacebookApiClient).to receive(:new).and_return(api_client)
allow(api_client).to receive(:phone_number_verified?).and_return(false)

# Verify a call happened
expect(api_client).to have_received(:register_phone_number).with('123456789', 223_456)

# Old-style double (not type-checked)
let(:mailer_double) { double }
allow(mailer_double).to receive(:deliver_later)
```

### Vitest Mocking

```javascript
// Auto-mock an entire module
vi.mock('dashboard/composables/store');

// Mock with factory
vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

// Clear between tests
beforeEach(() => { vi.clearAllMocks(); });

// Spy on a specific method
agentHelper.getAgentsByUpdatedPresence.mockImplementation(agents => agents);

// Verify
expect(mockFunction).toHaveBeenCalledWith(expectedArg);
```

### Time

```ruby
travel_to(Time.zone.parse('2025-06-01 12:00:00')) do
  expect(token.expired?).to be false
end
```

---

## WhatsApp Provider Testing

### `:channel_whatsapp` Factory Behaviour

The factory at `spec/factories/channel/channel_whatsapp.rb` has important defaults:

- **`sync_templates: false`** (transient) — bypasses the `sync_templates` after-create callback by defining a singleton no-op method on the instance.
- **`validate_provider_config: false`** (transient) — bypasses the `validate_provider_config` callback, preventing HTTP calls to the Facebook Graph API during creation.
- **`whatsapp_cloud` provider** — the factory automatically injects `source: 'embedded_signup'` into `provider_config` unless `source` is explicitly provided. This prevents the `after_commit :setup_webhooks` callback from firing.

To test webhook setup explicitly, override `source`:

```ruby
create(:channel_whatsapp,
       provider: 'whatsapp_cloud',
       provider_config: { 'source' => nil, 'business_account_id' => 'waba_id', 'api_key' => 'token' },
       validate_provider_config: false,
       sync_templates: false)
```

To create a `whatsapp_web` channel:

```ruby
create(:channel_whatsapp,
       provider: 'whatsapp_web',
       provider_config: { 'device_id' => '5511999999999' },
       sync_templates: false,
       validate_provider_config: false)
```

### Whatsapp::WebhookSetupService Tests

`spec/services/whatsapp/webhook_setup_service_spec.rb` — tests the full setup path. Pattern:

```ruby
let(:api_client) { instance_double(Whatsapp::FacebookApiClient) }
before do
  allow(Whatsapp::FacebookApiClient).to receive(:new).and_return(api_client)
  stub_request(:delete, /graph.facebook.com/).to_return(status: 200, body: '{}')
  Channel::Whatsapp.destroy_all  # avoid phone_number uniqueness conflicts
end
```

Uses `with_modified_env FRONTEND_URL: '...'` to verify the webhook URL built by the service.

### WhatsApp Web Incoming Message Tests

`spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb` — covers LID-based contacts, from_lid merging, and message deduplication:

```ruby
# Dedup lock is stubbed globally to avoid Redis leaks across examples
allow(Whatsapp::MessageDedupLock).to receive(:new).and_return(
  instance_double(Whatsapp::MessageDedupLock, acquire!: true)
)
```

LID contact creation is verified by asserting `contact.additional_attributes['is_lid_chat']` and `contact.additional_attributes['lid']` on the created record.

---

## Request Spec Conventions

Request specs (in `spec/controllers/`) use `type: :request` (inferred from location) and the Devise integration helper:

```ruby
RSpec.describe 'Conversations API', type: :request do
  let(:account) { create(:account) }
  let(:agent)   { create(:user, account: account, role: :agent) }

  it 'returns conversations' do
    get "/api/v1/accounts/#{account.id}/conversations",
        headers: agent.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response).to conform_schema(200)  # Skooma OpenAPI validation
  end
end
```

`conform_schema(200)` validates the response body against `swagger/swagger.json` via Skooma.

Unauthenticated requests are tested without headers:

```ruby
get "/api/v1/accounts/#{account.id}/conversations"
expect(response).to have_http_status(:unauthorized)
```

---

## test-prof Patterns

For expensive setup shared across many examples in a group:

```ruby
require 'test_prof/recipes/rspec/let_it_be'

RSpec.describe SomeModel do
  # Created once per describe block, not rolled back between examples
  let_it_be(:account) { create(:account) }

  # Still rolled back per example (normal let)
  let(:contact) { create(:contact, account: account) }
end
```

Use `let_it_be` only for records that tests do not mutate. Mutable records should use `let`.

---

## Coverage

### Ruby (SimpleCov)

Run the full suite and open the report:

```bash
bundle exec rspec
open coverage/index.html
```

CI produces `rspec.xml` via `RspecJunitFormatter`. No minimum threshold is enforced.

### JavaScript (Vitest)

```bash
pnpm test:coverage
open coverage/lcov-report/index.html
```

Output formats: `lcov` (`coverage/lcov.info`) and `text` (stdout). The Sonar XML is written to `coverage/sonar-report.xml`.

Coverage scope: `app/**/*.js`, `app/**/*.vue` — excludes `*.spec.js`, `*.stories.js`, `i18n/`, `specs/` directories.

---

## CI Workflows

### Backend — `.github/workflows/run_foss_spec.yml`

Triggers: push to `next`, pull_request (any branch), `workflow_dispatch`.

| Job | What it does |
|-----|-------------|
| `lint-backend` | `bundle exec rubocop --parallel` |
| `lint-frontend` | `pnpm run eslint` |
| `frontend-tests` | `pnpm run test:coverage` (Node 24) |
| `backend-tests` | RSpec parallelized across **16 matrix nodes** |

The backend matrix splits spec files using round-robin distribution:

```bash
SPEC_FILES=($(find spec -name '*_spec.rb' | sort))
# Each node runs files where: index % 16 == node_index
bundle exec rspec --profile=10 --format progress --format json --out tmp/rspec_results.json $TESTS
```

Services spun up per matrix node: PostgreSQL 16 (`pgvector/pgvector:pg16`) and Redis (alpine). Enterprise code is stripped before running (`rm -rf enterprise spec/enterprise`).

Test results are uploaded as artifacts (`rspec-results-{index}.json`). Rails logs are uploaded on failure.

### Frontend — `.github/workflows/frontend-fe.yml`

Triggers: push to `next`, pull_request to `next`.

Runs `pnpm run eslint` then `pnpm run test:coverage` on Node 24.

---

## Known Flaky Areas

- **Phone number uniqueness**: `Channel::Whatsapp` has a global unique index on `phone_number`. Tests that create multiple WhatsApp channels in sequence must either use sequenced phone numbers (the factory does this) or call `Channel::Whatsapp.destroy_all` in a `before` block. See `spec/services/whatsapp/webhook_setup_service_spec.rb` for the pattern.
- **Redis dedup lock leakage**: `Whatsapp::MessageDedupLock` uses Redis with a long TTL. Tests in `spec/services/whatsapp/incoming_message_whatsapp_web_service_spec.rb` stub it globally to avoid cross-example contamination when intentionally reusing fixed message IDs.
- **Webhook callbacks**: Creating a `whatsapp_cloud` channel without the correct `provider_config` shape (or without the `validate_provider_config: false` transient flag) triggers live HTTP calls via WebMock and raises `WebMock::NetConnectNotAllowedError`. Always pass `validate_provider_config: false, sync_templates: false` when the test is not about channel creation itself.
