<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import Integration from '../Integration.vue';
import WithLabel from 'v3/components/Form/WithLabel.vue';
import NextInput from 'next/input/Input.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'shared/components/Spinner.vue';
import WhatsappAdminApi from 'dashboard/api/whatsappAdminApi';

const { t } = useI18n();
const store = useStore();
const { currentAccount, updateAccount } = useAccount();

const integrationLoaded = ref(false);
const baseUrl = ref('');
const apiToken = ref('');
const portRangeStart = ref(3001);
const portRangeEnd = ref(3100);
const isTesting = ref(false);
const isSaving = ref(false);
const connectionStatus = ref('unknown');
const availablePorts = ref(0);

const integration = computed(() => {
  return store.getters['integrations/getIntegration']('whatsapp_web');
});

const isConfigured = computed(() => {
  return !!(baseUrl.value && apiToken.value);
});

const connectionStatusClass = computed(() => {
  switch (connectionStatus.value) {
    case 'connected':
      return 'text-green-700 bg-green-100 dark:text-green-400 dark:bg-green-900/20';
    case 'failed':
      return 'text-red-700 bg-red-100 dark:text-red-400 dark:bg-red-900/20';
    case 'not_configured':
      return 'text-gray-700 bg-gray-100 dark:text-gray-400 dark:bg-gray-900/20';
    default:
      return 'text-gray-700 bg-gray-100 dark:text-gray-400 dark:bg-gray-900/20';
  }
});

const connectionStatusText = computed(() => {
  switch (connectionStatus.value) {
    case 'connected':
      return t('INTEGRATION_SETTINGS.WHATSAPP_WEB.STATUS.CONNECTED');
    case 'failed':
      return t('INTEGRATION_SETTINGS.WHATSAPP_WEB.STATUS.FAILED');
    case 'not_configured':
      return t('INTEGRATION_SETTINGS.WHATSAPP_WEB.STATUS.NOT_CONFIGURED');
    default:
      return t('INTEGRATION_SETTINGS.WHATSAPP_WEB.STATUS.UNKNOWN');
  }
});

const testConnection = async () => {
  if (!baseUrl.value || !apiToken.value) {
    connectionStatus.value = 'not_configured';
    return;
  }

  isTesting.value = true;
  try {
    const response = await WhatsappAdminApi.checkAdminApiStatus(
      baseUrl.value,
      apiToken.value
    );
    if (response.data.healthy) {
      connectionStatus.value = 'connected';
      availablePorts.value = response.data.available_ports || 0;
    } else if (response.data.configured) {
      connectionStatus.value = 'failed';
    } else {
      connectionStatus.value = 'not_configured';
    }
  } catch (error) {
    connectionStatus.value = 'failed';
  } finally {
    isTesting.value = false;
  }
};

watch(
  currentAccount,
  account => {
    if (account) {
      const settings = account.settings || {};
      baseUrl.value = settings.whatsapp_admin_api_base_url || '';
      apiToken.value = settings.whatsapp_admin_api_token || '';
      portRangeStart.value = settings.whatsapp_admin_port_range_start || 3001;
      portRangeEnd.value = settings.whatsapp_admin_port_range_end || 3100;

      if (baseUrl.value && apiToken.value) {
        testConnection();
      }
    }
  },
  { immediate: true }
);

