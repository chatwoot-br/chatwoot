/* global axios */
import ApiClient from './ApiClient';

class WhatsappAdminApi extends ApiClient {
  constructor() {
    super('whatsapp_web/gateway', { accountScoped: true });
  }

  checkAdminApiStatus(baseUrl = null, apiToken = null) {
    const params = {};
    if (baseUrl) params.base_url = baseUrl;
    if (apiToken) params.api_token = apiToken;

    return axios.get(`${this.url}/admin_api_status`, { params });
  }

  provisionInstance(phoneNumber) {
    return axios.post(`${this.url}/provision_instance`, {
      phone_number: phoneNumber,
    });
  }

  getAvailableInstances() {
    return axios.get(`${this.url}/available_instances`);
  }
}

export default new WhatsappAdminApi();
