class Api::V1::Accounts::Conversations::MessagesController < Api::V1::Accounts::Conversations::BaseController
  def index
    @messages = message_finder.perform
  end

  def create
    user = Current.user || @resource
    Rails.logger.debug 'Processing message creation with potential audio attachments'

    # Process the transcript before constructing the message
    transcription = process_audio_transcription if audio_attachment?

    # Creates the parameters correctly
    merged_params = params.dup
    if transcription.present?
      Rails.logger.debug 'Adding transcription to message content'
      original_content = params[:content].presence
      merged_params[:content] = [original_content, transcription].compact.join("\n\n")
    end

    @message = Messages::MessageBuilder.new(user, @conversation, merged_params).perform
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def destroy
    ActiveRecord::Base.transaction do
      message.update!(content: I18n.t('conversations.messages.deleted'), content_type: :text, content_attributes: { deleted: true })
      message.attachments.destroy_all
    end
  end

  def retry
    return if message.blank?

    message.update!(status: :sent, content_attributes: {})
    ::SendReplyJob.perform_later(message.id)
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def translate
    return head :ok if already_translated_content_available?

    translated_content = Integrations::GoogleTranslate::ProcessorService.new(
      message: message,
      target_language: permitted_params[:target_language]
    ).perform

    if translated_content.present?
      translations = {}
      translations[permitted_params[:target_language]] = translated_content
      translations = message.translations.merge!(translations) if message.translations.present?
      message.update!(translations: translations)
    end

    render json: { content: translated_content }
  end

  private

  def audio_attachment?
    return false if params[:attachments].blank?

    params[:attachments].any? do |attachment|
      content_type = attachment.try(:content_type)
      content_type&.start_with?('audio/')
    end
  end

  def process_audio_transcription
    Rails.logger.debug 'Processing audio attachments for transcription'
    transcriptions = []

    params[:attachments].each do |attachment|
      next unless attachment.content_type&.start_with?('audio/')

      Rails.logger.debug { "Attempting to transcribe audio file: #{attachment.original_filename}" }

      begin
        # Temporarily upload to ActiveStorage
        blob = ActiveStorage::Blob.create_and_upload!(
          io: attachment.tempfile,
          filename: attachment.original_filename,
          content_type: attachment.content_type
        )

        temp_url = Rails.application.routes.url_helpers.rails_blob_url(blob, only_path: false)

        Rails.logger.debug { "Generated temporary URL for audio file: #{temp_url}" }
        transcription_service = Openai::AudioTranscriptionService.new(temp_url)
        transcription = transcription_service.process

        if transcription.present?
          Rails.logger.debug 'Transcription successful'
          transcriptions << transcription.to_s
        end
      rescue StandardError => e
        Rails.logger.error "Error transcribing audio file: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end

    transcriptions.any? ? transcriptions.join("\n\n") : nil
  end

  def message
    @message ||= @conversation.messages.find(permitted_params[:id])
  end

  def message_finder
    @message_finder ||= MessageFinder.new(@conversation, params)
  end

  def permitted_params
    params.permit(:id, :target_language)
  end

  def already_translated_content_available?
    message.translations.present? && message.translations[permitted_params[:target_language]].present?
  end
end
