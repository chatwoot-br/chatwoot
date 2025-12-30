class Whatsapp::Providers::WhatsappWebService < Whatsapp::Providers::BaseService
  HTTP_TIMEOUT = 30 # seconds

  def send_message(phone_number, message)
    @message = message

    if message.attachments.present?
      send_attachment_message(phone_number, message)
    else
      send_text_message(phone_number, message)
    end
  end

  def send_template(_phone_number, _template_info, _message)
    # WhatsApp Web doesn't support template messages
    nil
  end

  def sync_templates
    # WhatsApp Web doesn't support template messages
    # No-op to avoid errors
  end

  def validate_provider_config?
    return false if ENV['WHATSAPP_WEB_API_URL'].blank?
    return false if whatsapp_channel.provider_config['device_id'].blank?

    # Verify the device exists and is accessible
    response = HTTParty.get(
      "#{api_base_path}/devices/#{device_id}/status",
      headers: api_headers,
      timeout: HTTP_TIMEOUT
    )

    response.success?
  rescue StandardError => e
    Rails.logger.error "[WhatsApp Web] Validation failed: #{e.message}"
    false
  end

  def api_headers
    { 'X-Device-Id' => device_id, 'Content-Type' => 'application/json' }
  end

  def media_url(media_id)
    "#{api_base_path}/media/#{media_id}"
  end

  # Device management methods
  def qr_code
    response = HTTParty.get(
      "#{api_base_path}/devices/#{device_id}/login",
      headers: api_headers,
      timeout: HTTP_TIMEOUT
    )

    return nil unless response.success?

    response.parsed_response
  end

  def device_status
    response = HTTParty.get(
      "#{api_base_path}/devices/#{device_id}/status",
      headers: api_headers,
      timeout: HTTP_TIMEOUT
    )

    return nil unless response.success?

    response.parsed_response
  end

  def reconnect_device
    response = HTTParty.post(
      "#{api_base_path}/devices/#{device_id}/reconnect",
      headers: api_headers,
      timeout: HTTP_TIMEOUT
    )

    response.success?
  end

  def logout_device
    response = HTTParty.post(
      "#{api_base_path}/devices/#{device_id}/logout",
      headers: api_headers,
      timeout: HTTP_TIMEOUT
    )

    response.success?
  end

  # Fetch group info from go-whatsapp API
  # Returns the group info hash or nil if not available
  def fetch_group_info(group_id)
    response = HTTParty.get(
      "#{api_base_path}/group/info",
      headers: api_headers,
      query: { group_id: group_id },
      timeout: HTTP_TIMEOUT
    )

    return nil unless response.success?

    parsed = response.parsed_response
    return nil unless parsed['code'] == 'SUCCESS'

    parsed['results']
  rescue StandardError => e
    Rails.logger.error "[WhatsApp Web] Failed to fetch group info: #{e.message}"
    nil
  end

  # Fetch avatar URL for a phone number from go-whatsapp API
  # Returns the avatar URL or nil if not available
  def fetch_avatar_url(phone_number)
    response = HTTParty.get(
      "#{api_base_path}/user/avatar",
      headers: api_headers,
      query: { phone: phone_number },
      timeout: HTTP_TIMEOUT
    )

    return nil unless response.success?

    parsed = response.parsed_response
    return nil unless parsed['code'] == 'SUCCESS'

    parsed.dig('results', 'url')
  rescue StandardError => e
    Rails.logger.error "[WhatsApp Web] Failed to fetch avatar: #{e.message}"
    nil
  end

  # Override base service to handle go-whatsapp response format
  # go-whatsapp returns: { "code": "SUCCESS", "results": { "message_id": "..." } }
  # WhatsApp Cloud returns: { "messages": [{ "id": "..." }] }
  def process_response(response, message)
    parsed_response = response.parsed_response
    if response.success? && parsed_response['code'] == 'SUCCESS'
      parsed_response.dig('results', 'message_id')
    else
      handle_error(response, message)
      nil
    end
  end

  private

  def reply_message_id(message)
    message.content_attributes[:in_reply_to_external_id]
  end

  def api_base_path
    ENV.fetch('WHATSAPP_WEB_API_URL', 'http://localhost:3000')
  end

  def device_id
    whatsapp_channel.provider_config['device_id']
  end

  def send_text_message(phone_number, message)
    body = {
      phone: phone_number,
      message: message.outgoing_content
    }
    body[:reply_message_id] = reply_message_id(message) if reply_message_id(message).present?

    response = HTTParty.post(
      "#{api_base_path}/send/message",
      headers: api_headers,
      body: body.to_json,
      timeout: HTTP_TIMEOUT
    )

    process_response(response, message)
  end

  def send_attachment_message(phone_number, message)
    attachment = message.attachments.first
    endpoint = attachment_endpoint(attachment.file_type)

    body = build_attachment_body(phone_number, message, attachment)

    response = HTTParty.post(
      "#{api_base_path}#{endpoint}",
      headers: api_headers,
      body: body.to_json,
      timeout: HTTP_TIMEOUT
    )

    process_response(response, message)
  end

  def attachment_endpoint(file_type)
    case file_type
    when 'image' then '/send/image'
    when 'video' then '/send/video'
    when 'audio' then '/send/audio'
    else '/send/file'
    end
  end

  def build_attachment_body(phone_number, message, attachment)
    body = {
      'phone' => phone_number,
      attachment.file_type => attachment.download_url
    }

    # Add caption for supported types
    body['caption'] = message.outgoing_content if %w[image video].include?(attachment.file_type) && message.outgoing_content.present?

    # Add reply context if replying to a message
    body['reply_message_id'] = reply_message_id(message) if reply_message_id(message).present?

    body
  end

  def error_message(response)
    # Extract error message from go-whatsapp-web-multidevice API response
    parsed = response.parsed_response
    return parsed['error'] if parsed.is_a?(Hash) && parsed['error'].present?
    return parsed['message'] if parsed.is_a?(Hash) && parsed['message'].present?

    'Unknown error occurred'
  end
end
