require 'rails_helper'

RSpec.describe Whatsapp::IncomingMessageWhatsappWebService do
  let!(:account) { create(:account) }
  let!(:whatsapp_channel) do
    create(:channel_whatsapp,
           provider: 'whatsapp_web',
           account: account,
           sync_templates: false,
           validate_provider_config: false,
           provider_config: { 'device_id' => '5511999999999' })
  end
  let(:inbox) { whatsapp_channel.inbox }

  describe '#perform' do
    context 'with LID-based chat messages' do
      let(:lid_message_params) do
        {
          event: 'message',
          device_id: '5511999999999',
          payload: {
            id: 'msg_lid_001',
            chat_id: '215946727821336@lid',
            from: '215946727821336@lid',
            from_lid: '215946727821336@lid',
            from_name: 'LID Contact',
            body: 'Hello from LID chat',
            timestamp: Time.current.to_i.to_s,
            is_from_me: false
          }
        }.with_indifferent_access
      end

      it 'creates contact with LID as source_id and nil phone_number' do
        expect do
          described_class.new(inbox: inbox, params: lid_message_params).perform
        end.to change(Contact, :count).by(1)

        contact = Contact.last
        expect(contact.phone_number).to be_nil
        expect(contact.name).to eq('LID Contact')
        expect(contact.additional_attributes['is_lid_chat']).to be true
        expect(contact.additional_attributes['lid']).to eq('215946727821336@lid')
      end

      it 'creates contact_inbox with LID as source_id' do
        expect do
          described_class.new(inbox: inbox, params: lid_message_params).perform
        end.to change(ContactInbox, :count).by(1)

        contact_inbox = ContactInbox.last
        expect(contact_inbox.source_id).to eq('215946727821336@lid')
      end

      it 'creates conversation and message' do
        expect do
          described_class.new(inbox: inbox, params: lid_message_params).perform
        end.to change(Conversation, :count).by(1)
                                           .and change(Message, :count).by(1)

        message = Message.last
        expect(message.content).to eq('Hello from LID chat')
        expect(message.source_id).to eq('msg_lid_001')
      end
    end

    context 'when phone-based message arrives with from_lid matching existing LID contact' do
      let!(:lid_contact) do
        create(:contact, account: account, phone_number: nil,
                         additional_attributes: { is_lid_chat: true, lid: '215946727821336@lid' })
      end
      let!(:lid_contact_inbox) do
        create(:contact_inbox, contact: lid_contact, inbox: inbox, source_id: '215946727821336@lid')
      end

      let(:phone_message_with_from_lid_params) do
        {
          event: 'message',
          device_id: '5511999999999',
          payload: {
            id: 'msg_phone_001',
            chat_id: '556796707788@s.whatsapp.net',
            from: '556796707788@s.whatsapp.net',
            from_lid: '215946727821336@lid',
            from_name: 'Now With Phone',
            body: 'Hello with phone number now',
            timestamp: Time.current.to_i.to_s,
            is_from_me: false
          }
        }.with_indifferent_access
      end

      it 'updates existing LID contact with discovered phone number' do
        expect(lid_contact.phone_number).to be_nil

        described_class.new(inbox: inbox, params: phone_message_with_from_lid_params).perform

        lid_contact.reload
        expect(lid_contact.phone_number).to eq('+556796707788')
      end

      it 'uses existing contact_inbox (does not create new one)' do
        expect do
          described_class.new(inbox: inbox, params: phone_message_with_from_lid_params).perform
        end.not_to change(ContactInbox, :count)
      end

      it 'creates message in existing conversation (same conversation after phone discovery)' do
        # Create initial conversation for the LID contact
        conversation = create(:conversation, inbox: inbox, contact: lid_contact, contact_inbox: lid_contact_inbox)

        expect do
          described_class.new(inbox: inbox, params: phone_message_with_from_lid_params).perform
        end.not_to change(Conversation, :count)

        message = Message.last
        expect(message.content).to eq('Hello with phone number now')
        expect(message.conversation).to eq(conversation)
        expect(message.conversation.contact).to eq(lid_contact)
      end

      it 'does not overwrite phone if already set' do
        lid_contact.update(phone_number: '+5511888888888')

        described_class.new(inbox: inbox, params: phone_message_with_from_lid_params).perform

        lid_contact.reload
        expect(lid_contact.phone_number).to eq('+5511888888888')
      end
    end

    context 'with regular phone-based messages (no LID)' do
      let(:regular_message_params) do
        {
          event: 'message',
          device_id: '5511999999999',
          payload: {
            id: 'msg_regular_001',
            chat_id: '5521998765432@s.whatsapp.net',
            from: '5521998765432@s.whatsapp.net',
            from_name: 'Regular Contact',
            body: 'Hello from regular chat',
            timestamp: Time.current.to_i.to_s,
            is_from_me: false
          }
        }.with_indifferent_access
      end

      it 'creates contact with phone number' do
        expect do
          described_class.new(inbox: inbox, params: regular_message_params).perform
        end.to change(Contact, :count).by(1)

        contact = Contact.last
        expect(contact.phone_number).to eq('+5521998765432')
        expect(contact.name).to eq('Regular Contact')
      end

      it 'creates contact_inbox with phone-based source_id' do
        described_class.new(inbox: inbox, params: regular_message_params).perform

        contact_inbox = ContactInbox.last
        expect(contact_inbox.source_id).to eq('5521998765432')
      end
    end

    context 'with outgoing LID message (is_from_me: true)' do
      let(:outgoing_lid_params) do
        {
          event: 'message',
          device_id: '5511999999999',
          payload: {
            id: 'msg_out_lid_001',
            chat_id: '215946727821336@lid',
            from: '5511999999999@s.whatsapp.net',
            from_lid: '215946727821336@lid',
            chat_name: 'Recipient Name',
            body: 'Hello to LID contact',
            timestamp: Time.current.to_i.to_s,
            is_from_me: true
          }
        }.with_indifferent_access
      end

      it 'creates LID contact with chat_name as name' do
        described_class.new(inbox: inbox, params: outgoing_lid_params).perform

        # Find the LID contact via contact_inbox source_id (not the device contact)
        contact_inbox = inbox.contact_inboxes.find_by(source_id: '215946727821336@lid')
        expect(contact_inbox).to be_present

        contact = contact_inbox.contact
        expect(contact.name).to eq('Recipient Name')
        expect(contact.phone_number).to be_nil
        expect(contact.additional_attributes['is_lid_chat']).to be true
      end
    end

    context 'with group messages' do
      let(:group_message_params) do
        {
          event: 'message',
          device_id: '5511999999999',
          payload: {
            id: 'msg_group_001',
            chat_id: '120363421050222105@g.us',
            from: '5521998765432@s.whatsapp.net',
            from_name: 'Group Member',
            body: 'Hello from group',
            timestamp: Time.current.to_i.to_s,
            is_from_me: false
          }
        }.with_indifferent_access
      end

      before do
        provider_service = instance_double(Whatsapp::Providers::WhatsappWebService)
        allow(whatsapp_channel).to receive(:provider_service).and_return(provider_service)
        allow(provider_service).to receive(:fetch_group_info).and_return({ 'Name' => 'Test Group' })
        allow(provider_service).to receive(:fetch_avatar_url).and_return(nil)
      end

      it 'creates group contact with group ID as source_id' do
        described_class.new(inbox: inbox, params: group_message_params).perform

        contact_inbox = ContactInbox.last
        expect(contact_inbox.source_id).to eq('120363421050222105@g.us')

        contact = contact_inbox.contact
        expect(contact.additional_attributes['is_group']).to be true
      end
    end
  end

  describe '#lid_based_chat?' do
    let(:service) { described_class.new(inbox: inbox, params: params) }

    context 'when chat_id ends with @lid' do
      let(:params) do
        { payload: { chat_id: '215946727821336@lid' } }.with_indifferent_access
      end

      it 'returns true' do
        expect(service.send(:lid_based_chat?)).to be true
      end
    end

    context 'when chat_id ends with @s.whatsapp.net' do
      let(:params) do
        { payload: { chat_id: '5511999999999@s.whatsapp.net' } }.with_indifferent_access
      end

      it 'returns false' do
        expect(service.send(:lid_based_chat?)).to be false
      end
    end

    context 'when chat_id ends with @g.us' do
      let(:params) do
        { payload: { chat_id: '120363421050222105@g.us' } }.with_indifferent_access
      end

      it 'returns false' do
        expect(service.send(:lid_based_chat?)).to be false
      end
    end
  end

  describe '#from_lid_matches_existing_contact?' do
    let(:service) { described_class.new(inbox: inbox, params: params) }

    context 'when from_lid matches existing contact_inbox source_id' do
      let(:params) do
        {
          payload: {
            chat_id: '556796707788@s.whatsapp.net',
            from_lid: '215946727821336@lid'
          }
        }.with_indifferent_access
      end

      before do
        create(:contact_inbox, inbox: inbox, source_id: '215946727821336@lid')
      end

      it 'returns true' do
        expect(service.send(:from_lid_matches_existing_contact?)).to be true
      end
    end

    context 'when from_lid does not match any contact_inbox' do
      let(:params) do
        {
          payload: {
            chat_id: '556796707788@s.whatsapp.net',
            from_lid: '999999999999999@lid'
          }
        }.with_indifferent_access
      end

      it 'returns false' do
        expect(service.send(:from_lid_matches_existing_contact?)).to be false
      end
    end

    context 'when from_lid is blank' do
      let(:params) do
        {
          payload: {
            chat_id: '556796707788@s.whatsapp.net',
            from_lid: nil
          }
        }.with_indifferent_access
      end

      it 'returns false' do
        expect(service.send(:from_lid_matches_existing_contact?)).to be false
      end
    end

    context 'when from_lid does not end with @lid' do
      let(:params) do
        {
          payload: {
            chat_id: '556796707788@s.whatsapp.net',
            from_lid: '556796707788@s.whatsapp.net'
          }
        }.with_indifferent_access
      end

      it 'returns false' do
        expect(service.send(:from_lid_matches_existing_contact?)).to be false
      end
    end
  end
end
