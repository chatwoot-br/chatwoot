require 'rails_helper'
require_relative '../../../app/services/openai/exceptions'

RSpec.describe 'Openai::Exceptions' do
  describe 'exception hierarchy' do
    it 'TranscriptionError is a StandardError' do
      expect(Openai::TranscriptionError.new).to be_a(StandardError)
    end

    it 'RateLimitError inherits from TranscriptionError' do
      expect(Openai::RateLimitError.new).to be_a(Openai::TranscriptionError)
    end

    it 'NetworkError inherits from TranscriptionError' do
      expect(Openai::NetworkError.new).to be_a(Openai::TranscriptionError)
    end

    it 'InvalidFileError inherits from TranscriptionError' do
      expect(Openai::InvalidFileError.new).to be_a(Openai::TranscriptionError)
    end

    it 'AuthenticationError inherits from TranscriptionError' do
      expect(Openai::AuthenticationError.new).to be_a(Openai::TranscriptionError)
    end
  end

  describe 'raising and rescuing exceptions' do
    it 'can raise and rescue RateLimitError' do
      expect do
        raise Openai::RateLimitError, 'Rate limit exceeded'
      rescue Openai::RateLimitError => e
        expect(e.message).to eq('Rate limit exceeded')
        raise
      end.to raise_error(Openai::RateLimitError)
    end

    it 'can raise and rescue NetworkError' do
      expect do
        raise Openai::NetworkError, 'Network error'
      rescue Openai::NetworkError => e
        expect(e.message).to eq('Network error')
        raise
      end.to raise_error(Openai::NetworkError)
    end

    it 'can raise and rescue InvalidFileError' do
      expect do
        raise Openai::InvalidFileError, 'Invalid file'
      rescue Openai::InvalidFileError => e
        expect(e.message).to eq('Invalid file')
        raise
      end.to raise_error(Openai::InvalidFileError)
    end

    it 'can raise and rescue AuthenticationError' do
      expect do
        raise Openai::AuthenticationError, 'Auth failed'
      rescue Openai::AuthenticationError => e
        expect(e.message).to eq('Auth failed')
        raise
      end.to raise_error(Openai::AuthenticationError)
    end

    it 'can catch all transcription errors with base class' do
      expect do
        raise Openai::RateLimitError, 'Some error'
      rescue Openai::TranscriptionError => e
        expect(e.message).to eq('Some error')
        raise
      end.to raise_error(Openai::RateLimitError)
    end
  end
end
