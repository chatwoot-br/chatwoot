<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required } from '@vuelidate/validators';
import { isPhoneE164OrEmpty } from 'shared/helpers/Validators';

import NextButton from 'dashboard/components-next/button/Button.vue';
import QRCodeModal from 'dashboard/components/QRCodeModal.vue';
import WhatsappWebGatewayApi from 'dashboard/api/whatsappWebGateway';
import WhatsappAdminApi from 'dashboard/api/whatsappAdminApi';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
  mode: {
    type: String,
    default: 'create', // 'create' or 'edit'
    validator: value => ['create', 'edit'].includes(value),
  },
});

const emit = defineEmits(['submit']);

const { t } = useI18n();

const inboxName = ref('');
const phoneNumber = ref('');
const gatewayBaseUrl = ref('');
const basicAuthUser = ref('');
const basicAuthPassword = ref('');
const webhookSecret = ref('');
const includeSignature = ref(true);
const showQRModal = ref(false);
const connectionStatus = ref(null);
const isLoadingStatus = ref(false);
const isDisconnecting = ref(false);
const isReconnecting = ref(false);
const connectionMode = ref('existing'); // 'existing' or 'provision'
const adminApiConfigured = ref(false);
const isCheckingAdminApi = ref(false);
const isProvisioning = ref(false);
const provisionedPort = ref(null);
const isProvisionedInstance = ref(false);

const gatewayConfig = computed(() => ({
  gatewayBaseUrl: gatewayBaseUrl.value,
  phoneNumber: phoneNumber.value,
  basicAuthUser: basicAuthUser.value,
  basicAuthPassword: basicAuthPassword.value,
}));

const canShowQRCode = computed(() => {
  return gatewayBaseUrl.value && gatewayBaseUrl.value.trim() !== '';
});

const submitButtonLabel = computed(() => {
  return props.mode === 'create'
    ? t('INBOX_MGMT.ADD.WHATSAPP_WEB.SUBMIT_BUTTON')
    : t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_SECTION_UPDATE_BUTTON');
});

const showInboxNameField = computed(() => {
  return props.mode === 'create';
});

const connectionStatusText = computed(() => {
  if (isLoadingStatus.value) return 'CHECKING';
  if (!connectionStatus.value) return 'UNKNOWN';

  // Parse the status response based on QRCodeModal logic
  if (connectionStatus.value.code === 'SUCCESS') {
    // Check if logged in (similar to QRCodeModal logic)
    if (connectionStatus.value.results?.is_logged_in) {
      return 'CONNECTED';
    }

    // Check status string for more detailed info
    const status = connectionStatus.value.results?.status || '';
    if (status.includes('connected') || status.includes('authenticated')) {
      return 'CONNECTED';
    }
    if (
      status.includes('disconnected') ||
      status.includes('not authenticated')
    ) {
      return 'DISCONNECTED';
    }
    if (status.includes('qr') || status.includes('waiting')) {
      return 'WAITING_QR';
    }

    // Default to disconnected if success but no logged in flag
    return 'DISCONNECTED';
  }
  return 'ERROR';
});

const connectionStatusColor = computed(() => {
  switch (connectionStatusText.value) {
    case 'CONNECTED':
      return 'text-green-600 bg-green-50 border-green-200';
    case 'DISCONNECTED':
    case 'ERROR':
      return 'text-red-600 bg-red-50 border-red-200';
    case 'WAITING_QR':
      return 'text-yellow-600 bg-yellow-50 border-yellow-200';
    case 'CHECKING':
      return 'text-blue-600 bg-blue-50 border-blue-200';
    default:
      return 'text-gray-600 bg-gray-50 border-gray-200';
  }
});

const connectionStatusLabel = computed(() => {
  const statusKey = connectionStatusText.value;
  const translationKey = `INBOX_MGMT.ADD.WHATSAPP_WEB.CONNECTION_STATUS.${statusKey}`;
  return t(translationKey);
});

const showConnectButton = computed(() => {
  return connectionStatusText.value !== 'CONNECTED';
});

const showDisconnectButton = computed(() => {
  return connectionStatusText.value === 'CONNECTED';
});

