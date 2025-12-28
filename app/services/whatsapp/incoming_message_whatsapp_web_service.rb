# Service to handle incoming messages from go-whatsapp-web-multidevice webhook
# Transforms webhook payload to Chatwoot format compatible with IncomingMessageBaseService
class Whatsapp::IncomingMessageWhatsappWebService < Whatsapp::IncomingMessageBaseService
  private

  def processed_params
    @processed_params ||= transform_webhook_payload
  end

  def transform_webhook_payload
    return {} if params[:payload].blank?

    payload = params[:payload]
    event_type = params[:event]

    # Handle different event types
    case event_type
    when 'message'
      transform_message_event(payload)
    when 'message.reaction', 'message.revoked', 'message.edited'
      # Skip these for now - can be implemented later
      {}
    else
      Rails.logger.warn "Unknown WhatsApp Web event type: #{event_type}"
      {}
    end
  end

  def transform_message_event(payload)
    message_id = payload[:id]
    from = extract_phone_number(payload[:from])
    timestamp = parse_timestamp(payload[:timestamp])

    {
      contacts: [build_contact(payload)],
      messages: [build_message(payload, message_id, from, timestamp)]
    }
  end

  def build_contact(payload)
    from = extract_phone_number(payload[:from])
    profile_name = payload[:from_name]

    {
      wa_id: from,
      profile: {
        name: profile_name
      }
    }
  end

  def build_message(payload, message_id, from, timestamp)
    message = {
      id: message_id,
      from: from,
      timestamp: timestamp.to_i.to_s
    }

    add_message_content(message, payload)
    add_reply_context(message, payload)

    message
  end

  def add_message_content(message, payload)
    content = determine_message_content(payload)
    message.merge!(content)
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def determine_message_content(payload)
    return { type: 'text', text: { body: payload[:body] } } if payload[:body].present?
    return { type: 'image', image: build_media_object(payload[:image], payload[:caption]) } if payload[:image].present?
    return { type: 'video', video: build_media_object(payload[:video], payload[:caption]) } if payload[:video].present?
    return { type: 'audio', audio: build_media_object(payload[:audio]) } if payload[:audio].present?
    return { type: 'document', document: build_media_object(payload[:document]) } if payload[:document].present?
    return { type: 'sticker', sticker: build_media_object(payload[:sticker]) } if payload[:sticker].present?
    return { type: 'location', location: transform_location(payload[:location]) } if payload[:location].present?
    return { type: 'contacts', contacts: [transform_contact(payload[:contact])] } if payload[:contact].present?

    # Default to text with empty body
    { type: 'text', text: { body: '' } }
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def add_reply_context(message, payload)
    message[:context] = { id: payload[:replied_to_id] } if payload[:replied_to_id].present?
  end

  def build_media_object(media_data, caption = nil)
    media_obj = if media_data.is_a?(Hash)
                  # Media not auto-downloaded, has URL
                  { id: media_data[:url] }
                else
                  # Media auto-downloaded, has local path
                  { id: media_data }
                end

    media_obj[:caption] = caption if caption.present?
    media_obj
  end

  def transform_location(location_data)
    {
      latitude: location_data['degreesLatitude']&.to_f,
      longitude: location_data['degreesLongitude']&.to_f,
      name: location_data['name'],
      address: location_data['address'],
      url: location_data['url']
    }.compact
  end

  def transform_contact(contact_data)
    {
      name: {
        formatted_name: contact_data['displayName']
      },
      phones: contact_data['vcard'] ? extract_phones_from_vcard(contact_data['vcard']) : []
    }
  end

  def extract_phones_from_vcard(vcard)
    # Simple vCard parsing - extract phone numbers
    phones = vcard.to_s.scan(/TEL[^:]*:([^\n]+)/).map do |match|
      { phone: match[0].strip }
    end
    phones.presence || [{ phone: 'Phone number not available' }]
  end

  def extract_phone_number(jid)
    # Extract phone number from JID format (e.g., "628xxx@s.whatsapp.net" -> "628xxx")
    return '' if jid.blank?

    jid.split('@').first
  end

  def parse_timestamp(timestamp_str)
    return Time.current if timestamp_str.blank?

    Time.zone.parse(timestamp_str)
  rescue ArgumentError
    Time.current
  end

  def download_attachment_file(attachment_payload)
    media_id = attachment_payload[:id]
    return nil if media_id.blank?

    # Check if media_id is a URL (not auto-downloaded)
    if media_id.start_with?('http://', 'https://')
      # Download from WhatsApp Web API media endpoint
      download_from_whatsapp_web_api(media_id)
    elsif File.exist?(media_id)
      # Media was auto-downloaded, read from local path
      download_from_local_path(media_id)
    else
      Rails.logger.error "WhatsApp Web: Cannot download attachment - invalid media_id: #{media_id}"
      nil
    end
  end

  def download_from_whatsapp_web_api(media_url)
    # Download media from go-whatsapp-web-multidevice API
    # This would be used when WHATSAPP_AUTO_DOWNLOAD_MEDIA is false
    api_url = ENV.fetch('WHATSAPP_WEB_API_URL', nil)
    return nil if api_url.blank?

    device_id = inbox.channel.provider_config['device_id']
    headers = {
      'X-Device-Id' => device_id,
      'Accept' => '*/*'
    }

    Down.download(media_url, headers: headers)
  rescue Down::Error => e
    Rails.logger.error "WhatsApp Web: Failed to download media from API: #{e.message}"
    nil
  end

  def download_from_local_path(file_path)
    # Read media from local filesystem
    # This is used when WHATSAPP_AUTO_DOWNLOAD_MEDIA is true
    file = File.open(file_path, 'rb')
    filename = File.basename(file_path)
    content_type = Marcel::MimeType.for(file)

    # Create a Down::ChunkedIO compatible object
    Down::ChunkedIO.new(
      chunks: [file.read],
      size: File.size(file_path),
      data: {
        filename: filename,
        content_type: content_type
      }
    )
  rescue StandardError => e
    Rails.logger.error "WhatsApp Web: Failed to read local media file: #{e.message}"
    nil
  ensure
    file&.close
  end

  def process_statuses
    # Status updates (delivered, read) are not supported in the same way
    # as WhatsApp Cloud API for now. This could be implemented later
    # if go-whatsapp-web-multidevice adds receipt webhooks.
    Rails.logger.debug 'WhatsApp Web: Status updates not yet implemented'
  end
end
