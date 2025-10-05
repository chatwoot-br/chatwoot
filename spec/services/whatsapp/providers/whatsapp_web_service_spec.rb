require 'rails_helper'

RSpec.describe Whatsapp::Providers::WhatsappWebService do
  let(:whatsapp_channel) { create(:channel_whatsapp, provider: 'whatsapp_web', validate_provider_config: false, sync_templates: false) }
  let(:message) { create(:message, inbox: whatsapp_channel.inbox) }
  let(:service) { described_class.new(whatsapp_channel: whatsapp_channel) }

  describe '#get_accessible_attachment_url' do
    context 'when attachment has file attached' do
      let(:attachment) do
        attachment = message.attachments.new(account_id: message.account_id, file_type: :image)
        attachment.file.attach(
          io: StringIO.new('fake image'),
          filename: 'test.jpg',
          content_type: 'image/jpeg'
        )
        attachment.save!
        attachment
      end

      it 'returns file_url when available' do
        expect(attachment.file).to be_attached
        url = service.send(:get_accessible_attachment_url, attachment)
        expect(url).to be_present
        expect(url).to include('test.jpg')
      end
    end

    context 'when attachment has no file' do
      let(:attachment) { message.attachments.create!(account_id: message.account_id, file_type: :image) }

      it 'returns nil' do
        url = service.send(:get_accessible_attachment_url, attachment)
        expect(url).to be_nil
      end
    end
  end
end
