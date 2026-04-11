# Testing Patterns

**Analysis Date:** 2026-04-11

## Test Framework

**Ruby Test Runner:**
- Framework: RSpec (>= 6.1.5)
- Config: `spec/rails_helper.rb` and `spec/spec_helper.rb`
- Database: Transactional fixtures (test transactions)
- Spec type inference: Automatic based on file location

**JavaScript/Vue Test Runner:**
- Framework: Vitest (with globals)
- Config: `vite.config.ts` (test section) and `vitest.setup.js`
- Test environment: jsdom (browser environment simulation)
- Globals enabled: `describe`, `it`, `expect`, `beforeEach`, `afterEach` etc. available without import

**Assertion Library:**
- Ruby: RSpec matchers + Shoulda::Matchers for Rails
- JavaScript: Vitest assertions (compatible with Jest)

**Run Commands:**

```bash
# Ruby tests
bundle exec rspec                    # Run all RSpec tests
bundle exec rspec spec/models/       # Run model specs only
bundle exec rspec spec/services/     # Run service specs only
bundle exec rspec --pattern "spec/jobs/*_spec.rb"  # Run by pattern

# JavaScript tests
pnpm test                            # Run Vitest (no watch, no cache)
pnpm test:watch                      # Watch mode
pnpm test:coverage                   # Coverage report (lcov + text)

# Combined
./bin/ci                             # CI pipeline (runs both stacks)
```

## Test File Organization

**Ruby Test Location:**
- Co-located with source code directory structure
- `spec/models/` → `app/models/`
- `spec/services/` → `app/services/`
- `spec/builders/` → `app/builders/`
- `spec/listeners/` → `app/listeners/`
- `spec/dispatchers/` → `app/dispatchers/`
- `spec/policies/` → `app/policies/`
- `spec/mailers/` → `app/mailers/`
- `spec/jobs/` → `app/jobs/`
- `spec/controllers/` → `app/controllers/`
- `spec/helpers/` → `app/helpers/`
- `spec/integration/` → Integration/request specs
- `spec/support/` → Shared helpers, stubs, and fixtures

**JavaScript Test Location:**
- Co-located with source file: `filename.spec.js` in same directory
- Pattern: `app/**/*.{test,spec}.?(c|m)[jt]s?(x)` (from `vite.config.ts`)
- Exception: `spec/` directories allowed for fixtures and test utilities
- Examples:
  - `app/javascript/dashboard/composables/useAutomation.js` → `spec/useAutomation.spec.js` (in same dir)
  - `app/javascript/dashboard/helper/specs/` → Test utilities directory

**Naming Convention:**
- Ruby: `[name]_spec.rb`
- JavaScript: `[name].spec.js` or `[name].test.js`

## Test File Structure

**Ruby Model Test Example** (`spec/models/account_spec.rb`):

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Account do
  # Associations testing
  it { is_expected.to have_many(:users).through(:account_users) }
  it { is_expected.to have_many(:inboxes).dependent(:destroy_async) }

  # Validation testing
  describe 'length validations' do
    let(:account) { create(:account) }

    it 'validates name presence' do
      account.name = ''
      account.valid?
      expect(account.errors[:name]).to include("can't be blank")
    end
  end

  # Method testing
  describe '#inbound_email_domain' do
    let(:account) { create(:account) }

    context 'when domain is set' do
      it 'returns account domain' do
        account.update(domain: 'test.com')
        expect(account.inbound_email_domain).to eq('test.com')
      end
    end
  end
end
```

**Ruby Service Test Example** (`spec/services/account_deletion_service_spec.rb`):

```ruby
require 'rails_helper'

RSpec.describe AccountDeletionService do
  let(:account) { create(:account) }
  let(:mailer) { instance_double(ActionMailer::MessageDelivery, deliver_later: nil) }

  describe '#perform' do
    before do
      allow(DeleteObjectJob).to receive(:perform_later)
      allow(AdministratorNotifications::AccountComplianceMailer)
        .to receive(:with).and_return(
          instance_double(AdministratorNotifications::AccountComplianceMailer, account_deleted: mailer)
        )
    end

    it 'enqueues DeleteObjectJob with the account' do
      described_class.new(account: account).perform

      expect(DeleteObjectJob).to have_received(:perform_later).with(account)
    end

    context 'when handling users' do
      let(:user) { create(:user) }

      before do
        create(:account_user, user: user, account: account)
      end

      it 'soft deletes users who only belong to the deleted account' do
        original_email = user.email
        described_class.new(account: account).perform
        user.reload

        expect(user.email).not_to eq(original_email)
      end
    end
  end
