class Whatsapp::WhatsappWebDeviceService
  include HTTParty

  base_uri ENV.fetch('WHATSAPP_WEB_API_URL', 'http://localhost:3000')

  def initialize(phone_number)
    @phone_number = normalize_phone_number(phone_number)
  end

  def create_device
    response = self.class.post(
      '/devices',
      body: { device_id: @phone_number }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    handle_response(response)
  end

  def device_info
    response = self.class.get("/devices/#{@phone_number}")
    handle_response(response)
  end

  def delete_device
    response = self.class.delete("/devices/#{@phone_number}")
    handle_response(response)
  end

  def qr_code
    response = self.class.get("/devices/#{@phone_number}/login")
    handle_response(response)
  end

  def device_status
    response = self.class.get("/devices/#{@phone_number}/status")
    handle_response(response)
  end

  def reconnect_device
    response = self.class.post("/devices/#{@phone_number}/reconnect")
    handle_response(response)
  end

  def logout_device
    response = self.class.post("/devices/#{@phone_number}/logout")
    handle_response(response)
  end

  private

  def normalize_phone_number(phone_number)
    # Remove + prefix if present, as device_id doesn't use it
    phone_number.to_s.gsub(/^\+/, '')
  end

  def handle_response(response)
    if response.success?
      response.parsed_response
    else
      Rails.logger.error "[WhatsApp Web Device Service] Error: #{response.code} - #{response.body}"
      raise CustomExceptions::Provider::ApiError, response.body
    end
  end
end
