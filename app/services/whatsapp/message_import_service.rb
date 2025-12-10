# Service to import historical messages from WhatsApp Web API
# Used for syncing message history when a WhatsApp number connects
# rubocop:disable Metrics/ClassLength
class Whatsapp::MessageImportService
  BATCH_SIZE = 50
  MAX_CHATS = 100
  MAX_MESSAGES_PER_CHAT = 1000

  attr_reader :inbox, :channel, :stats

  def initialize(inbox:)
    @inbox = inbox
    @channel = inbox.channel
    @gateway_service = Whatsapp::Providers::WhatsappWebService.new(whatsapp_channel: @channel)
    @stats = { chats_processed: 0, messages_imported: 0, messages_skipped: 0, errors: [] }
    @company_contact = nil
    @sender_contacts_cache = {}
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
                           build_group_contact_attributes(jid, chat)
                         else
                           build_contact_attributes(jid, chat)
                         end

    # For individuals, search with both formats to find existing contact_inbox
    # (digits only from outgoing, full identifier from older imports)
    contact_inbox = if is_group
                      find_or_create_group_contact_inbox(jid, contact_attributes)
                    else
                      find_or_create_individual_contact_inbox(jid, contact_attributes)
                    end

    # Update existing contacts if they have a fallback name
    update_contact_name_if_needed(contact_inbox.contact, contact_attributes, is_group)

    # Fetch and update avatar for the contact
    fetch_and_attach_avatar(contact_inbox.contact, jid)

    contact_inbox
  end

  def find_or_create_individual_contact_inbox(jid, contact_attributes)
    raw_phone = jid.to_s.gsub(/\D/, '')

    # Check if contact_inbox already exists with either format
    existing = inbox.contact_inboxes.find_by(source_id: raw_phone)
    existing ||= inbox.contact_inboxes.find_by(source_id: jid)
    return existing if existing

    # Use digits-only format for new contact_inboxes (matches outgoing message format)
    ContactInboxWithContactBuilder.new(
      source_id: raw_phone,
      inbox: inbox,
      contact_attributes: contact_attributes
    ).perform
  end

  def find_or_create_group_contact_inbox(jid, contact_attributes)
    # Groups use full identifier as source_id
    ContactInboxWithContactBuilder.new(
      source_id: jid,
      inbox: inbox,
      contact_attributes: contact_attributes
    ).perform
  end

  def update_contact_name_if_needed(contact, attributes, is_group)
    current_name = contact.name
    new_name = attributes[:name]

    return if new_name.blank?
    return if current_name == new_name

    # Check if current name is a fallback
    is_fallback = if is_group
                    current_name&.match?(/^Group \d+$/)
                  else
                    current_name&.match?(/^\+?\d+$/)
                  end

    return unless is_fallback

    contact.update!(name: new_name)
  end

  def build_contact_attributes(jid, chat)
    chat_name = chat['name'] || chat['pushname']
    is_fallback_name = chat_name.blank? || chat_name.match?(/^\+?\d+$/)

    contact_name = if is_fallback_name
                     fetch_contact_name_from_gateway(jid) || chat_name
                   else
                     chat_name
                   end

    {
      identifier: jid,
      name: contact_name || extract_phone_display(jid),
      phone_number: extract_phone_number(jid)
    }
  end

  def fetch_contact_name_from_gateway(jid)
    contact_info = @gateway_service.contact_info(jid)
    return nil if contact_info.nil?

    contact_info[:name]
  rescue StandardError
    nil
  end

  def build_group_contact_attributes(jid, chat)
    # Check if chat['name'] is a real name or just a fallback
    chat_name = chat['name']
    is_fallback_name = chat_name.blank? || chat_name.match?(/^Group \d+$/)

    # Always fetch from gateway if we have a fallback name
    group_name = if is_fallback_name
                   fetch_group_name_from_gateway(jid)
                 else
                   chat_name
                 end

    {
      identifier: jid,
      name: group_name || extract_group_name(jid)
    }
  end

  def fetch_group_name_from_gateway(jid)
    group_info = @gateway_service.contact_info(jid)
    return nil if group_info.nil?

    group_info[:name]
  rescue StandardError
    nil
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
        import_message(message_data, conversation, contact, chat_jid: chat_jid, is_group: is_group)
      end

      offset += BATCH_SIZE

      # Safety limit to prevent infinite loops
      break if offset >= MAX_MESSAGES_PER_CHAT
    end

    # Update conversation timestamps to match imported messages
    update_conversation_timestamps(conversation)
  end

  def update_conversation_timestamps(conversation)
    messages = conversation.messages.order(:created_at)
    first_message = messages.first
    last_message = messages.last

    return if first_message.blank?

    # rubocop:disable Rails/SkipsModelValidations
    conversation.update_columns(
      created_at: first_message.created_at,
      last_activity_at: last_message&.created_at || first_message.created_at
    )
    # rubocop:enable Rails/SkipsModelValidations
  end

  def extract_messages(response)
    return [] unless response['code'] == 'SUCCESS'

    response.dig('results', 'data') || response['results'] || []
  end

  def import_message(message_data, conversation, contact, chat_jid: nil, is_group: false)
    source_id = message_data['id']
    return if source_id.blank?

    # Check if message already exists
    existing = Message.find_by(source_id: source_id, inbox: inbox)
    if existing
      # Retry media attachment for existing messages that should have attachments but don't
      if media?(message_data) && existing.attachments.empty?
        Rails.logger.info { "[HISTORY_SYNC] Retrying media for existing message #{source_id}" }
        attach_media(existing, message_data, chat_jid: chat_jid)
      end
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
    attach_media(message, message_data, chat_jid: chat_jid) if media?(message_data)

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
    content = message_data['content'] ||
              message_data['text'] ||
              message_data.dig('message', 'text') ||
              message_data.dig('message', 'conversation') ||
              message_data['caption']

    # Don't use placeholder text like "[Image #1]" for media messages
    return message_data['caption'] || default_content_for_type(message_data) if content.present? && content.match?(/^\[.+#\d+\]$/)

    content || default_content_for_type(message_data)
  end

  def default_content_for_type(message_data)
    media_type = message_data['media_type'] || message_data['type']
    return nil if media_type.blank?

    case media_type.to_s.downcase
    when 'image' then '[Image - media unavailable in history import]'
    when 'video' then '[Video - media unavailable in history import]'
    when 'audio', 'voice' then '[Audio - media unavailable in history import]'
    when 'sticker' then '[Sticker - media unavailable in history import]'
    when 'document' then message_data['filename'] || '[Document - media unavailable in history import]'
    when 'location' then 'Location shared'
    when 'contact', 'contacts' then 'Contact shared'
    end
  end

  def media?(message_data)
    media_type = message_data['media_type'] || message_data['type']
    return false if media_type.blank?

    %w[image video audio voice document sticker].include?(media_type.to_s.downcase)
  end

  def attach_media(message, message_data, chat_jid: nil)
    # Try to get local gateway path first (statics/media/...)
    media_url = message_data['media_path']

    # If no media_path, try to trigger on-demand download from gateway
    media_url = trigger_gateway_media_download(message_data['id'], chat_jid) if media_url.blank? && message_data['id'].present? && chat_jid.present?

    # Fall back to url field (might be WhatsApp CDN URL which won't work)
    media_url ||= message_data['url'] || message_data['media_url']

    if media_url.blank?
      Rails.logger.debug { "[HISTORY_SYNC] No media URL found in message #{message_data['id']}" }
      return
    end

    # WhatsApp CDN URLs (mmg.whatsapp.net) are encrypted and token-protected - not accessible
    # Also skip .enc files which are encrypted and can't be displayed
    if media_url.include?('mmg.whatsapp.net') || media_url.include?('whatsapp.net') || media_url.end_with?('.enc')
      Rails.logger.debug { "[HISTORY_SYNC] Skipping inaccessible/encrypted media for message #{message_data['id']}" }
      return
    end

    Rails.logger.info { "[HISTORY_SYNC] Downloading media from: #{media_url}" }

    media_type = message_data['media_type'] || message_data['type'] || 'file'
    filename = message_data['filename'] || generate_filename(media_type)

    # Download the media file
    file = download_media(media_url)
    return unless file

    # Infer content type from media_type/filename since CDN returns octet-stream
    content_type = infer_content_type(media_type, filename, file.content_type)

    message.attachments.new(
      account_id: message.account_id,
      file_type: file_content_type(media_type),
      file: {
        io: file,
        filename: filename,
        content_type: content_type
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

  # Trigger gateway to download and cache media for historical messages
  # Returns the local media_path if successful
  def trigger_gateway_media_download(message_id, chat_jid)
    Rails.logger.info { "[HISTORY_SYNC] Triggering media download for message #{message_id}" }

    result = @gateway_service.trigger_media_download(message_id: message_id, chat_jid: chat_jid)

    if result.nil?
      Rails.logger.warn { "[HISTORY_SYNC] Gateway download returned nil for #{message_id}" }
      return nil
    end

    Rails.logger.debug { "[HISTORY_SYNC] Gateway download response: #{result.inspect}" }

    # The gateway returns file_path in results after downloading
    media_path = result.dig('results', 'file_path') ||
                 result['media_path'] ||
                 result.dig('results', 'media_path') ||
                 result.dig('results', 'path')

    if media_path.present?
      # Strip phone number prefix from file_path if present
      # Gateway returns: /5521995539939/statics/media/...
      # We need: /statics/media/... (media_url adds the phone prefix)
      media_path = normalize_media_path(media_path)
      Rails.logger.info { "[HISTORY_SYNC] Gateway cached media at: #{media_path}" }
    else
      Rails.logger.warn { "[HISTORY_SYNC] Gateway response has no media_path. Keys: #{result.keys.inspect}" }
    end

    media_path
  end

  # Normalize media path by stripping phone number prefix if present
  # Gateway download endpoint returns: /5521995539939/statics/media/...
  # Messages API returns: /statics/media/...
  # media_url() adds the phone prefix, so we need the short form
  def normalize_media_path(path)
    return path if path.blank?

    # Validate path to prevent path traversal attacks
    raise ArgumentError, 'Invalid path: contains ..' if path.include?('..')
    raise ArgumentError, 'Invalid path: must start with /statics/ or /PHONE/statics/' unless path.match?(%r{^(/\d+)?/statics/})

    # Match pattern: /PHONE_NUMBER/statics/... or /PHONE_NUMBER/...
    # Strip the phone number prefix (digits only) from the start
    normalized = path.sub(%r{^/\d+/}, '/')
    Rails.logger.debug { "[HISTORY_SYNC] Normalized media path: #{path} -> #{normalized}" }
    normalized
  end

  def infer_content_type(media_type, filename, fallback)
    # Try to infer from filename extension first
    ext = File.extname(filename).downcase.delete('.')
    mime_from_ext = Rack::Mime.mime_type(".#{ext}", nil) if ext.present?
    return mime_from_ext if mime_from_ext.present?

    # Infer from media_type
    case media_type.to_s.downcase
    when 'image' then 'image/jpeg'
    when 'video' then 'video/mp4'
    when 'audio', 'voice' then 'audio/ogg'
    when 'sticker' then 'image/webp'
    else fallback || 'application/octet-stream'
    end
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

    # Check cache first to avoid N+1 queries
    return @sender_contacts_cache[clean_jid] if @sender_contacts_cache.key?(clean_jid)

    # Check if contact already exists
    existing_contact_inbox = inbox.contact_inboxes.find_by(source_id: clean_jid)
    if existing_contact_inbox
      enqueue_avatar_fetch(existing_contact_inbox.contact, clean_jid)
      @sender_contacts_cache[clean_jid] = existing_contact_inbox.contact
      return existing_contact_inbox.contact
    end

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

    enqueue_avatar_fetch(contact_inbox.contact, clean_jid)
    @sender_contacts_cache[clean_jid] = contact_inbox.contact
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

  def fetch_and_attach_avatar(contact, identifier)
    return if contact.blank? || identifier.blank?
    return if contact.avatar.attached? && contact.updated_at > 24.hours.ago

    # Use same job for both contacts and groups - gateway handles both
    Whatsapp::FetchContactAvatarJob.perform_later(contact.id, inbox.id, identifier)
  rescue StandardError
    nil
  end

  def enqueue_avatar_fetch(contact, identifier)
    fetch_and_attach_avatar(contact, identifier)
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
# rubocop:enable Metrics/ClassLength
