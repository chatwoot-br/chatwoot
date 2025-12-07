# Plan: Dynamic WhatsApp Instance Provisioning via Admin API

## Overview

Add the ability to dynamically provision new WhatsApp Web instances through the Go WhatsApp Multidevice Admin API, in addition to the existing flow of connecting to pre-existing instances.

## Design Decisions

| Decision | Choice |
|----------|--------|
| Admin API credentials | Per-account via `integrations_hooks` (following OpenAI pattern) |
| Port allocation | Auto-assign from configurable range |
| Instance lifecycle | Delete instance when inbox is deleted |
| UI flow | Toggle within WhatsApp Web form |

---

## Implementation Phases

### Phase 1: Backend Services

**1. Admin API Client**
`app/services/whatsapp/admin_api_client.rb`
```ruby
class Whatsapp::AdminApiClient
  def initialize(hook)  # Accepts hook, reads settings from hook.settings
  def create_instance(port:, webhook:, webhook_secret:, basic_auth: nil)
  def list_instances
  def get_instance(port)
  def update_instance(port, config)
  def delete_instance(port)
  def health_check
end
```

**2. Instance Provisioning Service**
`app/services/whatsapp/instance_provisioning_service.rb`
```ruby
class Whatsapp::InstanceProvisioningService
  def initialize(hook)  # Accepts hook
  def provision(phone_number:, webhook_secret:)
    # 1. Find available port from hook.settings port range
    # 2. Build Chatwoot webhook URL
    # 3. Create instance via Admin API
    # 4. Poll until RUNNING state (30s timeout)
    # 5. Return {gateway_url, port, basic_auth}
  end
end
```

**3. Instance Teardown Service**
`app/services/whatsapp/instance_teardown_service.rb`
```ruby
class Whatsapp::InstanceTeardownService
  def perform(channel)
    # Only if provider_config['provisioned'] == true
    # Call Admin API delete_instance(port)
  end
end
```

### Phase 2: Integration Hook Configuration

> **Migration Note:** Settings moved from `account.settings` to `integrations_hooks.settings` JSONB following the OpenAI integration pattern.

**Integration Configuration** (`config/integration/apps.yml`)
```yaml
whatsapp_web:
  id: whatsapp_web
  logo: whatsapp_web.png
  i18n_key: whatsapp_web
  action: /whatsapp_web
  hook_type: account
  allow_multiple_hooks: false
  settings_json_schema:
    {
      'type': 'object',
      'properties':
        {
          'base_url': { 'type': 'string' },
          'api_token': { 'type': 'string' },
          'port_range_start': { 'type': 'integer' },
          'port_range_end': { 'type': 'integer' },
        },
      'required': ['base_url', 'api_token'],
      'additionalProperties': false,
    }
```