const showReconnectButton = computed(() => {
  // Reconnect should be available when connected (to restart connection)
  // or when there are connection issues
  return (
    connectionStatusText.value === 'CONNECTED' ||
    connectionStatusText.value === 'DISCONNECTED' ||
    connectionStatusText.value === 'ERROR'
  );
});

const showConnectionModeToggle = computed(() => {
  return props.mode === 'create' && adminApiConfigured.value;
});

const isProvisioningMode = computed(() => {
  return connectionMode.value === 'provision';
});

const validationRules = computed(() => {
  const baseValidations = {
    phoneNumber: { required, isPhoneE164OrEmpty },
    webhookSecret: { required },
  };

  // In provisioning mode, we don't need gateway URL and basic auth
  if (!isProvisioningMode.value) {
    baseValidations.gatewayBaseUrl = { required };
    baseValidations.basicAuthUser = {};
    baseValidations.basicAuthPassword = {};
  }

  if (props.mode === 'create') {
    baseValidations.inboxName = { required };
  }

  return baseValidations;
});

const v$ = useVuelidate(validationRules, {
  inboxName,
  phoneNumber,
  gatewayBaseUrl,
  basicAuthUser,
  basicAuthPassword,
  webhookSecret,
});

const setDefaults = inbox => {
  if (!inbox) return;

  inboxName.value = inbox.name || '';
  phoneNumber.value = inbox.phone_number || '';

  if (inbox.provider_config) {
    gatewayBaseUrl.value = inbox.provider_config.gateway_base_url || '';
    basicAuthUser.value = inbox.provider_config.basic_auth_user || '';
    basicAuthPassword.value = inbox.provider_config.basic_auth_password || '';
    webhookSecret.value = inbox.provider_config.webhook_secret || '';
    includeSignature.value = inbox.provider_config.include_signature !== false;
  }
};

const openQRModal = () => {
  if (!canShowQRCode.value) {
    useAlert(t('INBOX_MGMT.ADD.WHATSAPP_WEB.TEST_CONNECTION.VALIDATION_ERROR'));
    return;
  }
  showQRModal.value = true;
};

const closeQRModal = () => {
  showQRModal.value = false;
};

const checkConnectionStatus = async () => {
  if (props.mode !== 'edit' || !props.inbox?.id) return;

  isLoadingStatus.value = true;
  try {
    const response = await WhatsappWebGatewayApi.getStatus(props.inbox.id);
    connectionStatus.value = response.data.data;
  } catch (error) {
    // Connection status check failed
    connectionStatus.value = { code: 'ERROR', error: error.message };
  } finally {
    isLoadingStatus.value = false;
  }
};

const handleWhatsAppConnected = async () => {
  closeQRModal();
  // Refresh the connection status after successful connection
  await checkConnectionStatus();
};

const checkAdminApiStatus = async () => {
  isCheckingAdminApi.value = true;
  try {
    const response = await WhatsappAdminApi.checkAdminApiStatus();
    adminApiConfigured.value =
      response.data.configured && response.data.healthy;
  } catch (error) {
    adminApiConfigured.value = false;
  } finally {
    isCheckingAdminApi.value = false;
  }
};