const saveSettings = async () => {
  isSaving.value = true;
  try {
    await updateAccount({
      whatsapp_admin_api_base_url: baseUrl.value,
      whatsapp_admin_api_token: apiToken.value,
      whatsapp_admin_port_range_start: parseInt(portRangeStart.value, 10),
      whatsapp_admin_port_range_end: parseInt(portRangeEnd.value, 10),
    });
    useAlert(t('INTEGRATION_SETTINGS.WHATSAPP_WEB.SAVE_SUCCESS'));
    await testConnection();
  } catch (error) {
    useAlert(
      error.message || t('INTEGRATION_SETTINGS.WHATSAPP_WEB.SAVE_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

const initializeIntegration = async () => {
  await store.dispatch('integrations/get');
  integrationLoaded.value = true;
};

onMounted(() => {
  initializeIntegration();
});
</script>

<template>
  <div
    v-if="integrationLoaded"
    class="flex flex-col flex-1 overflow-auto gap-5 pt-1 pb-10"
  >
    <Integration
      :integration-id="integration?.id || 'whatsapp_web'"
      :integration-name="
        integration?.name || $t('INTEGRATION_SETTINGS.WHATSAPP_WEB.TITLE')
      "
      :integration-description="
        integration?.description ||
        $t('INTEGRATION_SETTINGS.WHATSAPP_WEB.DESCRIPTION')
      "
      :integration-enabled="isConfigured"
      integration-action=""
    >
      <template #action>
        <span
          v-if="connectionStatus !== 'unknown'"
          class="px-3 py-1 text-xs font-medium rounded-full"
          :class="connectionStatusClass"
        >
          {{ connectionStatusText }}
        </span>
      </template>
    </Integration>

    <div
      class="p-6 outline outline-n-container outline-1 bg-n-alpha-3 rounded-md"
    >
      <div class="grid gap-5">
        <div
          v-if="connectionStatus !== 'unknown'"
          class="flex items-center justify-between p-3 rounded-lg border border-n-weak"
        >
          <span class="text-sm font-medium text-n-slate-12">
            {{ $t('INTEGRATION_SETTINGS.WHATSAPP_WEB.CONNECTION_STATUS') }}
          </span>
          <span
            class="px-2 py-1 text-xs font-medium rounded-full"
            :class="connectionStatusClass"
          >
            {{ connectionStatusText }}
          </span>
        </div>

        <form class="grid gap-4" @submit.prevent="saveSettings">
          <WithLabel
            :label="$t('INTEGRATION_SETTINGS.WHATSAPP_WEB.BASE_URL.LABEL')"
          >
            <NextInput
              v-model="baseUrl"
              type="url"
              class="w-full"
              :placeholder="
                $t('INTEGRATION_SETTINGS.WHATSAPP_WEB.BASE_URL.PLACEHOLDER')
              "
            />
          </WithLabel>

          <WithLabel
            :label="$t('INTEGRATION_SETTINGS.WHATSAPP_WEB.TOKEN.LABEL')"
          >
            <NextInput
              v-model="apiToken"
              type="password"
              class="w-full"
              :placeholder="
                $t('INTEGRATION_SETTINGS.WHATSAPP_WEB.TOKEN.PLACEHOLDER')
              "
            />
          </WithLabel>

          <div class="grid grid-cols-2 gap-4">
            <WithLabel
              :label="
                $t('INTEGRATION_SETTINGS.WHATSAPP_WEB.PORT_RANGE.START_LABEL')
              "
            >
              <NextInput
                v-model.number="portRangeStart"
                type="number"
                min="1024"
                max="65535"
                class="w-full"
              />
            </WithLabel>

            <WithLabel
              :label="
                $t('INTEGRATION_SETTINGS.WHATSAPP_WEB.PORT_RANGE.END_LABEL')
              "
            >
              <NextInput
                v-model.number="portRangeEnd"
                type="number"
                min="1024"
                max="65535"
                class="w-full"
              />
            </WithLabel>
          </div>

          <div
            v-if="connectionStatus === 'connected'"
            class="text-sm text-n-slate-11"
          >
            {{
              $t('INTEGRATION_SETTINGS.WHATSAPP_WEB.AVAILABLE_PORTS', {
                count: availablePorts,
              })
            }}
          </div>

          <div class="flex gap-2">
            <NextButton
              type="button"
              variant="outline"
              :is-loading="isTesting"
              @click="testConnection"
            >
              {{ $t('INTEGRATION_SETTINGS.WHATSAPP_WEB.TEST_CONNECTION') }}
            </NextButton>

            <NextButton blue type="submit" :is-loading="isSaving">
              {{ $t('INTEGRATION_SETTINGS.WHATSAPP_WEB.SAVE') }}
            </NextButton>
          </div>
        </form>
      </div>
    </div>
  </div>
  <div v-else class="flex items-center justify-center flex-1">
    <Spinner size="" color-scheme="primary" />
  </div>
</template>