**Settings Storage:**
- `hook.settings['base_url']` - Admin API URL
- `hook.settings['api_token']` - Bearer token (like OpenAI's `api_key`)
- `hook.settings['port_range_start']` - Port range start (default: 3001)
- `hook.settings['port_range_end']` - Port range end (default: 3100)

**Channel::Whatsapp Model** (`app/models/channel/whatsapp.rb`)
- Add `before_destroy :teardown_provisioned_instance`
- New provider_config fields (documented, no migration needed):
  - `provisioned: true/false`
  - `instance_port: 3001`

### Phase 3: Controller & Routes

**Gateway Controller** (`app/controllers/api/v1/accounts/whatsapp_web/gateway_controller.rb`)
```ruby
# Helper to find the whatsapp_web hook
def whatsapp_hook
  @whatsapp_hook ||= Current.account.hooks.find_by(app_id: 'whatsapp_web')
end

# Endpoints read from hook.settings
def admin_api_status
  # Test with params (before saving) or read from hook
end

def provision_instance
  # Uses Whatsapp::InstanceProvisioningService.new(whatsapp_hook)
end

def available_instances
  # Uses Whatsapp::AdminApiClient.new(whatsapp_hook)
end
```

**Routes** (`config/routes.rb`)
```ruby
namespace :whatsapp_web do
  resources :gateway, only: [], controller: 'gateway' do
    collection do
      post :provision_instance
      get :admin_api_status
      get :available_instances
    end
  end
end
```

### Phase 4: Frontend - Integrations Page

**New Component** (`app/javascript/dashboard/routes/dashboard/settings/integrations/WhatsappWeb/Index.vue`)
- Admin API URL input
- Admin Token input (password field)
- Port range inputs (start/end)
- Test connection button
- Save settings (creates/updates hook)
- Connection status display

**Vuex Store** (`app/javascript/dashboard/store/modules/integrations.js`)
```javascript
// Getter: enabled determined by hook existence
getAppIntegrations($state) {
  return $state.records.map(record => {
    if (record.id === 'whatsapp_web') {
      const hasHook = record.hooks && record.hooks.length > 0;
      return { ...record, enabled: hasHook };
    }
    return record;
  });
}

// Actions
createHook: async ({ commit }, hookData) => { ... }
updateHook: async ({ commit }, { hookId, hookData }) => { ... }
deleteHook: async ({ commit }, { appId, hookId }) => { ... }
```

**API Client** (`app/javascript/dashboard/api/integrations.js`)
```javascript
createHook(hookData) { ... }
showHook(hookId) { ... }
updateHook(hookId, hookData) { ... }
deleteHook(hookId) { ... }
```

### Phase 5: Frontend - Inbox Creation

**WhatsappWebForm.vue** (`app/javascript/dashboard/routes/dashboard/settings/inbox/channels/whatsapp/WhatsappWebForm.vue`)
- Add `connectionMode` toggle: `'existing'` | `'create_new'`
- Show toggle only if Admin API hook exists
- **Create New mode**: Hide gateway URL fields, show only phone + webhook secret
- **Existing mode**: Current form (no changes)
- Update submit handler for provisioning flow

**API Client** (`app/javascript/dashboard/api/whatsappAdminApi.js`)
```javascript
checkAdminApiStatus(baseUrl, apiToken)
provisionInstance(phoneNumber, webhookSecret)
```

### Phase 6: i18n Translations

**integrations.json** - `INTEGRATION_SETTINGS.WHATSAPP_WEB` section:
- `TITLE`, `DESCRIPTION`, `CONNECTION_STATUS`
- `BASE_URL.LABEL/PLACEHOLDER`, `TOKEN.LABEL/PLACEHOLDER`
- `PORT_RANGE.START_LABEL/END_LABEL`
- `TEST_CONNECTION`, `SAVE`, `SAVE_SUCCESS`, `SAVE_ERROR`
- `AVAILABLE_PORTS`, `STATUS.CONNECTED/NOT_CONFIGURED/FAILED/UNKNOWN`

**inboxMgmt.json** - Add under `WHATSAPP_WEB`:
- `PROVISIONING_MODE.LABEL/CREATE_NEW/CONNECT_EXISTING`
- `PROVISIONING.IN_PROGRESS/SUCCESS/ERROR/NO_PORTS_AVAILABLE`

**config/locales/en.yml** - Add under `integration_apps`:
- `whatsapp_web.name`, `whatsapp_web.short_description`, `whatsapp_web.description`

---

## Critical Files

| File | Status | Changes |
|------|--------|---------|
| `config/integration/apps.yml` | DONE | Add whatsapp_web with settings_json_schema |
| `app/services/whatsapp/admin_api_client.rb` | DONE | Accept hook, read from hook.settings |
| `app/services/whatsapp/instance_provisioning_service.rb` | DONE | Accept hook |
| `app/services/whatsapp/instance_teardown_service.rb` | TODO | Cleanup on inbox delete |
| `app/controllers/api/v1/accounts/whatsapp_web/gateway_controller.rb` | DONE | Read from hook via whatsapp_hook helper |
| `app/models/account.rb` | DONE | Removed WhatsApp settings (migrated to hooks) |
| `app/controllers/api/v1/accounts_controller.rb` | DONE | Removed WhatsApp params |
| `app/javascript/dashboard/api/integrations.js` | DONE | Add showHook, updateHook |
| `app/javascript/dashboard/store/modules/integrations.js` | DONE | Add updateHook action/mutation |
| `app/javascript/dashboard/store/mutation-types.js` | DONE | Add UPDATE_INTEGRATION_HOOK |
| `WhatsappWeb/Index.vue` | DONE | Use hooks instead of account.settings |
| `app/models/channel/whatsapp.rb` | TODO | Add teardown callback |
| `WhatsappWebForm.vue` | TODO | Add provisioning toggle |

---

## Provisioning Flow Sequence

```
User → Frontend → Backend → Admin API
  |
  1. Select "Create New Instance"
  2. Enter phone number + webhook secret
  3. Submit
     |
     → POST /provision_instance
        |
        → Find whatsapp_web hook
        → GET /admin/instances (find available port)
        → POST /admin/instances (create with webhook)
        → Poll GET /admin/instances/{port} until RUNNING
        |
     ← Return {gateway_url, port, credentials}
     |
  4. POST /inboxes (create channel with provisioned=true)
  5. Redirect to agents page
```

---

## Error Handling

| Error | Response |
|-------|----------|
| Admin API hook not configured | 400 - Guide user to integrations page |
| No ports available | 503 - All ports in range in use |
| Instance creation failed | 500 - Log + cleanup partial instance |
| Timeout waiting for RUNNING | 504 - 30s timeout exceeded |
| Admin API unreachable | 503 - Service unavailable |

---

## Implementation Progress

- [x] Phase 1: Backend services (AdminApiClient, ProvisioningService)
- [x] Phase 2: Integration hook configuration (apps.yml schema)
- [x] Phase 3: Gateway controller endpoints
- [x] Phase 4: Frontend integrations page (WhatsappWeb/Index.vue)
- [ ] Phase 5: Frontend inbox creation (WhatsappWebForm provisioning toggle)
- [x] Phase 6: i18n translations (partial)
- [ ] Instance teardown service
- [ ] Manual testing
