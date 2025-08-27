/* global axios */
import ApiClient from './ApiClient';

class WhatsappWebGatewayApi extends ApiClient {
  constructor() {
    super('whatsapp_web/gateway', { accountScoped: true });
  }

  login(inboxId) {
    return axios.get(`${this.url}/${inboxId}/login`);
  }

  loginWithCode(inboxId, phone) {
    return axios.get(`${this.url}/${inboxId}/login_with_code`, {
      params: { phone },
    });
  }

  getDevices(inboxId) {
    return axios.get(`${this.url}/${inboxId}/devices`);
  }

  logout(inboxId) {
    return axios.get(`${this.url}/${inboxId}/logout`);
  }

  reconnect(inboxId) {
    return axios.get(`${this.url}/${inboxId}/reconnect`);
  }

  syncHistory(inboxId) {
    return axios.post(`${this.url}/${inboxId}/sync_history`);
  }
}

export default new WhatsappWebGatewayApi();
