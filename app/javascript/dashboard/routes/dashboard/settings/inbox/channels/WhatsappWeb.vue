<script setup>
import { ref, computed, onBeforeUnmount } from 'vue';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { isPhoneE164OrEmpty } from 'shared/helpers/Validators';
import whatsappWebAPI from 'dashboard/api/channel/whatsappWebChannel';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'next/icon/Icon.vue';

const { t } = useI18n();
const router = useRouter();
const store = useStore();

// Constants
const POLL_INTERVAL_MS = 3000; // 3 seconds
const MAX_POLL_COUNT = 60; // 3 minutes max (60 * 3s)

// Form state
const currentStep = ref('phone_input');
const phoneNumber = ref('');
const inboxName = ref('');
const deviceId = ref('');
const qrCodeUrl = ref('');
const isLoading = ref(false);
const errorMessage = ref('');
const pollInterval = ref(null);
const pollCount = ref(0);

// Validation
const rules = {
  phoneNumber: { required, isPhoneE164OrEmpty },
  inboxName: { required },
};

const v$ = useVuelidate(rules, { phoneNumber, inboxName });

// Computed
const isPhoneInputStep = computed(() => currentStep.value === 'phone_input');
const isScanQRStep = computed(() => currentStep.value === 'scan_qr');

// Methods - defined in order of dependency

const fetchQRCode = async () => {
  try {
    const response = await whatsappWebAPI.getQRCode(deviceId.value);
    const blobUrl = URL.createObjectURL(response.data);

    // Revoke old URL if exists
    if (qrCodeUrl.value) {
      URL.revokeObjectURL(qrCodeUrl.value);
    }

    qrCodeUrl.value = blobUrl;
  } catch (error) {
    errorMessage.value =
      error.response?.data?.message ||
      t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.ERROR');
    useAlert(errorMessage.value);
  }
};

const stopStatusPolling = () => {
  if (pollInterval.value) {
    clearInterval(pollInterval.value);
    pollInterval.value = null;
  }
  pollCount.value = 0;
};

const createInbox = async () => {
  isLoading.value = true;
  errorMessage.value = '';

  try {
    const whatsappChannel = await store.dispatch('inboxes/createChannel', {
      name: inboxName.value.trim(),
      channel: {
        type: 'whatsapp',
        phone_number: phoneNumber.value,
        provider: 'whatsapp_web',
        provider_config: {
          device_id: deviceId.value,
        },
      },
    });

    useAlert(t('INBOX_MGMT.FINISH.MESSAGE'));

    router.replace({
      name: 'settings_inboxes_add_agents',
      params: {
        page: 'new',
        inbox_id: whatsappChannel.id,
      },
    });
  } catch (error) {
    errorMessage.value =
      error.response?.data?.message ||
      t('INBOX_MGMT.ADD.WHATSAPP_WEB.API.ERROR_MESSAGE');
    useAlert(errorMessage.value);
  } finally {
    isLoading.value = false;
  }
};

const checkDeviceStatus = async () => {
  pollCount.value += 1;

  // Check for timeout
  if (pollCount.value > MAX_POLL_COUNT) {
    stopStatusPolling();
    errorMessage.value = t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.TIMEOUT');
    useAlert(errorMessage.value);
    return;
  }

  try {
    const response = await whatsappWebAPI.getDeviceStatus(deviceId.value);

    if (response.data.state === 'logged_in') {
      stopStatusPolling();
      currentStep.value = 'connected';
      await createInbox();
    }
  } catch {
    // Silent fail during polling, don't show error to user
  }
};

const startStatusPolling = () => {
  pollCount.value = 0;
  pollInterval.value = setInterval(checkDeviceStatus, POLL_INTERVAL_MS);
};

const createDevice = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) {
    return;
  }

  isLoading.value = true;
  errorMessage.value = '';

  try {
    const response = await whatsappWebAPI.createDevice(phoneNumber.value);
    // Use device_id from response (phone number normalized by backend)
    deviceId.value = response.data.device_id;
    currentStep.value = 'scan_qr';
    await fetchQRCode();
    startStatusPolling();
  } catch (error) {
    errorMessage.value =
      error.response?.data?.message ||
      t('INBOX_MGMT.ADD.WHATSAPP_WEB.API.ERROR_MESSAGE');
    useAlert(errorMessage.value);
  } finally {
    isLoading.value = false;
  }
};

const refreshQRCode = async () => {
  isLoading.value = true;
  errorMessage.value = '';

  try {
    // Just fetch a new QR code - the /login endpoint handles initialization
    await fetchQRCode();
    // Reset poll count and restart polling on refresh
    pollCount.value = 0;
    if (!pollInterval.value) {
      startStatusPolling();
    }
  } catch (error) {
    errorMessage.value =
      error.response?.data?.message ||
      t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.REFRESH_ERROR');
    useAlert(errorMessage.value);
  } finally {
    isLoading.value = false;
  }
};

const skipQRScan = async () => {
  stopStatusPolling();
  await createInbox();
};

// Cleanup
onBeforeUnmount(() => {
  stopStatusPolling();
  if (qrCodeUrl.value) {
    URL.revokeObjectURL(qrCodeUrl.value);
  }
});
</script>

