module WhatsappWebChannelFinder
  extend ActiveSupport::Concern

  private

  def find_whatsapp_web_channel(device_id)
    Channel::Whatsapp.find_by(
      "provider = ? AND provider_config->>'device_id' = ?",
      Channel::Whatsapp::WHATSAPP_WEB_PROVIDER,
      device_id
    )
  end

  def whatsapp_web_channel_inactive?(channel)
    return true if channel.blank?
    return true if channel.reauthorization_required?
    return true unless channel.account.active?

    false
  end
end
