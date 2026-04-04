class Webhooks::WhatsappWebEventsJob < ApplicationJob
  include WhatsappWebChannelFinder

  queue_as :low

  def perform(params = {})
    device_id = params['device_id']

    if device_id.blank?
      Rails.logger.warn('WhatsApp Web events job received without device_id')
      return
    end

    channel = find_whatsapp_web_channel(device_id)

    if whatsapp_web_channel_inactive?(channel)
      Rails.logger.warn("WhatsApp Web events job for inactive channel: #{device_id}")
      return
    end

    Whatsapp::IncomingMessageWhatsappWebService.new(inbox: channel.inbox, params: params).perform
  end
end