const handleSubmit = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) {
    return;
  }

  // If provisioning mode, provision the instance first
  if (isProvisioningMode.value) {
    isProvisioning.value = true;
    try {
      const provisionResponse = await WhatsappAdminApi.provisionInstance(
        phoneNumber.value,
        webhookSecret.value
      );

      // Response is { success: true, data: { gateway_base_url, port, ... } }
      const provisionedData = provisionResponse.data.data;
      const { gateway_base_url, basic_auth_user, basic_auth_password, port } =
        provisionedData;

      // Use the provisioned credentials
      gatewayBaseUrl.value = gateway_base_url;
      basicAuthUser.value = basic_auth_user;
      basicAuthPassword.value = basic_auth_password;
      // Store provisioning info for teardown later
      provisionedPort.value = port;
      isProvisionedInstance.value = true;

      useAlert(t('INBOX_MGMT.ADD.WHATSAPP_WEB.PROVISIONING.SUCCESS'));
    } catch (error) {
      isProvisioning.value = false;
      const errorMessage = error.response?.data?.error || error.message;

      if (errorMessage.includes('No available ports')) {
        useAlert(t('INBOX_MGMT.ADD.WHATSAPP_WEB.PROVISIONING.NO_PORTS'));
      } else {
        useAlert(
          errorMessage || t('INBOX_MGMT.ADD.WHATSAPP_WEB.PROVISIONING.ERROR')
        );
      }
      return;
    } finally {
      isProvisioning.value = false;
    }
  }

  // Build provider_config, omitting optional Basic Auth if left blank
  const providerConfig = {
    gateway_base_url: gatewayBaseUrl.value,
    webhook_secret: webhookSecret.value,
    include_signature: includeSignature.value,
  };

  if (basicAuthUser.value && basicAuthPassword.value) {
    providerConfig.basic_auth_user = basicAuthUser.value;
    providerConfig.basic_auth_password = basicAuthPassword.value;
  }

  // Mark as provisioned instance so teardown service can clean up
  if (isProvisionedInstance.value) {
    providerConfig.provisioned = true;
    providerConfig.instance_port = provisionedPort.value;
  }

  const formData = {
    name: inboxName.value,
    phone_number: phoneNumber.value,
    provider_config: providerConfig,
  };

  emit('submit', formData);
};

const refreshConnectionStatus = async () => {
  await checkConnectionStatus();
};

const disconnectWhatsApp = async () => {
  if (!props.inbox?.id) return;

  // Show confirmation dialog
  const confirmed = window.confirm(
    t('INBOX_MGMT.ADD.WHATSAPP_WEB.DISCONNECT.CONFIRMATION')
  );

  if (!confirmed) return;

  isDisconnecting.value = true;
  try {
    await WhatsappWebGatewayApi.logout(props.inbox.id);
    useAlert(t('INBOX_MGMT.ADD.WHATSAPP_WEB.DISCONNECT.SUCCESS'));
    // Refresh status after successful disconnect
    await checkConnectionStatus();
  } catch (error) {
    useAlert(
      error.message || t('INBOX_MGMT.ADD.WHATSAPP_WEB.DISCONNECT.ERROR')
    );
  } finally {
    isDisconnecting.value = false;
  }
};

const reconnectWhatsApp = async () => {
  if (!props.inbox?.id) return;

  isReconnecting.value = true;
  try {
    await WhatsappWebGatewayApi.reconnect(props.inbox.id);
    useAlert(t('INBOX_MGMT.ADD.WHATSAPP_WEB.RECONNECT.SUCCESS'));
    // Refresh status after successful reconnect
    await checkConnectionStatus();
  } catch (error) {
    useAlert(error.message || t('INBOX_MGMT.ADD.WHATSAPP_WEB.RECONNECT.ERROR'));
  } finally {
    isReconnecting.value = false;
  }
};

watch(
  () => props.inbox,
  newInbox => {
    if (newInbox && props.mode === 'edit') {
      setDefaults(newInbox);
      checkConnectionStatus();
    }
  },
  { immediate: true }
);

onMounted(() => {
  if (props.mode === 'create') {
    checkAdminApiStatus();
  }
});
</script>

