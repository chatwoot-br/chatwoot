class Api::V1::Accounts::WhatsappWeb::GatewayController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :setup_gateway_service

  # GET /api/v1/accounts/:account_id/whatsapp_web/gateway/:id/login
  def login
    Rails.logger.info "[WHATSAPP_WEB] Login endpoint called for inbox #{params[:id]}"
    result = @gateway_service.connect
    Rails.logger.info "[WHATSAPP_WEB] Gateway response: #{result}"
    render json: { success: true, data: result }
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB] Login error: #{e.message}"
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # GET /api/v1/accounts/:account_id/whatsapp_web/gateway/:id/login_with_code
  def login_with_code
    phone = params[:phone]
    result = @gateway_service.gateway_login_with_code(phone)
    render json: { success: true, data: result }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # GET /api/v1/accounts/:account_id/whatsapp_web/gateway/:id/devices
  def devices
    result = @gateway_service.gateway_devices
    render json: { success: true, data: result }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # GET /api/v1/accounts/:account_id/whatsapp_web/gateway/:id/logout
  def logout
    result = @gateway_service.gateway_logout
    render json: { success: true, data: result }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # GET /api/v1/accounts/:account_id/whatsapp_web/gateway/:id/reconnect
  def reconnect
    result = @gateway_service.gateway_reconnect
    render json: { success: true, data: result }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # POST /api/v1/accounts/:account_id/whatsapp_web/gateway/:id/sync_history
  def sync_history
    Rails.logger.info "[WHATSAPP_WEB] Manual history sync requested for inbox #{@inbox.id}"

    # Trigger manual history sync - bypasses the 'already done' check
    Whatsapp::HistorySyncApiJob.perform_later(@inbox.id, manual: true)

    render json: {
      success: true,
      message: 'History sync initiated successfully',
      inbox_id: @inbox.id
    }
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_WEB] History sync initiation error: #{e.message}"
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_inbox
    # Get inbox_id from params (for GET) or from request body (for POST)
    inbox_id = params[:id] || request.parameters[:inbox_id]

    @inbox = Current.account.inboxes.find(inbox_id)
    authorize @inbox, :show?

    return if @inbox.channel.provider == 'whatsapp_web'

    render json: { error: 'Invalid inbox type' }, status: :unprocessable_entity
    return
  end

  def setup_gateway_service
    @gateway_service = Whatsapp::Providers::WhatsappWebService.new(
      whatsapp_channel: @inbox.channel
    )
  end

  def gateway_params
    params.permit(:id, :inbox_id, :phone)
  end
end
