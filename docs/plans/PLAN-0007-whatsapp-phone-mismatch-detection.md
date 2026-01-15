# Plan: Phone Number Mismatch Detection for WhatsApp Web Connection

## Status: Implemented

## Problem Statement
When a user connects a WhatsApp account via QR code scan, the system didn't validate if the connected phone number matches the expected phone number configured in the inbox. This caused messages to not appear in the inbox when a different phone was connected (e.g., user configured inbox for `+55998762522` but scanned with `+5521998762522`).

## Solution Overview
Add phone number validation after successful QR code scan. If the connected phone doesn't match the expected phone, show an error message, auto-disconnect the device, and provide clear UX for recovery.

## Files Modified

### 1. Backend - Devices Controller
**File:** `app/controllers/api/v1/accounts/whatsapp_web/devices_controller.rb`

**Changes:**
- Fixed `fetch_device_status_from_api` to use `GET /devices/:device_id` instead of `/devices/:id/status`
- The `/status` endpoint only returned connection state, not the actual JID
- Now returns `{ state, jid, display_name }` for proper phone validation

### 2. Frontend - Inbox Creation Wizard
**File:** `app/javascript/dashboard/routes/dashboard/settings/inbox/channels/WhatsappWeb.vue`

**Changes:**
- Added phone number validation helpers (`extractPhoneFromJid`, `normalizePhone`, `isPhoneMismatch`)
- After status polling returns `logged_in`, compare `response.data.jid` with expected `phoneNumber`
- If mismatch: show amber warning with icon, call logout API, stop polling, show "Go back" link
- Added `goBackToPhoneInput()` function to let users fix the phone number

### 3. Frontend - Connection Settings Page
**File:** `app/javascript/dashboard/routes/dashboard/settings/inbox/components/WhatsAppWebConnection.vue`

**Changes:**
- Added phone validation helpers (same as above)
- Added `mismatchError` ref for QR modal error state
- Added `phoneMismatchInfo` ref for page-load mismatch detection
- QR modal now shows error state with "Try Again" and "Close" buttons when mismatch detected
- Page shows warning banner if existing connection has phone mismatch
- `handleCloseQRModal` now refreshes device status to prevent stuck "Connecting..." state

### 4. i18n Translations
**File:** `app/javascript/dashboard/i18n/locale/en/inboxMgmt.json`

**New keys added:**
```json
// In ADD.WHATSAPP_WEB.QR_CODE:
"PHONE_MISMATCH": "Phone number mismatch. Expected {expected} but connected {connected}. Please scan with the correct WhatsApp account.",
"GO_BACK": "Go back to change phone number"

// In WHATSAPP_WEB_CONNECTION.ALERTS:
"PHONE_MISMATCH": "Phone number mismatch. Expected {expected} but connected {connected}. Please scan with the correct WhatsApp account."

// In WHATSAPP_WEB_CONNECTION.PHONE_MISMATCH:
"TITLE": "Wrong WhatsApp Account Connected",
"HELP": "Messages will not be received correctly until you connect with the correct phone number. Click Disconnect to sign out and scan the QR code again with the correct account."

// In WHATSAPP_WEB_CONNECTION.QR_MODAL.ERROR:
"TITLE": "Wrong WhatsApp Account",
"MESSAGE": "You scanned with {connected} but this inbox is configured for {expected}. Please scan with the correct WhatsApp account.",
"TRY_AGAIN": "Try Again"
```

## Implementation Details

### Phone Number Extraction Helper
```javascript
// Extract phone from JID: "5521998762522@s.whatsapp.net" → "5521998762522"
const extractPhoneFromJid = (jid) => {
  if (!jid) return '';
  return jid.split('@')[0];
};
```

### Phone Number Comparison Logic
```javascript
// Normalize for comparison (remove all non-digits)
const normalizePhone = (phone) => {
  if (!phone) return '';
  return phone.replace(/\D/g, '');
};

const isPhoneMismatch = (expectedPhone, connectedJid) => {
  const expected = normalizePhone(expectedPhone);
  const connected = normalizePhone(extractPhoneFromJid(connectedJid));
  return expected && connected && expected !== connected;
};
```

### Backend Fix - Correct Endpoint
```ruby
def fetch_device_status_from_api(device_id)
  # Use GET /devices/:device_id to get both status and JID
  # The /status endpoint doesn't return the actual JID from WhatsApp
  url = "#{whatsapp_web_api_url}/devices/#{device_id}"
  response = HTTParty.get(url, **http_options('X-Device-Id' => device_id))

  return { state: 'disconnected' } if !response.success? && response.body.to_s.include?('not found')

  results = handle_api_response(response, 'fetch device info')['results'] || {}
  state = results['state'] || 'disconnected'
  # ... state mapping logic ...

  { state: state, jid: results['jid'], display_name: results['display_name'] }
end
```

## UX Flow

### Inbox Creation Wizard
1. User enters phone number and clicks "Generate QR Code"
2. User scans QR code with wrong phone
3. System detects mismatch, logs out wrong device
4. Amber warning box appears with:
   - Warning icon
   - Error message showing expected vs connected numbers
   - "Go back to change phone number" link
5. User can go back to fix phone or try scanning again

### Settings Page - QR Modal
1. User clicks "Connect with QR Code"
2. User scans QR code with wrong phone
3. Modal switches to error state with:
   - Red warning icon
   - "Wrong WhatsApp Account" title
   - Message showing expected vs connected numbers
   - "Try Again" button (fetches new QR code)
   - "Close" button (closes modal, refreshes status)

### Settings Page - Page Load Detection
1. Page loads and fetches device status
2. If connected but phone mismatches, shows warning banner
3. Banner includes Disconnect button for easy recovery

## Verification Steps

1. **Test Creation Wizard:**
   - Create new WhatsApp Web inbox with phone +55998762522
   - Scan QR code with a different phone (e.g., +5521998762522)
   - Verify: Amber warning shown, "Go back" link works, device disconnected

2. **Test Settings Page QR Modal:**
   - Open existing WhatsApp Web inbox settings
   - Click Connect with QR Code
   - Scan with different phone
   - Verify: Modal shows error state, "Try Again" fetches new QR

3. **Test Settings Page Close Modal:**
   - Open QR modal, close without scanning
   - Verify: Status shows "Disconnected", not stuck on "Connecting..."

4. **Test Page Load Detection:**
   - Have inbox with mismatched phone connected
   - Navigate to settings page
   - Verify: Warning banner appears with Disconnect button

5. **Test Happy Path:**
   - Create/reconnect with matching phone number
   - Verify: Connection succeeds normally

## Edge Cases Handled

- JID format variations (e.g., `5521995539939@s.whatsapp.net`)
- Phone number format variations (with/without `+`, with spaces)
- Missing JID in status response (fallback to no validation)
- Logout API failure (ignore and still show error)
- Modal closed without action (refresh status to prevent stuck state)
- Existing mismatch on page load (show warning banner)
