# BeamDrop Transfer Flow UI

## Goal

The transfer UI must make progress, trust, route, and verification clear. A user
should know what is moving, where it is going, whether it is local, and whether
it finished safely.

## Send Entry Points

Mobile:

- Share Sheet or Android share intent.
- Home Send action.
- Send Text screen.
- Send File screen.
- Manual clipboard send.

Desktop:

- Drag-and-drop area.
- Menu bar/tray quick send.
- Native file picker.
- Context/share integration where available.
- Clipboard quick send when enabled.

## Transfer Preparation

Before sending, show:

- Selected item count.
- Total size.
- Target device.
- Route if known.
- Warning if target is unknown or manual.

Large files:

- Show that BeamDrop will resume if interrupted.
- Do not expose chunking as primary copy unless in details.

## Transfer Progress UI

Required fields:

- Direction: Sending or receiving.
- Other device.
- Current item.
- Overall progress.
- Bytes transferred.
- Total size.
- Speed.
- Route: Local, Manual IP, or future Relay.
- Verification state.

Actions:

- Pause where supported.
- Cancel.
- Resume after interruption.
- Retry after failure.

## Progress Details

Primary progress should be simple. Details can reveal:

- Current chunk range.
- Manifest ID.
- Hash verification state.
- Connection route.
- Error code for support.

Do not show protocol internals by default.

## Transfer Complete UI

Complete state must show:

- Verified status.
- Saved location.
- Open action.
- Reveal in Finder/Explorer on desktop.
- Send another action.

Copy:

- "Transfer complete."
- "Verified and saved to Downloads."

## Transfer Failed UI

Failure states:

- Receiver rejected.
- Network interrupted.
- Hash verification failed.
- Insufficient storage.
- Destination unavailable.
- Trust revoked.
- Resume unavailable.

Each failure must include a next action:

- Retry.
- Resume.
- Change destination.
- Open diagnostics.
- Pair again.
- Cancel.

## Receive Prompt UI

Required:

- Sender identity.
- Platform.
- Trust state.
- Content summary.
- Total size.
- Destination.
- Accept.
- Reject.

Unknown devices:

- Cannot auto-send.
- Must show approval before content is accepted.

Trusted devices:

- May use user-configured auto-accept rules, but the user must be able to change
  them in Settings.

## Clipboard Transfer UI

iPhone:

- Manual Share Sheet, Shortcuts, or Paste flow.
- No background clipboard monitor UI.

Android:

- User-triggered clipboard send.
- Explain restrictions when unavailable.

macOS/Windows:

- Opt-in clipboard watching if implemented.
- Visible active/paused state.
- Quick pause control.

## Resume UI

Resume available state:

- Show partial progress.
- Show original sender/receiver.
- Show "Resume" primary action.
- Show "Cancel and remove partial data" destructive action.

Resume unavailable state:

- Explain why: manifest changed, trust revoked, staged data missing, or sender
  unavailable.
