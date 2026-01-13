<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import whatsappWebAPI from 'dashboard/api/channel/whatsappWebChannel';
import ButtonV4 from 'next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Modal from 'dashboard/components/Modal.vue';

const props = defineProps({
  inbox: {
    type: Object,
    required: true,
  },
});

const { t } = useI18n();
const store = useStore();

// Constants
const POLL_INTERVAL_MS = 3000;
const MAX_POLL_COUNT = 60; // 3 minutes max

// State
const isLoading = ref(false);
const deviceStatus = ref(null);
const showQRModal = ref(false);
const showDisconnectModal = ref(false);
const qrCodeUrl = ref('');
const pollInterval = ref(null);
const pollCount = ref(0);
const isReconnecting = ref(false);
const isDisconnecting = ref(false);
const isSavingSettings = ref(false);
const ignoreGroupMessages = ref(
  props.inbox.provider_config?.ignore_group_messages ?? false
);

// Watch for inbox prop changes to sync ignoreGroupMessages
watch(
  () => props.inbox.provider_config?.ignore_group_messages,
  newValue => {
    ignoreGroupMessages.value = newValue ?? false;
  }
);

// Computed
const isConnected = computed(() => deviceStatus.value?.state === 'logged_in');

const isDisconnected = computed(
  () => !deviceStatus.value || deviceStatus.value?.state === 'disconnected'
);

const isConnecting = computed(
  () => deviceStatus.value?.state === 'connected' && !isConnected.value
);

const statusText = computed(() => {
  if (isLoading.value && !deviceStatus.value) {
    return t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.STATUS.CONNECTING');
  }
  if (isConnected.value) {
    return t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.STATUS.CONNECTED');
  }
  if (isConnecting.value) {
    return t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.STATUS.CONNECTING');
  }
  return t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.STATUS.DISCONNECTED');
});

const statusBadgeClass = computed(() => {
  if (isConnected.value) {
    return 'bg-n-teal-3 text-n-teal-11';
  }
  if (isConnecting.value) {
    return 'bg-n-amber-3 text-n-amber-11';
  }
  return 'bg-n-ruby-3 text-n-ruby-11';
});

const statusIconClass = computed(() => {
  if (isConnected.value) {
    return 'text-n-teal-11';
  }
  if (isConnecting.value) {
    return 'text-n-amber-11';
  }
  return 'text-n-ruby-11';
});

