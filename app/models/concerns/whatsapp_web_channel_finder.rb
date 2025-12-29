module WhatsappWebChannelFinder
  extend ActiveSupport::Concern

  private

  def find_whatsapp_web_channel(device_id)
    # go-whatsapp sends device_id as JID (e.g., "5521995539939@s.whatsapp.net")
    # but we store just the phone number, so extract it from the JID
    phone_number = extract_phone_from_jid(device_id)

    Channel::Whatsapp.find_by(
      "provider = ? AND provider_config->>'device_id' = ?",
      Channel::Whatsapp::WHATSAPP_WEB_PROVIDER,
      phone_number
    )
  end

  def extract_phone_from_jid(jid)
    return jid if jid.blank?

    # Extract phone number from JID format (e.g., "628xxx@s.whatsapp.net" -> "628xxx")
    jid.split('@').first
  end

  def whatsapp_web_channel_inactive?(channel)
    return true if channel.blank?
    return true if channel.reauthorization_required?
    return true unless channel.account.active?

    false
  end
end
