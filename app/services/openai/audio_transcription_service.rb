require 'httparty'
require 'down'
require 'tempfile'
require_relative 'exceptions'

class Openai::AudioTranscriptionService
  include HTTParty
  base_uri 'https://api.openai.com/v1'

  def initialize(audio_url, account: nil)
    @audio_url = audio_url
    @account = account
    @api_key = resolve_api_key
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
        file: audio_file,
        response_format: 'verbose_json'
      },
      multipart: true
    )

    if response.success?
      parsed = response.parsed_response
      {
        text: parsed['text'],
        language: parsed['language'],
        duration: parsed['duration']
      }
    else
      handle_error_response(response)
    end
  rescue StandardError => e
    Rails.logger.error "Error in transcription request: #{e.message}\n#{e.backtrace.join("\n")}"
    raise
  end

  def handle_error_response(response)
    error_message = "#{response.code} - #{response.body}"

    case response.code
    when 429
      raise Openai::RateLimitError, "Rate limit exceeded: #{error_message}"
    when 400
      raise Openai::InvalidFileError, "Invalid file: #{error_message}"
    when 401, 403
      raise Openai::AuthenticationError, "Authentication failed: #{error_message}"
    when 500..599
      raise Openai::NetworkError, "Server error: #{error_message}"
    else
      raise Openai::TranscriptionError, "Unknown error: #{error_message}"
    end
  end

  def cleanup_file(file)
    return unless file

    Rails.logger.debug 'Cleaning up temporary audio file'
    file.close
    file.unlink
  rescue StandardError => e
    Rails.logger.error "Error cleaning up file: #{e.message}"
  end

  def resolve_api_key
    # 1. Try integration hook first
    if @account
      integration = @account.hooks.find_by(app_id: 'openai', status: 'enabled')
      if integration&.settings&.dig('api_key').present?
        Rails.logger.debug { "Using OpenAI API key from integration for account #{@account.id}" }
        return integration.settings['api_key']
      end
    end

    # 2. Fall back to ENV
    Rails.logger.debug 'Using OpenAI API key from environment variable'
    ENV.fetch('OPENAI_API_KEY', nil)
  end
end
