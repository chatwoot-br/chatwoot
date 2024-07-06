class Api::V1::Accounts::Channels::EvolutionChannelsController < Api::V1::Accounts::BaseController
  include Api::V1::InboxesHelper

  def create
    ActiveRecord::Base.transaction do
      channel = create_channel
      @inbox = Current.account.inboxes.build(
        {
          name: inbox_name(channel),
          channel: channel
        }.merge(
          permitted_params.except(:channel)
        )
      )
      @inbox.save!
    end
  end

  private

  def create_channel
    return unless %w[api whatsapp].include?(permitted_params[:channel][:type])

    account_channels_method.create!(permitted_params(channel_type_from_params::EDITABLE_ATTRS)[:channel].except(:type))
  end

  def inbox_attributes
    [:name, :avatar, :greeting_enabled, :greeting_message, :enable_email_collect, :csat_survey_enabled,
     :enable_auto_assignment, :working_hours_enabled, :out_of_office_message, :timezone, :allow_messages_after_resolved,
     :lock_to_single_conversation, :portal_id, :sender_name_type, :business_name]
  end

  def permitted_params(channel_attributes = [])
    # We will remove this line after fixing https://linear.app/chatwoot/issue/CW-1567/null-value-passed-as-null-string-to-backend
    params.each { |k, v| params[k] = params[k] == 'null' ? nil : v }

    params.permit(
      *inbox_attributes,
      channel: [:type, *channel_attributes]
    )
  end

  def channel_type_from_params
    {
      'api' => Channel::Api,
      'whatsapp' => Channel::Whatsapp
    }[permitted_params[:channel][:type]]
  end
end
