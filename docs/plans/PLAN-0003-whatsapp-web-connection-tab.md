# Plan: WhatsApp Web Connection Management Tab

## Status: Implemented

## Overview
Add a "WhatsApp Web Connection" tab to the inbox settings page for `whatsapp_web` provider inboxes. This tab will display connection status and provide controls to login (QR code), logout, and reconnect.

## UX Design

### Tab Location
- Add new tab "Connection" after "Settings" tab (only visible for `whatsapp_web` provider)
- Tab order: Settings | **Connection** | Collaborators | Business Hours | CSAT | Bot Configuration

### Connection Status Section
Display a status card with:
- **Status Badge**: Green "Connected" / Red "Disconnected" / Yellow "Connecting..."
- **Phone Number**: Display the connected phone number
- **Last Updated**: Timestamp of last status check

### Action Buttons
Based on connection state:
- **Disconnected State**:
  - Primary: "Connect with QR Code" button → Opens QR code modal
- **Connected State**:
  - Secondary: "Reconnect" button
  - Danger: "Disconnect" button (with confirmation)
- **Connecting State**:
  - Show loading spinner, disable all actions

### QR Code Modal
When user clicks "Connect with QR Code":
- Modal with QR code image (same as inbox creation flow)
- Instructions for scanning
- "Refresh QR Code" button
- Auto-close on successful connection (poll status)

---

## Files Created

### 1. WhatsApp Web Connection Component
**`app/javascript/dashboard/routes/dashboard/settings/inbox/components/WhatsAppWebConnection.vue`**

```
<script setup>
- Props: inbox (object)
- State: deviceStatus, isLoading, showQRModal, qrCodeUrl, pollInterval
- Computed: isConnected, isDisconnected, statusBadgeColor
- Methods:
  - fetchDeviceStatus() - GET /api/v1/accounts/:id/whatsapp_web/devices/:inbox_id/status
  - handleConnect() - Show QR modal, start polling
  - handleReconnect() - POST reconnect, refetch status
  - handleDisconnect() - Confirm dialog, POST logout, refetch status
  - fetchQRCode() - Get QR code blob
  - startStatusPolling() / stopStatusPolling()
- Lifecycle: onMounted → fetchDeviceStatus()
</script>

<template>
- Status card with badge and phone number
- Action buttons based on state
- QR Code modal (v-if showQRModal)
</template>
```

---

## Files Modified

### 1. Settings.vue - Add Tab
**`app/javascript/dashboard/routes/dashboard/settings/inbox/Settings.vue`**

Added computed property:
```javascript
isAWhatsAppWebChannel() {
  return (
    this.channelType === INBOX_TYPES.WHATSAPP &&
    this.inbox.provider === 'whatsapp_web'
  );
}
```

Added to `tabs()` computed:
```javascript
if (this.isAWhatsAppWebChannel) {
  visibleToAllChannelTabs.splice(1, 0, {
    key: 'whatsapp-web-connection',
    name: this.$t('INBOX_MGMT.TABS.CONNECTION'),
  });
}
```

Added conditional render in template:
```vue
<WhatsAppWebConnection
  v-if="selectedTabKey === 'whatsapp-web-connection'"
  :inbox="inbox"
/>
```

### 2. Translations
**`app/javascript/dashboard/i18n/locale/en/inboxMgmt.json`**

Added to TABS:
```json
"CONNECTION": "Connection"
```

Added new section:
```json
"WHATSAPP_WEB_CONNECTION": {
  "TITLE": "WhatsApp Web Connection",
  "DESCRIPTION": "Manage your WhatsApp Web connection status",
  "PHONE_NUMBER": "Phone Number",
  "STATUS": {
    "CONNECTED": "Connected",
    "DISCONNECTED": "Disconnected",
    "CONNECTING": "Connecting...",
    "LABEL": "Connection Status"
  },
  "ACTIONS": {
    "CONNECT": "Connect with QR Code",
    "RECONNECT": "Reconnect",
    "DISCONNECT": "Disconnect",
    "REFRESH_QR": "Refresh QR Code",
    "CLOSE": "Close"
  },
  "QR_MODAL": {
    "TITLE": "Scan QR Code to Connect",
    "DESCRIPTION": "Open WhatsApp on your phone and scan this QR code",
    "INSTRUCTIONS": {
      "STEP_1": "Open WhatsApp on your phone",
      "STEP_2": "Tap Menu or Settings and select Linked Devices",
      "STEP_3": "Point your phone at this screen to capture the QR code"
    },
    "WAITING": "Waiting for connection..."
  },
  "DISCONNECT_CONFIRM": {
    "TITLE": "Disconnect WhatsApp?",
    "MESSAGE": "This will disconnect your WhatsApp account. You'll need to scan the QR code again to reconnect.",
    "CONFIRM": "Yes, Disconnect",
    "CANCEL": "Cancel"
  },
  "ALERTS": {
    "RECONNECT_SUCCESS": "WhatsApp reconnected successfully",
    "RECONNECT_ERROR": "Failed to reconnect. Please try again.",
    "DISCONNECT_SUCCESS": "WhatsApp disconnected successfully",
    "DISCONNECT_ERROR": "Failed to disconnect. Please try again.",
    "STATUS_ERROR": "Failed to fetch connection status"
  }
}
```

---

## Implementation Order

1. **Add translations** - Add i18n strings to `inboxMgmt.json` ✅
2. **Create component** - Create `WhatsAppWebConnection.vue` with all functionality ✅
3. **Integrate tab** - Modify `Settings.vue` to add tab and render component ✅
4. **Test** - Verify all states and actions work correctly ✅

---

## Component Details

### Status Badge Colors (Tailwind)
- Connected: `bg-n-teal-3 text-n-teal-11`
- Disconnected: `bg-n-ruby-3 text-n-ruby-11`
- Connecting: `bg-n-amber-3 text-n-amber-11`

### API Endpoints Used
- `GET /api/v1/accounts/:account_id/whatsapp_web/devices/:inbox_id/status`
- `GET /api/v1/accounts/:account_id/whatsapp_web/devices/:inbox_id/qr_code`
- `POST /api/v1/accounts/:account_id/whatsapp_web/devices/:inbox_id/reconnect`
- `POST /api/v1/accounts/:account_id/whatsapp_web/devices/:inbox_id/logout`

### Polling Strategy
- Poll status every 3 seconds when QR modal is open
- Stop polling when connected or modal closed
- Max poll time: 3 minutes (same as inbox creation flow)
