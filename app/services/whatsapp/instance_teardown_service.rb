class Whatsapp::InstanceTeardownService
  def initialize(channel)
    @channel = channel
  end

  def perform
    Rails.logger.info "[WHATSAPP] Teardown check - provider: #{@channel.provider}, provisioned: #{@channel.provider_config['provisioned'].inspect}"

    unless should_teardown?
      Rails.logger.info '[WHATSAPP] Skipping teardown - not a provisioned whatsapp_web instance'
      return
    end

    port = @channel.provider_config['instance_port']
    Rails.logger.info "[WHATSAPP] Tearing down provisioned instance on port #{port}"

    admin_client = Whatsapp::AdminApiClient.new(@channel.account)
    admin_client.delete_instance(port)

    Rails.logger.info "[WHATSAPP] Successfully deleted instance on port #{port}"
  rescue Whatsapp::AdminApiClient::NotConfiguredError => e
    Rails.logger.warn "[WHATSAPP] Cannot teardown instance - Admin API not configured: #{e.message}"
  rescue Whatsapp::AdminApiClient::NotFoundError => e
    Rails.logger.warn "[WHATSAPP] Instance on port #{port} not found (may have been deleted already): #{e.message}"
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP] Instance teardown failed: #{e.message}"
  end

  private

  def should_teardown?
    return false unless @channel.provider == 'whatsapp_web'

    # Handle both boolean true and string "true" from JSON serialization
    provisioned = @channel.provider_config['provisioned']
    ActiveModel::Type::Boolean.new.cast(provisioned)
  end
end
