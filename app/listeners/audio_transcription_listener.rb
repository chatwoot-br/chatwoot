class AudioTranscriptionListener < BaseListener
  def message_created(event)
    message = event.data[:message]

    return unless transcription_enabled?
    return unless audio_attachments?(message)
    return unless api_key_available?(message.account)

    Rails.logger.debug { "AudioTranscriptionListener: Processing message #{message.id} with audio attachments" }

    message.attachments.where(file_type: :audio).find_each do |attachment|
      Rails.logger.info "Enqueuing transcription job for message #{message.id}, attachment #{attachment.id}"
      # Delay slightly to allow ActiveStorage to write file to disk (avoids race condition)
      TranscribeAudioMessageJob.set(wait: 2.seconds).perform_later(message.id, attachment.id)
    end
  end

  private

  def transcription_enabled?
    ENV.fetch('AUDIO_TRANSCRIPTION_ENABLED', 'true') == 'true'
  end

  def audio_attachments?(message)
    message.attachments.any? { |attachment| attachment.file_type == 'audio' }
  end

  def api_key_available?(account)
    # Use the enhanced service from Phase 1 to check API key availability
    service = Openai::AudioTranscriptionService.new(audio_url: 'dummy', account: account)
    service.send(:resolve_api_key).present?
  rescue StandardError => e
    Rails.logger.error "Error checking API key availability: #{e.message}"
    false
  end
end
