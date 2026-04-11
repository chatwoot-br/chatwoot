# Coding Conventions

**Analysis Date:** 2026-04-11

## Naming Patterns

**Files:**
- Ruby/Rails files: snake_case (e.g., `account_builder.rb`, `base_listener.rb`)
- Vue components: PascalCase (e.g., `Input.vue`, `CardLayout.vue`)
- JavaScript modules: camelCase (e.g., `agents.js`, `useAutomation.js`)
- Services: `[noun]_service.rb` (e.g., `account_deletion_service.rb`, `base_refresh_oauth_token_service.rb`)
- Builders: `[noun]_builder.rb` (e.g., `account_builder.rb`, `conversation_builder.rb`)
- Listeners: `[noun]_listener.rb` (e.g., `base_listener.rb`, `webhook_listener.rb`)
- Dispatchers: `[noun]_dispatcher.rb` (e.g., `base_dispatcher.rb`, `async_dispatcher.rb`)
- Policies: `[model]_policy.rb` (e.g., `account_policy.rb`, `contact_policy.rb`)
- Composables: `use[Feature].js` (e.g., `useAutomation.js`, `useAgentsList.js`)
- Spec files: `[name]_spec.rb` for Ruby, `*.spec.js` for JavaScript

**Functions/Methods:**
- Ruby methods: snake_case
  - Query methods ending in `?` for predicates: `access_token_expired?`, `policy?`
  - Action methods use verbs: `validate_email`, `create_account`, `refresh_tokens`
  - Private methods marked with `private` keyword
- JavaScript functions: camelCase
  - Composables return objects: `{ agentsList, assignableAgents }`
  - Event handlers: `onEventChange`, `handleInput`, `handleFocus`
  - Computed properties return computed: `const eventName = computed(() => ...)`

**Variables:**
- Ruby instance variables: `@user`, `@account`, `@contact_inbox`
- Ruby local variables: snake_case: `current_user`, `inbox_id`, `permissions`
- JavaScript constants: UPPER_CASE: `RESULTS_PER_PAGE`, `DEFAULT_QUERY_SETTING`
- Vue refs/reactive: camelCase: `isFocused`, `inputRef`, `automationTypes`

**Types/Classes:**
- Ruby classes: PascalCase: `Account`, `AccountBuilder`, `BaseListener`
- Module nesting: compact style preferred (e.g., `class Api::V1::Accounts::ContactsController`)
- Modules for mixins: PascalCase: `Reportable`, `Featurable`, `CacheKeys`
- Custom exceptions: inherit from `CustomExceptions::Base`, namespaced: `CustomExceptions::Account::InvalidEmail`

## Code Style

**Formatting:**
- Line length: Max 150 characters (enforced by Rubocop)
- Ruby indentation: 2 spaces
- Vue/JavaScript indentation: 2 spaces (Prettier)
- Trailing commas: ES5 style in JavaScript (via Prettier)
- Arrow functions: avoid parens when possible (`arrowParens: 'avoid'`)

**Linting:**

Ruby:
- Tool: Rubocop (with plugins: rubocop-performance, rubocop-rails, rubocop-rspec, rubocop-factory_bot)
- Config: `.rubocop.yml`
- Custom cops: `rubocop/use_from_email.rb`, `rubocop/custom_cop_location.rb`, `rubocop/one_class_per_file.rb`
- No frozen string literal comments required
- Documentation comments disabled

JavaScript/Vue:
- Tool: ESLint with Airbnb legacy config + Vue3 plugin
- Config: `.eslintrc.js`
- Plugins: `vitest-globals`, `@intlify/vue-i18n`
- Vue block order: `<script setup>`, `<template>`, `<style>`
- No bare strings in templates (i18n required with allowlist for symbols)
- Component names: PascalCase in templates, auto-registered only (no camelCase)
- Max attributes per line: 20 for single-line, 1 for multi-line
- Self-closing tags required

Prettier:
- Config: `.prettierrc`
- Print width: 80 characters
- Single quotes: true
- Trailing commas: ES5
- Arrow parens: avoid

## Import Organization

**Ruby:**
Order in files:
1. Frozen string literal comment (optional)
2. Module/class name
3. Includes (mixins)
4. Constants and schemas (SETTINGS_PARAMS_SCHEMA, DEFAULT_QUERY_SETTING)
5. Validations
6. Associations
7. Methods (public first, then private)

