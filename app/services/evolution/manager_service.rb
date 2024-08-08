class Evolution::ManagerService
  def api_headers(api_key)
    { 'apikey' => api_key, 'Content-Type' => 'application/json' }
  end

  def create(account_id, name, webhook_url, api_key, access_token)
    response = HTTParty.post(
      "#{webhook_url}/instance/create",
      headers: api_headers(api_key),
      body: {
        instanceName: name,
        token: SecureRandom.uuid,
        qrcode: true,
        # number: phone_number,
        auto_create: false,
        chatwoot_name_inbox: name,
        chatwoot_account_id: account_id,
        chatwoot_token: access_token,
        chatwoot_url: ENV.fetch('FRONTEND_URL', 'http://localhost:3000'),
        chatwoot_sign_msg: true,
        chatwoot_reopen_conversation: true,
        chatwoot_conversation_pending: false,
        chatwoot_import_messages: false,
        chatwoot_import_contacts: false,
        chatwoot_merge_brazil_contacts: true,
        chatwoot_days_limit_import_messages: 0
      }.to_json
    )

    process_response(response)
  end

  def process_response(response)
    if response.success?
      Rails.logger.info("HTTP Request Successful: #{response}")
    else
      Rails.logger.error response.body
      nil
    end
  end
end