end
```

**JavaScript Composable Test Example** (`app/javascript/dashboard/composables/spec/useAgentsList.spec.js`):

```javascript
import { ref } from 'vue';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { useAgentsList } from '../useAgentsList';
import { useMapGetter } from 'dashboard/composables/store';
import { allAgentsData } from './fixtures/agentFixtures';
import * as agentHelper from 'dashboard/helper/agentHelper';

// Mock dependencies
vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => (key === 'AGENT_MGMT.MULTI_SELECTOR.LIST.NONE' ? 'None' : key),
  }),
}));

vi.mock('dashboard/composables/store');
vi.mock('dashboard/helper/agentHelper');

describe('useAgentsList', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    agentHelper.getAgentsByUpdatedPresence.mockImplementation(agents => agents);
    useMapGetter.mockImplementation(getter => ref([]));
  });

  it('returns agentsList and assignableAgents', () => {
    const { agentsList, assignableAgents } = useAgentsList();

    expect(assignableAgents.value).toEqual([]);
    expect(agentsList.value).toBeDefined();
  });

  it('includes None agent when includeNoneAgent is true', () => {
    const { agentsList } = useAgentsList(true);

    expect(agentsList.value[0].id).toBe(0);
  });
});
```

## Test Structure

**RSpec Describe/Context Blocks:**

```ruby
RSpec.describe ModelName do
  # Setup: factories, mocks
  let(:user) { create(:user) }
  let(:account) { create(:account) }

  # Group related tests
  describe '#method_name' do
    context 'when condition is true' do
      before do
        # Setup specific to this context
      end

      it 'does something' do
        expect(user.method_name).to eq(expected_value)
      end
    end

    context 'when condition is false' do
      it 'does something else' do
        expect(result).not_to eq(unwanted_value)
      end
    end
  end
end
```

Nesting limit: Max 4 levels deep (enforced by `RSpec/NestedGroups` in `.rubocop.yml`)

**Shared Examples and Shared Contexts:**

Location: `spec/support/shared_*.rb`

```ruby
# spec/support/shared_examples/api_authorization.rb
RSpec.shared_examples 'api endpoint requires authentication' do
  context 'without authentication' do
    it 'returns 401 unauthorized' do
      get_request_without_auth
      expect(response).to have_http_status(:unauthorized)
    end
  end
end

# Usage in a spec
RSpec.describe Api::V1::UsersController do
  include_examples 'api endpoint requires authentication'
end
```

**Patterns:**

Test-Prof for optimization:
```ruby
require 'test_prof/recipes/rspec/before_all'
require 'test_prof/recipes/rspec/let_it_be'

RSpec.describe Account do
  # Shared across all tests in this group (no transaction rollback)
  let_it_be(:account) { create(:account) }

  # Reused but rolled back per test
  let(:contact) { create(:contact, account: account) }
end
```

## Mocking and Stubbing

**WebMock (for HTTP requests):**
- Configured in `spec/spec_helper.rb`
- Disables real HTTP except localhost
- Used to mock external API calls

```ruby
# Disable real HTTP
WebMock.disable_net_connect!(allow_localhost: true)

# In tests
before do
  stub_request(:get, 'https://api.example.com/users').to_return(
    status: 200,
    body: { users: [] }.to_json
  )
end

it 'fetches users from API' do
  result = ExternalAPIService.new.fetch_users
  expect(result).to eq([])
end
```

**RSpec Doubles/Mocks:**
```ruby
# Instance double with methods
let(:mailer) { instance_double(ActionMailer::MessageDelivery, deliver_later: nil) }

# Mock class method
allow(DeleteObjectJob).to receive(:perform_later)

# Verify it was called
expect(DeleteObjectJob).to have_received(:perform_later).with(account)
```

**Vitest Mocking:**
```javascript
vi.mock('module/path');  // Auto-mock module
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

