# Service to handle incoming messages from go-whatsapp-web-multidevice webhook
# Transforms webhook payload to Chatwoot format compatible with IncomingMessageBaseService
# rubocop:disable Metrics/ClassLength
class Whatsapp::IncomingMessageWhatsappWebService < Whatsapp::IncomingMessageBaseService
  private

  def processed_params
    @processed_params ||= transform_webhook_payload
  end

  # Ensure params are accessible with symbol keys (webhook sends string keys)
  def webhook_params
    @webhook_params ||= params.with_indifferent_access
  end

  def transform_webhook_payload
    return {} if webhook_params[:payload].blank?

    payload = webhook_params[:payload].with_indifferent_access
    event_type = webhook_params[:event]

    # Handle different event types
    case event_type
    when 'message'
      transform_message_event(payload)
    when 'message.ack'
      transform_status_event(payload)
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

  # Transform message.ack event to status update format
  # go-whatsapp sends: { ids: [...], receipt_type: "delivered"|"read" }
  # Base service expects: { statuses: [{ id: "...", status: "delivered"|"read" }] }
  def transform_status_event(payload)
    message_ids = payload[:ids] || []
    receipt_type = payload[:receipt_type]

    # Map go-whatsapp receipt types to Chatwoot statuses
    status = case receipt_type
             when 'delivered' then 'delivered'
             when 'read' then 'read'
             else return {} # Unknown receipt type
             end

    statuses = message_ids.map do |message_id|
      { id: message_id, status: status }
    end

    { statuses: statuses }
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
    # Read media from local filesystem (used when WHATSAPP_AUTO_DOWNLOAD_MEDIA is true)
    Down::ChunkedIO.new(
      chunks: [File.binread(file_path)],
      size: File.size(file_path),
      data: { filename: File.basename(file_path), content_type: Marcel::MimeType.for(Pathname.new(file_path)) }
    )
  rescue Errno::ENOENT => e
    Rails.logger.error "WhatsApp Web: Media file not found: #{file_path} - #{e.message}"
    nil
  rescue Errno::EACCES => e
    Rails.logger.error "WhatsApp Web: Permission denied for media file: #{file_path} - #{e.message}"
    nil
  rescue StandardError => e
    Rails.logger.error "WhatsApp Web: Failed to read local media file: #{e.message}"
    nil
  end

  # Override to prevent status regression (delivered should not overwrite read)
  # go-whatsapp can send duplicate/out-of-order receipts
  def process_statuses
    processed_params[:statuses]&.each do |status_update|
      message = Message.find_by(source_id: status_update[:id])
      next unless message

      new_status = status_update[:status]
      current_status = message.status

      # Status progression: sent(0) → delivered(1) → read(2)
      # Only update if new status is higher priority (don't regress from read to delivered)
      next if status_should_not_progress?(current_status, new_status)

      message.update!(status: new_status)
    end
  rescue StandardError => e
    Rails.logger.error "WhatsApp Web: Error processing status update: #{e.message}"
  end

  def status_should_not_progress?(current_status, new_status)
    status_priority = { 'sent' => 0, 'delivered' => 1, 'read' => 2, 'failed' => -1 }
    current_priority = status_priority[current_status] || 0
    new_priority = status_priority[new_status] || 0

    # Don't regress (e.g., don't go from read back to delivered)
    # But always allow failed status
    new_status != 'failed' && new_priority <= current_priority
  end
end
# rubocop:enable Metrics/ClassLength
