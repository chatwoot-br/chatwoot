require 'rails_helper'

RSpec.describe Api::OneoffApiCampaignService do
  subject { described_class.new(campaign: campaign) }

  let(:account) { create(:account) }
  let(:api_channel) { create(:channel_api, account: account) }
  let(:api_inbox) { create(:inbox, channel: api_channel, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:label) { create(:label, account: account) }
  let(:campaign) { create(:campaign, account: account, inbox: api_inbox, audience: [{ 'type' => 'Label', 'id' => label.id }]) }

  before do
    contact.label_list = [label.title]
    contact.save!
  end

  describe '#perform' do
    context 'when campaign is valid' do
      it 'marks campaign as completed' do
        expect { subject.perform }.to change { campaign.reload.completed? }.from(false).to(true)
      end

      it 'creates contact inbox and conversation for each contact with matching labels' do
        expect { subject.perform }.to change { ContactInbox.count }.by(1)
                                  .and change { Conversation.count }.by(1)
      end

      it 'creates conversation with correct attributes' do
        subject.perform

        conversation = Conversation.last
        expect(conversation.account_id).to eq(account.id)
        expect(conversation.inbox_id).to eq(api_inbox.id)
        expect(conversation.contact_id).to eq(contact.id)
        expect(conversation.campaign_id).to eq(campaign.id)
      end

      it 'creates a message in the conversation' do
        expect { subject.perform }.to change { Message.count }.by(1)

        message = Message.last
        expect(message.content).to eq(campaign.message)
        expect(message.additional_attributes['campaign_id']).to eq(campaign.id)
      end

      it 'creates contact inbox with generated UUID source_id for API channel' do
        subject.perform

        contact_inbox = ContactInbox.last
        expect(contact_inbox.source_id).to be_present
        expect(contact_inbox.source_id).to match(/\A[\w-]+\z/) # UUID format
        expect(contact_inbox.inbox_id).to eq(api_inbox.id)
        expect(contact_inbox.contact_id).to eq(contact.id)
      end
    end

    context 'when campaign is already completed' do
      before { campaign.completed! }

      it 'raises an error' do
        expect { subject.perform }.to raise_error('Completed Campaign')
      end
    end

    context 'when campaign is not one_off' do
      before { campaign.update!(campaign_type: 'ongoing') }

      it 'the campaign type is automatically set back to one_off for API campaigns' do
        # The Campaign model's ensure_correct_campaign_attributes callback
        # automatically sets API campaigns to one_off type
        expect(campaign.reload.campaign_type).to eq('one_off')
        expect { subject.perform }.not_to raise_error
      end
    end

    context 'when inbox is not API type' do
      let(:website_inbox) { create(:inbox, account: account) }
      let(:campaign) { create(:campaign, account: account, inbox: website_inbox, audience: [{ 'type' => 'Label', 'id' => label.id }]) }

      it 'raises an error' do
        expect { subject.perform }.to raise_error("Invalid campaign #{campaign.id}")
      end
    end

    context 'when there are multiple contacts with matching labels' do
      let(:contact2) { create(:contact, account: account) }

      before do
        contact2.label_list = [label.title]
        contact2.save!
      end

      it 'creates conversations for all matching contacts' do
        expect { subject.perform }.to change { Conversation.count }.by(2)
                                  .and change { ContactInbox.count }.by(2)
                                  .and change { Message.count }.by(2)
      end
    end

    context 'when contact inbox creation fails' do
      before do
        allow(ContactInboxBuilder).to receive(:new).and_return(
          double('ContactInboxBuilder', perform: nil)
        )
      end

      it 'handles errors gracefully and continues processing' do
        expect { subject.perform }.not_to raise_error
        expect(campaign.reload).to be_completed
      end
    end

    context 'when conversation creation fails' do
      before do
        allow(Campaigns::CampaignConversationBuilder).to receive(:new).and_return(
          double('CampaignConversationBuilder', perform: nil)
        )
      end

      it 'handles errors gracefully and continues processing' do
        expect { subject.perform }.not_to raise_error
        expect(campaign.reload).to be_completed
      end
    end
  end

  describe 'logging' do
    it 'logs successful conversation creation' do
      allow(Rails.logger).to receive(:info).and_call_original
      expect(Rails.logger).to receive(:info).with(/\[API Campaign\] Created conversation/)
      subject.perform
    end

    context 'when an error occurs during conversation creation' do
      before do
        allow(ContactInboxBuilder).to receive(:new).and_raise(StandardError, 'Test error')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/\[API Campaign\] Failed to create conversation/)
        subject.perform
      end
    end
  end
end
