# Service to handle incoming messages from go-whatsapp-web-multidevice webhook
# Transforms webhook payload to Chatwoot format compatible with IncomingMessageBaseService
# rubocop:disable Metrics/ClassLength
class Whatsapp::IncomingMessageWhatsappWebService < Whatsapp::IncomingMessageBaseService
  def perform
    processed_params

    if processed_params.try(:[], :reaction).present?
      process_reaction
    else
      super
    end
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
    when 'message.revoked', 'message.edited'
      # Skip these for now - can be implemented later
      {}
    else
      Rails.logger.warn "Unknown WhatsApp Web event type: #{event_type}"
      {}
    end
  end

  def transform_message_event(payload)
    message_id = payload[:id]
    from = extract_phone_number(payload[:from])
    timestamp = parse_timestamp(payload[:timestamp])

    {
      contacts: [build_contact(payload)],
      messages: [build_message(payload, message_id, from, timestamp)]
    }
  end

  # Transform message.ack event to status update format
  # go-whatsapp sends: { ids: [...], receipt_type: "delivered"|"read" }
  # Base service expects: { statuses: [{ id: "...", status: "delivered"|"read" }] }
  def transform_status_event(payload)
    message_ids = payload[:ids] || []
    receipt_type = payload[:receipt_type]

    # Map go-whatsapp receipt types to Chatwoot statuses
    status = case receipt_type
             when 'delivered' then 'delivered'
             when 'read' then 'read'
             else return {} # Unknown receipt type
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

  # Override to handle group messages differently
  def set_contact
    if group_message?
      set_group_contact
    else
      super
      sync_contact_avatar if @contact
    end
  end

  def group_message?
    webhook_params.dig(:payload, :chat_id).to_s.end_with?('@g.us')
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

  # Override to store sender info for group messages
  def create_message(message)
    sender = group_message? ? find_or_create_sender_contact : @contact

    @message = @conversation.messages.build(
      content: message_content(message),
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      sender: sender,
      source_id: message[:id].to_s,
      in_reply_to_external_id: @in_reply_to_external_id,
      additional_attributes: group_message? ? group_sender_attributes : {}
    )
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
    from = extract_phone_number(payload[:from])
    profile_name = payload[:from_name]

    {
      wa_id: from,
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
    return { type: 'audio', audio: build_media_object(payload[:audio]) } if payload[:audio].present?
    return { type: 'document', document: build_media_object(payload[:document]) } if payload[:document].present?
    return { type: 'sticker', sticker: build_media_object(payload[:sticker]) } if payload[:sticker].present?
    return { type: 'location', location: transform_location(payload[:location]) } if payload[:location].present?
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
                  # Media not auto-downloaded, has URL
                  { id: media_data[:url] }
                else
                  # Media auto-downloaded, has local path
                  { id: media_data }
                end

    media_obj[:caption] = caption if caption.present?
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

  def parse_timestamp(timestamp_str)
    return Time.current if timestamp_str.blank?

    Time.zone.parse(timestamp_str)
  rescue ArgumentError
    Time.current
  end

  def download_attachment_file(attachment_payload)
    media_id = attachment_payload[:id]
    return nil if media_id.blank?

    # Check if media_id is a URL (not auto-downloaded)
    if media_id.start_with?('http://', 'https://')
      # Download from WhatsApp Web API media endpoint
      download_from_whatsapp_web_api(media_id)
    elsif File.exist?(media_id)
      # Media was auto-downloaded, read from local path
      download_from_local_path(media_id)
    else
      Rails.logger.error "WhatsApp Web: Cannot download attachment - invalid media_id: #{media_id}"
      nil
    end
  end

  def download_from_whatsapp_web_api(media_url)
    # Download media from go-whatsapp-web-multidevice API
    # This would be used when WHATSAPP_AUTO_DOWNLOAD_MEDIA is false
    api_url = ENV.fetch('WHATSAPP_WEB_API_URL', nil)
    return nil if api_url.blank?

    device_id = inbox.channel.provider_config['device_id']
    headers = {
      'X-Device-Id' => device_id,
      'Accept' => '*/*'
    }

    Down.download(media_url, headers: headers)
  rescue Down::Error => e
    Rails.logger.error "WhatsApp Web: Failed to download media from API: #{e.message}"
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
  def process_statuses
    processed_params[:statuses]&.each do |status_update|
      message = Message.find_by(source_id: status_update[:id])
      next unless message

      new_status = status_update[:status]
      current_status = message.status

      # Status progression: sent(0) → delivered(1) → read(2)
      # Only update if new status is higher priority (don't regress from read to delivered)
      next if status_should_not_progress?(current_status, new_status)

      message.update!(status: new_status)
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

  AVATAR_SYNC_INTERVAL = 1.hour

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
end
# rubocop:enable Metrics/ClassLength
