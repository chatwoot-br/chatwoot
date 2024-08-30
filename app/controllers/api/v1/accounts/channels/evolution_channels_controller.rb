class Api::V1::Accounts::Channels::EvolutionChannelsController < Api::V1::Accounts::BaseController
  include Api::V1::InboxesHelper
  before_action :authorize_request
  before_action :set_user

  def create
    params = permitted_params(channel_type_from_params::EDITABLE_ATTRS)[:channel].except(:type)
    evolution_api_url = ENV.fetch('EVOLUTION_API_URL', params[:webhook_url])
    evolution_api_key = ENV.fetch('EVOLUTION_API_KEY', params[:api_key])

    return render json: { error: 'Evolution API URL is missing' }, status: :unprocessable_entity if evolution_api_url.nil?

    ActiveRecord::Base.transaction do
      channel = create_channel(evolution_api_url)
      @inbox = Current.account.inboxes.build(
        {
          name: inbox_name(channel),
          channel: channel
        }.merge(
          permitted_params.except(:channel)
        )
      )

      Evolution::ManagerService.new.create(@inbox.account_id, permitted_params[:name], evolution_api_url,
                                           evolution_api_key, @user.access_token.token)
      @inbox.save!
    end

    render json: @inbox, status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def authorize_request
    authorize ::Inbox
  end

  def set_user
    @user = current_user
  end

  def create_channel(webhook_url)
    return unless %w[api whatsapp].include?(permitted_params[:channel][:type])

    params = permitted_params(channel_type_from_params::EDITABLE_ATTRS)[:channel].except(:type, :api_key)
    params[:webhook_url] = "#{webhook_url}/chatwoot/webhook/#{permitted_params[:name]}"
    account_channels_method.create!(params)
  end

  def inbox_attributes
    [:name]
  end

  def permitted_params(channel_attributes = [])
    # We will remove this line after fixing https://linear.app/chatwoot/issue/CW-1567/null-value-passed-as-null-string-to-backend
    params.each { |k, v| params[k] = params[k] == 'null' ? nil : v }

    params.permit(
      *inbox_attributes,
      channel: [:type, :api_key, *channel_attributes]
    )
  end

  def channel_type_from_params
    {
      'api' => Channel::Api,
      'whatsapp' => Channel::Whatsapp
    }[permitted_params[:channel][:type]]
  end
end
