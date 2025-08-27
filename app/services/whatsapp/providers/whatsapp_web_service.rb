class Whatsapp::Providers::WhatsappWebService < Whatsapp::Providers::BaseService
  def send_message(phone_number, message)
    @message = message

    if message.attachments.present?
      send_attachment_message(phone_number, message)
    elsif message.content_type == 'input_select'
      send_interactive_text_message(phone_number, message)
    else
      send_text_message(phone_number, message)
    end
  end

  def send_template(phone_number, _template_info, message)
    # A API WhatsApp Web Gateway pode não suportar templates complexos
    # Por enquanto, enviamos o conteúdo como mensagem de texto simples
    response = HTTParty.post(
      "#{api_path}/send/message",
      headers: api_headers,
      body: {
        phone: sanitize_number(phone_number),
        message: message.outgoing_content
      }.to_json
    )

    process_response(response, message)
  end

  def sync_templates
    # A API WhatsApp Web Gateway pode não suportar sincronização de templates
    # da mesma forma que a API oficial do WhatsApp
    # Por enquanto, apenas marcamos como atualizado
    whatsapp_channel.mark_message_templates_updated
    whatsapp_channel.update(message_templates: [], message_templates_last_updated: Time.now.utc)
  end

  def validate_provider_config?
    response = HTTParty.get("#{api_path}/app/devices")
    Rails.logger.debug { "[WHATSAPP] Webhook setup response: #{response.inspect}" }
    response.success?
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP] Webhook setup failed: #{e.message}"
    false
  end

  def api_headers
    headers = {
      'Content-Type' => 'application/json'
    }

    # Add basic auth if configured
    if whatsapp_channel.provider_config['basic_auth_user'].present? &&
       whatsapp_channel.provider_config['basic_auth_password'].present?
      auth_string = Base64.strict_encode64(
        "#{whatsapp_channel.provider_config['basic_auth_user']}:#{whatsapp_channel.provider_config['basic_auth_password']}"
      )
      headers['Authorization'] = "Basic #{auth_string}"
    end

    headers
  end

  def multipart_headers
    headers = {}

    # Add basic auth if configured
    if whatsapp_channel.provider_config['basic_auth_user'].present? &&
       whatsapp_channel.provider_config['basic_auth_password'].present?
      auth_string = Base64.strict_encode64(
        "#{whatsapp_channel.provider_config['basic_auth_user']}:#{whatsapp_channel.provider_config['basic_auth_password']}"
      )
      headers['Authorization'] = "Basic #{auth_string}"
    end

    headers
  end

  def api_path
    "#{api_base_path}/#{sanitize_number(whatsapp_channel['phone_number'])}"
  end

  def api_base_path
    ENV.fetch('WHATSAPP_WEB_BASE_URL', whatsapp_channel.provider_config['gateway_base_url'] || 'http://localhost:3001')
  end

  def media_url(media_id)
    # For go-whatsapp-web-multidevice, media_id is the relative path
    # Build the complete URL to the media file directly from base URL
    "#{api_path}/#{media_id.sub(%r{^/}, '')}"
  end

  def avatar_url(identifier)
    response = HTTParty.get(
      "#{api_path}/user/avatar",
      headers: api_headers,
      query: { phone: identifier, is_preview: true }
    )

    raise StandardError, "Gateway avatar failed: #{response.message}" unless response.success?

    response.dig('results', 'url')
  end

  def send_text_message(phone_number, message)
    payload = {
      phone: sanitize_number(phone_number),
      message: message.outgoing_content
    }

    # Add reply_message_id if this is a reply to another message
    reply_id = extract_reply_message_id(message)
    payload[:reply_message_id] = reply_id if reply_id.present?

    response = HTTParty.post(
      "#{api_path}/send/message",
      headers: api_headers,
      body: payload.to_json
    )

    process_response(response, message)
  end

  def send_attachment_message(phone_number, message)
    attachment = message.attachments.first
    sanitized_phone = sanitize_number(phone_number)

    case attachment.file_type
    when 'image'
      send_image_message(sanitized_phone, attachment, message)
    when 'audio'
      send_audio_message(sanitized_phone, attachment, message)
    when 'video'
      send_video_message(sanitized_phone, attachment, message)
    else
      send_file_message(sanitized_phone, attachment, message)
    end
  end

  def send_image_message(phone_number, attachment, message)
    # Use image_url instead of binary upload to avoid ActiveStorage access issues
    image_url = attachment.download_url

    response = HTTParty.post(
      "#{api_path}/send/image",
      headers: multipart_headers,
      body: {
        phone: phone_number,
        caption: message.outgoing_content,
        image_url: image_url
      }
    )

    process_response(response, message)
  end

  def send_audio_message(phone_number, attachment, message)
    response = HTTParty.post(
      "#{api_path}/send/audio",
      headers: multipart_headers,
      body: {
        phone: phone_number,
        audio: attachment.file
      }
    )

    process_response(response, message)
  end

  def send_video_message(phone_number, attachment, message)
    response = HTTParty.post(
      "#{api_path}/send/video",
      headers: multipart_headers,
      body: {
        phone: phone_number,
        caption: message.outgoing_content,
        video: attachment.file
      }
    )

    process_response(response, message)
  end

  def send_file_message(phone_number, attachment, message)
    response = HTTParty.post(
      "#{api_path}/send/file",
      headers: multipart_headers,
      body: {
        phone: phone_number,
        caption: message.outgoing_content,
        file: attachment.file
      }
    )

    process_response(response, message)
  end

  def error_message(response)
    # https://developers.facebook.com/docs/whatsapp/cloud-api/support/error-codes/#sample-response
    response.parsed_response&.dig('error', 'message')
  end

  def template_body_parameters(template_info)
    template_body = {
      name: template_info[:name],
      language: {
        policy: 'deterministic',
        code: template_info[:lang_code]
      }
    }

    # Enhanced template parameters structure
    # Note: Legacy format support (simple parameter arrays) has been removed
    # in favor of the enhanced component-based structure that supports
    # headers, buttons, and authentication templates.
    #
    # Expected payload format from frontend:
    # {
    #   processed_params: {
    #     body: { '1': 'John', '2': '123 Main St' },
    #     header: { media_url: 'https://...', media_type: 'image' },
    #     buttons: [{ type: 'url', parameter: 'otp123456' }]
    #   }
    # }
    # This gets transformed into WhatsApp API component format:
    # [
    #   { type: 'body', parameters: [...] },
    #   { type: 'header', parameters: [...] },
    #   { type: 'button', sub_type: 'url', parameters: [...] }
    # ]
    template_body[:components] = template_info[:parameters] || []

    template_body
  end

  def whatsapp_reply_context(message)
    reply_to = message.content_attributes[:in_reply_to_external_id]
    return nil if reply_to.blank?

    {
      message_id: reply_to
    }
  end

  # Gateway methods for WhatsApp Web connection
  def connect
    response = HTTParty.get(
      "#{api_path}/app/login",
      headers: api_headers
    )

    Rails.logger.debug { "[WHATSAPP_WEB] Gateway login response: #{response.inspect}" }

    raise StandardError, "Gateway login failed: #{response.message}" unless response.success?

    response.parsed_response
  end

  def gateway_login_with_code(phone_number)
    response = HTTParty.get(
      "#{api_path}/app/login-with-code",
      query: { phone: sanitize_number(phone_number) },
      headers: api_headers
    )

    Rails.logger.debug { "[WHATSAPP_WEB] Gateway login with code response: #{response.inspect}" }

    raise StandardError, "Gateway login with code failed: #{response.message}" unless response.success?

    response.parsed_response
  end

  def gateway_devices
    response = HTTParty.get(
      "#{api_path}/app/devices",
      headers: api_headers
    )

    Rails.logger.debug { "[WHATSAPP_WEB] Gateway devices response: #{response.inspect}" }

    raise StandardError, "Gateway devices failed: #{response.message}" unless response.success?

    response.parsed_response
  end

  def gateway_logout
    response = HTTParty.get(
      "#{api_path}/app/logout",
      headers: api_headers
    )

    Rails.logger.debug { "[WHATSAPP_WEB] Gateway logout response: #{response.inspect}" }

    raise StandardError, "Gateway logout failed: #{response.message}" unless response.success?

    response.parsed_response
  end

  def gateway_reconnect
    response = HTTParty.get(
      "#{api_path}/app/reconnect",
      headers: api_headers
    )

    Rails.logger.debug { "[WHATSAPP_WEB] Gateway reconnect response: #{response.inspect}" }

    raise StandardError, "Gateway reconnect failed: #{response.message}" unless response.success?

    response.parsed_response
  end

  def send_interactive_text_message(phone_number, message)
    # Para mensagens interativas, usamos o endpoint de mensagem padrão
    # pois a API WhatsApp Web Gateway pode não suportar mensagens interativas complexas
    response = HTTParty.post(
      "#{api_path}/send/message",
      headers: api_headers,
      body: {
        phone: sanitize_number(phone_number),
        message: message.outgoing_content
      }.to_json
    )

    process_response(response, message)
  end

  private

  def process_response(response, message)
    parsed_response = JSON.parse(response.body) if response.body.present?
    return nil unless parsed_response

    # Handle go-whatsapp-web-multidevice API response format:
    # {
    #   "code": "SUCCESS",
    #   "message": "Success",
    #   "results": {
    #     "message_id": "3EB0B430B6F8F1D0E053AC120E0A9E5C",
    #     "status": "<feature> success ...."
    #   }
    # }
    if parsed_response['code'] == 'SUCCESS' && parsed_response['results'].present?
      message_id = parsed_response.dig('results', 'message_id')
      if message_id.present?
        Rails.logger.info "[WHATSAPP WEB] Message sent successfully with ID: #{message_id}"
        # Update message with source_id for receipt tracking
        message.update!(source_id: message_id) if message
        return message_id
      end
    end

    Rails.logger.error "[WHATSAPP WEB] Message send failed: #{parsed_response}"
    nil
  end

  def sanitize_number(number)
    number.to_s.strip.delete_prefix('+')
  end

  def extract_reply_message_id(message)
    # Extract reply message ID from content attributes
    # This corresponds to in_reply_to_external_id from the frontend
    message.content_attributes&.dig('in_reply_to_external_id')
  end
end
