class SendReplyJob < MutexApplicationJob
  queue_as :high
  retry_on LockAcquisitionError, wait: 1.second, attempts: 8

  CHANNEL_SERVICES = {
    'Channel::TwitterProfile' => ::Twitter::SendOnTwitterService,
    'Channel::TwilioSms' => ::Twilio::SendOnTwilioService,
    'Channel::Line' => ::Line::SendOnLineService,
    'Channel::Telegram' => ::Telegram::SendOnTelegramService,
    'Channel::Whatsapp' => ::Whatsapp::SendOnWhatsappService,
    'Channel::Sms' => ::Sms::SendOnSmsService,
    'Channel::Instagram' => ::Instagram::SendOnInstagramService,
    'Channel::Tiktok' => ::Tiktok::SendOnTiktokService,
    'Channel::Email' => ::Email::SendOnEmailService,
    'Channel::WebWidget' => ::Messages::SendEmailNotificationService,
    'Channel::Api' => ::Messages::SendEmailNotificationService
  }.freeze

  def perform(message_id)
    key = format(::Redis::RedisKeys::SEND_REPLY_MUTEX, message_id: message_id)
    with_lock(key) do
      message = Message.find(message_id)
      channel_name = message.conversation.inbox.channel.class.to_s

      if channel_name == 'Channel::FacebookPage'
        send_on_facebook_page(message)
      else
        service_class = CHANNEL_SERVICES[channel_name]
        service_class&.new(message: message)&.perform
      end
    end
  end

  private

  def send_on_facebook_page(message)
    if message.conversation.additional_attributes['type'] == 'instagram_direct_message'
      ::Instagram::Messenger::SendOnInstagramService.new(message: message).perform
    else
      ::Facebook::SendOnFacebookService.new(message: message).perform
    end
  end
end
