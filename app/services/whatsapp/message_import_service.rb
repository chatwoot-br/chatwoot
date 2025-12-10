# Service to import historical messages from WhatsApp Web API
# Used for syncing message history when a WhatsApp number connects
# rubocop:disable Metrics
class Whatsapp::MessageImportService
  BATCH_SIZE = 50
  MAX_CHATS = 100

  attr_reader :inbox, :channel, :stats

  def initialize(inbox:)
    @inbox = inbox
    @channel = inbox.channel
    @gateway_service = Whatsapp::Providers::WhatsappWebService.new(whatsapp_channel: @channel)
    @stats = { chats_processed: 0, messages_imported: 0, messages_skipped: 0, errors: [] }
    @company_contact = nil
  end

  def perform
    Rails.logger.info "[HISTORY_SYNC] Starting message import for inbox #{inbox.id} (#{inbox.name})"

    setup_company_contact
    import_all_chats
    log_completion

    @stats
  rescue StandardError => e
    Rails.logger.error "[HISTORY_SYNC] Import failed for inbox #{inbox.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    @stats[:errors] << e.message
    @stats
  end

  private

  def import_all_chats
    offset = 0

    loop do
      response = @gateway_service.fetch_chats(limit: BATCH_SIZE, offset: offset)
      chats = extract_chats(response)

      break if chats.empty?

      chats.each do |chat|
        import_chat(chat)
        @stats[:chats_processed] += 1
      end

      offset += BATCH_SIZE
      break if offset >= MAX_CHATS
    end
  end

  def extract_chats(response)
    return [] unless response['code'] == 'SUCCESS'

    response.dig('results', 'data') || response['results'] || []
  end

  def import_chat(chat)
    chat_jid = chat['jid'] || chat['id']
    return if chat_jid.blank?

    Rails.logger.debug { "[HISTORY_SYNC] Processing chat: #{chat_jid}" }

    # Create or find contact and contact_inbox
    contact_inbox = find_or_create_contact_inbox(chat)
    return unless contact_inbox

    # Create or find conversation
    conversation = find_or_create_conversation(contact_inbox)
    return unless conversation

    # Import messages for this chat
    import_messages_for_chat(chat_jid, conversation, contact_inbox.contact)
  rescue StandardError => e
    Rails.logger.error "[HISTORY_SYNC] Error processing chat #{chat['jid']}: #{e.message}"
    @stats[:errors] << "Chat #{chat['jid']}: #{e.message}"
  end

  def find_or_create_contact_inbox(chat)
    jid = chat['jid'] || chat['id']
    is_group = jid.include?('@g.us')

    contact_attributes = if is_group
                           {
                             identifier: jid,
                             name: chat['name'] || extract_group_name(jid)
                           }
                         else
                           {
                             identifier: jid,
                             name: chat['name'] || chat['pushname'] || extract_phone_display(jid),
                             phone_number: extract_phone_number(jid)
                           }
                         end

    ContactInboxWithContactBuilder.new(
      source_id: jid,
      inbox: inbox,
      contact_attributes: contact_attributes
    ).perform
  end

  def find_or_create_conversation(contact_inbox)
    # Use lock_to_single_conversation setting to determine conversation handling
    conversation = if inbox.lock_to_single_conversation
                     contact_inbox.conversations.last
                   else
                     contact_inbox.conversations.where.not(status: :resolved).last
                   end

    return conversation if conversation

    Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: contact_inbox.contact_id,
      contact_inbox_id: contact_inbox.id
    )
  end

  def import_messages_for_chat(chat_jid, conversation, contact)
    offset = 0
    is_group = chat_jid.include?('@g.us')

    loop do
      response = @gateway_service.fetch_messages(chat_jid: chat_jid, limit: BATCH_SIZE, offset: offset)
      messages = extract_messages(response)

      break if messages.empty?

      # Sort messages by timestamp to import in chronological order
      sorted_messages = messages.sort_by { |m| m['timestamp'] || 0 }

      sorted_messages.each do |message_data|
        import_message(message_data, conversation, contact, is_group: is_group)
      end

      offset += BATCH_SIZE

      # Safety limit to prevent infinite loops
      break if offset >= 1000
    end
  end

  def extract_messages(response)
    return [] unless response['code'] == 'SUCCESS'

    response.dig('results', 'data') || response['results'] || []
  end

  def import_message(message_data, conversation, contact, is_group: false)
    source_id = message_data['id']
    return if source_id.blank?

    # Skip if message already exists (duplicate prevention)
    existing = Message.find_by(source_id: source_id, inbox: inbox)
    if existing
      @stats[:messages_skipped] += 1
      return
    end

    # Determine message type and sender
    is_from_me = message_data['is_from_me'] || message_data['fromMe']
    message_type = is_from_me ? :outgoing : :incoming

    # For group messages, get the actual sender from sender_jid
    sender = determine_message_sender(message_data, contact, is_from_me: is_from_me, is_group: is_group)

    # Parse timestamp
    timestamp = parse_timestamp(message_data['timestamp'])

    # Build the message
    message = conversation.messages.build(
      content: extract_content(message_data),
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: message_type,
      sender: sender,
      source_id: source_id,
      content_attributes: {
        external_created_at: timestamp&.iso8601
      }
    )

    # Handle media attachments
    attach_media(message, message_data) if media?(message_data)

    message.save!

    # Preserve original timestamp after save (bypasses callbacks)
    # rubocop:disable Rails/SkipsModelValidations
    message.update_columns(created_at: timestamp) if timestamp.present?
    # rubocop:enable Rails/SkipsModelValidations
    @stats[:messages_imported] += 1
  rescue StandardError => e
    Rails.logger.error "[HISTORY_SYNC] Error importing message #{source_id}: #{e.message}"
    @stats[:errors] << "Message #{source_id}: #{e.message}"
  end

  def extract_content(message_data)
    message_data['content'] ||
      message_data['text'] ||
      message_data.dig('message', 'text') ||
      message_data.dig('message', 'conversation') ||
      message_data['caption'] ||
      default_content_for_type(message_data)
  end

  def default_content_for_type(message_data)
    media_type = message_data['media_type'] || message_data['type']
    return nil if media_type.blank?

    case media_type.to_s.downcase
    when 'document' then message_data['filename']
    when 'location' then 'Location shared'
    when 'contact', 'contacts' then 'Contact shared'
    end
  end

  def media?(message_data)
    media_type = message_data['media_type'] || message_data['type']
    return false if media_type.blank?

    %w[image video audio voice document sticker].include?(media_type.to_s.downcase)
  end

  def attach_media(message, message_data)
    media_url = message_data['url'] || message_data['media_url']
    return if media_url.blank?

    media_type = message_data['media_type'] || message_data['type'] || 'file'
    filename = message_data['filename'] || generate_filename(media_type)

    # Download the media file
    file = download_media(media_url)
    return unless file

    message.attachments.new(
      account_id: message.account_id,
      file_type: file_content_type(media_type),
      file: {
        io: file,
        filename: filename,
        content_type: file.content_type
      }
    )
  rescue StandardError => e
    Rails.logger.warn "[HISTORY_SYNC] Could not attach media: #{e.message}"
  end

  def download_media(url)
    # Build full URL if relative path
    full_url = url.start_with?('http') ? url : @channel.media_url(url)
    Down.download(full_url, headers: @channel.api_headers)
  rescue StandardError => e
    Rails.logger.warn "[HISTORY_SYNC] Media download failed for #{url}: #{e.message}"
    nil
  end

  def file_content_type(media_type)
    case media_type.to_s.downcase
    when 'image', 'sticker' then :image
    when 'audio', 'voice' then :audio
    when 'video' then :video
    when 'location' then :location
    when 'contact', 'contacts' then :contact
    else :file
    end
  end

  def generate_filename(media_type)
    extension = case media_type.to_s.downcase
                when 'image' then 'jpg'
                when 'video' then 'mp4'
                when 'audio', 'voice' then 'ogg'
                when 'sticker' then 'webp'
                else 'bin'
                end
    "#{SecureRandom.uuid}.#{extension}"
  end

  def parse_timestamp(timestamp)
    return nil if timestamp.blank?

    case timestamp
    when String
      Time.zone.parse(timestamp)
    when Integer, Numeric
      Time.zone.at(timestamp)
    end
  rescue ArgumentError
    nil
  end

  def determine_message_sender(message_data, default_contact, is_from_me:, is_group:)
    # For outgoing messages, always use company contact
    return @company_contact if is_from_me

    # For individual chats, use the chat contact
    return default_contact unless is_group

    # For group messages, find/create sender from sender_jid
    sender_jid = message_data['sender_jid']
    return default_contact if sender_jid.blank?

    find_or_create_sender_contact(sender_jid)
  end

  def find_or_create_sender_contact(sender_jid)
    # Clean the sender_jid (remove device suffix like :73)
    clean_jid = sender_jid.split(':').first
    clean_jid = "#{clean_jid}@s.whatsapp.net" unless clean_jid.include?('@')

    # Check if contact already exists
    existing_contact_inbox = inbox.contact_inboxes.find_by(source_id: clean_jid)
    return existing_contact_inbox.contact if existing_contact_inbox

    # Create sender contact
    contact_inbox = ContactInboxWithContactBuilder.new(
      source_id: clean_jid,
      inbox: inbox,
      contact_attributes: {
        identifier: clean_jid,
        name: extract_phone_display(clean_jid),
        phone_number: extract_phone_number(clean_jid)
      }
    ).perform

    contact_inbox.contact
  end

  def extract_phone_number(jid)
    return nil if jid.blank?

    phone = jid.split('@').first.split(':').first
    "+#{phone}" if phone.present?
  end

  def extract_phone_display(jid)
    phone = extract_phone_number(jid)
    phone || jid.split('@').first
  end

  def extract_group_name(jid)
    group_number = jid.split('@').first
    "Group #{group_number}"
  end

  def setup_company_contact
    phone_number = channel.phone_number
    return if phone_number.blank?

    # Build JID for the company phone
    clean_phone = phone_number.gsub(/\D/, '')
    source_id = "#{clean_phone}@s.whatsapp.net"

    # Check if company contact already exists
    existing_contact_inbox = inbox.contact_inboxes.find_by(source_id: source_id)
    if existing_contact_inbox
      @company_contact = existing_contact_inbox.contact
      Rails.logger.info "[HISTORY_SYNC] Using existing company contact: #{@company_contact.name}"
      return
    end

    # Create company contact
    contact_inbox = ContactInboxWithContactBuilder.new(
      source_id: source_id,
      inbox: inbox,
      contact_attributes: {
        identifier: source_id,
        name: phone_number,
        phone_number: phone_number
      }
    ).perform

    @company_contact = contact_inbox.contact
    Rails.logger.info "[HISTORY_SYNC] Created company contact: #{@company_contact.name}"
  end

  def log_completion
    Rails.logger.info(
      "[HISTORY_SYNC] Import completed for inbox #{inbox.id}. " \
      "Chats: #{@stats[:chats_processed]}, " \
      "Messages imported: #{@stats[:messages_imported]}, " \
      "Skipped: #{@stats[:messages_skipped]}, " \
      "Errors: #{@stats[:errors].count}"
    )
  end
end
# rubocop:enable Metrics
