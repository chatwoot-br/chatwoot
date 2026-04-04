# rubocop:disable Metrics/ClassLength
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
    # Only check that required config is present, NOT connection status
    # This allows inbox creation before WhatsApp is connected
    return false if ENV['WHATSAPP_WEB_API_URL'].blank?
    return false if whatsapp_channel.provider_config['device_id'].blank?

    true
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

  # Fetch list of chats from go-whatsapp API for history sync
  def fetch_chats(limit: 100, offset: 0)
    response = HTTParty.get(
      "#{api_base_path}/chats",
      headers: api_headers,
      query: { limit: limit, offset: offset },
      timeout: HTTP_TIMEOUT
    )

    return nil unless response.success?

    response.parsed_response['results']
  rescue StandardError => e
    Rails.logger.error "[WhatsApp Web] Failed to fetch chats: #{e.message}"
    nil
  end

  # Fetch messages from a specific chat for history sync
  def fetch_chat_messages(chat_jid:, limit: 100, offset: 0)
    response = HTTParty.get(
      "#{api_base_path}/chat/#{CGI.escape(chat_jid)}/messages",
      headers: api_headers,
      query: { limit: limit, offset: offset },
      timeout: HTTP_TIMEOUT
    )

    return nil unless response.success?

    response.parsed_response['results']
  rescue StandardError => e
    Rails.logger.error "[WhatsApp Web] Failed to fetch messages for #{chat_jid}: #{e.message}"
    nil
  end

  # Download and decrypt media for a history sync message
  # Returns the accessible URL to the downloaded file, or nil if download fails
  def download_message_media(message_id:, chat_jid:)
    phone = chat_jid.split('@').first
    response = HTTParty.get(
      "#{api_base_path}/message/#{CGI.escape(message_id)}/download",
      headers: api_headers,
      query: { phone: phone },
      timeout: 60 # Longer timeout for media download
    )

    return nil unless response.success?

    results = response.parsed_response['results']
    return nil if results.blank? || results['file_path'].blank?

    # Return the full URL to access the downloaded file
    "#{api_base_path}/#{results['file_path']}"
  rescue StandardError => e
    Rails.logger.error "[WhatsApp Web] Failed to download media for message #{message_id}: #{e.message}"
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

    # go-whatsapp's /send/file endpoint only accepts multipart form data, not URLs
    # For other types (image, video, audio), URLs are supported
    if attachment.file_type == 'file'
      send_file_multipart(phone_number, message, attachment, endpoint)
    else
      send_attachment_with_url(phone_number, message, attachment, endpoint)
    end
  end

  def send_attachment_with_url(phone_number, message, attachment, endpoint)
    body = build_attachment_body(phone_number, message, attachment)
    Rails.logger.info "[WhatsApp Web] Sending attachment with URL: #{body.to_json}"

    response = HTTParty.post(
      "#{api_base_path}#{endpoint}",
      headers: api_headers,
      body: body.to_json,
      timeout: HTTP_TIMEOUT
    )

    process_response(response, message)
  end

  def send_file_multipart(phone_number, message, attachment, endpoint)
    Rails.logger.info "[WhatsApp Web] Sending file via multipart: #{attachment.file.filename}"

    filename = attachment.file.filename.to_s
    content_type = attachment.file.content_type || 'application/octet-stream'

    # Use blob.open for streaming file access (recommended by Chatwoot)
    attachment.file.blob.open do |tempfile|
      form_data = build_file_form_data(phone_number, message, tempfile, content_type, filename)
      response = post_multipart_file(endpoint, form_data)
      return process_faraday_response(response, message)
    end
  end

  def build_file_form_data(phone_number, message, tempfile, content_type, filename)
    form_data = {
      phone: phone_number,
      file: Faraday::Multipart::FilePart.new(tempfile, content_type, filename)
    }
    # Add caption (message text) if present
    form_data[:caption] = message.content if message.content.present?
    form_data[:reply_message_id] = reply_message_id(message) if reply_message_id(message).present?
    form_data
  end

  def post_multipart_file(endpoint, form_data)
    connection = Faraday.new(url: api_base_path) do |f|
      f.request :multipart
      f.request :url_encoded
      f.adapter Faraday.default_adapter
    end

    connection.post(endpoint) do |req|
      req.headers['X-Device-Id'] = device_id
      req.body = form_data
      req.options.timeout = HTTP_TIMEOUT
    end
  end

  def process_faraday_response(response, message)
    parsed_response = JSON.parse(response.body)
    if response.success? && parsed_response['code'] == 'SUCCESS'
      parsed_response.dig('results', 'message_id')
    else
      Rails.logger.error "[WhatsApp Web] File upload failed: #{response.body}"
      handle_faraday_error(response, message)
      nil
    end
  rescue JSON::ParserError => e
    Rails.logger.error "[WhatsApp Web] Failed to parse response: #{e.message}"
    nil
  end

  def handle_faraday_error(response, message)
    parsed = begin
      JSON.parse(response.body)
    rescue JSON::ParserError
      {}
    end
    error_msg = parsed['error'] || parsed['message'] || 'Unknown error occurred'
    Rails.logger.error "[WhatsApp Web] Error sending file: #{error_msg}"
    message.update!(status: :failed, external_error: error_msg)
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
    # go-whatsapp expects *_url suffix for URL parameters (e.g., audio_url, image_url)
    # The non-suffixed fields (audio, image) are for multipart file uploads
    url_field = attachment_url_field(attachment.file_type)

    body = {
      'phone' => phone_number,
      url_field => accessible_download_url(attachment)
    }

    # Add caption for supported types
    body['caption'] = message.outgoing_content if %w[image video].include?(attachment.file_type) && message.outgoing_content.present?

    # Send audio as voice note (PTT = Push-to-Talk)
    body['ptt'] = true if attachment.file_type == 'audio'

    # Add reply context if replying to a message
    body['reply_message_id'] = reply_message_id(message) if reply_message_id(message).present?

    body
  end

  # Transform download URL to be accessible by go-whatsapp service
  # 0.0.0.0 is a bind address, not a valid hostname for external access
  def accessible_download_url(attachment)
    url = attachment.download_url
    return url if url.blank?

    # Use INTERNAL_API_URL if available (for Docker/service communication)
    internal_url = ENV.fetch('INTERNAL_API_URL', nil)
    if internal_url.present?
      frontend_url = ENV.fetch('FRONTEND_URL', 'http://0.0.0.0:3000')
      return url.sub(frontend_url, internal_url)
    end

    # Fallback: replace 0.0.0.0 with localhost
    url.gsub('://0.0.0.0:', '://localhost:')
  end

  def attachment_url_field(file_type)
    case file_type
    when 'image' then 'image_url'
    when 'video' then 'video_url'
    when 'audio' then 'audio_url'
    else 'file_url'
    end
  end

  def error_message(response)
    # Extract error message from go-whatsapp-web-multidevice API response
    parsed = response.parsed_response
    return parsed['error'] if parsed.is_a?(Hash) && parsed['error'].present?
    return parsed['message'] if parsed.is_a?(Hash) && parsed['message'].present?

    'Unknown error occurred'
  end
end
# rubocop:enable Metrics/ClassLength
