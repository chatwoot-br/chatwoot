require_relative '../services/openai/exceptions'

class TranscribeAudioMessageJob < ApplicationJob
  queue_as :default

  # Retry configuration for transient errors
  retry_on Openai::RateLimitError, wait: :polynomially_longer, attempts: 3
  retry_on Openai::NetworkError, wait: :polynomially_longer, attempts: 3

  # Discard on permanent failures
  discard_on Openai::InvalidFileError
  discard_on Openai::AuthenticationError

  def perform(message_id, attachment_id)
    message = Message.find_by(id: message_id)
    attachment = Attachment.find_by(id: attachment_id)

    if message.blank?
      Rails.logger.error "Message not found: #{message_id}"
      return
    end

    if attachment.blank?
      Rails.logger.error "Attachment not found: #{attachment_id}"
      return
    end

    Rails.logger.info "Starting transcription for message #{message_id}, attachment #{attachment_id}"

    result = Openai::AudioTranscriptionService.new(
      attachment.download_url,
      account: message.account
    ).process

    return unless result

    update_message_with_transcription(message, result)
    store_transcription_metadata(message, result)
    broadcast_transcription_update(message)

    Rails.logger.info "Transcription completed for message #{message_id}"
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Record not found: #{e.message}"
  end

  private

  def update_message_with_transcription(message, result)
    current_content = message.content.presence || ''
    transcription_text = "\n\n#{result[:text]}"

    message.update!(content: current_content + transcription_text)
  end

  def store_transcription_metadata(message, result)
    metadata = message.additional_attributes || {}
    metadata['transcription'] = {
      'language' => result[:language],
      'duration' => result[:duration],
      'transcribed_at' => Time.current.iso8601
    }
    message.update!(additional_attributes: metadata)
  end

  def broadcast_transcription_update(message)
    ActionCable.server.broadcast(
      "messages:#{message.conversation_id}",
      {
        event: 'message.updated',
        data: message.push_event_data
      }
    )
  end
end
