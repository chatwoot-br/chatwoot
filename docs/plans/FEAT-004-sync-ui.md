# Plan: Add Sync History Button with User Feedback

## Overview
Add a "Sync History" button to the WhatsApp Web Settings page and provide visual feedback about the message import process.

## Current State
- Backend `HistorySyncApiJob` stores sync status in `provider_config['history_sync_status']`
- Frontend already has `syncHistory` API method
- Basic i18n translations exist (`STARTED`, `ERROR`)

## UI Enhancement Plan

### 1. Add Sync Button
Add a "Sync History" button next to the existing action buttons when:
- Mode is `edit`
- Connection status is `CONNECTED`

Button properties:
- Icon: `i-lucide-download` (or `i-lucide-history`)
- Color: `purple` or `slate` (to differentiate from other actions)
- Shows loading state while syncing

### 2. Add Sync Status Section
Display sync status below connection status showing:
- **Not synced**: No previous sync
- **In Progress**: Syncing with spinner animation
- **Completed**: Show when completed with timestamp and stats
- **Failed**: Show error state with retry option

### 3. Visual Design
Create a status card/section with:
- Icon indicating state
- Status text (Never synced / Syncing... / Synced X messages / Failed)
- Timestamp of last sync
- Stats: messages imported, chats processed

## Files to Modify

### `app/javascript/dashboard/routes/dashboard/settings/inbox/channels/whatsapp/WhatsappWebForm.vue`

**New reactive state:**
```javascript
const isSyncing = ref(false);
const syncStatus = ref(null); // 'in_progress', 'completed', 'failed'
const syncStats = ref(null);  // { messages_imported, chats_processed }
const lastSyncAt = ref(null);
```

**New computed:**
```javascript
const showSyncButton = computed(() => {
  return connectionStatusText.value === 'CONNECTED';
});

const syncStatusFromConfig = computed(() => {
  return props.inbox?.provider_config?.history_sync_status;
});
```

**New method:**
```javascript
const syncHistory = async () => {
  isSyncing.value = true;
  try {
    await WhatsappWebGatewayApi.syncHistory(props.inbox.id);
    useAlert(t('INBOX_MGMT.ADD.WHATSAPP_WEB.HISTORY_SYNC.STARTED'));
    // Poll or update status after short delay
  } catch (error) {
    useAlert(t('INBOX_MGMT.ADD.WHATSAPP_WEB.HISTORY_SYNC.ERROR'));
  } finally {
    isSyncing.value = false;
  }
};
```

**Template additions:**
1. Sync History button in the action buttons row
2. Sync status section below connection status

### `app/javascript/dashboard/i18n/locale/en/inboxMgmt.json`

Expand HISTORY_SYNC translations:
```json
"HISTORY_SYNC": {
  "TITLE": "Sync History",
  "BUTTON": "Sync Messages",
  "STARTED": "Message history sync started in the background",
  "ERROR": "Failed to start history sync",
  "STATUS": {
    "LABEL": "Message Sync",
    "NEVER": "Not synced yet",
    "IN_PROGRESS": "Syncing messages...",
    "COMPLETED": "Synced successfully",
    "FAILED": "Sync failed"
  },
  "STATS": {
    "MESSAGES": "%{count} messages imported",
    "CHATS": "%{count} conversations"
  },
  "LAST_SYNC": "Last synced %{time}"
}
```

## Implementation Steps

1. **Add state variables** for sync status tracking
2. **Add computed properties** to read sync status from inbox config
3. **Add sync button** in the buttons section (after Restart Connection)
4. **Add sync status section** below connection status with:
   - Status badge (similar to connection status)
   - Stats display when completed
   - Last sync timestamp
5. **Add i18n translations**
6. **Initialize sync status** from `inbox.provider_config` on mount/watch

## Design Aesthetic
Match existing Chatwoot design:
- Use same badge styling as connection status
- Purple/violet color for sync-related elements (differentiate from connection green/red)
- Subtle animation for in-progress state
- Clean stats display with small text
