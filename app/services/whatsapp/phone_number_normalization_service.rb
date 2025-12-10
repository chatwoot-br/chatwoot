# Service to handle phone number normalization for WhatsApp messages
# Currently supports Brazil and Argentina phone number format variations
# Supports both WhatsApp Cloud API and Twilio WhatsApp providers
class Whatsapp::PhoneNumberNormalizationService
  def initialize(inbox)
    @inbox = inbox
  end

  # @param raw_number [String] The phone number in provider-specific format
  #   - Cloud: "5541988887777" (clean number)
  #   - Twilio: "whatsapp:+5541988887777" (prefixed format)
  # @param provider [Symbol] :cloud or :twilio
  # @return [String] Normalized source_id in provider format or original if not found
  def normalize_and_find_contact_by_provider(raw_number, provider)
    # Extract clean number based on provider format
    clean_number = extract_clean_number(raw_number, provider)

    # Find appropriate normalizer for the country
    normalizer = find_normalizer_for_country(clean_number)
    return raw_number unless normalizer

    # Normalize the clean number
    normalized_clean_number = normalizer.normalize(clean_number)

    # Format for provider and check for existing contact
    provider_format = format_for_provider(normalized_clean_number, provider)

    # Try normalized format first
    existing_contact_inbox = find_existing_contact_inbox(provider_format)

    # Fallback: try raw format if normalized not found (handles legacy data)
    existing_contact_inbox ||= find_existing_contact_inbox(raw_number) if raw_number != provider_format

    # Fallback for Brazil: try alternate format (with/without 9 digit)
    if existing_contact_inbox.nil? && normalizer.is_a?(Whatsapp::PhoneNormalizers::BrazilPhoneNormalizer)
      alternate = brazil_alternate_format(clean_number)
      if alternate != clean_number
        alternate_format = format_for_provider(alternate, provider)
        existing_contact_inbox = find_existing_contact_inbox(alternate_format)
      end
    end

    # Always return normalized format for new contacts to ensure consistent storage
    existing_contact_inbox&.source_id || provider_format
  end

  private

  attr_reader :inbox

  # Returns the alternate Brazil phone format (with 9 if missing, without 9 if present)
  # Brazil numbers can be stored with or without the 9 digit after DDD
  # This allows finding contacts regardless of which format was originally stored
  def brazil_alternate_format(number)
    return number unless number.start_with?('55') && number.length >= 12

    ddd = number[2, 2]
    rest = number[4..]

    if number.length == 13 && rest.start_with?('9')
      # Has 9 (13 digits), return without 9 (12 digits)
      "55#{ddd}#{rest[1..]}"
    elsif number.length == 12
      # No 9 (12 digits), return with 9 (13 digits)
      "55#{ddd}9#{rest}"
    else
      number
    end
  end

  def find_normalizer_for_country(waid)
    NORMALIZERS.map(&:new)
               .find { |normalizer| normalizer.handles_country?(waid) }
  end

  def find_existing_contact_inbox(normalized_waid)
    inbox.contact_inboxes.find_by(source_id: normalized_waid)
  end

  # Extract clean number from provider-specific format
  def extract_clean_number(raw_number, provider)
    case provider
    when :twilio
      raw_number.gsub(/^whatsapp:\+/, '') # Remove prefix: "whatsapp:+5541988887777" → "5541988887777"
    else
      raw_number # Default fallback for unknown providers
    end
  end

  # Format normalized number for provider-specific storage
  def format_for_provider(clean_number, provider)
    case provider
    when :twilio
      "whatsapp:+#{clean_number}" # Add prefix: "5541988887777" → "whatsapp:+5541988887777"
    else
      clean_number # Default for :cloud and unknown providers: "5541988887777"
    end
  end

  NORMALIZERS = [
    Whatsapp::PhoneNormalizers::BrazilPhoneNormalizer,
    Whatsapp::PhoneNormalizers::ArgentinaPhoneNormalizer
  ].freeze
end