// Methods
const fetchDeviceStatus = async () => {
  isLoading.value = true;
  try {
    const response = await whatsappWebAPI.getDeviceStatus(props.inbox.id);
    deviceStatus.value = response.data;
  } catch (error) {
    useAlert(t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.ALERTS.STATUS_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const fetchQRCode = async () => {
  try {
    const response = await whatsappWebAPI.getQRCode(props.inbox.id);
    // Revoke old URL if exists
    if (qrCodeUrl.value) {
      URL.revokeObjectURL(qrCodeUrl.value);
    }
    qrCodeUrl.value = URL.createObjectURL(response.data);
  } catch (error) {
    useAlert(t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.ERROR'));
  }
};

const stopStatusPolling = () => {
  if (pollInterval.value) {
    clearInterval(pollInterval.value);
    pollInterval.value = null;
  }
  pollCount.value = 0;
};

const checkDeviceStatus = async () => {
  pollCount.value += 1;

  if (pollCount.value > MAX_POLL_COUNT) {
    stopStatusPolling();
    useAlert(t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.TIMEOUT'));
    return;
  }

  try {
    const response = await whatsappWebAPI.getDeviceStatus(props.inbox.id);
    deviceStatus.value = response.data;

    if (response.data.state === 'logged_in') {
      stopStatusPolling();
      showQRModal.value = false;
      useAlert(
        t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.ALERTS.RECONNECT_SUCCESS')
      );
    }
  } catch {
    // Silent fail during polling
  }
};

const startStatusPolling = () => {
  pollCount.value = 0;
  pollInterval.value = setInterval(checkDeviceStatus, POLL_INTERVAL_MS);
};

const handleConnect = async () => {
  showQRModal.value = true;
  await fetchQRCode();
  startStatusPolling();
};

const handleRefreshQR = async () => {
  await fetchQRCode();
  pollCount.value = 0;
  if (!pollInterval.value) {
    startStatusPolling();
  }
};

const handleCloseQRModal = () => {
  showQRModal.value = false;
  stopStatusPolling();
  if (qrCodeUrl.value) {
    URL.revokeObjectURL(qrCodeUrl.value);
    qrCodeUrl.value = '';
  }
};

const handleReconnect = async () => {
  isReconnecting.value = true;
  try {
    await whatsappWebAPI.reconnect(props.inbox.id);
    useAlert(t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.ALERTS.RECONNECT_SUCCESS'));
    await fetchDeviceStatus();

    // Auto-sync history after successful reconnect
    try {
      await whatsappWebAPI.syncHistory(props.inbox.id);
      useAlert(t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.ALERTS.SYNC_SUCCESS'));
    } catch {
      useAlert(t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.ALERTS.SYNC_ERROR'));
    }
  } catch (error) {
    useAlert(t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.ALERTS.RECONNECT_ERROR'));
  } finally {
    isReconnecting.value = false;
  }
};

const handleDisconnectClick = () => {
  showDisconnectModal.value = true;
};

const handleDisconnectConfirm = async () => {
  isDisconnecting.value = true;
  try {
    await whatsappWebAPI.logout(props.inbox.id);
    useAlert(t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.ALERTS.DISCONNECT_SUCCESS'));
    showDisconnectModal.value = false;
    await fetchDeviceStatus();
  } catch (error) {
    useAlert(t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.ALERTS.DISCONNECT_ERROR'));
  } finally {
    isDisconnecting.value = false;
  }
};

const handleDisconnectCancel = () => {
  showDisconnectModal.value = false;
};

const handleIgnoreGroupMessagesChange = async () => {
  isSavingSettings.value = true;
  try {
    const updatedProviderConfig = {
      ...props.inbox.provider_config,
      ignore_group_messages: ignoreGroupMessages.value,
    };
    // Use formData: false to properly serialize nested objects like provider_config
    await store.dispatch('inboxes/updateInbox', {
      id: props.inbox.id,
      formData: false,
      channel: {
        provider_config: updatedProviderConfig,
      },
    });
    useAlert(t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.ALERTS.SETTINGS_UPDATED'));
  } catch {
    // Revert the value on error
    ignoreGroupMessages.value = !ignoreGroupMessages.value;
    useAlert(
      t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.ALERTS.SETTINGS_UPDATE_ERROR')
    );
  } finally {
    isSavingSettings.value = false;
  }
};

// Lifecycle
onMounted(() => {
  fetchDeviceStatus();
});

onBeforeUnmount(() => {
  stopStatusPolling();
  if (qrCodeUrl.value) {
    URL.revokeObjectURL(qrCodeUrl.value);
  }
});
</script>

<template>
  <div class="gap-4 pt-8 mx-8">
    <div
      class="px-5 py-5 space-y-6 rounded-xl border shadow-sm border-n-weak bg-n-solid-2"
    >
      <!-- Header -->
      <div
        class="flex flex-col gap-5 justify-between items-start w-full md:flex-row"
      >
        <div>
          <span class="text-base font-medium text-n-slate-12">
            {{ t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.TITLE') }}
          </span>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.DESCRIPTION') }}
          </p>
        </div>
      </div>

      <!-- Status Card -->
      <div
        class="flex flex-col gap-4 p-4 rounded-lg border border-n-weak bg-n-solid-1"
      >
        <div class="flex gap-4 justify-between items-center">
          <div class="flex gap-3 items-center">
            <div
              class="flex justify-center items-center w-10 h-10 rounded-lg"
              :class="isConnected ? 'bg-n-teal-3' : 'bg-n-ruby-3'"
            >
              <Icon
                :icon="isConnected ? 'i-lucide-wifi' : 'i-lucide-wifi-off'"
                class="w-5 h-5"
                :class="statusIconClass"
              />
            </div>
            <div>
              <p class="text-sm font-medium text-n-slate-11">
                {{ t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.STATUS.LABEL') }}
              </p>
              <span
                class="inline-flex items-center px-2 py-0.5 mt-1 text-xs font-medium rounded-md"
                :class="statusBadgeClass"
              >
                {{ statusText }}
              </span>
            </div>
          </div>

          <!-- Phone Number -->
          <div class="text-right">
            <p class="text-sm text-n-slate-11">
              {{ t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.PHONE_NUMBER') }}
            </p>
            <p class="text-sm font-medium text-n-slate-12">
              {{ inbox.phone_number || inbox.phoneNumber || 'N/A' }}
            </p>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="flex flex-wrap gap-3 pt-2 border-t border-n-weak">
          <!-- Disconnected: Show Connect button -->
          <ButtonV4
            v-if="isDisconnected"
            sm
            solid
            blue
            :disabled="isLoading"
            @click="handleConnect"
          >
            <Icon icon="i-lucide-qr-code" class="mr-1 w-4 h-4" />
            {{ t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.ACTIONS.CONNECT') }}
          </ButtonV4>

          <!-- Connected: Show Reconnect and Disconnect buttons -->
          <template v-if="isConnected">
            <ButtonV4
              sm
              faded
              slate
              :disabled="isReconnecting"
              @click="handleReconnect"
            >
              <Icon
                icon="i-lucide-refresh-cw"
                class="mr-1 w-4 h-4"
                :class="{ 'animate-spin': isReconnecting }"
              />
              {{ t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.ACTIONS.RECONNECT') }}
            </ButtonV4>
            <ButtonV4
              sm
              faded
              ruby
              :disabled="isDisconnecting"
              @click="handleDisconnectClick"
            >
              <Icon icon="i-lucide-log-out" class="mr-1 w-4 h-4" />
              {{ t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.ACTIONS.DISCONNECT') }}
            </ButtonV4>
          </template>

          <!-- Connecting: Show loading state -->
          <div
            v-if="isConnecting"
            class="flex gap-2 items-center text-sm text-n-slate-11"
          >
            <Icon
              icon="i-lucide-loader-circle"
              class="w-4 h-4 animate-spin text-n-amber-11"
            />
            <span>{{
              t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.STATUS.CONNECTING')
            }}</span>
          </div>
        </div>
      </div>

      <!-- Settings Section -->
      <div
        class="flex flex-col gap-4 p-4 rounded-lg border border-n-weak bg-n-solid-1"
      >
        <label class="flex gap-3 items-start cursor-pointer">
          <input
            v-model="ignoreGroupMessages"
            type="checkbox"
            class="mt-0.5 w-4 h-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
            :disabled="isSavingSettings"
            @change="handleIgnoreGroupMessagesChange"
          />
          <div class="flex flex-col gap-1">
            <span class="text-sm font-medium text-n-slate-12">
              {{
                t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.IGNORE_GROUP_MESSAGES')
              }}
            </span>
            <span class="text-xs text-n-slate-11">
              {{
                t(
                  'INBOX_MGMT.WHATSAPP_WEB_CONNECTION.IGNORE_GROUP_MESSAGES_HELP'
                )
              }}
            </span>
          </div>
        </label>
      </div>
    </div>

    <!-- QR Code Modal -->
    <Modal :show="showQRModal" :on-close="handleCloseQRModal">
      <div class="flex flex-col gap-6 p-6">
        <div class="text-center">
          <h2 class="text-lg font-medium text-n-slate-12">
            {{ t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.QR_MODAL.TITLE') }}
          </h2>
          <p class="mt-1 text-sm text-n-slate-11">
            {{ t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.QR_MODAL.DESCRIPTION') }}
          </p>
        </div>

        <!-- QR Code Image -->
        <div class="flex justify-center">
          <div
            v-if="qrCodeUrl"
            class="p-4 bg-white rounded-lg border border-n-weak"
          >
            <img :src="qrCodeUrl" alt="WhatsApp QR Code" class="w-64 h-64" />
          </div>
          <div
            v-else
            class="flex justify-center items-center w-64 h-64 rounded-lg border border-n-weak bg-n-solid-1"
          >
            <Icon
              icon="i-lucide-loader-circle"
              class="w-8 h-8 animate-spin text-n-slate-11"
            />
          </div>
        </div>

        <!-- Instructions -->
        <div class="p-4 rounded-lg bg-n-slate-2">
          <h3 class="mb-3 text-sm font-medium text-n-slate-12">
            {{
              t(
                'INBOX_MGMT.WHATSAPP_WEB_CONNECTION.QR_MODAL.INSTRUCTIONS.TITLE'
              )
            }}
          </h3>
          <ol
            class="space-y-2 text-sm list-decimal list-inside text-n-slate-11"
          >
            <li>
              {{
                t(
                  'INBOX_MGMT.WHATSAPP_WEB_CONNECTION.QR_MODAL.INSTRUCTIONS.STEP_1'
                )
              }}
            </li>
            <li>
              {{
                t(
                  'INBOX_MGMT.WHATSAPP_WEB_CONNECTION.QR_MODAL.INSTRUCTIONS.STEP_2'
                )
              }}
            </li>
            <li>
              {{
                t(
                  'INBOX_MGMT.WHATSAPP_WEB_CONNECTION.QR_MODAL.INSTRUCTIONS.STEP_3'
                )
              }}
            </li>
          </ol>
        </div>

        <!-- Waiting indicator -->
        <div
          class="flex gap-2 justify-center items-center text-sm text-n-slate-11"
        >
          <Icon
            icon="i-lucide-loader-circle"
            class="w-4 h-4 animate-spin text-n-brand"
          />
          <span>{{
            t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.QR_MODAL.WAITING')
          }}</span>
        </div>

        <!-- Actions -->
        <div class="flex gap-3 justify-center">
          <ButtonV4 sm faded slate @click="handleRefreshQR">
            <Icon icon="i-lucide-refresh-cw" class="mr-1 w-4 h-4" />
            {{ t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.ACTIONS.REFRESH_QR') }}
          </ButtonV4>
          <ButtonV4 sm faded slate @click="handleCloseQRModal">
            {{ t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.ACTIONS.CLOSE') }}
          </ButtonV4>
        </div>
      </div>
    </Modal>

    <!-- Disconnect Confirmation Modal -->
    <Modal :show="showDisconnectModal" :on-close="handleDisconnectCancel">
      <div class="flex flex-col gap-6 p-6">
        <div class="text-center">
          <div
            class="flex justify-center items-center mx-auto mb-4 w-12 h-12 rounded-full bg-n-ruby-3"
          >
            <Icon
              icon="i-lucide-alert-triangle"
              class="w-6 h-6 text-n-ruby-11"
            />
          </div>
          <h2 class="text-lg font-medium text-n-slate-12">
            {{
              t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.DISCONNECT_CONFIRM.TITLE')
            }}
          </h2>
          <p class="mt-2 text-sm text-n-slate-11">
            {{
              t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.DISCONNECT_CONFIRM.MESSAGE')
            }}
          </p>
        </div>

        <div class="flex gap-3 justify-center">
          <ButtonV4
            sm
            faded
            slate
            :disabled="isDisconnecting"
            @click="handleDisconnectCancel"
          >
            {{
              t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.DISCONNECT_CONFIRM.CANCEL')
            }}
          </ButtonV4>
          <ButtonV4
            sm
            solid
            ruby
            :disabled="isDisconnecting"
            @click="handleDisconnectConfirm"
          >
            <Icon
              v-if="isDisconnecting"
              icon="i-lucide-loader-circle"
              class="mr-1 w-4 h-4 animate-spin"
            />
            {{
              t('INBOX_MGMT.WHATSAPP_WEB_CONNECTION.DISCONNECT_CONFIRM.CONFIRM')
            }}
          </ButtonV4>
        </div>
      </div>
    </Modal>
  </div>
</template>