<template>
  <form class="flex flex-wrap flex-col mx-0" @submit.prevent="handleSubmit()">
    <!-- Connection Mode Toggle -->
    <div
      v-if="showConnectionModeToggle"
      class="flex-shrink-0 flex-grow-0 mb-4 p-4 border border-slate-200 dark:border-slate-700 rounded-lg"
    >
      <label
        class="block text-sm font-medium text-slate-900 dark:text-slate-100 mb-3"
      >
        {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.CONNECTION_MODE.LABEL') }}
      </label>
      <div class="grid grid-cols-1 gap-3">
        <label
          class="flex items-start p-3 border rounded-lg cursor-pointer transition-colors"
          :class="
            connectionMode === 'existing'
              ? 'border-blue-500 bg-blue-50 dark:bg-blue-900/20'
              : 'border-slate-200 dark:border-slate-700 hover:border-slate-300'
          "
        >
          <input
            v-model="connectionMode"
            type="radio"
            value="existing"
            class="mt-1 mr-3"
          />
          <div>
            <div class="font-medium text-slate-900 dark:text-slate-100">
              {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.CONNECTION_MODE.EXISTING') }}
            </div>
            <div class="text-xs text-slate-600 dark:text-slate-400 mt-1">
              {{
                $t('INBOX_MGMT.ADD.WHATSAPP_WEB.CONNECTION_MODE.EXISTING_DESC')
              }}
            </div>
          </div>
        </label>
        <label
          class="flex items-start p-3 border rounded-lg cursor-pointer transition-colors"
          :class="
            connectionMode === 'provision'
              ? 'border-blue-500 bg-blue-50 dark:bg-blue-900/20'
              : 'border-slate-200 dark:border-slate-700 hover:border-slate-300'
          "
        >
          <input
            v-model="connectionMode"
            type="radio"
            value="provision"
            class="mt-1 mr-3"
          />
          <div>
            <div class="font-medium text-slate-900 dark:text-slate-100">
              {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.CONNECTION_MODE.PROVISION') }}
            </div>
            <div class="text-xs text-slate-600 dark:text-slate-400 mt-1">
              {{
                $t('INBOX_MGMT.ADD.WHATSAPP_WEB.CONNECTION_MODE.PROVISION_DESC')
              }}
            </div>
          </div>
        </label>
      </div>
    </div>

    <div v-if="showInboxNameField" class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.inboxName.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.INBOX_NAME.LABEL') }}
        <input
          v-model="inboxName"
          type="text"
          :placeholder="
            $t('INBOX_MGMT.ADD.WHATSAPP_WEB.INBOX_NAME.PLACEHOLDER')
          "
          @blur="v$.inboxName.$touch"
        />
        <span v-if="v$.inboxName.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.INBOX_NAME.ERROR') }}
        </span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.phoneNumber.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.PHONE_NUMBER.LABEL') }}
        <input
          v-model="phoneNumber"
          type="text"
          :placeholder="
            $t('INBOX_MGMT.ADD.WHATSAPP_WEB.PHONE_NUMBER.PLACEHOLDER')
          "
          @blur="v$.phoneNumber.$touch"
        />
        <span v-if="v$.phoneNumber.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.PHONE_NUMBER.ERROR') }}
        </span>
      </label>
    </div>

    <!-- Only show gateway fields in existing mode -->
    <div v-if="!isProvisioningMode" class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.gatewayBaseUrl.$error }">
        <span>
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.GATEWAY_BASE_URL.LABEL') }}
          <span class="text-xs text-slate-11 ml-1">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.GATEWAY_BASE_URL.TOOLTIP') }}
          </span>
        </span>
        <input
          v-model="gatewayBaseUrl"
          type="url"
          :placeholder="
            $t('INBOX_MGMT.ADD.WHATSAPP_WEB.GATEWAY_BASE_URL.PLACEHOLDER')
          "
          @blur="v$.gatewayBaseUrl.$touch"
        />
        <span v-if="v$.gatewayBaseUrl.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.GATEWAY_BASE_URL.ERROR') }}
        </span>
      </label>
    </div>

    <div v-if="!isProvisioningMode" class="grid grid-cols-2 gap-4">
      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.basicAuthUser.$error }">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.BASIC_AUTH_USER.LABEL') }}
          <input
            v-model="basicAuthUser"
            type="text"
            :placeholder="
              $t('INBOX_MGMT.ADD.WHATSAPP_WEB.BASIC_AUTH_USER.PLACEHOLDER')
            "
            @blur="v$.basicAuthUser.$touch"
          />
          <span v-if="v$.basicAuthUser.$error" class="message">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.BASIC_AUTH_USER.ERROR') }}
          </span>
        </label>
      </div>

      <div class="flex-shrink-0 flex-grow-0">
        <label :class="{ error: v$.basicAuthPassword.$error }">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.BASIC_AUTH_PASSWORD.LABEL') }}
          <input
            v-model="basicAuthPassword"
            type="password"
            :placeholder="
              $t('INBOX_MGMT.ADD.WHATSAPP_WEB.BASIC_AUTH_PASSWORD.PLACEHOLDER')
            "
            @blur="v$.basicAuthPassword.$touch"
          />
          <span v-if="v$.basicAuthPassword.$error" class="message">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.BASIC_AUTH_PASSWORD.ERROR') }}
          </span>
        </label>
      </div>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label :class="{ error: v$.webhookSecret.$error }">
        <span>
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.WEBHOOK_SECRET.LABEL') }}
          <span class="text-xs text-slate-11 ml-1">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.WEBHOOK_SECRET.TOOLTIP') }}
          </span>
        </span>
        <input
          v-model="webhookSecret"
          type="password"
          :placeholder="
            $t('INBOX_MGMT.ADD.WHATSAPP_WEB.WEBHOOK_SECRET.PLACEHOLDER')
          "
          @blur="v$.webhookSecret.$touch"
        />
        <span v-if="v$.webhookSecret.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.WEBHOOK_SECRET.ERROR') }}
        </span>
      </label>
    </div>

    <div class="flex-shrink-0 flex-grow-0">
      <label class="flex items-center">
        <input v-model="includeSignature" type="checkbox" class="mr-2" />
        <span>
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.INCLUDE_SIGNATURE.LABEL') }}
        </span>
      </label>
      <p class="text-xs text-slate-11 mt-1">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.INCLUDE_SIGNATURE.HELP_TEXT') }}
      </p>
    </div>

    <!-- Connection Status (only in edit mode) -->
    <div v-if="mode === 'edit'" class="flex-shrink-0 flex-grow-0 my-4">
      <div class="flex items-center justify-between mb-2">
        <span class="text-sm font-medium text-slate-12">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.CONNECTION_STATUS.LABEL') }}
        </span>
        <button
          type="button"
          :disabled="isLoadingStatus"
          class="text-sm text-blue-600 hover:text-blue-800 disabled:text-gray-400"
          @click="refreshConnectionStatus"
        >
          {{
            isLoadingStatus
              ? $t('INBOX_MGMT.ADD.WHATSAPP_WEB.CONNECTION_STATUS.REFRESHING')
              : $t('INBOX_MGMT.ADD.WHATSAPP_WEB.CONNECTION_STATUS.REFRESH')
          }}
        </button>
      </div>
      <div
        class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium border"
        :class="connectionStatusColor"
      >
        <span
          v-if="isLoadingStatus"
          class="inline-block w-3 h-3 mr-2 border-2 border-current border-t-transparent rounded-full animate-spin"
        />
        <span v-else class="w-2 h-2 mr-2 rounded-full bg-current" />
        {{ connectionStatusLabel }}
      </div>
    </div>

    <div class="flex gap-2 mt-4">
      <!-- Connect Button (QR Code) -->
      <NextButton
        v-if="mode === 'edit' && showConnectButton"
        type="button"
        color="green"
        variant="outline"
        size="md"
        icon="i-lucide-qr-code"
        :label="$t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.TITLE')"
        :disabled="!canShowQRCode"
        @click="openQRModal"
      />

      <!-- Disconnect Button -->
      <NextButton
        v-if="mode === 'edit' && showDisconnectButton"
        type="button"
        color="red"
        variant="outline"
        size="md"
        icon="i-lucide-log-out"
        :label="$t('INBOX_MGMT.ADD.WHATSAPP_WEB.DISCONNECT.TITLE')"
        :is-loading="isDisconnecting"
        @click="disconnectWhatsApp"
      />

      <!-- Reconnect Button -->
      <NextButton
        v-if="mode === 'edit' && showReconnectButton"
        type="button"
        color="orange"
        variant="outline"
        size="md"
        icon="i-lucide-refresh-cw"
        :label="$t('INBOX_MGMT.ADD.WHATSAPP_WEB.RECONNECT.TITLE')"
        :is-loading="isReconnecting"
        @click="reconnectWhatsApp"
      />

      <!-- Submit Button -->
      <NextButton
        :is-loading="isLoading || isProvisioning"
        type="submit"
        variant="solid"
        color="blue"
        size="md"
        :label="
          isProvisioning
            ? $t('INBOX_MGMT.ADD.WHATSAPP_WEB.PROVISIONING.IN_PROGRESS')
            : submitButtonLabel
        "
      />
    </div>

    <!-- QR Code Modal -->
    <QRCodeModal
      :show="showQRModal"
      :gateway-config="gatewayConfig"
      :inbox-id="inbox?.id"
      @close="closeQRModal"
      @connected="handleWhatsAppConnected"
    />
  </form>
</template>
