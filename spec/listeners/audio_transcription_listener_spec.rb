require 'rails_helper'

describe AudioTranscriptionListener do
  let(:listener) { described_class.instance }
  let!(:account) { create(:account) }
  let!(:user) { create(:user, account: account) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: user) }
  let(:event_name) { 'message.created' }

  describe '#message_created' do
    context 'when message has audio attachments' do
      let!(:message) { create(:message, message_type: 'incoming', account: account, inbox: inbox, conversation: conversation) }
      let!(:audio_attachment) { create_audio_attachment(message) }
      let!(:event) { Events::Base.new(event_name, Time.zone.now, message: message) }

      context 'when feature is enabled and API key is available' do
        before do
          allow(ENV).to receive(:fetch).and_call_original
          allow(ENV).to receive(:fetch).with('AUDIO_TRANSCRIPTION_ENABLED', 'true').and_return('true')
          allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-api-key')
        end

        it 'enqueues transcription job for each audio attachment' do
          expect(TranscribeAudioMessageJob).to receive(:perform_later).with(message.id, audio_attachment.id)
          listener.message_created(event)
        end
      end

      context 'when feature is disabled' do
        before do
          allow(ENV).to receive(:fetch).and_call_original
          allow(ENV).to receive(:fetch).with('AUDIO_TRANSCRIPTION_ENABLED', 'true').and_return('false')
        end

        it 'does not enqueue transcription job' do
          expect(TranscribeAudioMessageJob).not_to receive(:perform_later)
          listener.message_created(event)
        end
      end

      context 'when API key is not available' do
        before do
          allow(ENV).to receive(:fetch).and_call_original
          allow(ENV).to receive(:fetch).with('AUDIO_TRANSCRIPTION_ENABLED', 'true').and_return('true')
          allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return(nil)
        end

        it 'does not enqueue transcription job' do
          expect(TranscribeAudioMessageJob).not_to receive(:perform_later)
          listener.message_created(event)
        end
      end

      context 'when account has OpenAI integration' do
        let!(:openai_hook) do
          create(:integrations_hook, account: account, app_id: 'openai', status: 'enabled',
                                     settings: { 'api_key' => 'account-specific-key' })
        end

        before do
          allow(ENV).to receive(:fetch).and_call_original
          allow(ENV).to receive(:fetch).with('AUDIO_TRANSCRIPTION_ENABLED', 'true').and_return('true')
          allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return(nil)
        end

        it 'enqueues transcription job using account-specific API key' do
          expect(TranscribeAudioMessageJob).to receive(:perform_later).with(message.id, audio_attachment.id)
          listener.message_created(event)
        end
      end

      context 'when account has disabled OpenAI integration' do
        let!(:openai_hook) do
          create(:integrations_hook, account: account, app_id: 'openai', status: 'disabled',
                                     settings: { 'api_key' => 'account-specific-key' })
        end

        before do
          allow(ENV).to receive(:fetch).and_call_original
          allow(ENV).to receive(:fetch).with('AUDIO_TRANSCRIPTION_ENABLED', 'true').and_return('true')
          allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return(nil)
        end

        it 'does not enqueue transcription job' do
          expect(TranscribeAudioMessageJob).not_to receive(:perform_later)
          listener.message_created(event)
        end
      end
    end

    context 'when message has multiple audio attachments' do
      let!(:message) { create(:message, message_type: 'incoming', account: account, inbox: inbox, conversation: conversation) }
      let!(:audio_attachment1) { create_audio_attachment(message) }
      let!(:audio_attachment2) { create_audio_attachment(message) }
      let!(:event) { Events::Base.new(event_name, Time.zone.now, message: message) }

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('AUDIO_TRANSCRIPTION_ENABLED', 'true').and_return('true')
        allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-api-key')
      end

      it 'enqueues transcription job for each audio attachment' do
        expect(TranscribeAudioMessageJob).to receive(:perform_later).with(message.id, audio_attachment1.id)
        expect(TranscribeAudioMessageJob).to receive(:perform_later).with(message.id, audio_attachment2.id)
        listener.message_created(event)
      end
    end

    context 'when message has no audio attachments' do
      let!(:message) { create(:message, message_type: 'incoming', account: account, inbox: inbox, conversation: conversation) }
      let!(:event) { Events::Base.new(event_name, Time.zone.now, message: message) }

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('AUDIO_TRANSCRIPTION_ENABLED', 'true').and_return('true')
        allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-api-key')
      end

      it 'does not enqueue transcription job' do
        expect(TranscribeAudioMessageJob).not_to receive(:perform_later)
        listener.message_created(event)
      end
    end

    context 'when message has mixed attachment types' do
      let!(:message) { create(:message, message_type: 'incoming', account: account, inbox: inbox, conversation: conversation) }
      let!(:audio_attachment) { create_audio_attachment(message) }
      let!(:image_attachment) { create_image_attachment(message) }
      let!(:event) { Events::Base.new(event_name, Time.zone.now, message: message) }

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('AUDIO_TRANSCRIPTION_ENABLED', 'true').and_return('true')
        allow(ENV).to receive(:fetch).with('OPENAI_API_KEY', nil).and_return('test-api-key')
      end

      it 'only enqueues transcription job for audio attachments' do
        expect(TranscribeAudioMessageJob).to receive(:perform_later).with(message.id, audio_attachment.id)
        listener.message_created(event)
      end
    end

    context 'when API key check raises an error' do
      let!(:message) { create(:message, message_type: 'incoming', account: account, inbox: inbox, conversation: conversation) }
      let!(:audio_attachment) { create_audio_attachment(message) }
      let!(:event) { Events::Base.new(event_name, Time.zone.now, message: message) }

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('AUDIO_TRANSCRIPTION_ENABLED', 'true').and_return('true')
        allow_any_instance_of(Openai::AudioTranscriptionService).to receive(:send).and_raise(StandardError.new('API error'))
      end

      it 'handles the error gracefully and does not enqueue job' do
        expect(Rails.logger).to receive(:error).with(/Error checking API key availability/)
        expect(TranscribeAudioMessageJob).not_to receive(:perform_later)
        listener.message_created(event)
      end
    end
  end

  private

  def create_audio_attachment(message)
    attachment = message.attachments.build(
      account_id: message.account_id,
      file_type: :audio
    )
    attachment.file.attach(
      io: File.open(Rails.root.join('spec/assets/sample.mp3')),
      filename: 'sample.mp3',
      content_type: 'audio/mpeg'
    )
    attachment.save!
    attachment
  end

  def create_image_attachment(message)
    attachment = message.attachments.build(
      account_id: message.account_id,
      file_type: :image
    )
    attachment.file.attach(
      io: File.open(Rails.root.join('spec/assets/avatar.png')),
      filename: 'avatar.png',
      content_type: 'image/png'
    )
    attachment.save!
    attachment
  end
end