Example from `account_builder.rb`:
```ruby
# frozen_string_literal: true

class AccountBuilder
  include CustomExceptions::Account
  pattr_initialize [:account_name, :email!, :confirmed, :user, :user_full_name, :user_password, :super_admin, :locale]

  def perform
    # public method
  end

  private

  def create_account
    # private method
  end
end
```

**JavaScript/Vue:**
Order in files:
1. Import statements (external, then local using path aliases)
2. Vue component setup: `<script setup>`
3. `defineProps()` → `defineEmits()` → `defineSlots()` (in that order)
4. Reactive state: `ref()`, `reactive()`, `computed()`
5. Functions/handlers
6. Template
7. Styles

Path aliases available (from `vite.config.ts`):
- `components` -> `app/javascript/dashboard/components`
- `next` -> `app/javascript/dashboard/components-next`
- `v3` -> `app/javascript/v3`
- `dashboard` -> `app/javascript/dashboard`
- `helpers` -> `app/javascript/shared/helpers`
- `shared` -> `app/javascript/shared`
- `survey` -> `app/javascript/survey`
- `widget` -> `app/javascript/widget`
- `assets` -> `app/javascript/dashboard/assets`

Example from `Input.vue`:
```vue
<script setup>
import { computed, ref, onMounted } from 'vue';

const props = defineProps({ ... });
const emit = defineEmits(['update:modelValue', 'blur', ...]);

const isFocused = ref(false);
const inputRef = ref(null);

const messageClass = computed(() => { ... });
const handleInput = event => { ... };
</script>

<template>...</template>
<style>...</style>
```

## Error Handling

**Ruby Pattern:**
- Custom exceptions in `lib/custom_exceptions/[domain].rb`
- Base class: `CustomExceptions::Base` with `message`, `http_status`, `to_hash` methods
- Namespaced by domain: `CustomExceptions::Account::InvalidEmail`, `CustomExceptions::CustomFilter::InvalidAttribute`
- Usage in builders/services: rescue with specific exception, re-raise with context

Example from `account_builder.rb`:
```ruby
def validate_user
  if User.exists?(email: @email)
    raise UserExists.new(email: @email)
  else
    true
  end
end
```

- Controllers rescue specific exceptions and render errors
- Rails transaction blocks ensure atomicity: `ActiveRecord::Base.transaction do`

**JavaScript Pattern:**
- Throw errors in async actions/API calls
- Catch in components using try/catch or promise `.catch()`
- No custom error classes required—use native Error with message
- API responses with error status are handled by response check

Example from `agents.js` store:
```javascript
export const actions = {
  create: async ({ commit }, agentInfo) => {
    commit(types.default.SET_AGENT_CREATING_STATUS, true);
    try {
      const response = await AgentAPI.create(agentInfo);
      commit(types.default.ADD_AGENT, response.data);
    } catch (error) {
      commit(types.default.SET_AGENT_CREATING_STATUS, false);
      throw error; // Re-throw to be caught by caller
    }
  },
};
```

## Logging

**Ruby:**
- Framework: `Rails.logger` (configured in `config/initializers/`)
- Usage: Debug in development, info for important events
- No custom logging framework; use standard Rails logger

**JavaScript/Vue:**
- Console methods forbidden in production code: ESLint rule `no-console: 'error'`
- Story files allowed: `'no-console': 'off'` in `.story.vue` override
- No logging framework required; use browser DevTools console during development
- No custom logger implementation

## Comments

**When to Comment:**
- Non-obvious business logic (e.g., rate limiting windows, calculation rationale)
- Complex queries or database operations
- Reference to external resources (URLs, issue links)
- Temporary workarounds with TODO/FIXME tags
- Performance-critical sections

**JSDoc/TSDoc:**
- Not heavily used in Vue components (props/emits are self-documenting)
- Functions in services/utilities may have JSDoc for complex logic
- Ruby: Minimal documentation comments (disabled by Rubocop)
- Example from service files: Single-line comments explaining method purpose

Ruby service example from `base_refresh_oauth_token_service.rb`:
```ruby
# Adding a 5 minute window to expiry check to avoid any race
# conditions during the fetch operation. This would assure that the
# tokens are updated when we fetch the emails.
Time.current.utc >= DateTime.parse(expiry) - 5.minutes
```

## Function Design

**Size:**
- Ruby method length max: 19 lines (enforced by Rubocop)
- JavaScript functions: No strict limit, but keep under 50 lines for readability
- Extract complex logic into separate functions/methods