<template>
  <div class="flex flex-col">
    <!-- Step 1: Phone Number Input -->
    <div v-if="isPhoneInputStep">
      <div class="mb-6">
        <h2 class="mb-2 text-lg font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-11">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.DESCRIPTION') }}
        </p>
      </div>

      <form class="flex flex-col gap-4" @submit.prevent="createDevice">
        <div class="flex flex-col gap-2">
          <label
            for="inbox-name"
            class="text-sm font-medium text-n-slate-12"
            :class="{ 'text-n-error': v$.inboxName.$error }"
          >
            {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.INBOX_NAME.LABEL') }}
          </label>
          <input
            id="inbox-name"
            v-model="inboxName"
            type="text"
            class="px-3 py-2 text-sm border rounded-lg border-n-weak focus:border-n-brand focus:ring-1 focus:ring-n-brand"
            :class="{ 'border-n-error': v$.inboxName.$error }"
            :placeholder="
              $t('INBOX_MGMT.ADD.WHATSAPP_WEB.INBOX_NAME.PLACEHOLDER')
            "
            @blur="v$.inboxName.$touch"
          />
          <span v-if="v$.inboxName.$error" class="text-xs text-n-error">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.INBOX_NAME.ERROR') }}
          </span>
        </div>

        <div class="flex flex-col gap-2">
          <label
            for="phone-number"
            class="text-sm font-medium text-n-slate-12"
            :class="{ 'text-n-error': v$.phoneNumber.$error }"
          >
            {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.PHONE_NUMBER.LABEL') }}
          </label>
          <input
            id="phone-number"
            v-model="phoneNumber"
            type="text"
            class="px-3 py-2 text-sm border rounded-lg border-n-weak focus:border-n-brand focus:ring-1 focus:ring-n-brand"
            :class="{ 'border-n-error': v$.phoneNumber.$error }"
            :placeholder="
              $t('INBOX_MGMT.ADD.WHATSAPP_WEB.PHONE_NUMBER.PLACEHOLDER')
            "
            @blur="v$.phoneNumber.$touch"
          />
          <span v-if="v$.phoneNumber.$error" class="text-xs text-n-error">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.PHONE_NUMBER.ERROR') }}
          </span>
          <span class="text-xs text-n-slate-11">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.PHONE_NUMBER.HELP') }}
          </span>
        </div>

        <div v-if="errorMessage" class="p-3 rounded-lg bg-n-error/10">
          <p class="text-sm text-n-error">{{ errorMessage }}</p>
        </div>

        <div class="flex gap-3 justify-end">
          <NextButton
            type="submit"
            :is-loading="isLoading"
            :is-disabled="isLoading"
          >
            {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.PHONE_INPUT.SUBMIT') }}
          </NextButton>
        </div>
      </form>
    </div>

    <!-- Step 2: Scan QR Code -->
    <div v-if="isScanQRStep">
      <div class="mb-6">
        <h2 class="mb-2 text-lg font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.TITLE') }}
        </h2>
        <p class="text-sm text-n-slate-11">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.DESCRIPTION') }}
        </p>
      </div>

      <div class="flex flex-col items-center gap-6">
        <!-- QR Code Display -->
        <div
          v-if="qrCodeUrl"
          class="p-6 bg-white border rounded-lg border-n-weak"
        >
          <img :src="qrCodeUrl" alt="WhatsApp QR Code" class="w-64 h-64" />
        </div>

        <!-- Instructions -->
        <div class="max-w-md p-4 rounded-lg bg-n-slate-2">
          <h3 class="mb-3 text-sm font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.INSTRUCTIONS.TITLE') }}
          </h3>
          <ol
            class="space-y-2 text-sm list-decimal list-inside text-n-slate-11"
          >
            <li>
              {{
                $t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.INSTRUCTIONS.STEP_1')
              }}
            </li>
            <li>
              {{
                $t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.INSTRUCTIONS.STEP_2')
              }}
            </li>
            <li>
              {{
                $t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.INSTRUCTIONS.STEP_3')
              }}
            </li>
          </ol>
        </div>

        <!-- Status -->
        <div class="flex gap-2 items-center text-sm text-n-slate-11">
          <Icon
            icon="i-lucide-loader-circle"
            class="animate-spin text-n-brand"
            size="16"
          />
          <span>{{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.WAITING') }}</span>
        </div>

        <!-- Error Message -->
        <div
          v-if="errorMessage"
          class="w-full max-w-md p-3 rounded-lg bg-n-error/10"
        >
          <p class="text-sm text-n-error">{{ errorMessage }}</p>
        </div>

        <!-- Actions -->
        <div class="flex gap-3">
          <NextButton
            variant="secondary"
            :is-loading="isLoading"
            :is-disabled="isLoading"
            @click="refreshQRCode"
          >
            <Icon icon="i-lucide-refresh-cw" size="16" />
            {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.REFRESH') }}
          </NextButton>
          <NextButton
            variant="primary"
            :is-loading="isLoading"
            :is-disabled="isLoading"
            @click="skipQRScan"
          >
            {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.SKIP') }}
          </NextButton>
        </div>

        <!-- Skip note -->
        <p class="text-xs text-center text-n-slate-10 max-w-md">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.SKIP_NOTE') }}
        </p>
      </div>
    </div>

    <!-- Step 3: Connected (handled by redirect) -->
  </div>
</template>
