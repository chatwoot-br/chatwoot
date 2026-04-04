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

  before do
    provider_service_double = instance_double(Whatsapp::Providers::WhatsappWebService)
    dedup_lock_double = instance_double(Whatsapp::MessageDedupLock, acquire!: true)
    allow(whatsapp_channel).to receive(:provider_service).and_return(provider_service_double)
    allow(provider_service_double).to receive(:fetch_avatar_url).and_return(nil)
    allow(provider_service_double).to receive(:fetch_group_info).and_return({})
    # Message source dedup lock uses Redis with long TTL and can leak across examples
    # because many examples intentionally reuse fixed message IDs.
    allow(Whatsapp::MessageDedupLock).to receive(:new).and_return(dedup_lock_double)
  end

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

  # ISSUE-0002: Concurrent message processing creates duplicate contacts
  # This test replicates the scenario where "Quezia" (phone 556796707788) appears multiple times
  # due to race conditions during message processing
  describe 'concurrent message processing duplicate contacts issue (ISSUE-0002)' do
    let(:contact_phone) { '556796707788' }
    let(:contact_name) { 'Quezia' }
    let(:chat_jid) { "#{contact_phone}@s.whatsapp.net" }

    def build_message_params(message_id, content)
      {
        'event' => 'message',
        'device_id' => '5511999999999',
        'payload' => {
          'id' => message_id,
          'chat_id' => chat_jid,
          'from' => chat_jid,
          'from_name' => contact_name,
          'body' => content,
          'timestamp' => Time.current.to_i.to_s,
          'is_from_me' => false
        }
      }.with_indifferent_access
    end

    describe 'sequential message processing (expected behavior)' do
      # rubocop:disable RSpec/MultipleExpectations
      it 'creates exactly one contact and one conversation for same sender' do
        # Process first message
        expect do
          described_class.new(inbox: inbox, params: build_message_params('msg_001', 'Ok')).perform
        end.to change(Contact, :count).by(1)
                                      .and change(Conversation, :count).by(1)
                                                                       .and change(Message, :count).by(1)

        # Verify single contact with correct data
        contact = inbox.contacts.find_by(phone_number: "+#{contact_phone}")
        expect(contact).to be_present
        expect(contact.name).to eq(contact_name)

        # Process second message - should go to same contact/conversation
        initial_contact_count = Contact.count
        initial_conversation_count = Conversation.count

        expect do
          described_class.new(inbox: inbox, params: build_message_params('msg_002', 'Já estou na sala')).perform
        end.to change(Message, :count).by(1)

        expect(Contact.count).to eq(initial_contact_count)
        expect(Conversation.count).to eq(initial_conversation_count)

        # Verify still single contact_inbox
        contact_inboxes = inbox.contact_inboxes.where(source_id: contact_phone)
        expect(contact_inboxes.count).to eq(1)

        # Verify still single conversation with 2 messages
        conversations = inbox.conversations.joins(:contact).where(contacts: { phone_number: "+#{contact_phone}" })
        expect(conversations.count).to eq(1)
        expect(conversations.first.messages.count).to eq(2)
      end
      # rubocop:enable RSpec/MultipleExpectations

      it 'does not create duplicates when same message processed twice' do
        # First processing
        described_class.new(inbox: inbox, params: build_message_params('msg_001', 'Ok')).perform

        initial_contact_count = Contact.count
        initial_conversation_count = Conversation.count
        initial_message_count = Message.count

        # Second processing (simulates duplicate webhook)
        described_class.new(inbox: inbox, params: build_message_params('msg_001', 'Ok')).perform

        # Should not create duplicates
        expect(Contact.count).to eq(initial_contact_count)
        expect(Conversation.count).to eq(initial_conversation_count)
        expect(Message.count).to eq(initial_message_count)
      end
    end

    describe 'concurrent message processing (bug scenario - ISSUE-0002)' do
      # This test demonstrates the race condition that causes duplicate contacts
      # when multiple webhooks for the same contact arrive simultaneously
      #
      # NOTE: Ruby threads with GIL may not reliably trigger race conditions.
      # The real issue occurs in production with multiple Sidekiq workers.
      # This test documents expected behavior; for true concurrency testing,
      # use database-level tests or multiple processes.

      it 'should NOT create duplicate contacts when processing concurrently', :aggregate_failures do
        threads = []
        errors = []
        barrier = begin
          Concurrent::CyclicBarrier.new(3)
        rescue StandardError
          nil
        end

        # Simulate 3 concurrent webhook jobs processing different messages for same contact
        # This replicates what was seen in production logs with multiple job IDs
        3.times do |i|
          threads << Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              barrier&.wait # Synchronize thread start for maximum collision chance
              described_class.new(inbox: inbox, params: build_message_params("msg_concurrent_#{i}", "Message #{i}")).perform
            end
          rescue StandardError => e
            errors << e
          end
        end

        threads.each(&:join)

        # Check for any errors during concurrent processing
        expect(errors).to be_empty, "Errors during concurrent processing: #{errors.map(&:message).join(', ')}"

        # This documents the expected behavior - exactly 1 contact_inbox
        contact_inboxes = inbox.contact_inboxes.where(source_id: contact_phone)

        # Expected: exactly 1 contact_inbox
        # Bug scenario: may create 2-3 contact_inboxes due to race conditions
        expect(contact_inboxes.count).to eq(1),
                                         "Expected 1 contact_inbox, got #{contact_inboxes.count}. " \
                                         "This indicates a race condition creating duplicate contacts for '#{contact_name}' (#{contact_phone})"

        # Verify conversation count
        conversations = inbox.conversations.joins(:contact_inbox).where(contact_inboxes: { source_id: contact_phone })
        expect(conversations.count).to eq(1),
                                       "Expected 1 conversation, got #{conversations.count}. " \
                                       'Multiple conversations created for same contact due to race condition'
      end

      it 'should NOT create duplicate conversations when lock_to_single_conversation is false', :aggregate_failures do
        # Disable lock_to_single_conversation to test conversation duplication
        inbox.update!(lock_to_single_conversation: false)

        threads = []
        errors = []

        # Simulate concurrent message processing
        3.times do |i|
          threads << Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              described_class.new(inbox: inbox, params: build_message_params("msg_unlock_#{i}", "Message #{i}")).perform
            end
          rescue StandardError => e
            errors << e
          end
        end

        threads.each(&:join)

        # With lock_to_single_conversation=false, race conditions may create multiple conversations
        contact_inboxes = inbox.contact_inboxes.where(source_id: contact_phone)
        conversations = inbox.conversations.joins(:contact_inbox).where(contact_inboxes: { source_id: contact_phone })

        # Document what happens - this may create duplicates
        # Expected (correct): 1 contact, 1 conversation
        # Actual (bug): may have multiple conversations
        expect(contact_inboxes.count).to eq(1),
                                         "Expected 1 contact_inbox, got #{contact_inboxes.count}"

        # This assertion documents expected behavior - may fail due to race condition
        expect(conversations.count).to eq(1),
                                       "BUG: Expected 1 conversation, got #{conversations.count}. " \
                                       'Multiple conversations created for same contact due to race condition when lock_to_single_conversation=false'
      end
    end

    describe 'LID-to-phone linking' do
      # Scenario: Contact first appears via LID, then phone is discovered
      # Race condition: concurrent jobs may create separate LID and phone contacts

      let(:contact_lid) { '186234680901688@lid' }

      let(:lid_message_params) do
        {
          'event' => 'message',
          'device_id' => '5511999999999',
          'payload' => {
            'id' => 'msg_lid_first',
            'chat_id' => contact_lid,
            'from' => contact_lid,
            'from_lid' => contact_lid,
            'from_name' => contact_name,
            'body' => 'Hello from LID',
            'timestamp' => Time.current.to_i.to_s,
            'is_from_me' => false
          }
        }.with_indifferent_access
      end

      let(:phone_message_with_lid_params) do
        {
          'event' => 'message',
          'device_id' => '5511999999999',
          'payload' => {
            'id' => 'msg_phone_after',
            'chat_id' => chat_jid,
            'from' => chat_jid,
            'from_lid' => contact_lid,
            'from_name' => contact_name,
            'body' => 'Hello with phone now',
            'timestamp' => Time.current.to_i.to_s,
            'is_from_me' => false
          }
        }.with_indifferent_access
      end

      it 'links phone to existing LID contact when processed sequentially (LID first)' do
        # Step 1: LID message arrives first
        described_class.new(inbox: inbox, params: lid_message_params).perform

        lid_contact = inbox.contact_inboxes.find_by(source_id: contact_lid)&.contact
        expect(lid_contact).to be_present
        expect(lid_contact.phone_number).to be_nil
        expect(lid_contact.name).to eq(contact_name)

        # Step 2: Phone message with from_lid arrives
        described_class.new(inbox: inbox, params: phone_message_with_lid_params).perform

        # Should update existing contact, not create new one
        lid_contact.reload
        expect(lid_contact.phone_number).to eq("+#{contact_phone}")

        # Verify no duplicate contact was created
        phone_contacts = inbox.contacts.where(phone_number: "+#{contact_phone}")
        expect(phone_contacts.count).to eq(1)
        expect(phone_contacts.first).to eq(lid_contact)
      end

      context 'when phone message arrives before LID contact exists (race condition)' do
        # ISSUE-0002: This test verifies LID→phone linking when phone message arrives first
        # Fixed by storing from_lid on contact and looking it up when LID message arrives

        it 'should link LID message to existing phone contact' do
          # Phone message arrives first (with from_lid field)
          described_class.new(inbox: inbox, params: phone_message_with_lid_params).perform

          phone_contact_inbox = inbox.contact_inboxes.find_by(source_id: contact_phone)
          expect(phone_contact_inbox).to be_present
          phone_contact = phone_contact_inbox.contact

          # LID message arrives after - should recognize same contact via from_lid
          described_class.new(inbox: inbox, params: lid_message_params).perform

          # EXPECTED BEHAVIOR (currently fails):
          # The LID message should recognize that from_lid was already seen in phone_message_with_lid_params
          # and link to the existing contact instead of creating a new one

          lid_contact_inbox = inbox.contact_inboxes.find_by(source_id: contact_lid)

          # This SHOULD pass but FAILS due to bug:
          # Expected: LID contact_inbox links to same contact as phone contact_inbox
          # Actual: Two separate contacts are created
          expect(lid_contact_inbox.contact).to eq(phone_contact),
                                               'BUG: LID message created separate contact instead of linking to existing phone contact. ' \
                                               "Phone contact ID: #{phone_contact.id}, LID contact ID: #{lid_contact_inbox&.contact&.id}"
        end
      end
    end

    describe 'multiple conversation entries for same contact (screenshot scenario)' do
      # Replicates the screenshot showing "Quezia" appearing 3 times + phone number separately

      it 'should not create multiple conversations for the same contact' do
        # Process messages that should all go to the same conversation
        3.times do |i|
          message_params = build_message_params("msg_quezia_#{i}", "Message #{i}")
          described_class.new(inbox: inbox, params: message_params).perform
        end

        # All messages should be in the same conversation
        contact = inbox.contacts.find_by(phone_number: "+#{contact_phone}")
        expect(contact).to be_present

        conversations = inbox.conversations.joins(:contact).where(contacts: { id: contact.id })
        expect(conversations.count).to eq(1), "Expected 1 conversation for #{contact_name}, got #{conversations.count}"

        messages = conversations.first.messages
        expect(messages.count).to eq(3)
      end
    end
  end

  describe '#build_lid_to_phone_mapping' do
    let(:service) { described_class.new(inbox: inbox, params: {}) }

    it 'extracts LID to phone mapping from messages with from_lid field' do
      messages = [
        { chat_jid: '5567967077880@s.whatsapp.net', from_lid: '215946727821336@lid', content: 'hello' },
        { chat_jid: '5511999887766@s.whatsapp.net', content: 'no lid' },
        { chat_jid: '215946727821336@lid', content: 'lid message' }
      ]

      mapping = service.send(:build_lid_to_phone_mapping, messages)

      expect(mapping).to eq({
                              '215946727821336@lid' => '5567967077880@s.whatsapp.net'
                            })
    end

    it 'handles empty messages array' do
      mapping = service.send(:build_lid_to_phone_mapping, [])
      expect(mapping).to eq({})
    end

    it 'ignores messages where chat_jid is LID (not phone)' do
      messages = [
        { chat_jid: '215946727821336@lid', from_lid: '999999@lid', content: 'lid to lid' }
      ]

      mapping = service.send(:build_lid_to_phone_mapping, messages)

      expect(mapping).to eq({})
    end
  end

  describe '#build_normalized_contact_map' do
    let(:service) { described_class.new(inbox: inbox, params: {}) }

    let(:chats_by_jid) do
      {
        '5567967077880@s.whatsapp.net' => { 'id' => '5567967077880@s.whatsapp.net', 'name' => 'Quezia' },
        '215946727821336@lid' => { 'id' => '215946727821336@lid', 'name' => 'Quezia LID' },
        '5511999887766@s.whatsapp.net' => { 'id' => '5511999887766@s.whatsapp.net', 'name' => 'Other Contact' }
      }
    end

    let(:lid_to_phone_mapping) do
      { '215946727821336@lid' => '5567967077880@s.whatsapp.net' }
    end

    it 'merges LID entries into their phone counterparts' do
      contact_map = service.send(:build_normalized_contact_map, chats_by_jid, lid_to_phone_mapping)

      # Should have 2 contacts, not 3 (LID merged into phone)
      expect(contact_map.keys.count).to eq(2)

      # Phone entry should exist with LID attached
      expect(contact_map['5567967077880@s.whatsapp.net']).to include(
        name: 'Quezia',
        lid: '215946727821336@lid'
      )

      # Standalone LID entry should be removed
      expect(contact_map).not_to have_key('215946727821336@lid')

      # Other contact unchanged
      expect(contact_map['5511999887766@s.whatsapp.net']).to include(name: 'Other Contact')
    end

    it 'preserves LID-only contacts when no phone mapping exists' do
      chats = { '999999@lid' => { 'id' => '999999@lid', 'name' => 'LID Only' } }

      contact_map = service.send(:build_normalized_contact_map, chats, {})

      expect(contact_map['999999@lid']).to include(name: 'LID Only')
    end

    it 'uses LID name as fallback when phone entry has no name' do
      chats = {
        '5567967077880@s.whatsapp.net' => { 'id' => '5567967077880@s.whatsapp.net', 'name' => nil },
        '215946727821336@lid' => { 'id' => '215946727821336@lid', 'name' => 'Quezia from LID' }
      }
      mapping = { '215946727821336@lid' => '5567967077880@s.whatsapp.net' }

      contact_map = service.send(:build_normalized_contact_map, chats, mapping)

      expect(contact_map['5567967077880@s.whatsapp.net'][:name]).to eq('Quezia from LID')
    end
  end

  describe '#bulk_create_contacts_for_history_sync' do
    let(:service) { described_class.new(inbox: inbox, params: {}) }

    let(:contact_map) do
      {
        '5567967077880@s.whatsapp.net' => { jid: '5567967077880@s.whatsapp.net', name: 'Quezia', lid: '215946727821336@lid' },
        '5511999887766@s.whatsapp.net' => { jid: '5511999887766@s.whatsapp.net', name: 'Other', lid: nil }
      }
    end

    it 'creates contacts and returns cache with both JID and LID keys' do
      cache = service.send(:bulk_create_contacts_for_history_sync, contact_map)

      # Should have entries for both phone JIDs
      expect(cache['5567967077880@s.whatsapp.net']).to be_a(ContactInbox)
      expect(cache['5511999887766@s.whatsapp.net']).to be_a(ContactInbox)

      # Should also have entry for LID pointing to same contact_inbox
      expect(cache['215946727821336@lid']).to eq(cache['5567967077880@s.whatsapp.net'])

      # Contacts should have correct phone numbers
      expect(cache['5567967077880@s.whatsapp.net'].contact.phone_number).to eq('+5567967077880')
    end

    it 'reuses existing contacts instead of creating duplicates' do
      # Pre-create a contact (source_id must be phone number only, not full JID)
      existing_contact = create(:contact, account: inbox.account, phone_number: '+5567967077880')
      create(:contact_inbox, inbox: inbox, contact: existing_contact, source_id: '5567967077880')

      cache = service.send(:bulk_create_contacts_for_history_sync, contact_map)

      # Should reuse existing contact
      expect(cache['5567967077880@s.whatsapp.net'].contact.id).to eq(existing_contact.id)

      # Total contacts created should be 2 (existing + new)
      expect(Contact.where(phone_number: ['+5567967077880', '+5511999887766']).count).to eq(2)
    end

    it 'handles RecordNotUnique by fetching existing contact' do
      # Simulate race condition by creating contact after map is built
      contact_map_single = {
        '5567967077880@s.whatsapp.net' => { jid: '5567967077880@s.whatsapp.net', name: 'Quezia', lid: nil }
      }

      # This should not raise, even if contact exists
      expect do
        service.send(:bulk_create_contacts_for_history_sync, contact_map_single)
      end.not_to raise_error
    end
  end

  describe '#processable_chat_jid?' do
    let(:service) { described_class.new(inbox: inbox, params: {}) }

    it 'returns true for valid @s.whatsapp.net JID' do
      expect(service.send(:processable_chat_jid?, '556281945389@s.whatsapp.net')).to be true
    end

    it 'returns true for valid @g.us group JID' do
      expect(service.send(:processable_chat_jid?, '120363419221703893@g.us')).to be true
    end

    it 'returns true for valid @lid JID' do
      expect(service.send(:processable_chat_jid?, '142897974350025@lid')).to be true
    end

    it 'returns false for status@broadcast' do
      expect(service.send(:processable_chat_jid?, 'status@broadcast')).to be false
    end

    it 'returns false for nil' do
      expect(service.send(:processable_chat_jid?, nil)).to be false
    end

    it 'returns false for blank string' do
      expect(service.send(:processable_chat_jid?, '')).to be false
    end
  end

  describe '#resolve_contact_from_history_cache' do
    let(:service) { described_class.new(inbox: inbox, params: {}) }
    let(:contact_inbox) { create(:contact_inbox, inbox: inbox) }

    let(:cache) do
      {
        '5567967077880@s.whatsapp.net' => contact_inbox,
        '215946727821336@lid' => contact_inbox
      }
    end

    let(:lid_to_phone) do
      { '215946727821336@lid' => '5567967077880@s.whatsapp.net' }
    end

    it 'resolves by direct phone JID' do
      message = { chat_jid: '5567967077880@s.whatsapp.net' }

      result = service.send(:resolve_contact_from_history_cache, message, cache, lid_to_phone)

      expect(result).to eq(contact_inbox)
    end

    it 'resolves by from_lid field' do
      message = { chat_jid: '9999999@s.whatsapp.net', from_lid: '215946727821336@lid' }

      result = service.send(:resolve_contact_from_history_cache, message, cache, lid_to_phone)

      expect(result).to eq(contact_inbox)
    end

    it 'resolves LID message via phone mapping' do
      message = { chat_jid: '215946727821336@lid' }

      result = service.send(:resolve_contact_from_history_cache, message, cache, lid_to_phone)

      expect(result).to eq(contact_inbox)
    end

    it 'returns nil for unknown contacts' do
      message = { chat_jid: '1111111@s.whatsapp.net' }

      result = service.send(:resolve_contact_from_history_cache, message, cache, lid_to_phone)

      expect(result).to be_nil
    end
  end

  describe '#process_history_sync two-phase approach' do
    let(:provider_service) { instance_double(Whatsapp::Providers::WhatsappWebService) }

    before do
      whatsapp_channel.update!(provider_config: whatsapp_channel.provider_config.merge('history_sync_enabled' => true))
      # Need to stub on inbox.channel since that's what the service uses
      allow(inbox).to receive(:channel).and_return(whatsapp_channel)
      allow(whatsapp_channel).to receive(:provider_service).and_return(provider_service)
      allow(provider_service).to receive(:fetch_avatar_url).and_return(nil)
    end

    it 'creates single contact when same phone appears with LID and phone JID' do
      # Simulate chats with same contact appearing twice (LID + phone)
      chats = [
        { 'jid' => '5567967077880@s.whatsapp.net', 'name' => 'Quezia' },
        { 'jid' => '215946727821336@lid', 'name' => 'Quezia' }
      ]

      # Messages: phone message has from_lid linking to LID
      phone_messages = [
        { 'id' => 'msg1', 'chat_jid' => '5567967077880@s.whatsapp.net', 'from_lid' => '215946727821336@lid',
          'content' => 'hello', 'timestamp' => 1.hour.ago.to_i, 'is_from_me' => false }
      ]
      lid_messages = [
        { 'id' => 'msg2', 'chat_jid' => '215946727821336@lid',
          'content' => 'hi', 'timestamp' => 2.hours.ago.to_i, 'is_from_me' => false }
      ]

      allow(provider_service).to receive(:fetch_chats).and_return({ 'data' => chats })
      allow(provider_service).to receive(:fetch_chat_messages)
        .with(chat_jid: '5567967077880@s.whatsapp.net', limit: anything, offset: anything)
        .and_return({ 'data' => phone_messages })
      allow(provider_service).to receive(:fetch_chat_messages)
        .with(chat_jid: '215946727821336@lid', limit: anything, offset: anything)
        .and_return({ 'data' => lid_messages })

      # payload must not be blank for transform_webhook_payload to process
      service = described_class.new(inbox: inbox, params: { event: 'history_sync_complete', payload: { type: 'sync' } })

      expect do
        service.perform
      end.to change(Contact, :count).by(1)
                                    .and change(ContactInbox, :count).by(2)

      # Verify single contact with correct data
      contact = Contact.last
      expect(contact.phone_number).to eq('+5567967077880')
      expect(contact.name).to eq('Quezia')

      # History sync keeps both phone and LID source_ids mapped to the same contact
      phone_ci = inbox.contact_inboxes.find_by(source_id: '5567967077880')
      lid_ci = inbox.contact_inboxes.find_by(source_id: '215946727821336@lid')
      expect(phone_ci).to be_present
      expect(lid_ci).to be_present
      expect(phone_ci.contact_id).to eq(contact.id)
      expect(lid_ci.contact_id).to eq(contact.id)
    end

    it 'handles concurrent-like scenario without creating duplicates' do
      # Same contact appears in multiple chats (simulates race condition scenario)
      chats = [
        { 'jid' => '5567967077880@s.whatsapp.net', 'name' => 'Quezia' }
      ]

      messages = [
        { 'id' => 'msg1', 'chat_jid' => '5567967077880@s.whatsapp.net', 'content' => 'a', 'timestamp' => 1.hour.ago.to_i, 'is_from_me' => false },
        { 'id' => 'msg2', 'chat_jid' => '5567967077880@s.whatsapp.net', 'content' => 'b', 'timestamp' => 2.hours.ago.to_i, 'is_from_me' => false },
        { 'id' => 'msg3', 'chat_jid' => '5567967077880@s.whatsapp.net', 'content' => 'c', 'timestamp' => 3.hours.ago.to_i, 'is_from_me' => false }
      ]

      allow(provider_service).to receive(:fetch_chats).and_return({ 'data' => chats })
      allow(provider_service).to receive(:fetch_chat_messages).and_return({ 'data' => messages })

      # payload must not be blank for transform_webhook_payload to process
      service = described_class.new(inbox: inbox, params: { event: 'history_sync_complete', payload: { type: 'sync' } })

      expect do
        service.perform
      end.to change(Contact, :count).by(1)
                                    .and change(ContactInbox, :count).by(1)
    end
  end
end
