class Webhooks::WhatsappWebController < ActionController::API
  include WhatsappWebChannelFinder

  before_action :verify_webhook_secret

  def process_payload
    device_id = params[:device_id]

    if device_id.blank?
      Rails.logger.warn('WhatsApp Web webhook received without device_id')
      render json: { error: 'Missing device_id' }, status: :unprocessable_entity
      return
    end

    channel = find_whatsapp_web_channel(device_id)

    if channel.blank?
      Rails.logger.warn("WhatsApp Web webhook received for unknown device_id: #{device_id}")
      render json: { error: 'Channel not found' }, status: :not_found
      return
    end

    if whatsapp_web_channel_inactive?(channel)
      Rails.logger.warn("WhatsApp Web webhook received for inactive channel: #{device_id}")
      render json: { error: 'Inactive channel' }, status: :unprocessable_entity
      return
    end

    Webhooks::WhatsappWebEventsJob.perform_later(params.to_unsafe_hash)
    head :ok
  end

  private

  def verify_webhook_secret
    secret = ENV.fetch('WHATSAPP_WEB_WEBHOOK_SECRET', nil)
    return if secret.blank? # Skip verification if secret not configured

    provided_secret = request.headers['X-Webhook-Secret'] || params[:webhook_secret]

    return if ActiveSupport::SecurityUtils.secure_compare(secret, provided_secret.to_s)

    Rails.logger.warn('WhatsApp Web webhook received with invalid secret')
    render json: { error: 'Invalid webhook secret' }, status: :unauthorized
  end
end
