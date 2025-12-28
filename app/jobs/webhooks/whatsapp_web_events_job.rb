class Webhooks::WhatsappWebEventsJob < ApplicationJob
  queue_as :low

  def perform(params = {})
    device_id = params['device_id']

    if device_id.blank?
      Rails.logger.warn('WhatsApp Web events job received without device_id')
      return
    end

    channel = find_channel_by_device_id(device_id)

    if channel_is_inactive?(channel)
      Rails.logger.warn("WhatsApp Web events job for inactive channel: #{device_id}")
      return
    end

    Whatsapp::IncomingMessageWhatsappWebService.new(inbox: channel.inbox, params: params).perform
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
