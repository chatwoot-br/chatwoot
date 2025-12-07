class Whatsapp::InstanceProvisioningService
  class NoPortsAvailableError < StandardError; end
  class ProvisioningTimeoutError < StandardError; end

  DEFAULT_PORT_RANGE_START = 3001
  DEFAULT_PORT_RANGE_END = 3100
  MAX_PORT_ALLOCATION_RETRIES = 3
  INSTANCE_RUNNING_TIMEOUT = 30
  GATEWAY_READY_TIMEOUT = 10
  HTTP_TIMEOUT = 3

  def initialize(account)
    @account = account
    @admin_client = Whatsapp::AdminApiClient.new(account)
  end

  def provision(phone_number:, webhook_secret:)
    Rails.logger.info "[WHATSAPP] Starting instance provisioning for #{phone_number}"

    basic_auth = generate_basic_auth
    webhook_url = build_webhook_url(phone_number)

    # Clean phone number for use as base_path (remove + prefix)
    clean_phone = phone_number.to_s.gsub(/[^\d]/, '')

    port = provision_with_retry(webhook_url, webhook_secret, basic_auth, clean_phone)

    gateway_base_url = build_gateway_url(port)

    Rails.logger.info "[WHATSAPP] Successfully provisioned instance at #{gateway_base_url}"

    {
      gateway_base_url: gateway_base_url,
      port: port,
      basic_auth_user: basic_auth[:user],
      basic_auth_password: basic_auth[:password],
      webhook_url: webhook_url,
      webhook_secret: webhook_secret
    }
  rescue Whatsapp::AdminApiClient::AdminApiError => e
    Rails.logger.error "[WHATSAPP] Provisioning failed: #{e.message}"
    raise
  end

  private

  def provision_with_retry(webhook_url, webhook_secret, basic_auth, clean_phone)
    retries = 0

    loop do
      port = find_available_port
      raise NoPortsAvailableError, 'No available ports in configured range' if port.nil?

      Rails.logger.info "[WHATSAPP] Creating instance on port #{port} with webhook #{webhook_url} and base_path /#{clean_phone}"

      begin
        @admin_client.create_instance(
          port: port,
          webhook: webhook_url,
          webhook_secret: webhook_secret,
          basic_auth: basic_auth[:combined],
          base_path: "/#{clean_phone}"
        )

        wait_for_running(port, clean_phone)
        return port
      rescue Whatsapp::AdminApiClient::ConflictError => e
        retries += 1
        Rails.logger.warn "[WHATSAPP] Port #{port} conflict (attempt #{retries}/#{MAX_PORT_ALLOCATION_RETRIES}): #{e.message}"

        if retries >= MAX_PORT_ALLOCATION_RETRIES
          raise NoPortsAvailableError, "Failed to allocate port after #{MAX_PORT_ALLOCATION_RETRIES} attempts due to conflicts"
        end

        # Retry with next available port
        next
      end
    end
  end

  def find_available_port
    existing = @admin_client.list_instances
    used_ports = existing.is_a?(Array) ? existing.pluck('port') : []

    range_start = @account.whatsapp_admin_port_range_start || DEFAULT_PORT_RANGE_START
    range_end = @account.whatsapp_admin_port_range_end || DEFAULT_PORT_RANGE_END

    Rails.logger.debug { "[WHATSAPP] Searching for available port in range #{range_start}..#{range_end}, used ports: #{used_ports}" }

    (range_start..range_end).find { |p| used_ports.exclude?(p) }
  end

  def generate_basic_auth
    user = SecureRandom.alphanumeric(8)
    password = SecureRandom.alphanumeric(16)
    { user: user, password: password, combined: "#{user}:#{password}" }
  end

  def build_webhook_url(phone_number)
    # Use INTERNAL_API_URL for container-to-container communication (gateway -> Rails)
    # Fall back to FRONTEND_URL for non-containerized setups
    base = ENV.fetch('INTERNAL_API_URL', nil) || ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
    # Remove + prefix and non-digit characters from phone number for URL
    clean_phone = phone_number.to_s.gsub(/[^\d]/, '')
    "#{base}/webhooks/whatsapp_web/#{clean_phone}"
  end

  def build_gateway_url(port)
    base_url = @account.whatsapp_admin_api_base_url.chomp('/')
    # Extract host from Admin API URL and use same for gateway
    uri = URI.parse(base_url)
    "#{uri.scheme}://#{uri.host}:#{port}"
  end

  def wait_for_running(port, phone_path, timeout: INSTANCE_RUNNING_TIMEOUT, interval: 2)
    Rails.logger.info "[WHATSAPP] Waiting for instance on port #{port} to become RUNNING"
    start_time = Time.current
    max_time = start_time + timeout.seconds

    loop do
      instance = @admin_client.get_instance(port)

      if instance['state'] == 'RUNNING'
        Rails.logger.info "[WHATSAPP] Instance on port #{port} is now RUNNING"
        # Wait for gateway to actually be ready to accept connections
        wait_for_gateway_ready(port, phone_path)
        return true
      end

      if Time.current >= max_time
        raise ProvisioningTimeoutError, "Instance did not reach RUNNING state within #{timeout} seconds (current state: #{instance['state']})"
      end

      Rails.logger.debug { "[WHATSAPP] Instance state: #{instance['state']}, waiting..." }
      sleep(interval)
    end
  end

  def wait_for_gateway_ready(port, phone_path, timeout: GATEWAY_READY_TIMEOUT, interval: 1)
    gateway_url = build_gateway_url(port)
    check_url = "#{gateway_url}/#{phone_path}/app/devices"
    Rails.logger.info "[WHATSAPP] Waiting for gateway at #{check_url} to accept connections"

    start_time = Time.current
    max_time = start_time + timeout.seconds

    loop do
      begin
        response = HTTParty.get(check_url, timeout: HTTP_TIMEOUT)
        if response.success?
          Rails.logger.info "[WHATSAPP] Gateway at #{check_url} is ready"
          return true
        end
      rescue StandardError => e
        Rails.logger.debug { "[WHATSAPP] Gateway not ready yet: #{e.message}" }
      end

      if Time.current >= max_time
        Rails.logger.warn '[WHATSAPP] Gateway readiness check timed out, proceeding anyway'
        return true
      end

      sleep(interval)
    end
  end
end
