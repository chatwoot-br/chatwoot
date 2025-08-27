<script>
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required, url, helpers } from '@vuelidate/validators';
import { isPhoneE164OrEmpty } from 'shared/helpers/Validators';

import NextButton from 'dashboard/components-next/button/Button.vue';
import QRCodeModal from 'dashboard/components/QRCodeModal.vue';

// Custom URL validator that accepts localhost
const urlOrLocalhost = helpers.withMessage(
  'Please provide a valid URL',
  value => {
    if (!value) return true; // Allow empty values (let required handle it)

    // Allow localhost URLs
    if (value.includes('localhost:')) {
      return true;
    }

    // Use standard URL validation for other URLs
    return url(value);
  }
);

export default {
  name: 'WhatsappWebForm',
  components: {
    NextButton,
    QRCodeModal,
  },
  props: {
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
  },
  emits: ['submit'],
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      inboxName: '',
      phoneNumber: '',
      gatewayBaseUrl: '',
      basicAuthUser: '',
      basicAuthPassword: '',
      webhookSecret: '',
      showQRModal: false,
    };
  },
  computed: {
    gatewayConfig() {
      return {
        gatewayBaseUrl: this.gatewayBaseUrl,
        phoneNumber: this.phoneNumber,
        basicAuthUser: this.basicAuthUser,
        basicAuthPassword: this.basicAuthPassword,
      };
    },
    canShowQRCode() {
      return this.gatewayBaseUrl && this.gatewayBaseUrl.trim() !== '';
    },
    submitButtonLabel() {
      return this.mode === 'create'
        ? this.$t('INBOX_MGMT.ADD.WHATSAPP_WEB.SUBMIT_BUTTON')
        : this.$t('INBOX_MGMT.SETTINGS_POPUP.WHATSAPP_SECTION_UPDATE_BUTTON');
    },
    showInboxNameField() {
      return this.mode === 'create';
    },
  },
  validations() {
    const baseValidations = {
      phoneNumber: { required, isPhoneE164OrEmpty },
      gatewayBaseUrl: { required, urlOrLocalhost },
      basicAuthUser: {},
      basicAuthPassword: {},
      webhookSecret: { required },
    };

    if (this.mode === 'create') {
      baseValidations.inboxName = { required };
    }

    return baseValidations;
  },
  watch: {
    inbox: {
      immediate: true,
      handler(newInbox) {
        if (newInbox && this.mode === 'edit') {
          this.setDefaults(newInbox);
        }
      },
    },
  },
  methods: {
    setDefaults(inbox) {
      if (!inbox) return;

      this.inboxName = inbox.name || '';
      this.phoneNumber = inbox.phone_number || '';

      if (inbox.provider_config) {
        this.gatewayBaseUrl = inbox.provider_config.gateway_base_url || '';
        this.basicAuthUser = inbox.provider_config.basic_auth_user || '';
        this.basicAuthPassword =
          inbox.provider_config.basic_auth_password || '';
        this.webhookSecret = inbox.provider_config.webhook_secret || '';
      }
    },

    openQRModal() {
      if (!this.canShowQRCode) {
        useAlert(
          this.$t(
            'INBOX_MGMT.ADD.WHATSAPP_WEB.TEST_CONNECTION.VALIDATION_ERROR'
          )
        );
        return;
      }
      this.showQRModal = true;
    },

    closeQRModal() {
      this.showQRModal = false;
    },

    handleWhatsAppConnected() {
      this.closeQRModal();
      // You could add additional logic here, like auto-filling fields
      // or proceeding to the next step
    },

    handleSubmit() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      // Build provider_config, omitting optional Basic Auth if left blank
      const providerConfig = {
        gateway_base_url: this.gatewayBaseUrl,
        webhook_secret: this.webhookSecret,
      };

      if (this.basicAuthUser && this.basicAuthPassword) {
        providerConfig.basic_auth_user = this.basicAuthUser;
        providerConfig.basic_auth_password = this.basicAuthPassword;
      }

      const formData = {
        name: this.inboxName,
        phone_number: this.phoneNumber,
        provider_config: providerConfig,
      };

      this.$emit('submit', formData);
    },
  },
};
</script>

<template>
  <form class="flex flex-wrap flex-col mx-0" @submit.prevent="handleSubmit()">
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

    <div class="flex-shrink-0 flex-grow-0">
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

    <div class="grid grid-cols-2 gap-4">
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

    <div class="flex gap-2 mt-4">
      <NextButton
        type="button"
        color="green"
        variant="outline"
        size="md"
        icon="i-lucide-qr-code"
        :label="$t('INBOX_MGMT.ADD.WHATSAPP_WEB.QR_CODE.TITLE')"
        :disabled="!canShowQRCode"
        @click="openQRModal"
      />

      <NextButton
        :is-loading="isLoading"
        type="submit"
        variant="solid"
        color="blue"
        size="md"
        :label="submitButtonLabel"
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
