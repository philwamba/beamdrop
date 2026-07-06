# BeamDrop States and Dialogs

## State Principles

BeamDrop states must be explicit and actionable. The app should never leave the
user wondering whether content was sent, received, verified, rejected, or blocked.

## Empty States

### No Trusted Devices

Message:

- "No trusted devices yet."
- "Pair with QR code to send locally without logging in."

Actions:

- Pair with QR.
- Scan QR.
- Manual IP.

### No Nearby Devices

Message:

- "No nearby devices found."
- "Public or corporate Wi-Fi may block local discovery."

Actions:

- Try again.
- Manual IP.
- Network diagnostics.

### No Transfer History

Message:

- "No transfers yet."
- "Sent and received items will appear here after completion."

Action:

- Send something.

### Clipboard Unavailable

Message varies by platform:

- iPhone: "Clipboard sending is manual on iPhone."
- Android: "Android requires user-triggered clipboard sending."
- Desktop: "Enable clipboard features in Settings."

## Loading States

Required loading states:

- Scanning nearby devices.
- Generating QR code.
- Connecting.
- Waiting for approval.
- Preparing transfer.
- Sending chunks.
- Receiving chunks.
- Verifying file hash.
- Resuming transfer.

Long states need cancel where safe.

## Error States

### Discovery Blocked

Copy:

- "BeamDrop could not find devices on this network."
- "Some public or corporate Wi-Fi networks block local discovery."

Actions:

- Manual IP.
- Show QR fallback.
- Open diagnostics.

### Pairing Expired

Copy:

- "This QR code expired."

Actions:

- Refresh QR.
- Scan again.

### Hash Verification Failed

Copy:

- "The received file did not pass verification."
- "BeamDrop did not save it as a completed transfer."

Actions:

- Retry.
- Cancel.

### Transfer Interrupted

Copy:

- "Transfer interrupted."
- "Resume is available for this large transfer."

Actions:

- Resume.
- Cancel.
- Diagnostics.

### Permission Denied

Copy must name the permission and why BeamDrop needs it:

- Camera: QR scanning.
- Local network: local transfer.
- Notifications: incoming requests.
- Files/photos: selected send and save actions.

Action:

- Open Settings.

## Confirmation Dialogs

### Revoke Trusted Device

Title:

- "Revoke this device?"

Body:

- "BeamDrop will block future trusted sends and transfer resume from this device
  until you pair again with QR code."

Actions:

- Revoke.
- Cancel.

### Cancel Transfer

Title:

- "Cancel transfer?"

Body:

- "Received chunks will be removed unless this transfer can be resumed."

Actions:

- Cancel transfer.
- Keep sending.

### Clear History

Title:

- "Clear transfer history?"

Body:

- "This removes local history entries. It does not delete files already saved on
  this device."

Actions:

- Clear.
- Cancel.

## Receive-File Approval Dialog

Required for unknown senders.

Content:

- Sender name.
- Sender platform.
- Trust state.
- Transfer type.
- Item count.
- Total size.
- Destination.
- Route.

Actions:

- Accept.
- Reject.

Optional secondary action:

- Pair after accepting, only after explaining trust.

Unknown sender note:

- "Accepting this transfer does not trust this device."

## Permission Explanation Screens

Every permission explanation must include:

- What BeamDrop wants to do.
- Why it matters.
- What happens if declined.
- Link or action to continue without the permission where possible.

Examples:

- Local network: "Find and transfer to nearby trusted devices without cloud
  upload."
- Camera: "Scan QR codes to pair trusted devices."
- Notifications: "Show incoming transfer requests when BeamDrop is not open."
- Clipboard: platform-specific manual or opt-in explanation.

## Focus and Accessibility States

- Every dialog action must be reachable by keyboard on desktop.
- Default action must be clear but not dangerous.
- Destructive actions must not be the default focused action.
- Screen readers must announce title, sender, transfer size, and actions in
  receive dialogs.
