class Whatsapp::WebhookTeardownService
  def initialize(channel)
    @channel = channel
  end

  def perform
    teardown_whatsapp_web_device if whatsapp_web_provider?
    teardown_webhook if should_teardown_webhook?
  rescue StandardError => e
    handle_webhook_teardown_error(e)
  end

  private

  def should_teardown_webhook?
    whatsapp_cloud_provider? && embedded_signup_source? && webhook_config_present?
  end

  def whatsapp_cloud_provider?
    @channel.provider == 'whatsapp_cloud'
  end

  def whatsapp_web_provider?
    @channel.whatsapp_web? && @channel.provider_config['device_id'].present?
  end

  def teardown_whatsapp_web_device
    @channel.provider_service.logout_device
    Rails.logger.info "[WHATSAPP] Device logged out successfully for channel #{@channel.id}"
  end

  def embedded_signup_source?
    @channel.provider_config['source'] == 'embedded_signup'
  end

  def webhook_config_present?
    @channel.provider_config['business_account_id'].present? &&
      @channel.provider_config['api_key'].present?
  end

  def teardown_webhook
    waba_id = @channel.provider_config['business_account_id']
    access_token = @channel.provider_config['api_key']
    api_client = Whatsapp::FacebookApiClient.new(access_token)

    api_client.unsubscribe_waba_webhook(waba_id)
    Rails.logger.info "[WHATSAPP] Webhook unsubscribed successfully for channel #{@channel.id}"
  end

  def handle_webhook_teardown_error(error)
    Rails.logger.error "[WHATSAPP] Teardown failed for channel #{@channel.id}: #{error.message}"
    # Don't raise the error to prevent channel deletion from failing
    # Failed teardown shouldn't block deletion
  end
end
