<!-- generated-by: gsd-doc-writer -->
# Development Guide

Day-to-day development conventions for the Chatwoot fork. For prerequisites and
first-run setup, see `docs/GETTING-STARTED.md`. For system architecture, see
`docs/ARCHITECTURE.md`.

---

## Table of Contents

1. [Dev Loop Commands](#dev-loop-commands)
2. [Code Style and Linting](#code-style-and-linting)
3. [Ruby Conventions](#ruby-conventions)
4. [Service Object Pattern](#service-object-pattern)
5. [Builder Pattern](#builder-pattern)
6. [Listener / Dispatcher Pattern](#listener--dispatcher-pattern)
7. [Pundit Policies](#pundit-policies)
8. [Serializers (jbuilder)](#serializers-jbuilder)
9. [Frontend State Management (Vuex)](#frontend-state-management-vuex)
10. [Vue Composables](#vue-composables)
11. [Adding a New API Endpoint](#adding-a-new-api-endpoint)
12. [Adding a New Dashboard Page](#adding-a-new-dashboard-page)
13. [Adding a New Channel](#adding-a-new-channel)
14. [Commit and PR Conventions](#commit-and-pr-conventions)

---

## Dev Loop Commands

### Rails / Backend

| Command | What it does |
|---|---|
| `bundle exec rails server` | Start Rails on port 3000 |
| `bundle exec sidekiq` | Start background job processor |
| `bundle exec rspec` | Run the full RSpec suite |
| `bundle exec rspec spec/models/` | Run a subset of specs |
| `bundle exec rspec spec/path/to/file_spec.rb` | Run a single spec file |
| `bundle exec rspec spec/path/to/file_spec.rb:42` | Run a single example at line 42 |
| `bundle exec rubocop` | Lint Ruby (read-only) |
| `bundle exec rubocop -a` | Auto-fix safe Rubocop offenses |
| `bundle exec rubocop -A` | Auto-fix all offenses (unsafe included) |
| `pnpm ruby:prettier` | Alias for `bundle exec rubocop -a` |

### Frontend

| Command | What it does |
|---|---|
| `pnpm dev` | Start Vite dev server (uses `overmind` + `Procfile.dev`) |
| `pnpm start:dev` | Same via `foreman` |
| `pnpm eslint` | Lint all JS/Vue files |
| `pnpm eslint:fix` | Auto-fix ESLint violations |
| `pnpm test` | Run Vitest once (no watch, no coverage) |
| `pnpm test:watch` | Run Vitest in watch mode |
| `pnpm test:coverage` | Run Vitest with coverage report |
| `pnpm story:dev` | Start Histoire component explorer |

### Full stack (recommended for daily work)

```bash
# Terminal 1 — backend
bundle exec rails server

# Terminal 2 — background jobs
bundle exec sidekiq

# Terminal 3 — frontend
pnpm dev
```

Or start everything at once with overmind:

```bash
pnpm dev   # reads Procfile.dev
```

---

## Code Style and Linting

### Ruby — Rubocop

Config: `.rubocop.yml` (project root)

Plugins active: `rubocop-performance`, `rubocop-rails`, `rubocop-rspec`,
`rubocop-factory_bot`.

Custom cops:
- `rubocop/use_from_email.rb`
- `rubocop/custom_cop_location.rb`
- `rubocop/attachment_download.rb`
- `rubocop/one_class_per_file.rb`

Key limits enforced:

| Rule | Limit |
|---|---|
| `Layout/LineLength` | 150 characters |
| `Metrics/ClassLength` | 175 lines |
| `Metrics/MethodLength` | 19 lines |
| `RSpec/ExampleLength` | 50 lines |
| `Style/FrozenStringLiteralComment` | disabled |
| `Style/Documentation` | disabled |

Run before every commit:

```bash
bundle exec rubocop -a
```

### JavaScript / Vue — ESLint

Config: `.eslintrc.js` (project root)

Extends: `airbnb-base/legacy`, `prettier`, `plugin:vue/vue3-recommended`,
`plugin:vitest-globals/recommended`, `plugin:@intlify/vue-i18n/recommended`.

Key rules:
- `vue/block-order`: `<script>` → `<template>` → `<style>` (enforced)
- `vue/no-bare-strings-in-template`: error — all UI strings must use `t('KEY')`
- `no-console`: error in production code (allowed in `*.story.vue`)
- `vue/component-name-in-template-casing`: PascalCase only
- `vue/next-tick-style`: callback style required

Run:

```bash
pnpm eslint          # check
pnpm eslint:fix      # auto-fix
```

### Prettier

Config: `.prettierrc` (project root)

```json
{
  "printWidth": 80,
  "singleQuote": true,
  "trailingComma": "es5",
  "arrowParens": "avoid"
}
```

Prettier is invoked through ESLint via `eslint-plugin-prettier`, so
`pnpm eslint:fix` also formats code.

---

## Ruby Conventions

### Naming

- Files: `snake_case` — `account_deletion_service.rb`, `base_listener.rb`
- Classes / modules: `PascalCase` — `AccountBuilder`, `BaseListener`
- Methods: `snake_case`; predicate methods end with `?` (`access_token_expired?`)
- Instance variables: `@account`, `@contact_inbox`
- Constants: `UPPER_CASE` — `RESULTS_PER_PAGE`, `EDITABLE_ATTRS`

### Module nesting

Prefer compact style:

```ruby
class Api::V1::Accounts::ContactsController < Api::V1::Accounts::BaseController
  # ...
end
```

### Error handling

Custom exceptions live in `lib/custom_exceptions/[domain].rb`. They inherit
from `CustomExceptions::Base` which provides `message`, `http_status`, and
`to_hash`. Namespace by domain:

```ruby
CustomExceptions::Account::InvalidEmail
CustomExceptions::CustomFilter::InvalidAttribute
```

Raise in builders/services; rescue in controllers and render the error hash.

### File structure inside a class

1. Includes / concerns
2. `pattr_initialize` parameter declaration
3. Constants and schema definitions
4. Validations
5. Associations
6. Public methods
7. `private` keyword
8. Private helper methods

---

## Service Object Pattern

Location: `app/services/[domain]/` or `app/services/[name]_service.rb`

A service object encapsulates a single business operation. It has one public
entry point (`perform`) and no instance state after construction.

```ruby
class MyOperationService
  pattr_initialize [:required_param!, :optional_param]

  def perform
    do_step_one
    do_step_two
  end

  private

  def do_step_one
    # ...
  end

  def do_step_two
    # ...
  end
end

# Usage
MyOperationService.new(required_param: value).perform
```

Rules:
- Use `pattr_initialize`; suffix required params with `!`
- Return result directly from `perform` (no wrapper object)
- Raise custom exceptions for domain errors; let the controller rescue them
- Keep each private method under 19 lines (Rubocop enforced)

Real examples: `app/services/account_deletion_service.rb`,
`app/services/base_refresh_oauth_token_service.rb`.

---

## Builder Pattern

Location: `app/builders/[name]_builder.rb`

Builders orchestrate the creation of multiple related records inside a single
transaction. They return an array of the created objects.

```ruby
class ThingBuilder
  include CustomExceptions::Thing
  pattr_initialize [:param_a!, :param_b]

  def perform
    ActiveRecord::Base.transaction do
      @primary = create_primary
      @related = create_related
      [@primary, @related]
    end
  end

  private

  def create_primary
    # ...
  end

  def create_related
    # ...
  end
end

# Usage — returns [primary, related]
primary, related = ThingBuilder.new(param_a: val).perform
```

Real examples: `app/builders/account_builder.rb`,
`app/builders/conversation_builder.rb`,
`app/builders/contact_inbox_builder.rb`.

---

## Listener / Dispatcher Pattern

### Listeners

Location: `app/listeners/[name]_listener.rb`

Listeners implement the observer pattern using the **Wisper** pub/sub gem.
Every listener is a singleton. Models broadcast events; listeners react to them.

```ruby
class ThingListener
  include Singleton

  def thing_created(event)
    object = event.data[:thing]
    account = object.account
    # react to the event
  end
end
```

`app/listeners/base_listener.rb` provides shared helpers such as
`extract_conversation_and_account(event)`. Listeners are subscribed in
`config/initializers/`.

Real examples: `app/listeners/webhook_listener.rb`,
`app/listeners/notification_listener.rb`,
`app/listeners/automation_rule_listener.rb`.

### Dispatchers

Location: `app/dispatchers/[name]_dispatcher.rb`

Dispatchers implement the command pattern for immediate or queued event
delivery.

| File | Role |
|---|---|
| `app/dispatchers/dispatcher.rb` | Public interface — routes to sync or async |
| `app/dispatchers/sync_dispatcher.rb` | Executes in current thread |
| `app/dispatchers/async_dispatcher.rb` | Queues via Sidekiq |
| `app/dispatchers/base_dispatcher.rb` | Shared template |

```ruby
Dispatcher.dispatch(:event_name, { key: value })
```

---

## Pundit Policies

Location: `app/policies/[model]_policy.rb`

Authorization context passed to every policy:
`{ user: user, account: account, account_user: account_user }`.

```ruby
class ThingPolicy < ApplicationPolicy
  def index?
    # return true/false
  end

  def show?
    scope.exists?(id: record.id)
  end

  def create?
    @account_user.administrator?
  end

  class Scope
    def initialize(user_context, scope)
      @user         = user_context[:user]
      @account      = user_context[:account]
      @account_user = user_context[:account_user]
      @scope        = scope
    end

    def resolve
      @scope.where(account: @account)
    end
  end
end
```

Use in controllers:

```ruby
authorize(@thing)               # raises Pundit::NotAuthorizedError if denied
@things = policy_scope(Thing)   # returns scope filtered for current user
```

---

## Serializers (jbuilder)

Location: `app/views/api/v1/[domain]/[action].json.jbuilder`
Partials: `app/views/api/v1/models/_[model].json.jbuilder`

No ActiveModel Serializers — jbuilder only.

Standard envelope shape:

```ruby
# index.json.jbuilder
json.meta do
  json.count @records.total_count
  json.current_page @current_page
end

json.payload do
  json.array! @records do |record|
    json.partial! 'api/v1/models/thing', formats: [:json], resource: record
  end
end
```

```ruby
# _thing.json.jbuilder
json.id       resource.id
json.name     resource.name
json.account  do
  json.id     resource.account.id
end
```

Conventions:
- Top-level `meta` for pagination / counts
- Top-level `payload` for data
- Nested objects: `json.object do ... end`
- Arrays: `json.array!` with block

---

## Frontend State Management (Vuex)

Location: `app/javascript/dashboard/store/modules/[domain].js`

The project uses **classic Vuex** (not Pinia). Each module follows a strict
four-part structure: `state`, `getters`, `actions`, `mutations`.

```javascript
// store/modules/things.js
import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import ThingsAPI from '../../api/things';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getAll($state) {
    return $state.records;
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.SET_THINGS_FETCHING_STATUS, true);
    try {
      const { data } = await ThingsAPI.get();
      commit(types.SET_THINGS, data);
    } finally {
      commit(types.SET_THINGS_FETCHING_STATUS, false);
    }
  },
  create: async ({ commit }, params) => {
    commit(types.SET_THINGS_CREATING_STATUS, true);
    try {
      const { data } = await ThingsAPI.create(params);
      commit(types.ADD_THING, data);
    } catch (error) {
      commit(types.SET_THINGS_CREATING_STATUS, false);
      throw error;
    }
    commit(types.SET_THINGS_CREATING_STATUS, false);
  },
};

export const mutations = {
  [types.SET_THINGS]($state, records) {
    $state.records = records;
  },
  [types.ADD_THING]($state, record) {
    $state.records.push(record);
  },
  [types.SET_THINGS_FETCHING_STATUS]($state, status) {
    $state.uiFlags.isFetching = status;
  },
};

export default { state, getters, actions, mutations };
```

Register new modules in `app/javascript/dashboard/store/index.js`.

Mutation type constants live in
`app/javascript/dashboard/store/mutation-types.js`.

---

## Vue Composables

Location: `app/javascript/dashboard/composables/use[Feature].js`

Composables encapsulate reusable reactive logic. They are plain functions that
return a plain object of reactive values and handler functions.

```javascript
// composables/useThing.js
import { ref, computed } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';

export function useThing(initialValue = null) {
  const store = useStore();
  const { t } = useI18n();

  const thing = ref(initialValue);
  const label = computed(() => t('THING.LABEL'));

  const updateThing = newValue => {
    thing.value = newValue;
  };

  const removeThing = () => {
    thing.value = null;
  };

  return { thing, label, updateThing, removeThing };
}
```

Conventions:
- File name: `use[Feature].js` (camelCase after `use`)
- Always return a plain object — never a single ref
- Handler functions use verb names: `appendItem`, `removeFilter`, `onSelect`
- Re-export from `app/javascript/dashboard/composables/index.js`

Path alias for imports: `dashboard/composables/useThing`.

Real examples: `composables/useAutomation.js`, `composables/useAgentsList.js`,
`composables/useAccount.js`.

---

## Adding a New API Endpoint

Use this checklist for a standard account-scoped REST endpoint. Example: adding
a `Widget` resource.

### 1. Migration and model

```bash
bundle exec rails generate migration CreateWidgets
```

Edit `app/models/widget.rb`:

```ruby
class Widget < ApplicationRecord
  belongs_to :account
  validates :name, presence: true
end
```

### 2. Policy

Create `app/policies/widget_policy.rb` (see [Pundit Policies](#pundit-policies)
above).

### 3. Controller

Create `app/controllers/api/v1/accounts/widgets_controller.rb`:

```ruby
class Api::V1::Accounts::WidgetsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_widget, only: [:show, :update, :destroy]

  def index
    @widgets = policy_scope(Widget)
  end

  def create
    @widget = Current.account.widgets.new(widget_params)
    authorize(@widget)
    @widget.save!
  end

  def show; end

  def update
    @widget.update!(widget_params)
  end

  def destroy
    @widget.destroy!
    head :ok
  end

  private

  def fetch_widget
    @widget = Current.account.widgets.find(params[:id])
  end

  def widget_params
    params.require(:widget).permit(:name, :description)
  end
end
```

### 4. Route

In `config/routes.rb`, inside the `resources :accounts` block:

```ruby
resources :widgets, only: [:index, :show, :create, :update, :destroy]
```

### 5. jbuilder views

```
app/views/api/v1/accounts/widgets/index.json.jbuilder
app/views/api/v1/accounts/widgets/show.json.jbuilder
app/views/api/v1/models/_widget.json.jbuilder
```

### 6. Frontend API client

Create `app/javascript/dashboard/api/widgets.js`:

```javascript
import ApiClient from './ApiClient';

class Widgets extends ApiClient {
  constructor() {
    super('widgets', { accountScoped: true });
  }
}

export default new Widgets();
```

### 7. Vuex store module

Create `app/javascript/dashboard/store/modules/widgets.js` following the
pattern in [Frontend State Management](#frontend-state-management-vuex).

Register it in `app/javascript/dashboard/store/index.js`.

### 8. Specs

- `spec/models/widget_spec.rb`
- `spec/policies/widget_policy_spec.rb`
- `spec/controllers/api/v1/accounts/widgets_controller_spec.rb` (or
  `spec/requests/api/v1/accounts/widgets_spec.rb`)

---

## Adding a New Dashboard Page

### 1. Create the Vue page component

```
app/javascript/dashboard/routes/dashboard/[section]/
  MyNewPage.vue
  [section].routes.js   ← add a route entry here
```

Page components live under `app/javascript/dashboard/routes/dashboard/`.
Group by section (e.g., `settings/`, `contacts/`, `campaigns/`).

### 2. Register the route

Open the relevant `[section].routes.js` and add an entry:

```javascript
import MyNewPage from './MyNewPage.vue';
import { frontendURL } from '../../../helper/URLHelper';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/section/new-page'),
    name: 'new_page',
    component: MyNewPage,
    meta: {
      permissions: ['administrator', 'agent'],
    },
  },
];
```

Then spread your routes into the parent `dashboard.routes.js` children array.

### 3. Add a sidebar / navigation entry (if needed)

Navigation items are configured in
`app/javascript/dashboard/routes/dashboard/settings/` or the main sidebar
component. Search for existing nav entries to find the right array to add to.

### 4. i18n strings

Add keys to the relevant locale file under
`app/javascript/dashboard/i18n/locale/en/` (and other locales as needed).

### 5. Store module (if the page needs its own data)

Follow [Adding a New API Endpoint](#adding-a-new-api-endpoint) steps 6–7.

### 6. Spec

Add a Vitest spec alongside the component:

```
app/javascript/dashboard/routes/dashboard/[section]/MyNewPage.spec.js
```

---

## Adding a New Channel

A "channel" is a messaging provider (WhatsApp, Email, Telegram, etc.). Adding
one requires changes in six areas.

### 1. Database model

Create `app/models/channel/my_channel.rb`:

```ruby
class Channel::MyChannel < ApplicationRecord
  include Channelable   # mandatory — provides account_id, inbox association

  self.table_name = 'channel_my_channel'
  EDITABLE_ATTRS = [:api_key, :webhook_url].freeze

  validates :api_key, presence: true

  def name
    'MyChannel'
  end

  def create_contact_inbox; end    # implement as needed
  def receive(incoming_payload); end
end
```

`include Channelable` (`app/models/concerns/channelable.rb`) wires in:
- `belongs_to :account`
- `has_one :inbox, as: :channel`
- `validates :account_id, presence: true`

### 2. Migration

```bash
bundle exec rails generate migration CreateChannelMyChannel \
  api_key:string:null webhook_url:string account_id:integer:null
```

### 3. Inbox registration

Register the channel type in the `Inbox` model so it can be created via the
API. Search for existing channel type references in
`app/models/inbox.rb` and `app/controllers/api/v1/accounts/channels/` to
follow the existing pattern.

Create a channel-specific controller in:
`app/controllers/api/v1/accounts/channels/my_channel_controller.rb`

### 4. Provider service (if needed)

For channels that integrate with an external API:

```
app/services/my_channel/
  incoming_message_service.rb
  outgoing_message_service.rb
```

### 5. Frontend — channel wizard component

Add a setup wizard component:

```
app/javascript/dashboard/routes/dashboard/settings/inbox/channels/MyChannel.vue
```

Register it in `ChannelFactory.vue` (same directory):

```
app/javascript/dashboard/routes/dashboard/settings/inbox/ChannelFactory.vue
```

Also add a card entry in `ChannelList.vue`:

```
app/javascript/dashboard/routes/dashboard/settings/inbox/ChannelList.vue
```

### 6. Channel list and routing

Update the inbox settings route in:
`app/javascript/dashboard/routes/dashboard/settings/inbox/inbox.routes.js`

to include a named route for the new channel's wizard step, following the
pattern of existing channels such as `Whatsapp.vue` or `Telegram.vue`.

### 7. i18n strings

Add channel-specific strings to:
`app/javascript/dashboard/i18n/locale/en/`

### 8. Specs

- `spec/models/channel/my_channel_spec.rb`
- `spec/services/my_channel/` (incoming / outgoing)

Real examples to read:
- `app/models/channel/whatsapp.rb` — most complete channel model
- `app/models/channel/telegram.rb` — simpler webhook-based model
- `app/javascript/dashboard/routes/dashboard/settings/inbox/channels/Whatsapp.vue`
- `app/javascript/dashboard/routes/dashboard/settings/inbox/channels/WhatsappWeb.vue`

---

## Commit and PR Conventions

### Branch naming

```
feat/<short-description>          # new feature
fix/<short-description>           # bug fix
chore/<short-description>         # tooling, deps, config
refactor/<short-description>      # non-functional change
```

Branch off `next` (the trunk). Keep branches short-lived.

### Commit messages

Follow the **Conventional Commits** format:

```
<type>(<optional scope>): <imperative summary under 72 chars>

Optional body explaining the why, not the what.

Fixes #<issue-number>   ← if applicable
```

Types: `feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `perf`, `ci`.

Example:

```
feat(whatsapp): add WhatsApp Web provider with QR code authentication

Implements the whatsapp_web provider variant of Channel::Whatsapp,
backed by a gowa sidecar process. Adds QR polling endpoint and
session teardown on inbox destroy.

Fixes #14
```

### Opening a PR

The PR template at `.github/PULL_REQUEST_TEMPLATE.md` must be filled in
completely. Required checklist items:

- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Hard-to-understand areas are commented
- [ ] Tests added that prove the fix or feature works
- [ ] All existing tests pass locally
- [ ] No new linting warnings (`bundle exec rubocop` and `pnpm eslint` both clean)

### Fork-specific notes

This is a fork of upstream Chatwoot. Keep fork-specific changes clearly
scoped to avoid painful rebase conflicts when pulling upstream fixes:

- Add fork-specific models / services / routes in their own files; avoid
  editing large upstream files in-place when an additive approach is possible.
- Prefix fork-only migration files with a timestamp that is clearly later than
  the upstream baseline to avoid conflicts.
- Tag releases follow the pattern `v{VERSION_CW}{OCTAL}` — managed by the
  auto-release workflow in `.github/workflows/auto-release.yaml`.
