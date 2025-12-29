class Api::V1::Accounts::WhatsappWeb::DevicesController < Api::V1::Accounts::BaseController
  HTTP_TIMEOUT = 30 # seconds

  before_action :check_whatsapp_web_api_url
  before_action :authorize_account_access, only: [:create]
  before_action :resolve_device_id, only: [:qr_code, :status, :reconnect, :logout]

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
    authorize_device_action(:update?)
    qr_image = fetch_qr_code_from_api(@device_id)

    send_data qr_image, type: 'image/png', disposition: 'inline'
  rescue StandardError => e
    render_error(e)
  end

  # GET /api/v1/accounts/:account_id/whatsapp_web/devices/:id/status
  # Returns device connection status
  def status
    authorize_device_action(:show?)
    status_data = fetch_device_status_from_api(@device_id)

    render json: status_data
  rescue StandardError => e
    render_error(e)
  end

  # POST /api/v1/accounts/:account_id/whatsapp_web/devices/:id/reconnect
  # Triggers device reconnection
  def reconnect
    authorize_device_action(:update?)
    reconnect_device_in_api(@device_id)

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
    authorize_device_action(:update?)
    logout_device_in_api(@device_id)

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

  def authorize_account_access
    authorize Current.account, :update?
  end

  # Resolves device_id from either:
  # 1. An existing inbox ID (for post-setup operations)
  # 2. A direct device_id (for pre-inbox setup flow)
  def resolve_device_id
    @inbox = Current.account.inboxes.find_by(id: params[:id])

    if @inbox
      validate_whatsapp_web_inbox
      @device_id = @inbox.channel.provider_config['device_id']
    else
      # Pre-inbox setup: params[:id] is the device_id directly
      @device_id = params[:id]
    end
  end

  def validate_whatsapp_web_inbox
    channel = @inbox.channel
    return if channel.is_a?(Channel::Whatsapp) && channel.provider == Channel::Whatsapp::WHATSAPP_WEB_PROVIDER

    render json: {
      success: false,
      error: 'Inbox is not a WhatsApp Web channel'
    }, status: :bad_request
  end

  # Authorizes based on whether we're in setup mode or have an inbox
  def authorize_device_action(policy_action)
    if @inbox
      authorize @inbox, policy_action
    else
      # Pre-inbox setup: authorize account access
      authorize Current.account, :update?
    end
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

  def http_options(extra_headers = {})
    {
      headers: api_headers.merge(extra_headers),
      timeout: HTTP_TIMEOUT
    }
  end

  def create_device_in_api(phone_number)
    url = "#{whatsapp_web_api_url}/devices"

    response = HTTParty.post(
      url,
      **http_options,
      body: { device_id: phone_number }.to_json
    )

    # Handle "device already exists" as success
    return { 'device_id' => phone_number } if !response.success? && response.body.to_s.include?('already exists')

    handle_api_response(response, 'create device')
  end

  def fetch_qr_code_from_api(device_id)
    # Use legacy /app/login endpoint with X-Device-Id header
    # as /devices/{id}/login is not implemented yet
    url = "#{whatsapp_web_api_url}/app/login"

    response = HTTParty.get(url, **http_options('X-Device-Id' => device_id))
    raise "Failed to fetch QR code: #{response.code} - #{response.body}" unless response.success?

    # Parse JSON response to get QR code image URL
    parsed = JSON.parse(response.body)
    qr_link = parsed.dig('results', 'qr_link')
    raise 'QR code link not found in response' if qr_link.blank?

    # Download the actual QR code image
    image_response = HTTParty.get(qr_link, timeout: HTTP_TIMEOUT)
    raise "Failed to download QR image: #{image_response.code}" unless image_response.success?

    image_response.body
  end

  def fetch_device_status_from_api(device_id)
    url = "#{whatsapp_web_api_url}/devices/#{device_id}/status"

    response = HTTParty.get(url, **http_options('X-Device-Id' => device_id))
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

    response = HTTParty.post(url, **http_options('X-Device-Id' => device_id))
    handle_api_response(response, 'reconnect device')
  end

  def logout_device_in_api(device_id)
    url = "#{whatsapp_web_api_url}/devices/#{device_id}/logout"

    response = HTTParty.post(url, **http_options('X-Device-Id' => device_id))
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