**Parameters:**
- Ruby: Use `pattr_initialize` gem for service objects—requires at least one parameter (with `!`)
- JavaScript: Use destructuring for object parameters, avoid excessive optional args
- Named parameters for clarity (Ruby hash style, JavaScript objects)

Example from `BaseRefreshOauthTokenService`:
```ruby
class BaseRefreshOauthTokenService
  pattr_initialize [:channel!]  # Required parameter

  def access_token
    return provider_config[:access_token] unless access_token_expired?
    refreshed_tokens = refresh_tokens
    refreshed_tokens[:access_token]
  end
end
```

**Return Values:**
- Ruby services: Return the result directly (not wrapped in object)
- Ruby builders: Return array of created objects: `[@user, @account]`
- Vue composables: Return object with reactive values and functions: `{ agentsList, assignableAgents, removeFilter }`
- JavaScript actions: Return promise implicitly (async)

## Module Design

**Exports:**
- Ruby: Classes/modules in `app/` automatically loaded by Rails
- JavaScript modules: Named exports preferred: `export function useAutomation() { ... }`
- API clients: `export default new Agents();` (singleton pattern)

Example from `agents.js`:
```javascript
class Agents extends ApiClient {
  constructor() {
    super('agents', { accountScoped: true });
  }

  bulkInvite({ emails }) {
    return axios.post(`${this.url}/bulk_create`, { emails });
  }
}

export default new Agents();
```

**Barrel Files:**
- Ruby: Not used explicitly; Rails autoloading handles it
- JavaScript: `index.js` files used to re-export composables from directories
- Vue: Storybook story files ending in `.story.vue` for component documentation

Example from `dashboard/composables/index.js`:
```javascript
// Re-exports of composables for convenient importing
export { useAutomation } from './useAutomation';
export { useAgentsList } from './useAgentsList';
```

## Service Object Pattern

Location: `app/services/[domain]/` or `app/services/[name]_service.rb`

Structure:
```ruby
class ServiceName
  pattr_initialize [:required_param!, :optional_param]  # Use ! for required

  def perform
    # Main entry point—returns result directly, no wrapper
  end

  private

  # Helper methods
end
```

Characteristics:
- Single public method: `perform` (or domain-specific like `refresh!`)
- Initialize with params using `pattr_initialize`
- No instance state persistence
- Return value directly from `perform`
- Private helper methods for sub-steps
- Can raise custom exceptions

Example: `AccountDeletionService.new(account: account).perform`

## Builder Pattern

Location: `app/builders/[name]_builder.rb`

Structure:
```ruby
class BuilderName
  include CustomExceptions::Domain
  pattr_initialize [:param1!, :param2]

  def perform
    # Orchestrate creation steps
    # Usually wrapped in transaction
    # Returns array of created objects
  end

  private

  def create_primary_object
  end

  def create_related_objects
  end
end
```

Return convention: Return array `[object1, object2]` for multi-object builders

Example: `AccountBuilder.new(email: 'user@example.com').perform` returns `[user, account]`

## Listener/Dispatcher Pattern

**Listeners** (event handlers, observer pattern):
Location: `app/listeners/[name]_listener.rb`

```ruby
class NameListener
  include Singleton  # Singleton pattern

  def event_occurred(event)
    object = event.data[:object_key]
    account = object.account
    # Process event
  end
end
```

Used with Wisper pub/sub gem for loose coupling:
- Events fired from models: `broadcast(:event_name, object: value)`
- Listeners subscribe in initializers
- Base listener extracts common patterns: `extract_conversation_and_account(event)`

**Dispatchers** (command pattern, immediate execution):
Location: `app/dispatchers/[name]_dispatcher.rb`

Types:
- `BaseDispatcher`: Template for dispatcher implementations
- `SyncDispatcher`: Execute immediately in current thread
- `AsyncDispatcher`: Queue job via Sidekiq

Example dispatch usage:
```ruby
Dispatcher.dispatch(event_name, {key: value})  # Routes to sync/async based on config
```

## Pundit Policies

Location: `app/policies/[model]_policy.rb`

Structure:
```ruby
class [Model]Policy < ApplicationPolicy
  def index?
    # Check if user can list
  end

  def show?
    scope.exists?(id: record.id)
  end

  def create?
    # Check if user can create
  end

  class Scope
    def initialize(user_context, scope)
      @user_context = user_context
      @user = user_context[:user]
      @account = user_context[:account]
      @scope = scope
    end

    def resolve
      # Filter scope for current user
      @scope
    end
  end
end
```

Authorization context passed: `{ user: user, account: account, account_user: account_user }`