// Clear mocks between tests
beforeEach(() => {
  vi.clearAllMocks();
});

// Verify calls
expect(mockFunction).toHaveBeenCalledWith(expectedArg);
```

**What to Mock:**
- External API calls (HTTP requests)
- Third-party services (Stripe, Twilio, etc.)
- Expensive operations (file uploads, image processing)
- Time-dependent code (use `ActiveSupport::Testing::TimeHelpers`)
- Date/time: `travel_to(Time.zone.parse('2020-01-01 12:00:00'))`

**What NOT to Mock:**
- Database queries (use test database)
- Models and their associations
- Helper methods and utilities
- Controllers (use full request specs)
- Your own services (test them in isolation)

## Fixtures and Factories

**Factory Bot:**
Location: `spec/factories/*.rb`

```ruby
# spec/factories/accounts.rb
FactoryBot.define do
  factory :account do
    sequence(:name) { |n| "Account #{n}" }
    status { 'active' }
    domain { 'test.com' }
    support_email { 'support@test.com' }

    # Traits for variations
    trait :inactive do
      status { 'inactive' }
    end

    # Associated records
    association :user, factory: :user
  end
end
```

Usage:
```ruby
let(:account) { create(:account) }                    # Create with defaults
let(:account) { create(:account, :inactive) }        # With trait
let(:accounts) { create_list(:account, 3) }          # Multiple records
let(:account) { build(:account) }                    # In-memory (not saved)
```

Factory syntax in RSpec:
- `create(...)` - Create and save record
- `build(...)` - Create in-memory object
- `create_list(..., count)` - Create multiple

Faker for data:
```ruby
sequence(:email) { |n| "user#{n}@example.com" }
name { Faker::Name.name }
phone_number { Faker::PhoneNumber.cell_phone }
```

**Test Fixtures:**
Location: `spec/fixtures/`

Used for:
- File uploads (CSV imports, images)
- Sample responses from external APIs
- Binary data

Access in tests:
```ruby
file_fixture('sample.csv')  # Returns file path
fixture_file_upload('sample.csv', 'text/csv')  # For file uploads
```

## Coverage

**Ruby:**
- Tool: SimpleCov
- Run: `bundle exec rspec --format RspecJunitFormatter --out rspec.xml`
- Coverage report: `coverage/index.html`
- Target: No strict requirement enforced

**JavaScript:**
- Tool: Vitest coverage reporter
- Run: `pnpm test:coverage`
- Output: `coverage/sonar-report.xml`, `coverage/lcov.info`
- Reporters: `['lcov', 'text']`
- Include: `app/**/*.js`, `app/**/*.vue`
- Exclude: `*.spec.js`, `*.stories.js`, `i18n/`, `specs/`

View coverage:
```bash
# Ruby
open coverage/index.html

# JavaScript
open coverage/lcov-report/index.html
```

## Test Types and Scope

**Ruby Tests:**

Model Specs (`spec/models/`):
- Test validations, associations, callbacks
- No database calls beyond save/load
- Test scopes and class methods

```ruby
RSpec.describe Contact do
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to have_many(:conversations) }

  describe '.active' do
    let(:active) { create(:contact, status: 'active') }
    let(:inactive) { create(:contact, status: 'inactive') }

    it 'returns only active contacts' do
      expect(Contact.active).to include(active)
      expect(Contact.active).not_to include(inactive)
    end
  end
end
```

Service Specs (`spec/services/`):
- Test business logic in isolation
- Mock external dependencies
- Verify return values and side effects

Controller Specs (`spec/controllers/` or request specs in `spec/integration/`):
- Test HTTP endpoints
- Verify response status, JSON payload
- Test authorization/authentication

```ruby
RSpec.describe Api::V1::UsersController do
  describe 'GET /api/v1/users' do
    let(:user) { create(:user) }

    before { sign_in user }

    it 'returns list of users' do
      get :index
      expect(response).to have_http_status(:ok)
      expect(response_json['users']).not_to be_empty
    end
  end
