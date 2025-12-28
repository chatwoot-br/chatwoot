class Api::V1::Accounts::WhatsappWeb::DevicesController < Api::V1::Accounts::BaseController
  before_action :check_whatsapp_web_api_url
  before_action :fetch_inbox, only: [:qr_code, :status, :reconnect, :logout]

  # POST /api/v1/accounts/:account_id/whatsapp_web/devices
  # Creates a new device in go-whatsapp-web-multidevice
  def create
    validate_create_params!

    phone_number = normalize_phone_number(params[:phone_number])
    response = create_device_in_api(phone_number)

    render json: {
      success: true,
      device_id: response['device_id'] || phone_number,
      message: 'Device created successfully'
    }
  rescue StandardError => e
    render_error(e)
  end

  # GET /api/v1/accounts/:account_id/whatsapp_web/devices/:id/qr_code
  # Returns QR code image for device login
  def qr_code
    authorize @inbox, :update?

    device_id = @inbox.channel.provider_config['device_id']
    qr_image = fetch_qr_code_from_api(device_id)

    send_data qr_image, type: 'image/png', disposition: 'inline'
  rescue StandardError => e
    render_error(e)
  end

  # GET /api/v1/accounts/:account_id/whatsapp_web/devices/:id/status
  # Returns device connection status
  def status
    authorize @inbox, :show?

    device_id = @inbox.channel.provider_config['device_id']
    status_data = fetch_device_status_from_api(device_id)

    render json: status_data
  rescue StandardError => e
    render_error(e)
  end

  # POST /api/v1/accounts/:account_id/whatsapp_web/devices/:id/reconnect
  # Triggers device reconnection
  def reconnect
    authorize @inbox, :update?

    device_id = @inbox.channel.provider_config['device_id']
    reconnect_device_in_api(device_id)

    render json: {
      success: true,
      message: 'Reconnection initiated'
    }
  rescue StandardError => e
    render_error(e)
  end

  # POST /api/v1/accounts/:account_id/whatsapp_web/devices/:id/logout
  # Logs out device from WhatsApp Web
  def logout
    authorize @inbox, :update?

    device_id = @inbox.channel.provider_config['device_id']
    logout_device_in_api(device_id)

    render json: {
      success: true,
      message: 'Device logged out successfully'
    }
  rescue StandardError => e
    render_error(e)
  end

  private

  def check_whatsapp_web_api_url
    return if whatsapp_web_api_url.present?

    render json: {
      success: false,
      error: 'WHATSAPP_WEB_API_URL is not configured'
    }, status: :service_unavailable
  end

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:id])
    validate_whatsapp_web_inbox
  end

  def validate_whatsapp_web_inbox
    return if @inbox.channel.is_a?(Channel::Whatsapp) && @inbox.channel.provider == 'whatsapp_web'

    render json: {
      success: false,
      error: 'Inbox is not a WhatsApp Web channel'
    }, status: :bad_request
  end

  def validate_create_params!
    return if params[:phone_number].present?

    raise ArgumentError, 'phone_number parameter is required'
  end

  def normalize_phone_number(phone)
    # Remove all non-digit characters
    phone.to_s.gsub(/\D/, '')
  end

  def whatsapp_web_api_url
    @whatsapp_web_api_url ||= ENV.fetch('WHATSAPP_WEB_API_URL', nil)
  end

  def api_headers
    {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end

  def create_device_in_api(phone_number)
    url = "#{whatsapp_web_api_url}/devices"
    body = { device_id: phone_number }.to_json

    response = HTTParty.post(url, headers: api_headers, body: body)
    handle_api_response(response, 'create device')
  end

  def fetch_qr_code_from_api(device_id)
    url = "#{whatsapp_web_api_url}/devices/#{device_id}/login"
    headers = api_headers.merge('X-Device-Id' => device_id)

    response = HTTParty.get(url, headers: headers)

    raise "Failed to fetch QR code: #{response.code} - #{response.body}" unless response.success?

    response.body
  end

  def fetch_device_status_from_api(device_id)
    url = "#{whatsapp_web_api_url}/devices/#{device_id}/status"
    headers = api_headers.merge('X-Device-Id' => device_id)

    response = HTTParty.get(url, headers: headers)
    parsed_response = handle_api_response(response, 'fetch device status')

    # Transform response to expected format
    {
      state: parsed_response['state'] || 'disconnected',
      jid: parsed_response['jid'],
      display_name: parsed_response['display_name']
    }
  end

  def reconnect_device_in_api(device_id)
    url = "#{whatsapp_web_api_url}/devices/#{device_id}/reconnect"
    headers = api_headers.merge('X-Device-Id' => device_id)

    response = HTTParty.post(url, headers: headers)
    handle_api_response(response, 'reconnect device')
  end

  def logout_device_in_api(device_id)
    url = "#{whatsapp_web_api_url}/devices/#{device_id}/logout"
    headers = api_headers.merge('X-Device-Id' => device_id)

    response = HTTParty.post(url, headers: headers)
    handle_api_response(response, 'logout device')
  end

  def handle_api_response(response, action)
    if response.success?
      begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        {}
      end
    else
      error_message = extract_error_message(response)
      raise "Failed to #{action}: #{response.code} - #{error_message}"
    end
  end

  def extract_error_message(response)
    parsed = JSON.parse(response.body)
    parsed['error'] || parsed['message'] || response.body
  rescue JSON::ParserError
    response.body
  end

  def render_error(error)
    Rails.logger.error "[WHATSAPP WEB DEVICE] Error: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")

    render json: {
      success: false,
      error: error.message
    }, status: :unprocessable_entity
  end
end