Usage in controllers: `authorize(record)` to check action, `policy_scope(Model)` for filtered list

## Serialization (jbuilder)

Location: `app/views/api/v1/[domain]/[action].json.jbuilder` or partials in `models/`

Pattern:
```erb
json.meta do
  json.count @records.count
  json.current_page @current_page
end

json.payload do
  json.array! @records do |record|
    json.partial! 'api/v1/models/[model]', formats: [:json], resource: record
  end
end
```

Partial naming: `_[model].json.jbuilder`

Conventions:
- Top-level `meta` for pagination/count info
- Top-level `payload` for data array
- Nested objects use `json.object do; ... end`
- Arrays use `json.array!` with block

No ActiveModel Serializers (AMS)—using jbuilder exclusively for API responses

## Frontend State Management (Vuex)

Location: `app/javascript/dashboard/store/modules/[domain].js`

Structure (classic Vuex):
```javascript
export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
  },
};

export const getters = {
  getRecords($state) {
    return $state.records;
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.default.SET_FETCHING_STATUS, true);
    try {
      const response = await API.get();
      commit(types.default.SET_RECORDS, response.data);
    } catch (error) {
      // Handle error
    } finally {
      commit(types.default.SET_FETCHING_STATUS, false);
    }
  },
};

export const mutations = {
  [types.default.SET_FETCHING_STATUS]($state, status) {
    $state.uiFlags.isFetching = status;
  },
};
```

Key patterns:
- State: flat structure with `records` array and `uiFlags` object
- Getters: filter or compute values from state
- Actions: async API calls, commit mutations
- Mutations: single source of truth updates
- Type constants: `types.default.ACTION_NAME` in `store/mutation-types.js`
- UI state separate from data state: `isFetching`, `isCreating`, `isUpdating`, `isDeleting`

## API Client Pattern (JavaScript)

Location: `app/javascript/dashboard/api/[resource].js`

Classes extend `ApiClient` base:
```javascript
class Resource extends ApiClient {
  constructor() {
    super('resource', { accountScoped: true });  // Adds /accounts/:id/ to URL
  }

  bulkAction({ ids, action }) {
    return axios.post(`${this.url}/bulk_action`, { ids, action });
  }
}

export default new Resource();  // Singleton
```

ApiClient provides standard methods: `get()`, `create(data)`, `update(id, data)`, `delete(id)`

Naming convention: File name matches resource plural form (e.g., `agents.js` for Agent resource)

## Form Components

Location: `app/javascript/dashboard/components-next/input/`, `/selectmenu/`, etc.

Vue3 Composition API with `<script setup>`:
```vue
<script setup>
const props = defineProps({
  modelValue: { type: String, default: '' },
  label: { type: String, default: '' },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue', 'blur', 'focus', 'enter']);

const handleInput = event => {
  emit('update:modelValue', event.target.value);
};
</script>
```

Patterns:
- v-model support via `modelValue` prop + `update:modelValue` emit
- Custom input classes via `customInputClass` prop
- Message states: `info`, `error`, `success` (via `messageType`)
- Size variants: `sm`, `md` (via `size`)
- Accessible: aria attributes, unique IDs, label association

## Composables

Location: `app/javascript/dashboard/composables/use*.js`

Pattern:
```javascript
export function useFeature(param = null) {
  const { getters } = useStoreGetters();  // Access Vuex
  const { t } = useI18n();  // Access i18n
  
  const state = ref(param);
  const computed_value = computed(() => state.value?.property);
  
  const onEvent = () => {
    // Handle event
  };
  
  const removeItem = (index) => {
    // Remove item
  };
  
  return {
    state,
    computed_value,
    onEvent,
    removeItem,
  };
}
```

Conventions:
- Argument for initial state is optional
- Return object with reactive properties and functions
- Functions use verb names: `appendNewCondition`, `removeFilter`
- Computed properties use descriptive names
- No leading underscores for private functions (all exposed)

## i18n Usage

**Ruby:**
```ruby
I18n.t('path.to.key')
I18n.t('path.with.param', email: @email)
```

Stored in `config/locales/*.yml`

**Vue/JavaScript:**
```javascript
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
const message = t('AGENT_MGMT.MULTI_SELECTOR.LIST.NONE');

// In template
<span>{{ t('KEY_NAME') }}</span>
```

Locales in `app/javascript/[module]/i18n/locale/*.json`

Convention: ALL_CAPS.NESTED.PATH in frontend, lowercase.path.key in backend

---

*Convention analysis: 2026-04-11*
