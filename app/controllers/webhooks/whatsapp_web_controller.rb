class Webhooks::WhatsappWebController < ActionController::API
  def process_payload
    device_id = params[:device_id]

    if device_id.blank?
      Rails.logger.warn('WhatsApp Web webhook received without device_id')
      render json: { error: 'Missing device_id' }, status: :unprocessable_entity
      return
    end

    channel = find_channel_by_device_id(device_id)

    if channel.blank?
      Rails.logger.warn("WhatsApp Web webhook received for unknown device_id: #{device_id}")
      render json: { error: 'Channel not found' }, status: :not_found
      return
    end

    if channel_is_inactive?(channel)
      Rails.logger.warn("WhatsApp Web webhook received for inactive channel: #{device_id}")
      render json: { error: 'Inactive channel' }, status: :unprocessable_entity
      return
    end

    Webhooks::WhatsappWebEventsJob.perform_later(params.to_unsafe_hash)
    head :ok
  end

  private

  def find_channel_by_device_id(device_id)
    Channel::Whatsapp.find_by("provider = 'whatsapp_web' AND provider_config->>'device_id' = ?", device_id)
  end

  def channel_is_inactive?(channel)
    return true if channel.blank?
    return true if channel.reauthorization_required?
    return true unless channel.account.active?

    false
  end
end
