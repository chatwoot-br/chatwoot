require 'httparty'
require 'down'
require 'tempfile'

class Openai::AudioTranscriptionService
  include HTTParty
  base_uri 'https://api.openai.com/v1'

  def initialize(audio_url)
    @audio_url = audio_url
    @api_key = ENV.fetch('OPENAI_API_KEY', nil)
  end

  def process
    if @api_key.blank?
      Rails.logger.info 'OpenAI API key is not configured'
      return nil
    end

    Rails.logger.debug { "Downloading audio file from: #{@audio_url}" }
    audio_file = download_audio_file

    unless audio_file
      Rails.logger.error 'Failed to download audio file'
      return nil
    end

    Rails.logger.debug 'Making API request to OpenAI for transcription'
    transcription = request_transcription(audio_file)

    if transcription
      Rails.logger.debug 'Successfully received transcription from OpenAI'
      transcription
    else
      Rails.logger.error 'Failed to get transcription from OpenAI'
      nil
    end
  ensure
    cleanup_file(audio_file)
  end

  private

  def download_audio_file
    file_url = if @audio_url.start_with?('http')
                 @audio_url
               else
                 "#{ENV.fetch('FRONTEND_URL', nil)}#{@audio_url}"
               end

    Rails.logger.debug { "Downloading from: #{file_url}" }
    tempfile = Down.download(file_url)

    Rails.logger.debug { "Audio file downloaded to: #{tempfile.path}" }
    tempfile
  rescue StandardError => e
    Rails.logger.error "Error downloading audio file: #{e.message}\n#{e.backtrace.join("\n")}"
    nil
  end

  def request_transcription(audio_file)
    response = self.class.post(
      '/audio/transcriptions',
      headers: {
        'Authorization' => "Bearer #{@api_key}"
      },
      body: {
        model: 'whisper-1',
        file: audio_file
      },
      multipart: true
    )

    if response.success?
      response.parsed_response['text']
    else
      Rails.logger.error "OpenAI API error: #{response.code} - #{response.body}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "Error in transcription request: #{e.message}\n#{e.backtrace.join("\n")}"
    nil
  end

  def cleanup_file(file)
    return unless file

    Rails.logger.debug 'Cleaning up temporary audio file'
    file.close
    file.unlink
  rescue StandardError => e
    Rails.logger.error "Error cleaning up file: #{e.message}"
  end
end
