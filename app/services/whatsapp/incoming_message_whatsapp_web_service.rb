# Service to handle incoming messages from go-whatsapp-web-multidevice webhook
# Transforms webhook payload to Chatwoot format compatible with IncomingMessageBaseService
# rubocop:disable Metrics/ClassLength
class Whatsapp::IncomingMessageWhatsappWebService < Whatsapp::IncomingMessageBaseService
  def perform
    processed_params
    return if ignore_group_messages? && group_message?
    return if empty_message?

    if processed_params.try(:[], :reaction).present?
      process_reaction
    else
      super
    end
  end

  # Skip messages with no content and no attachments (but allow reactions and status updates)
  def empty_message?
    return false if processed_params.blank? || processed_params[:reaction].present? || processed_params[:statuses].present?

    first_message = processed_params.dig(:messages, 0)
    return false if first_message.blank? || message_has_media?(first_message)

    message_content(first_message).blank?
  end

  def message_has_media?(message)
    %i[image video audio document sticker location contacts].any? { |key| message[key].present? }
  end

  private

  def processed_params
    @processed_params ||= transform_webhook_payload
  end

  # Ensure params are accessible with symbol keys (webhook sends string keys)
  def webhook_params
    @webhook_params ||= params.with_indifferent_access
  end

  def transform_webhook_payload
    return {} if webhook_params[:payload].blank?

    payload = webhook_params[:payload].with_indifferent_access
    event_type = webhook_params[:event]

    # Handle different event types
    case event_type
    when 'message'
      transform_message_event(payload)
    when 'message.ack'
      transform_status_event(payload)
    when 'message.reaction'
      transform_reaction_event(payload)
    when 'history_sync_complete'
      process_history_sync
      {} # Return empty - messages processed inline
    when 'message.revoked', 'message.edited'
      # Skip these for now - can be implemented later
      {}
    else
      Rails.logger.warn "Unknown WhatsApp Web event type: #{event_type}"
      {}
    end
  end

  def transform_message_event(payload)
    # Skip invalid JIDs (e.g., status@broadcast)
    return {} unless processable_chat_jid?(payload[:chat_id])

    message_id = payload[:id]
    timestamp = parse_timestamp(payload[:timestamp])

    # For LID-based chats, use LID as identifier (phone not known yet)
    # For regular chats, use phone-based JID
    if lid_based_chat_payload?(payload)
      # LID-only: use LID as identifier, no phone available
      contact_jid = payload[:chat_id]
      contact_phone = nil # Phone not known yet
    else
      # For is_from_me messages, use chat_id as the contact identifier (the recipient)
      # For incoming messages, use from as the contact identifier (the sender)
      contact_jid = payload[:is_from_me] ? payload[:chat_id] : payload[:from]
      contact_phone = extract_phone_number(contact_jid)
    end

    {
      contacts: [build_contact(payload)],
      messages: [build_message(payload, message_id, contact_phone || extract_phone_number(contact_jid), timestamp)]
    }
  end

  # Helper to check LID in payload context (for transform methods)
  def lid_based_chat_payload?(payload)
    payload[:chat_id].to_s.end_with?('@lid')
  end

  # Transform message.ack event to status update format
  # go-whatsapp sends: { ids: [...], receipt_type: "delivered"|"read"|"read_self"|"played"|"played_self" }
  # Base service expects: { statuses: [{ id: "...", status: "delivered"|"read" }] }
  def transform_status_event(payload)
    message_ids = payload[:ids] || []
    receipt_type = payload[:receipt_type]

    # Map go-whatsapp receipt types to Chatwoot statuses
    # - delivered: message delivered to recipient device
    # - read/read_self: message seen by recipient
    # - played/played_self: media viewed (treat as read)
    status = case receipt_type
             when 'delivered' then 'delivered'
             when 'read', 'read_self', 'played', 'played_self' then 'read'
             else return {} # Unknown receipt type (e.g., 'sent' from linked devices)
             end

    statuses = message_ids.map do |message_id|
      { id: message_id, status: status }
    end

    { statuses: statuses }
  end

  # Transform message.reaction event to reaction update format
  # go-whatsapp sends: { reacted_message_id: "...", reaction: "👍", from: "..." }
  def transform_reaction_event(payload)
    {
      reaction: {
        message_id: payload[:reacted_message_id],
        emoji: payload[:reaction],
        sender: extract_phone_number(payload[:from])
      }
    }
  end

  def process_reaction
    reaction_data = processed_params[:reaction]
    message = inbox.messages.find_by(source_id: reaction_data[:message_id])
    return unless message

    updated_reactions = update_reactions(message.reactions || {}, reaction_data[:emoji], reaction_data[:sender])
    message.update!(reactions: updated_reactions)
  rescue StandardError => e
    Rails.logger.error "[WhatsApp Web] Error processing reaction: #{e.message}"
  end

  def update_reactions(reactions, emoji, sender)
    # Remove any existing reaction from this sender
    remove_sender_from_reactions(reactions, sender)
    # Add new reaction if emoji is present (empty means un-react)
    add_reaction(reactions, emoji, sender) if emoji.present?
    reactions
  end

  def remove_sender_from_reactions(reactions, sender)
    reactions.each_value { |senders| senders.delete(sender) }
    reactions.delete_if { |_, senders| senders.empty? }
  end

  def add_reaction(reactions, emoji, sender)
    reactions[emoji] ||= []
    reactions[emoji] << sender unless reactions[emoji].include?(sender)
  end

  # Override to handle group messages and LID-based chats differently
  def set_contact
    if group_message?
      set_group_contact
    elsif lid_based_chat?
      # Scenario 1: chat_id is @lid (phone not known yet)
      # First check if a phone contact already has this LID stored
      if phone_contact_with_lid_exists?
        set_contact_from_phone_with_lid
      else
        set_lid_contact
      end
    elsif from_lid_matches_existing_contact?
      # Scenario 2: chat_id is @s.whatsapp.net but from_lid matches existing LID contact
      # This is when we finally learn the phone number!
      set_contact_from_lid_match
    else
      super
      sync_contact_avatar if @contact
      store_from_lid_on_contact if payload_from_lid.present?
    end
  end

  def group_message?
    webhook_params.dig(:payload, :chat_id).to_s.end_with?('@g.us')
  end

  # Check if a JID is processable (valid for WhatsApp channel)
  # Returns false for special JIDs like status@broadcast that don't match WHATSAPP_CHANNEL_REGEX
  def processable_chat_jid?(jid)
    return false if jid.blank?

    source_id = extract_source_id_from_jid(jid)
    RegexHelper::WHATSAPP_CHANNEL_REGEX.match?(source_id)
  end

  # LID (Linked ID) detection methods
  # WhatsApp uses LID for contacts where phone number is not yet identified
  def lid_based_chat?
    webhook_params.dig(:payload, :chat_id).to_s.end_with?('@lid')
  end

  def lid_chat_id
    webhook_params.dig(:payload, :chat_id)
  end

  # Check if from_lid matches an existing LID-based contact
  # This allows linking phone-based messages back to existing LID contacts
  def from_lid_matches_existing_contact?
    from_lid = payload_from_lid
    return false if from_lid.blank?
    return false unless from_lid.end_with?('@lid')

    inbox.contact_inboxes.exists?(source_id: from_lid)
  end

  def payload_from_lid
    webhook_params.dig(:payload, :from_lid)
  end

  # Check if a phone-based contact already has this LID stored in additional_attributes
  # This handles the case where phone message with from_lid arrived before LID message
  def phone_contact_with_lid_exists?
    lid_jid = lid_chat_id
    return false if lid_jid.blank?

    inbox.contacts.exists?(["additional_attributes->>'from_lid' = ?", lid_jid])
  end

  # Scenario 3: LID message arrives but phone contact already has this LID stored
  # Link the LID to the existing phone contact instead of creating a new one
  def set_contact_from_phone_with_lid
    lid_jid = lid_chat_id
    @contact = inbox.contacts.find_by("additional_attributes->>'from_lid' = ?", lid_jid)

    # Create a contact_inbox for the LID pointing to the same contact
    @contact_inbox = inbox.contact_inboxes.find_or_create_by!(
      source_id: lid_jid,
      contact: @contact
    )

    # Update contact to mark it as having LID
    attrs = @contact.additional_attributes.merge('is_lid_chat' => true, 'lid' => lid_jid)
    @contact.update(additional_attributes: attrs)

    Rails.logger.info "[WhatsApp Web] Linked LID #{lid_jid} to existing phone contact #{@contact.id} (#{@contact.phone_number})"
  end

  # Store the from_lid on the contact so we can find it when LID message arrives later
  def store_from_lid_on_contact
    return unless @contact
    return if payload_from_lid.blank?

    # Store the LID in additional_attributes for reverse lookup
    attrs = @contact.additional_attributes.merge('from_lid' => payload_from_lid)
    @contact.update(additional_attributes: attrs)

    Rails.logger.info "[WhatsApp Web] Stored from_lid #{payload_from_lid} on contact #{@contact.id}"
  end

  def ignore_group_messages?
    inbox.channel.provider_config['ignore_group_messages'] == true
  end

  def history_sync_enabled?
    inbox.channel.provider_config['history_sync_enabled'] == true
  end

  def group_id
    webhook_params.dig(:payload, :chat_id)
  end

  def set_group_contact
    group_jid = group_id
    group_name = fetch_group_name(group_jid) || "Group #{group_jid.split('@').first}"

    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: group_jid,
      inbox: inbox,
      contact_attributes: {
        name: group_name,
        additional_attributes: { is_group: true }
      }
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact

    # Sync group avatar (uses same endpoint as user avatar)
    sync_group_avatar(group_jid)
  end

  # Scenario 1: Create contact with LID as source_id, no phone
  # Called when chat_id ends with @lid (phone not known yet)
  def set_lid_contact
    lid_jid = lid_chat_id
    payload = webhook_params[:payload]
    contact_name = payload[:is_from_me] ? payload[:chat_name] : payload[:from_name]

    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: lid_jid,
      inbox: inbox,
      contact_attributes: {
        name: contact_name || lid_jid.split('@').first,
        phone_number: nil, # Phone not known yet for LID-only chats
        additional_attributes: { is_lid_chat: true, lid: lid_jid }
      }
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact

    Rails.logger.info "[WhatsApp Web] Created LID contact: source_id=#{lid_jid}, name=#{@contact.name}"
  end

  # Scenario 2: Phone-based message with from_lid matching existing LID contact
  # Now we can update the contact with the phone number!
  def set_contact_from_lid_match
    from_lid = payload_from_lid
    contact_inbox = inbox.contact_inboxes.find_by(source_id: from_lid)

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact

    # Update phone number now that we know it
    update_contact_with_discovered_phone
    sync_contact_avatar if @contact
  end

  # Update contact with discovered phone number from from_lid match
  def update_contact_with_discovered_phone
    payload = webhook_params[:payload]
    # For incoming messages, phone is in 'from'; for outgoing, it's in 'chat_id'
    phone_jid = payload[:is_from_me] ? payload[:chat_id] : payload[:from]
    phone = extract_phone_number(phone_jid)

    return if phone.blank?
    return if @contact.phone_number.present? # Don't overwrite if already set

    formatted_phone = "+#{phone}"
    @contact.update(phone_number: formatted_phone)
    Rails.logger.info "[WhatsApp Web] Discovered phone for LID contact #{@contact.id}: #{formatted_phone} (from_lid: #{payload_from_lid})"
  end

  def sync_group_avatar(group_jid)
    return if avatar_recently_synced?

    avatar_url = inbox.channel.provider_service.fetch_avatar_url(group_jid)
    return if avatar_url.blank?

    Avatar::AvatarFromUrlJob.perform_later(@contact, avatar_url)
  rescue StandardError => e
    Rails.logger.error "[WhatsApp Web] Failed to sync group avatar: #{e.message}"
  end

  def fetch_group_name(group_jid)
    group_info = inbox.channel.provider_service.fetch_group_info(group_jid)
    # go-whatsapp returns 'Name' (capital N) for group name
    group_info&.dig('Name') || group_info&.dig('name')
  rescue StandardError => e
    Rails.logger.error "[WhatsApp Web] Failed to fetch group name: #{e.message}"
    nil
  end

  # Override to skip attachment processing and saving for duplicate messages
  def create_regular_message(message)
    create_message(message)
    return if @message_already_exists

    attach_files
    attach_location if message_type == 'location'
    @message.save!
  end

  # Override to handle outgoing messages and group sender info
  # Also check for duplicate messages by source_id to prevent race conditions
  def create_message(message, source_id: nil)
    source_id = (source_id || message[:id]).to_s
    existing_message = inbox.messages.find_by(source_id: source_id)

    if existing_message
      # If duplicate exists but new message has content and existing doesn't, update it
      new_content = message_content(message)
      existing_message.update!(content: new_content) if new_content.present? && existing_message.content.blank?
      @message = existing_message
      @message_already_exists = true
      return
    end

    @message = @conversation.messages.build(message_attributes(message))
  end

  def message_attributes(message)
    base_attrs = {
      content: message_content(message),
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      source_id: message[:id].to_s,
      in_reply_to_external_id: @in_reply_to_external_id,
      created_at: message_created_at(message)
    }

    # Messages from the connected device are outgoing with device contact as sender
    if message_from_me?
      base_attrs.merge(outgoing_message_attributes)
    else
      base_attrs.merge(incoming_message_attributes)
    end
  end

  # Extract created_at from message timestamp
  # Timestamp is stored as Unix timestamp string (seconds since epoch)
  def message_created_at(message)
    timestamp = message[:timestamp]
    return Time.current if timestamp.blank?

    Time.zone.at(timestamp.to_i)
  rescue ArgumentError
    Time.current
  end

  # Messages from connected device are outgoing (right side, blue bubble)
  # with device contact as sender for proper name/avatar display
  def outgoing_message_attributes
    {
      message_type: :outgoing,
      sender: find_or_create_device_contact
    }
  end

  # Find or create a Contact for the connected WhatsApp device
  def find_or_create_device_contact
    device_phone = extract_phone_number(webhook_params[:device_id])
    sender_name = webhook_params.dig(:payload, :from_name)

    contact = inbox.account.contacts.find_or_initialize_by(
      phone_number: "+#{device_phone}"
    )

    if contact.new_record?
      contact.name = sender_name.presence || device_phone
      contact.save!
    elsif contact.name.blank? && sender_name.present?
      contact.update(name: sender_name)
    end

    # Sync avatar for this device contact
    sync_sender_avatar(contact, device_phone)

    contact
  end

  def incoming_message_attributes
    attrs = {
      message_type: :incoming,
      sender: group_message? ? find_or_create_sender_contact : @contact
    }
    attrs[:additional_attributes] = group_sender_attributes if group_message?
    attrs
  end

  def message_from_me?
    webhook_params.dig(:payload, :is_from_me) == true
  end

  # Find or create a Contact record for the actual message sender in a group
  # This allows proper avatar sync and contact management for group participants
  def find_or_create_sender_contact
    payload = webhook_params[:payload]
    sender_phone = extract_phone_number(payload[:from])
    sender_name = payload[:from_name]

    contact = inbox.account.contacts.find_or_initialize_by(
      phone_number: "+#{sender_phone}"
    )

    if contact.new_record?
      contact.name = sender_name.presence || sender_phone
      contact.save!
    elsif contact.name.blank? && sender_name.present?
      contact.update(name: sender_name)
    end

    # Sync avatar for this sender
    sync_sender_avatar(contact, sender_phone)

    contact
  end

  def sync_sender_avatar(contact, phone_number)
    return if sender_avatar_recently_synced?(contact)

    avatar_url = inbox.channel.provider_service.fetch_avatar_url(phone_number)
    if avatar_url.blank?
      Rails.logger.info "[WhatsApp Web] No avatar URL for sender #{phone_number}"
      return
    end

    Rails.logger.info "[WhatsApp Web] Syncing avatar for contact #{contact.id} from #{avatar_url}"
    # Use perform_now for new contacts to ensure avatar is available immediately
    if contact.avatar.blank?
      Avatar::AvatarFromUrlJob.perform_now(contact, avatar_url)
    else
      Avatar::AvatarFromUrlJob.perform_later(contact, avatar_url)
    end
  rescue StandardError => e
    Rails.logger.error "[WhatsApp Web] Failed to sync sender avatar: #{e.message}"
  end

  def sender_avatar_recently_synced?(contact)
    last_sync = contact.additional_attributes&.dig('last_avatar_sync_at')
    return false if last_sync.blank?

    Time.zone.parse(last_sync) > AVATAR_SYNC_INTERVAL.ago
  rescue ArgumentError
    false
  end

  def group_sender_attributes
    payload = webhook_params[:payload]
    {
      sender_phone: extract_phone_number(payload[:from]),
      sender_name: payload[:from_name]
    }
  end

  def build_contact(payload)
    # For is_from_me messages, use chat_id as the contact (the recipient)
    # For incoming messages, use from as the contact (the sender)
    contact_jid = payload[:is_from_me] ? payload[:chat_id] : payload[:from]
    contact_phone = extract_phone_number(contact_jid)

    # Profile name resolution:
    # - Incoming messages: use from_name (sender's push name)
    # - Outgoing messages: use contact_name (history sync) or chat_name (real-time webhook)
    profile_name = if payload[:is_from_me]
                     # contact_name is set by history sync, chat_name is set by real-time webhook
                     payload[:contact_name] || payload[:chat_name]
                   else
                     payload[:from_name]
                   end

    # Debug: Log contact name resolution
    Rails.logger.info "[WhatsApp] build_contact: is_from_me=#{payload[:is_from_me]}, " \
                      "contact_jid=#{contact_jid}, contact_phone=#{contact_phone}, " \
                      "from_name=#{payload[:from_name].inspect}, contact_name=#{payload[:contact_name].inspect}, " \
                      "chat_name=#{payload[:chat_name].inspect}, profile_name=#{profile_name.inspect}"

    {
      wa_id: contact_phone,
      profile: {
        name: profile_name
      }
    }
  end

  def build_message(payload, message_id, from, timestamp)
    message = {
      id: message_id,
      from: from,
      timestamp: timestamp.to_i.to_s
    }

    add_message_content(message, payload)
    add_reply_context(message, payload)

    message
  end

  def add_message_content(message, payload)
    content = determine_message_content(payload)
    message.merge!(content)
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def determine_message_content(payload)
    return { type: 'text', text: { body: payload[:body] } } if payload[:body].present?
    return { type: 'image', image: build_media_object(payload[:image], payload[:caption]) } if payload[:image].present?
    return { type: 'video', video: build_media_object(payload[:video], payload[:caption]) } if payload[:video].present?
    # video_note is PTV (push-to-talk video) - treat as video
    return { type: 'video', video: build_media_object(payload[:video_note], payload[:caption]) } if payload[:video_note].present?
    return { type: 'audio', audio: build_media_object(payload[:audio]) } if payload[:audio].present?
    return { type: 'document', document: build_media_object(payload[:document]) } if payload[:document].present?
    return { type: 'sticker', sticker: build_media_object(payload[:sticker]) } if payload[:sticker].present?
    return { type: 'location', location: transform_location(payload[:location]) } if payload[:location].present?
    # live_location treated as regular location
    return { type: 'location', location: transform_location(payload[:live_location]) } if payload[:live_location].present?
    return { type: 'contacts', contacts: [transform_contact(payload[:contact])] } if payload[:contact].present?

    # Default to text with empty body
    { type: 'text', text: { body: '' } }
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def add_reply_context(message, payload)
    message['context'] = { 'id' => payload[:replied_to_id] } if payload[:replied_to_id].present?
  end

  def build_media_object(media_data, caption = nil)
    media_obj = if media_data.is_a?(Hash)
                  # go-whatsapp sends either:
                  # - { media_path: "...", mime_type: "...", caption: "..." } when auto-downloaded
                  # - { url: "..." } when not auto-downloaded
                  path = media_data[:media_path] || media_data[:url]
                  { id: path }
                else
                  # Direct string path (legacy format)
                  { id: media_data }
                end

    # Extract caption: prefer explicit caption parameter, then try nested caption in media_data
    effective_caption = caption.presence || (media_data.is_a?(Hash) ? media_data[:caption] : nil)
    media_obj[:caption] = effective_caption if effective_caption.present?
    media_obj
  end

  def transform_location(location_data)
    {
      latitude: location_data['degreesLatitude']&.to_f,
      longitude: location_data['degreesLongitude']&.to_f,
      name: location_data['name'],
      address: location_data['address'],
      url: location_data['url']
    }.compact
  end

  def transform_contact(contact_data)
    {
      name: {
        formatted_name: contact_data['displayName']
      },
      phones: contact_data['vcard'] ? extract_phones_from_vcard(contact_data['vcard']) : []
    }
  end

  def extract_phones_from_vcard(vcard)
    # Simple vCard parsing - extract phone numbers
    phones = vcard.to_s.scan(/TEL[^:]*:([^\n]+)/).map do |match|
      { phone: match[0].strip }
    end
    phones.presence || [{ phone: 'Phone number not available' }]
  end

  def extract_phone_number(jid)
    # Extract phone number from JID format (e.g., "628xxx@s.whatsapp.net" -> "628xxx")
    return '' if jid.blank?

    jid.split('@').first
  end

  def group_chat?(jid)
    # Group chats have JIDs ending in @g.us
    return false if jid.blank?

    jid.end_with?('@g.us')
  end

  # Look up sender name for group messages
  # Priority: message['sender_name'] > individual chat lookup > nil (placeholder)
  # NEVER return group name - that causes contacts to be named with group names
  def lookup_sender_name_for_group(message, sender_jid)
    # First try sender_name from message API (populated by go-whatsapp)
    name = message['sender_name']
    return name if name.present?

    # Fall back to looking up sender's individual chat
    return nil unless @history_chats_by_jid && sender_jid.present?

    # Try direct lookup first
    sender_chat = @history_chats_by_jid[sender_jid]

    # Try with @s.whatsapp.net suffix if not found
    sender_chat = @history_chats_by_jid["#{sender_jid}@s.whatsapp.net"] if sender_chat.nil? && sender_jid.exclude?('@')

    sender_chat&.dig('name')
  end

  # Look up the device owner's name from their own chat entry
  # For history sync outgoing messages, we need the device owner's actual name,
  # NOT the chat recipient's name
  def lookup_device_owner_name
    return nil unless @history_chats_by_jid

    device_id = webhook_params[:device_id]
    return nil if device_id.blank?

    # Try to find the device owner's own chat (self-chat/notes)
    device_jid = "#{device_id}@s.whatsapp.net"
    device_chat = @history_chats_by_jid[device_jid]

    name = device_chat&.dig('name')

    # If name is just the phone number, return nil to use phone as fallback
    # This prevents creating a contact with a phone number as the display name
    return nil if name.blank? || name == device_id

    name
  end

  # Merge chat_info into enriched_chat, but preserve non-blank name from original
  # This prevents empty name from messages API overwriting good name from chats list
  def merge_chat_info_preserving_name(enriched_chat, chat_info)
    return enriched_chat if chat_info.blank?

    original_name = enriched_chat['name']
    merged = enriched_chat.merge(chat_info)

    # Restore original name if new one is blank but original was present
    if merged['name'].blank? && original_name.present?
      Rails.logger.info "[WhatsApp History Sync] Preserving name: chat_info had blank name, keeping #{original_name.inspect}"
      merged['name'] = original_name
    end

    merged
  end

  def parse_timestamp(timestamp_str)
    return Time.current if timestamp_str.blank?

    # GoWA sends Unix epoch seconds (e.g. "1712345678")
    if timestamp_str.to_s.match?(/\A\d+\z/)
      Time.zone.at(timestamp_str.to_i)
    else
      Time.zone.parse(timestamp_str)
    end
  rescue ArgumentError
    Time.current
  end

  def download_attachment_file(attachment_payload)
    media_id = attachment_payload[:id]
    return nil if media_id.blank?

    # Check if media_id is a full URL
    if media_id.start_with?('http://', 'https://')
      download_from_url(media_id)
    elsif media_id.start_with?('/')
      # Absolute local path
      download_from_local_path(media_id)
    else
      # Relative path from go-whatsapp (e.g., "statics/media/...")
      # Construct full URL to go-whatsapp server
      download_from_go_whatsapp_path(media_id)
    end
  end

  def download_from_go_whatsapp_path(relative_path)
    api_url = ENV.fetch('WHATSAPP_WEB_API_URL', nil)
    if api_url.blank?
      Rails.logger.error 'WhatsApp Web: WHATSAPP_WEB_API_URL not configured for media download'
      return nil
    end

    full_url = "#{api_url}/#{relative_path}"
    Rails.logger.info "WhatsApp Web: Downloading media from #{full_url}"
    download_from_url(full_url)
  end

  def download_from_url(url)
    Down.download(url, max_size: 100.megabytes)
  rescue Down::Error => e
    Rails.logger.error "WhatsApp Web: Failed to download media from URL: #{e.message}"
    nil
  end

  def download_from_local_path(file_path)
    # Read media from local filesystem (used when WHATSAPP_AUTO_DOWNLOAD_MEDIA is true)
    Down::ChunkedIO.new(
      chunks: [File.binread(file_path)],
      size: File.size(file_path),
      data: { filename: File.basename(file_path), content_type: Marcel::MimeType.for(Pathname.new(file_path)) }
    )
  rescue Errno::ENOENT => e
    Rails.logger.error "WhatsApp Web: Media file not found: #{file_path} - #{e.message}"
    nil
  rescue Errno::EACCES => e
    Rails.logger.error "WhatsApp Web: Permission denied for media file: #{file_path} - #{e.message}"
    nil
  rescue StandardError => e
    Rails.logger.error "WhatsApp Web: Failed to read local media file: #{e.message}"
    nil
  end

  # Override to prevent status regression (delivered should not overwrite read)
  # go-whatsapp can send duplicate/out-of-order receipts
  # Uses database locking to prevent race conditions when multiple status updates arrive simultaneously
  def process_statuses
    processed_params[:statuses]&.each do |status_update|
      message = Message.find_by(source_id: status_update[:id])
      next unless message

      new_status = status_update[:status]

      # Use pessimistic locking to prevent race conditions
      # This ensures we read the latest status before deciding to update
      message.with_lock do
        current_status = message.status

        # Status progression: sent(0) → delivered(1) → read(2)
        # Only update if new status is higher priority (don't regress from read to delivered)
        next if status_should_not_progress?(current_status, new_status)

        message.update!(status: new_status)
      end
    end
  rescue StandardError => e
    Rails.logger.error "WhatsApp Web: Error processing status update: #{e.message}"
  end

  def status_should_not_progress?(current_status, new_status)
    status_priority = { 'sent' => 0, 'delivered' => 1, 'read' => 2, 'failed' => -1 }
    current_priority = status_priority[current_status] || 0
    new_priority = status_priority[new_status] || 0

    # Don't regress (e.g., don't go from read back to delivered)
    # But always allow failed status
    new_status != 'failed' && new_priority <= current_priority
  end

  # History sync configuration
  HISTORY_CHAT_BATCH_SIZE = 100
  HISTORY_MESSAGE_BATCH_SIZE = 100
  AVATAR_SYNC_INTERVAL = 1.hour

  # Process history sync complete event by fetching and importing messages
  # Uses two-phase approach to prevent duplicate contacts:
  # Phase 1: Collect all messages, build LID→phone mapping, normalize contacts
  # Phase 2: Bulk create contacts, then process messages using cached lookups
  def process_history_sync
    Rails.logger.info "[WhatsApp History Sync] Starting two-phase sync for inbox #{inbox.id}"

    unless history_sync_enabled?
      Rails.logger.info "[WhatsApp History Sync] Skipping - history sync is disabled for inbox #{inbox.id}"
      return
    end

    # Fetch all chats
    @history_chats = fetch_all_history_chats
    return if @history_chats.empty?

    @history_chats_by_jid = @history_chats.index_by { |c| c['jid'] }

    # === PHASE 1: Collect and normalize ===
    Rails.logger.info '[WhatsApp History Sync] Phase 1: Collecting messages and building contact map'

    all_messages = collect_all_history_messages(@history_chats)
    lid_to_phone = build_lid_to_phone_mapping(all_messages)
    contact_map = build_normalized_contact_map(@history_chats_by_jid, lid_to_phone)

    Rails.logger.info "[WhatsApp History Sync] Found #{contact_map.size} unique contacts (after LID normalization)"

    # === PHASE 2: Create contacts and process messages ===
    Rails.logger.info '[WhatsApp History Sync] Phase 2: Creating contacts and processing messages'

    contact_cache = bulk_create_contacts_for_history_sync(contact_map)

    # Process messages using cache
    @history_chats.each do |chat|
      chat_jid = chat['jid']
      next unless processable_chat_jid?(chat_jid)
      next if ignore_group_messages? && group_chat?(chat_jid)

      begin
        messages = @history_messages_by_chat[chat_jid] || []
        process_history_messages_with_cache(chat_jid, messages, contact_cache, lid_to_phone)
        update_conversation_timestamps_for_chat(chat_jid)
      rescue StandardError => e
        Rails.logger.error "[WhatsApp History Sync] Failed to process chat #{chat_jid}: #{e.message}"
      end
    end

    Rails.logger.info "[WhatsApp History Sync] Completed for inbox #{inbox.id}"
  rescue StandardError => e
    Rails.logger.error "[WhatsApp History Sync] Failed: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
  ensure
    @history_chats = nil
    @history_chats_by_jid = nil
    @history_messages_by_chat = nil
  end

  # Collect all messages from all chats for Phase 1 analysis
  def collect_all_history_messages(chats)
    @history_messages_by_chat = {}
    all_messages = []

    chats.each do |chat|
      chat_jid = chat['jid']
      next unless processable_chat_jid?(chat_jid)
      next if ignore_group_messages? && group_chat?(chat_jid)

      messages = fetch_all_messages_for_chat(chat_jid)
      @history_messages_by_chat[chat_jid] = messages
      all_messages.concat(messages)
    end

    all_messages
  end

  def fetch_all_messages_for_chat(chat_jid)
    messages = []
    offset = 0

    loop do
      response = inbox.channel.provider_service.fetch_chat_messages(
        chat_jid: chat_jid,
        limit: HISTORY_MESSAGE_BATCH_SIZE,
        offset: offset
      )
      break if response.blank?

      batch = response['data']
      break if batch.blank? || !batch.is_a?(Array)

      messages.concat(batch)
      break unless more_history_pages?(response, offset, HISTORY_MESSAGE_BATCH_SIZE)

      offset += HISTORY_MESSAGE_BATCH_SIZE
    end

    messages
  end

  # Process messages using pre-built contact cache (Phase 2)
  def process_history_messages_with_cache(chat_jid, messages, contact_cache, lid_to_phone)
    messages.each do |message|
      contact_inbox = resolve_contact_from_history_cache(message, contact_cache, lid_to_phone)
      next if contact_inbox.nil?

      process_single_history_message_with_contact(chat_jid, message, contact_inbox)
    rescue StandardError => e
      Rails.logger.error "[WhatsApp History Sync] Error processing message #{message['id']}: #{e.message}"
    end
  end

  def process_single_history_message_with_contact(chat_jid, message, _contact_inbox)
    # Skip if message already exists
    source_id = message['id']
    return if source_id.blank?
    return if inbox.messages.exists?(source_id: source_id)

    # Use existing build_history_message_params + perform flow
    # This reuses all existing logic: timestamps, avatars, media, sender resolution
    chat = @history_chats_by_jid[chat_jid]
    return if chat.nil?

    transformed_params = build_history_message_params(message, chat)
    self.class.new(inbox: inbox, params: transformed_params).perform
  end

  def fetch_all_history_chats
    chats = []
    offset = 0

    loop do
      response = inbox.channel.provider_service.fetch_chats(limit: HISTORY_CHAT_BATCH_SIZE, offset: offset)
      break if response.blank?

      batch = response['data']
      break if batch.blank? || !batch.is_a?(Array)

      chats.concat(batch)
      break unless more_history_pages?(response, offset, HISTORY_CHAT_BATCH_SIZE)

      offset += HISTORY_CHAT_BATCH_SIZE
    end

    chats
  end

  def sync_history_chat_messages(chat)
    chat_jid = chat['jid']
    return if chat_jid.blank?
    return if ignore_group_messages? && group_chat?(chat_jid)

    # Will be enriched with chat_info from first messages response
    enriched_chat = chat.dup
    offset = 0

    loop do
      response = inbox.channel.provider_service.fetch_chat_messages(
        chat_jid: chat_jid,
        limit: HISTORY_MESSAGE_BATCH_SIZE,
        offset: offset
      )
      break if response.blank?

      # Merge chat_info from response, but only non-blank values (preserve original name if new one is blank)
      chat_info = response['chat_info']
      enriched_chat = merge_chat_info_preserving_name(enriched_chat, chat_info) if chat_info.present?

      batch = response['data']
      break if batch.blank? || !batch.is_a?(Array)

      process_history_messages(batch, enriched_chat)
      break unless more_history_pages?(response, offset, HISTORY_MESSAGE_BATCH_SIZE)

      offset += HISTORY_MESSAGE_BATCH_SIZE
    end

    # After all messages are synced, update conversation timestamps
    update_conversation_timestamps_for_chat(chat_jid)
  rescue StandardError => e
    Rails.logger.error "[WhatsApp History Sync] Error syncing chat #{chat_jid}: #{e.message}"
  end

  def process_history_messages(messages, chat)
    messages.each do |msg|
      process_single_history_message(msg, chat)
    rescue StandardError => e
      Rails.logger.error "[WhatsApp History Sync] Error processing message #{msg['id']}: #{e.message}"
    end
  end

  def process_single_history_message(message, chat)
    # Skip if message already exists
    message_id = message['id']
    return if message_id.blank?
    return if inbox.messages.exists?(source_id: message_id)

    # Transform to webhook format and process
    transformed_params = build_history_message_params(message, chat)
    self.class.new(inbox: inbox, params: transformed_params).perform
  end

  def build_history_message_params(message, chat)
    chat_jid = chat['jid']
    sender_jid = message['sender_jid'] || chat_jid
    is_from_me = message['is_from_me'] == true

    # For outgoing messages (is_from_me=true):
    #   - from_name should be the device owner's name (NOT the chat/recipient name)
    #   - contact_name is the chat name (recipient) for build_contact
    # For incoming messages:
    #   - from_name is the sender's name
    # For group chats: use sender_name from message (individual's name)
    # NEVER use group chat name for sender - that causes contacts to get group names
    sender_name = if is_from_me
                    # For outgoing messages, get device owner's name from their own chat entry
                    lookup_device_owner_name
                  elsif group_chat?(chat_jid)
                    lookup_sender_name_for_group(message, sender_jid)
                  else
                    chat['name']
                  end

    # Debug: Log sender name resolution
    Rails.logger.info "[WhatsApp History Sync] build_params: chat_jid=#{chat_jid}, sender_jid=#{sender_jid}, " \
                      "is_from_me=#{is_from_me}, chat_name=#{chat['name'].inspect}, sender_name=#{sender_name.inspect}"

    payload = {
      id: message['id'],
      chat_id: chat_jid,
      from: is_from_me ? webhook_params[:device_id] : sender_jid,
      from_name: sender_name,
      contact_name: chat['name'], # Used by build_contact for outgoing messages to get recipient name
      timestamp: message['timestamp'],
      is_from_me: is_from_me
    }

    content = message['content']
    payload[:body] = content if content.present?

    add_history_media_to_payload(payload, message, chat)

    {
      'event' => 'message',
      'device_id' => webhook_params[:device_id],
      'payload' => payload
    }
  end

  def add_history_media_to_payload(payload, message, chat)
    media_type = message['media_type']
    return if media_type.blank?

    message_id = message['id']
    chat_jid = chat['jid']
    return if message_id.blank? || chat_jid.blank?

    # Download and decrypt media via go-whatsapp API
    # WhatsApp CDN URLs require decryption with MediaKey, so we use the download endpoint
    downloaded_url = inbox.channel.provider_service.download_message_media(
      message_id: message_id,
      chat_jid: chat_jid
    )

    return if downloaded_url.blank?

    filename = message['filename']
    media_obj = { url: downloaded_url }
    media_obj[:filename] = filename if filename.present?

    case media_type.downcase
    when 'image' then payload[:image] = media_obj
    when 'video', 'video_note' then payload[:video] = media_obj
    when 'audio' then payload[:audio] = media_obj
    when 'document' then payload[:document] = media_obj
    when 'sticker' then payload[:sticker] = media_obj
    end
  end

  def more_history_pages?(response, current_offset, batch_size)
    return false unless response.is_a?(Hash)

    pagination = response['pagination']
    return false unless pagination

    total = pagination['total']
    return false unless total

    (current_offset + batch_size) < total
  end

  # Update conversation timestamps based on actual message dates
  # This ensures created_at reflects the oldest message and last_activity_at reflects the newest
  def update_conversation_timestamps_for_chat(chat_jid)
    # Find the contact_inbox for this chat
    phone = extract_phone_number(chat_jid)
    contact_inbox = inbox.contact_inboxes.joins(:contact).find_by(
      source_id: chat_jid
    ) || inbox.contact_inboxes.joins(:contact).find_by(
      contacts: { phone_number: "+#{phone}" }
    )
    return unless contact_inbox

    # Get the conversation
    conversation = contact_inbox.conversations.last
    return unless conversation

    # Get min and max created_at from messages
    message_timestamps = conversation.messages.pluck(:created_at)
    return if message_timestamps.empty?

    oldest_message_at = message_timestamps.min
    newest_message_at = message_timestamps.max

    # Update conversation timestamps using update_columns to skip callbacks
    # rubocop:disable Rails/SkipsModelValidations
    updates = { last_activity_at: newest_message_at }

    # Only update created_at if oldest message is older than current created_at
    updates[:created_at] = oldest_message_at if oldest_message_at < conversation.created_at

    conversation.update_columns(updates)
    # rubocop:enable Rails/SkipsModelValidations

    Rails.logger.info "[WhatsApp History Sync] Updated conversation #{conversation.id} timestamps: " \
                      "created_at=#{conversation.created_at}, last_activity_at=#{newest_message_at}"
  rescue StandardError => e
    Rails.logger.error "[WhatsApp History Sync] Error updating conversation timestamps: #{e.message}"
  end

  # Fetch avatar from go-whatsapp and schedule sync job
  # Rate limited to once per hour to avoid excessive API calls
  def sync_contact_avatar
    return if avatar_recently_synced?

    phone_number = @contact.phone_number&.delete_prefix('+')
    return if phone_number.blank?

    avatar_url = inbox.channel.provider_service.fetch_avatar_url(phone_number)
    return if avatar_url.blank?

    Avatar::AvatarFromUrlJob.perform_later(@contact, avatar_url)
  rescue StandardError => e
    Rails.logger.error "WhatsApp Web: Failed to sync avatar for contact #{@contact.id}: #{e.message}"
  end

  def avatar_recently_synced?
    last_sync = @contact.additional_attributes&.dig('last_avatar_sync_at')
    return false if last_sync.blank?

    Time.zone.parse(last_sync) > AVATAR_SYNC_INTERVAL.ago
  rescue ArgumentError
    false
  end

  # Build a mapping of LID JIDs to phone JIDs from messages with from_lid field
  # Used during history sync Phase 1 to normalize contacts before creation
  def build_lid_to_phone_mapping(messages)
    mapping = {}

    messages.each do |msg|
      chat_jid = msg[:chat_jid] || msg['chat_jid']
      from_lid = msg[:from_lid] || msg['from_lid']

      next if from_lid.blank?
      next unless chat_jid&.end_with?('@s.whatsapp.net')

      mapping[from_lid] = chat_jid
    end

    mapping
  end

  # Build a normalized contact map from chats, merging LID entries into phone entries
  # Used during history sync Phase 1 to deduplicate contacts before creation
  def build_normalized_contact_map(chats_by_jid, lid_to_phone_mapping)
    contact_map = {}

    # First pass: build initial contact map from chats
    chats_by_jid.each do |jid, chat|
      contact_map[jid] = {
        jid: jid,
        name: chat['name'],
        lid: nil
      }
    end

    # Second pass: merge LID entries into phone entries
    lid_to_phone_mapping.each do |lid_jid, phone_jid|
      next unless contact_map.key?(lid_jid)

      lid_data = contact_map.delete(lid_jid)

      contact_map[phone_jid] ||= { jid: phone_jid, name: nil, lid: nil }
      contact_map[phone_jid][:lid] = lid_jid
      contact_map[phone_jid][:name] ||= lid_data[:name]
    end

    contact_map
  end

  # Bulk create contacts for history sync and return a cache for lookups
  # Used during history sync Phase 2
  def bulk_create_contacts_for_history_sync(contact_map)
    cache = {}

    contact_map.each do |jid, data|
      contact_inbox = find_or_create_contact_for_history_sync(jid, data)
      next if contact_inbox.nil?

      # Cache by primary JID
      cache[jid] = contact_inbox

      # Also cache by LID if present
      cache[data[:lid]] = contact_inbox if data[:lid].present?
    rescue StandardError => e
      Rails.logger.error "[WhatsApp History Sync] Failed to create contact for #{jid}: #{e.message}"
    end

    cache
  end

  def find_or_create_contact_for_history_sync(jid, data)
    phone_number = extract_phone_number_from_jid(jid)

    # Try to find existing contact_inbox
    contact_inbox = find_existing_contact_inbox_for_history_sync(jid, phone_number, data[:lid])
    return contact_inbox if contact_inbox.present?

    # Create new contact
    create_contact_for_history_sync(jid, data, phone_number)
  rescue ActiveRecord::RecordNotUnique
    # Race condition: another process created it, fetch and return
    find_existing_contact_inbox_for_history_sync(jid, phone_number, data[:lid])
  end

  def find_existing_contact_inbox_for_history_sync(jid, phone_number, lid)
    # Try by source_id (phone number only for regular chats, full JID for LID/group)
    source_id = extract_source_id_from_jid(jid)
    contact_inbox = inbox.contact_inboxes.find_by(source_id: source_id)
    return contact_inbox if contact_inbox.present?

    # Try by LID source_id
    if lid.present?
      contact_inbox = inbox.contact_inboxes.find_by(source_id: lid)
      return contact_inbox if contact_inbox.present?
    end

    # Try by phone number
    if phone_number.present?
      contact = inbox.account.contacts.find_by(phone_number: phone_number)
      return contact.contact_inboxes.find_by(inbox: inbox) if contact.present?
    end

    nil
  end

  def create_contact_for_history_sync(jid, data, phone_number)
    contact_attributes = {
      name: data[:name] || phone_number || jid,
      phone_number: phone_number
    }

    # Build additional_attributes based on JID type
    additional_attrs = {}
    additional_attrs[:lid] = data[:lid] if data[:lid].present?
    additional_attrs[:is_group] = true if jid.end_with?('@g.us')
    additional_attrs[:is_broadcast] = true if jid.end_with?('@broadcast')
    contact_attributes[:additional_attributes] = additional_attrs if additional_attrs.present?

    # source_id must be phone number only (not full JID) for WhatsApp inbox validation
    # or the full JID for LID/group chats
    source_id = extract_source_id_from_jid(jid)

    ContactInboxWithContactBuilder.new(
      inbox: inbox,
      source_id: source_id,
      contact_attributes: contact_attributes
    ).perform
  end

  def extract_phone_number_from_jid(jid)
    return nil if jid.blank?
    return nil if jid.end_with?('@lid')
    return nil if jid.end_with?('@g.us')
    return nil if jid.end_with?('@broadcast')
    return nil unless jid.end_with?('@s.whatsapp.net')

    phone = jid.gsub('@s.whatsapp.net', '')
    phone.present? ? "+#{phone}" : nil
  end

  # Extract source_id for ContactInbox - WhatsApp validation requires:
  # - Phone number only (digits) for regular chats
  # - Full JID for group chats (@g.us), LID chats (@lid), and broadcasts (@broadcast)
  def extract_source_id_from_jid(jid)
    return jid if jid.blank?
    return jid if jid.end_with?('@lid', '@g.us', '@broadcast')

    # For regular chats, extract phone number only
    jid.gsub('@s.whatsapp.net', '')
  end

  # Resolve contact from history sync cache using multiple lookup strategies
  # Used during history sync Phase 2 to find contacts without database queries
  def resolve_contact_from_history_cache(message, cache, lid_to_phone)
    chat_jid = message[:chat_jid] || message['chat_jid']
    from_lid = message[:from_lid] || message['from_lid']

    # Try direct JID lookup
    contact_inbox = cache[chat_jid]
    return contact_inbox if contact_inbox.present?

    # Try from_lid lookup
    if from_lid.present?
      contact_inbox = cache[from_lid]
      return contact_inbox if contact_inbox.present?
    end

    # Try LID→phone mapping for LID messages
    if chat_jid&.end_with?('@lid')
      phone_jid = lid_to_phone[chat_jid]
      contact_inbox = cache[phone_jid] if phone_jid.present?
      return contact_inbox if contact_inbox.present?
    end

    Rails.logger.warn(
      "[HistorySync] Contact not found in cache: chat_jid=#{chat_jid}, from_lid=#{from_lid}"
    )
    nil
  end
end
# rubocop:enable Metrics/ClassLength