end
```

Job Specs (`spec/jobs/`):
- Test Sidekiq background jobs
- Verify job enqueueing

```ruby
RSpec.describe ProcessScheduledMessagesJob do
  it 'enqueues the job' do
    expect {
      described_class.perform_later(conversation_id)
    }.to have_enqueued_job(described_class).with(conversation_id)
  end
end
```

Mailer Specs (`spec/mailers/`):
- Test email generation
- Verify subject, to, body

Integration Specs (`spec/integration/`):
- Test full request/response cycle
- Test feature workflows

System Specs:
- Browser-based testing with Capybara
- Not heavily used in this codebase (see CI workflows)

**JavaScript Tests:**

Composable Tests (`*.spec.js` in same directory):
- Test reactivity and computed properties
- Mock store getters
- Verify function returns

```javascript
it('returns agentsList', () => {
  const { agentsList } = useAgentsList();
  expect(agentsList.value).toBeDefined();
});
```

Component Tests:
- Limited in codebase (via Storybook stories)
- Component prop validation
- Event emission

Store Module Tests:
- Test mutations, actions, getters
- Mock API client
- Verify state changes

Helper Tests:
- Pure function testing
- No Vue dependencies

## Common Test Patterns

**Async Testing (Ruby):**

```ruby
it 'handles async operations' do
  expect {
    described_class.new(user: user).perform
  }.to change(User, :count).by(1)
end

# With ActiveJob
it 'enqueues a job' do
  expect {
    action
  }.to have_enqueued_job(SomeJob).with(arg)
end
```

**Async Testing (JavaScript):**

```javascript
it('fetches and updates state', async () => {
  const { agentsList } = useAgentsList();

  // Wait for computed to update
  await nextTick();

  expect(agentsList.value).toHaveLength(3);
});

// For store actions
it('handles async action', async () => {
  await store.dispatch('agents/get');

  expect(store.state.agents.records).toBeDefined();
});
```

**Error Testing (Ruby):**

```ruby
it 'raises custom exception on invalid email' do
  expect {
    AccountBuilder.new(email: 'invalid').perform
  }.to raise_error(CustomExceptions::Account::InvalidEmail)
end
```

**Error Testing (JavaScript):**

```javascript
it('throws error on API failure', async () => {
  const { t } = useI18n();
  vi.mock('dashboard/api/agents', () => ({
    get: () => Promise.reject(new Error('API Error')),
  }));

  await expect(
    store.dispatch('agents/get')
  ).rejects.toThrow('API Error');
});
```

**Time-Dependent Tests:**

```ruby
# Ruby
it 'expires token after 5 minutes' do
  travel_to(2.minutes.from_now) do
    expect(token.expired?).to be false
  end

  travel_to(6.minutes.from_now) do
    expect(token.expired?).to be true
  end
end

# Or with freeze_time
freeze_time do
  Timecop.travel(5.minutes.from_now)
  # assertions
end
```

**Database Transaction Testing:**

```ruby
it 'rolls back on validation error' do
  expect {
    ActiveRecord::Base.transaction do
      create(:user)
      create(:invalid_user)  # Raises error
    end
  }.to raise_error
end
```

## CI Workflow

**Workflow Files:**
- `.github/workflows/` directory
- Key workflows: `test_*.yml` files
- Ruby tests: Usually run via `bundle exec rspec`
- JavaScript tests: Via `pnpm test`

Testing is integrated into CI checks on PRs.

## Test Shared Contexts and Helpers

**Located in:** `spec/support/`

Examples:
- `spec/support/slack_stubs.rb` - Slack API mocking
- `spec/support/file_upload_helpers.rb` - File handling in tests
- `spec/support/csv_spec_helpers.rb` - CSV testing utilities
- `spec/support/instagram_spec_helpers.rb` - Instagram-specific stubs

Included globally in `spec/rails_helper.rb`:
```ruby
config.include SlackStubs
config.include FileUploadHelpers
config.include CsvSpecHelpers
config.include InstagramSpecHelpers
```

**Environment Helpers:**
```ruby
# Modify ENV during test
with_modified_env MAILER_INBOUND_EMAIL_DOMAIN: 'test.com' do
  # Test code runs with modified ENV
end
```

Implemented with ClimateControl gem.

---

*Testing analysis: 2026-04-11*
