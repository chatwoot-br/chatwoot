/* global axios */
import ApiClient from '../ApiClient';

class WhatsappWebChannel extends ApiClient {
  constructor() {
    super('whatsapp_web', { accountScoped: true });
  }

  createDevice(phoneNumber) {
    return axios.post(`${this.baseUrl()}/whatsapp_web/devices`, {
      phone_number: phoneNumber,
    });
  }

  getQRCode(inboxId) {
    return axios.get(
      `${this.baseUrl()}/whatsapp_web/devices/${inboxId}/qr_code`,
      {
        responseType: 'blob',
      }
    );
  }

  getDeviceStatus(inboxId) {
    return axios.get(
      `${this.baseUrl()}/whatsapp_web/devices/${inboxId}/status`
    );
  }

  reconnect(inboxId) {
    return axios.post(
      `${this.baseUrl()}/whatsapp_web/devices/${inboxId}/reconnect`
    );
  }

  logout(inboxId) {
    return axios.post(
      `${this.baseUrl()}/whatsapp_web/devices/${inboxId}/logout`
    );
  }

  syncHistory(inboxId) {
    return axios.post(
      `${this.baseUrl()}/whatsapp_web/devices/${inboxId}/sync_history`
    );
  }
}

export default new WhatsappWebChannel();
