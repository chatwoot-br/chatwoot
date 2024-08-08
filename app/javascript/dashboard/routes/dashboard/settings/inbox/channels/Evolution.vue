<template>
  <form class="mx-0 flex flex-wrap" @submit.prevent="createChannel()">
    <div class="w-[65%] flex-shrink-0 flex-grow-0 max-w-[65%]">
      <label :class="{ error: $v.channelName.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.LABEL') }}
        <input
          v-model.trim="channelName"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.PLACEHOLDER')"
          @blur="$v.channelName.$touch"
        />
        <span v-if="$v.channelName.$error" class="message">{{
          $t('INBOX_MGMT.ADD.WHATSAPP.INBOX_NAME.ERROR')
        }}</span>
      </label>
    </div>

    <div class="w-[65%] flex-shrink-0 flex-grow-0 max-w-[65%]">
      <label :class="{ error: $v.webhookUrl.$error }">
        {{ $t('INBOX_MGMT.ADD.EVOLUTION.WEBHOOK_URL.LABEL') }}
        <input
          v-model.trim="webhookUrl"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.EVOLUTION.WEBHOOK_URL.PLACEHOLDER')"
          @blur="$v.webhookUrl.$touch"
        />
        <span v-if="$v.webhookUrl.$error" class="message">{{
          $t('INBOX_MGMT.ADD.EVOLUTION.WEBHOOK_URL.ERROR')
        }}</span>
      </label>
      <p class="help-text">
        {{ $t('INBOX_MGMT.ADD.EVOLUTION.WEBHOOK_URL.SUBTITLE') }}
      </p>
    </div>

    <div class="w-[65%] flex-shrink-0 flex-grow-0 max-w-[65%]">
      <label :class="{ error: $v.apiKey.$error }">
        {{ $t('INBOX_MGMT.ADD.EVOLUTION.API_KEY.LABEL') }}
        <input
          v-model.trim="apiKey"
          type="text"
          :placeholder="$t('INBOX_MGMT.ADD.EVOLUTION.API_KEY.PLACEHOLDER')"
          @blur="$v.apiKey.$touch"
        />
        <span v-if="$v.apiKey.$error" class="message">{{
          $t('INBOX_MGMT.ADD.WHATSAPP.API_KEY.ERROR')
        }}</span>
      </label>
      <p class="help-text">
        {{ $t('INBOX_MGMT.ADD.EVOLUTION.API_KEY.SUBTITLE') }}
      </p>
    </div>

    <div class="w-full">
      <woot-submit-button
        :loading="uiFlags.isCreating"
        :button-text="$t('INBOX_MGMT.ADD.WHATSAPP.SUBMIT_BUTTON')"
      />
    </div>
  </form>
</template>

<script>
import { mapGetters } from 'vuex';
import alertMixin from 'shared/mixins/alertMixin';
import { required } from 'vuelidate/lib/validators';
import router from '../../../../index';

const shouldBeWebhookUrl = (value = '') =>
  value ? value.startsWith('http') : true;

const shouldContainOnlyValidChars = (value = '') =>
  value ? /^[a-zA-Z0-9_]+$/.test(value) : true;

export default {
  mixins: [alertMixin],
  data() {
    return {
      channelName: '',
      webhookUrl: '',
      apiKey: '',
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'inboxes/getUIFlags',
    }),
  },
  validations: {
    channelName: { shouldContainOnlyValidChars },
    webhookUrl: { shouldBeWebhookUrl },
    apiKey: { required },
  },
  methods: {
    async createChannel() {
      this.$v.$touch();
      if (this.$v.$invalid) {
        return;
      }

      try {
        const apiChannel = await this.$store.dispatch(
          'inboxes/createEvolutionChannel',
          {
            name: this.channelName,
            channel: {
              type: 'api',
              webhook_url: this.webhookUrl,
              api_key: this.apiKey,
            },
          });

        router.replace({
          name: 'settings_inboxes_add_agents',
          params: {
            page: 'new',
            inbox_id: apiChannel.id,
          },
        });
      } catch (error) {
        this.showAlert(this.$t('INBOX_MGMT.ADD.WHATSAPP.API.ERROR_MESSAGE'));
      }
    },
  },
};
</script>
