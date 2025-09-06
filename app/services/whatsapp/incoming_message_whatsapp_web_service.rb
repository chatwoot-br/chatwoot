# Service to process incoming messages from go-whatsapp-web-multidevice
# Based on documentation: https://github.com/aldinokemal/go-whatsapp-web-multidevice
class Whatsapp::IncomingMessageWhatsappWebService < Whatsapp::IncomingMessageBaseService
  private

  def processed_params
    @processed_params ||= normalize_payload
  end

  def set_contact
    contact_from = @processed_params[:contacts]&.first
    Rails.logger.info { "WhatsApp Web: Incoming message from contact: #{contact_from.inspect}" }
    contact_to = @processed_params[:contacts]&.last
    Rails.logger.info { "WhatsApp Web: Incoming message to contact: #{contact_to.inspect}" }

    # Return early if no valid contacts to avoid creating empty conversations
    return if contact_from.blank?

    # Ensure we have valid message data before creating contacts
    messages = @processed_params[:messages]
    return if messages.blank? || messages.first.blank?

    # Check if this is a message from the company's own WhatsApp (outgoing)
    if message_from_company?(contact_from, contact_to)
      Rails.logger.info { 'WhatsApp Web: Outgoing message from company WhatsApp' }
      # For outgoing messages, we need:
      # 1. Create contact_inbox for the external contact (recipient)
      setup_external_contact(contact_to)
      # 2. Create/find the company contact that will be the sender
      setup_company_contact(contact_from)
    elsif message_to_group?(contact_from, contact_to)
      Rails.logger.info { 'WhatsApp Web: Incoming message to a group' }
      # For incoming messages, the external contact is contact_from
      setup_external_contact(contact_from)
      # Update existing contact name if ProfileName is available and current name is just phone number
      update_contact_with_profile_name(contact_from)
      # For group messages, set up the group contact but with null phone_number
      contact_to_modified = contact_to.dup
      contact_to_modified[:profile][:phone_number] = nil
      setup_external_contact(contact_to_modified)
    else
      Rails.logger.info { 'WhatsApp Web: Incoming message from external contact' }
      # For incoming messages, the external contact is contact_from
      setup_external_contact(contact_from)
      # Update existing contact name if ProfileName is available and current name is just phone number
      update_contact_with_profile_name(contact_from)
    end

    update_contact_with_whatsapp_web_specific_data
  end

  def create_messages
    super
    contact_from = @processed_params[:contacts]&.first
    contact_to = @processed_params[:contacts]&.last

    # Check if this is an outgoing message from the company's WhatsApp
    return unless message_from_company?(contact_from, contact_to)

    Rails.logger.info { 'WhatsApp Web: Setting message as outgoing from company' }
    @message.update_attribute(:message_type, :outgoing)

    # For outgoing messages, the sender should be the company contact, not external contact
    return unless @company_contact

    @message.update_attribute(:sender, @company_contact)
    Rails.logger.info { "WhatsApp Web: Message attributed to company contact: #{@company_contact.name}" }
  end

  def update_contact_with_whatsapp_web_specific_data
    identifier = @contact.identifier

    # Update identifier if it's blank and we have phone number data
    if identifier.blank?
      contact_params = @processed_params[:contacts]&.first
      potential_identifier = contact_params.dig(:profile, :identifier)
      if potential_identifier.present?
        @contact.update!(identifier: potential_identifier)
        identifier = potential_identifier
        Rails.logger.debug { "WhatsApp Web: Updated contact identifier to: #{identifier}" }
      else
        Rails.logger.debug 'WhatsApp Web: Could not determine identifier, skipping avatar update'
        return
      end
    end

    # Skip if avatar was recently updated (within last 24 hours)
    if @contact.avatar.attached? && @contact.updated_at > 24.hours.ago
      Rails.logger.debug { 'WhatsApp Web: Contact has recent avatar, skipping update' }
      return
    end

    Rails.logger.debug { "WhatsApp Web: Updating contact avatar for identifier: #{identifier}" }

    # Use the full identifier (not just phone number) for avatar request
    avatar_url = inbox.channel.avatar_url(identifier)
    update_contact_avatar(@contact, avatar_url)
  rescue StandardError => e
    Rails.logger.error "WhatsApp Web: Error updating contact avatar: #{e.message}"
    Rails.logger.error "WhatsApp Web: Identifier: #{identifier}"
    Rails.logger.error "WhatsApp Web: Backtrace: #{e.backtrace.join("\n")}"
    nil
  end

  def update_contact_avatar(contact, avatar_url)
    ::Avatar::AvatarFromUrlJob.perform_later(contact, avatar_url) if avatar_url
  end

  def normalize_payload
    # go-whatsapp-web-multidevice payloads have different structure
    # We need to normalize them to the format expected by the base service

    # Extract the actual payload data (controller wraps webhook data in 'payload' key)
    payload_data = params[:payload] || params
    event_type = payload_data[:event] || params[:event] || event_type_from_payload(payload_data)

    case event_type
    when 'message.ack'
      normalize_receipt_payload
    when 'message', 'group.message'
      # Only process if we have valid message data
      return {}.with_indifferent_access if payload_data[:message].blank? && payload_data[:text].blank?

      normalize_message_payload
    when 'group.participants'
      # Skip group events entirely to avoid empty conversations
      Rails.logger.debug { 'WhatsApp Web: Skipping group event processing' }
      return {}.with_indifferent_access
    else
      # Skip unknown event types to avoid empty conversations
      Rails.logger.debug { "WhatsApp Web: Skipping unknown event type: #{event_type}" }
      {}.with_indifferent_access
    end
  end

  def event_type_from_payload(payload)
    from_field = payload[:from]
    return 'message' if from_field.nil? || from_field.blank?

    identifier = to_identifier(from_field)
    return 'message' if identifier.nil? || identifier.blank?

    return 'message' if identifier.include?('@s.whatsapp.net')
    return 'group.message' if identifier.include?('@g.us')
    return 'newsletter' if identifier.include?('@newsletter')

    return 'message'
  end

  def normalize_message_payload
    payload = params[:payload] || params

    # Validate that we have essential message data
    if payload[:message].blank? && payload[:text].blank? && payload[:content].blank?
      Rails.logger.debug { 'WhatsApp Web: Skipping payload without message content' }
      return {}.with_indifferent_access
    end

    # Extract contact information based on payload fields
    contact_from = extract_contact_from(payload)
    contact_to = extract_contact_to(payload)

    # Extract message information
    message_info = extract_message_info(payload)

    # Validate message has content before proceeding
    if message_info['text']&.dig('body').blank? &&
       message_info['image'].blank? &&
       message_info['video'].blank? &&
       message_info['audio'].blank? &&
       message_info['document'].blank? &&
       message_info['location'].blank? &&
       message_info['contacts'].blank? &&
       message_info['sticker'].blank?
      Rails.logger.debug { 'WhatsApp Web: Skipping message without valid content' }
      return {}.with_indifferent_access
    end

    {
      contacts: [contact_from, contact_to],
      messages: [message_info]
    }.with_indifferent_access
  end

  def normalize_receipt_payload
    # For receipt events, the data can be nested differently
    # Check if this is a nested receipt event (event: "message.ack", payload: {...})
    if params[:payload][:event] == 'message.ack'
      receipt_data = params[:payload][:payload] || params[:payload]
      timestamp = params[:payload][:timestamp] || params[:timestamp]
    else
      receipt_data = params[:payload] || params
      timestamp = params[:timestamp]
    end

    # Process all message IDs in the receipt, not just the first one
    message_ids = receipt_data[:ids] || []
    status = map_receipt_status(receipt_data[:receipt_type])

    statuses = message_ids.map do |message_id|
      {
        id: message_id,
        status: status,
        timestamp: timestamp
      }
    end

    {
      statuses: statuses
    }.with_indifferent_access
  end

  def normalize_group_payload
    # Group events are not processed as messages at the moment
    # Returns empty structure to avoid processing
    Rails.logger.debug { 'WhatsApp Web: Skipping group event processing' }
    {}.with_indifferent_access
  end

  def extract_contact_from(payload)
    identifier = from_identifier(payload[:from])
    phone_number = "+#{extract_phone_number(identifier)}"

    {
      wa_id: extract_phone_number(identifier), # source_id
      profile: {
        identifier: identifier,
        name: payload[:pushname] || phone_number,
        phone_number: phone_number
      }
    }
  end

  def extract_contact_to(payload)
    # For WhatsApp Web, if payload[:from] contains " in ", extract the part after " in "
    # Otherwise, if this is incoming to our number (payload doesn't have " in "),
    # the destination is the current inbox phone number
    if payload[:from].to_s.include?(' in ')
      identifier = to_identifier(payload[:from])
      phone_number = "+#{extract_phone_number(identifier)}"
    else
      # For incoming messages without " in " structure, check if sender is different from our inbox
      sender_phone = extract_phone_number(payload[:from])
      inbox_phone = extract_phone_number(inbox.channel.phone_number)

      if sender_phone == inbox_phone
        # Fallback to original logic if sender matches our inbox (edge case)
        identifier = to_identifier(payload[:from])
        phone_number = "+#{extract_phone_number(identifier)}"
      else
        # This is an incoming message, destination should be our inbox number
        identifier = "#{inbox_phone}@s.whatsapp.net"
        phone_number = "+#{inbox_phone}"
      end
    end

    # For groups, use the full identifier as wa_id to pass validation
    wa_id_value = identifier.include?('@g.us') ? identifier : extract_phone_number(identifier)

    {
      wa_id: wa_id_value, # source_id
      profile: {
        identifier: identifier,
        name: phone_number,
        phone_number: phone_number
      }
    }
  end

  def extract_message_info(payload)
    base_message = {
      'id' => payload.dig(:message, :id),
      'from' => payload[:sender_id],
      'to' => payload[:chat_id],
      'timestamp' => convert_timestamp(payload[:timestamp]),
      'type' => determine_message_type(payload)
    }

    # Add specific content based on message type
    case base_message['type']
    when 'text'
      base_message['text'] = { 'body' => payload.dig(:message, :text) || payload[:message] || payload[:content] || payload[:text] }
    when 'reaction'
      # Handle reaction as a reply to the reacted message
      reaction_data = payload[:reaction]
      base_message['text'] = { 'body' => reaction_data[:message] || reaction_data['message'] }
      base_message['context'] = { 'id' => reaction_data[:id] || reaction_data['id'] }
    when 'image', 'video', 'audio', 'document'
      base_message[base_message['type']] = extract_media_info(payload)
    when 'location'
      base_message['location'] = extract_location_info(payload)
    when 'contacts'
      base_message['contacts'] = extract_contacts_info(payload)
    when 'sticker'
      base_message['sticker'] = extract_media_info(payload)
    end

    # Add reply context if present
    if payload.dig(:message, :replied_id).present? || payload[:quoted_message_id] || payload[:in_reply_to]
      reply_id = payload.dig(:message, :replied_id) || payload[:quoted_message_id] || payload[:in_reply_to]
      base_message['context'] = { 'id' => reply_id.to_s }
    end

    base_message
  end

  def extract_phone_number(phone_identifier)
    return '' if phone_identifier.nil? || phone_identifier.to_s.blank?

    # Remove WhatsApp suffixes if present (@s.whatsapp.net, @g.us)
    clean_number = phone_identifier.to_s.split('@').first

    # Remove device-specific parts (e.g., ":35" from "557999777712:35")
    clean_number = clean_number.split(':').first

    # Extract only numeric characters to ensure valid source_id
    clean_number.gsub(/\D/, '')
  end

  def from_identifier(identifier)
    return identifier if identifier.blank?

    # Handle complex identifiers like "552140402221:14@s.whatsapp.net in 552140402221@s.whatsapp.net"
    # Extract the main phone number (first "in" if present, otherwise the first part)
    if identifier.include?(' in ')
      # Get the part before "in" and clean it
      return cleanup_identifier(identifier.split(' in ').first)
    end

    cleanup_identifier(identifier)
  end

  def to_identifier(identifier)
    return '' if identifier.blank? || identifier.nil?

    # Handle complex identifiers like "552140402221:14@s.whatsapp.net in 552140402221@s.whatsapp.net"
    # Extract the main phone number (last "in" if present, otherwise the first part)
    if identifier.include?(' in ')
      # Get the part after "in" and clean it
      result = cleanup_identifier(identifier.split(' in ').last)
      return result.presence || cleanup_identifier(identifier.split(' in ').first)
    end

    cleanup_identifier(identifier)
  end

  def cleanup_identifier(identifier)
    return identifier if identifier.nil? || identifier.blank?

    # Handle device-specific identifiers like "552140402221:14@s.whatsapp.net"
    if identifier.include?(':') && identifier.include?('@')
      phone_part = identifier.split(':').first
      suffix_part = identifier.split('@').last
      return "#{phone_part}@#{suffix_part}"
    end
    identifier
  end

  def convert_timestamp(timestamp)
    # Convert timestamp to Unix format (seconds)
    case timestamp
    when String
      # If already in RFC3339 format, convert to Unix timestamp
      Time.parse(timestamp).to_i.to_s
    when Integer, Numeric
      timestamp.to_s
    else
      Time.current.to_i.to_s
    end
  end

  def determine_message_type(payload)
    # Determine message type based on payload
    return payload[:type] if payload[:type].present?

    # Check for reaction first (special case)
    return 'reaction' if payload[:reaction].present?

    # Inference based on present fields (check both webhook and legacy formats)
    return 'image' if payload[:image].present? || payload[:image_url] || payload[:media_type] == 'image'
    return 'video' if payload[:video].present? || payload[:video_url] || payload[:media_type] == 'video'
    return 'audio' if payload[:audio].present? || payload[:audio_url] || payload[:media_type] == 'audio'
    return 'document' if payload[:document].present? || payload[:document_url] || payload[:media_type] == 'document'
    return 'location' if payload[:location].present? || (payload[:latitude] && payload[:longitude])
    return 'contacts' if payload[:contact].present? || payload[:contact_vcard] || payload[:contacts]
    return 'sticker' if payload[:sticker].present? || payload[:sticker_url] || payload[:media_type] == 'sticker'

    'text' # Default for text messages
  end

  def extract_media_info(payload)
    media_info = {}

    # Handle different media payload structures
    if payload[:image].present?
      media_data = payload[:image]
      media_info[:id] = media_data[:media_path] || media_data[:id]
      media_info[:mime_type] = media_data[:mime_type]
      media_info[:caption] = media_data[:caption]
    elsif payload[:video].present?
      media_data = payload[:video]
      media_info[:id] = media_data[:media_path] || media_data[:id]
      media_info[:mime_type] = media_data[:mime_type]
      media_info[:caption] = media_data[:caption]
    elsif payload[:audio].present?
      media_data = payload[:audio]
      media_info[:id] = media_data[:media_path] || media_data[:id]
      media_info[:mime_type] = media_data[:mime_type]
      media_info[:caption] = media_data[:caption]
    elsif payload[:document].present?
      media_data = payload[:document]
      media_info[:id] = media_data[:media_path] || media_data[:id]
      media_info[:mime_type] = media_data[:mime_type]
      media_info[:caption] = media_data[:caption]
      media_info[:filename] = media_data[:filename]
    elsif payload[:sticker].present?
      media_data = payload[:sticker]
      media_info[:id] = media_data[:media_path] || media_data[:id]
      media_info[:mime_type] = media_data[:mime_type]
    else
      # Legacy format fallback
      media_url = payload[:image_url] || payload[:video_url] || payload[:audio_url] ||
                  payload[:document_url] || payload[:sticker_url] || payload[:media_url]

      if media_url
        media_info[:id] = media_url # Use URL as ID for download
        media_info[:mime_type] = payload[:mime_type] || infer_mime_type(media_url)
        media_info[:caption] = payload[:caption] if payload[:caption]
        media_info[:filename] = payload[:filename] if payload[:filename]
      end
    end

    media_info
  end

  def extract_location_info(payload)
    if payload[:location].present?
      # New webhook format
      location_data = payload[:location]
      {
        latitude: location_data[:degreesLatitude] || location_data[:latitude],
        longitude: location_data[:degreesLongitude] || location_data[:longitude],
        name: location_data[:name],
        address: location_data[:address],
        url: location_data[:url]
      }.compact
    else
      # Legacy format
      {
        latitude: payload[:latitude],
        longitude: payload[:longitude],
        name: payload[:location_name],
        address: payload[:location_address],
        url: payload[:location_url]
      }.compact
    end
  end

  def extract_contacts_info(payload)
    if payload[:contact].present?
      # New webhook format
      contact_data = payload[:contact]
      [{
        vcard: contact_data[:vcard],
        name: { formatted_name: contact_data[:displayName] }
      }.compact]
    elsif payload[:contact_vcard]
      # Parse vCard if available
      [{ vcard: payload[:contact_vcard] }]
    elsif payload[:contacts]
      payload[:contacts]
    else
      []
    end
  end

  def infer_mime_type(url)
    extension = File.extname(url).downcase
    case extension
    when '.jpg', '.jpeg' then 'image/jpeg'
    when '.png' then 'image/png'
    when '.gif' then 'image/gif'
    when '.mp4' then 'video/mp4'
    when '.mp3' then 'audio/mpeg'
    when '.wav' then 'audio/wav'
    when '.pdf' then 'application/pdf'
    when '.doc' then 'application/msword'
    when '.docx' then 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    else 'application/octet-stream'
    end
  end

  def map_receipt_status(receipt_type)
    status_map = {
      'delivered' => 'delivered',
      'read' => 'read',
      'sent' => 'sent'
    }

    status_map[receipt_type&.downcase] || 'delivered'
  end

  def download_attachment_file(attachment_payload)
    # Use the same pattern as WhatsApp Cloud service
    media_url = inbox.channel.media_url(attachment_payload[:id])
    Down.download(media_url, headers: inbox.channel.api_headers)
  rescue StandardError => e
    Rails.logger.error "Error downloading WhatsApp Web media: #{e.message}"
    nil
  end

  def message_content(message)
    # Override base method to handle WhatsApp Web specific types
    content = message.dig(:text, :body) ||
              message.dig(:button, :text) ||
              message.dig(:interactive, :button_reply, :title) ||
              message.dig(:interactive, :list_reply, :title) ||
              message.dig(:name, :formatted_name)

    # For location messages, return default content
    return 'Location shared' if message['type'] == 'location' && content.blank?
    # For contact messages, return default content
    return 'Contact shared' if message['type'] == 'contacts' && content.blank?
    # For reaction messages, content is already set in text.body
    return content if message['type'] == 'reaction' && content.present?

    content
  end

  # Check if the message is sent from the company's own WhatsApp number
  def message_from_company?(contact_from, contact_to)
    return false if contact_from.blank? || contact_to.blank?

    # Get the company's phone number from the inbox
    company_phone = extract_phone_number(inbox.channel.phone_number)
    from_phone = extract_phone_number(contact_from.dig(:profile, :identifier))

    Rails.logger.debug { "WhatsApp Web: Company phone: #{company_phone}, From phone: #{from_phone}" }

    # Message is from company if the sender phone matches the company phone
    company_phone == from_phone
  end

  # Check if the message is sent from the company's own WhatsApp number
  def message_to_group?(contact_from, contact_to)
    return false if contact_from.blank? || contact_to.blank?

    to_phone =  contact_to.dig(:profile, :identifier)
    to_phone.include?('@g.us')
  end

  # Setup contact inbox for the external contact (not the company)
  def setup_external_contact(external_contact_params)
    # Validate we have essential contact data
    return unless external_contact_params&.dig(:profile, :identifier).present?

    source_id = processed_waid(external_contact_params[:wa_id])

    # Check if contact_inbox already exists to avoid duplicates
    existing_contact_inbox = inbox.contact_inboxes.find_by(source_id: source_id)
    if existing_contact_inbox
      @contact_inbox = existing_contact_inbox
      @contact = existing_contact_inbox.contact
      Rails.logger.debug { "WhatsApp Web: Using existing contact_inbox for source_id: #{source_id}" }
      return
    end

    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: source_id,
      inbox: inbox,
      contact_attributes: {
        identifier: external_contact_params.dig(:profile, :identifier),
        name: external_contact_params.dig(:profile, :name),
        phone_number: external_contact_params.dig(:profile, :phone_number)
      }
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact

    # Update existing contact name if ProfileName is available and current name is just phone number
    update_contact_with_profile_name(external_contact_params)
  end

  # Setup company contact for outgoing messages
  def setup_company_contact(company_contact_params)
    # Validate we have essential contact data
    return unless company_contact_params&.dig(:profile, :identifier).present?

    company_phone = extract_phone_number(inbox.channel.phone_number)

    Rails.logger.info { "WhatsApp Web: Setting up company contact with phone: #{company_phone}" }

    source_id = processed_waid(company_contact_params[:wa_id])

    # Check if company contact_inbox already exists to avoid duplicates
    existing_company_contact_inbox = inbox.contact_inboxes.find_by(source_id: source_id)
    if existing_company_contact_inbox
      @company_contact = existing_company_contact_inbox.contact
      Rails.logger.debug { "WhatsApp Web: Using existing company contact_inbox for source_id: #{source_id}" }
      return
    end

    # Find or create company contact
    company_contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: source_id,
      inbox: inbox,
      contact_attributes: {
        identifier: company_contact_params.dig(:profile, :identifier),
        name: company_contact_params.dig(:profile, :name),
        phone_number: inbox.channel.phone_number
      }
    ).perform

    @company_contact = company_contact_inbox.contact
    Rails.logger.info { "WhatsApp Web: Company contact set: #{@company_contact.name} (ID: #{@company_contact.id})" }
  end
end
