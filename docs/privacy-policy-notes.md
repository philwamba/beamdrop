# BeamDrop Privacy Policy Notes

## Purpose

These notes define privacy commitments and disclosures for BeamDrop. They are not
a final legal privacy policy, but they describe the product behavior that the
policy must accurately reflect.

## Core Privacy Position

BeamDrop is local-first. Local network transfer must work without login and
without cloud upload. User content should move directly between trusted devices
where possible.

Optional relay or signaling services may be introduced later, but they must not
be required for MVP local transfer. If relay is used, the privacy policy and app
UI must explain what metadata the server processes and whether content remains
end-to-end protected.

## Data BeamDrop Handles

BeamDrop may handle:

- Selected files and folders.
- Text snippets.
- Links.
- Screenshots.
- Clipboard content when user-triggered or explicitly enabled.
- Device names.
- Device IDs.
- Public keys.
- Trusted device records.
- Transfer history.
- Local network endpoint information.

## Data Minimization

BeamDrop should minimize stored sensitive data:

- Do not store clipboard content longer than needed to send or receive it.
- Avoid retaining text previews in history by default.
- Store transfer history metadata without file contents.
- Allow users to clear transfer history.
- Do not upload content for local transfers.
- Do not include clipboard text, file contents, private keys, relay tokens, or
  decrypted payload metadata in logs or crash reports.

## Clipboard Privacy

iPhone cannot silently monitor clipboard in the background. BeamDrop iPhone
clipboard workflows must be manual through Share Sheet, Shortcuts, or Paste.

Android background clipboard access is restricted. BeamDrop Android clipboard
sending must be user-triggered where required.

Desktop apps can support stronger clipboard workflows with user permission. If
macOS or Windows watched clipboard features are implemented, the privacy policy
must disclose:

- What is monitored.
- When monitoring is active.
- Whether clipboard content is stored.
- How users pause or disable it.

BeamDrop should block sensitive-looking clipboard content from automatic or
tray-initiated sends by default. This includes password-like, token-like,
private-key-like, and card-number-like text. The policy should disclose that
this protection is heuristic and is not a guarantee that all sensitive text will
be detected.

## Device Trust Data

BeamDrop stores trusted device records locally so devices can recognize each
other after QR pairing. Trusted devices can be revoked. Revocation should be
reflected in local trust state and should block future trusted sends and large
transfer resume from that device.

## Local Network Data

BeamDrop may use local network information to discover and connect to nearby
trusted devices. Public and corporate Wi-Fi may block discovery, so BeamDrop may
offer manual IP or QR fallback.

The privacy policy should explain that local IP addresses and device names may be
visible to paired devices as part of local transfer.

## Optional Relay or Signaling Data

If optional servers are added, document:

- Whether the server is relay, signaling, or both.
- Whether login is required for that feature.
- What metadata is processed.
- Whether file content is end-to-end encrypted and that relay upload must be
  client-side encrypted before the server receives it.
- Retention duration for logs.
- Whether relay is optional.
- How quickly relay tokens and encrypted temporary blobs expire.

For MVP, optional remote relay must not be required.

## Permissions Disclosure

The privacy policy and in-app education must cover:

- Camera for QR pairing.
- Local network for nearby transfer.
- Notifications for incoming transfer prompts and completion.
- Files/photos for selected send and receive actions.
- Clipboard for platform-supported manual or opt-in workflows.

## User Controls

BeamDrop must provide:

- Revoke trusted device.
- Clear transfer history.
- Disable clipboard features.
- Change receive destination.
- Cancel active transfer.
- Reject incoming transfer.
- Disable optional relay if implemented as a user setting.

## Privacy Review Checklist

- Local transfer works without login.
- No cloud upload occurs for local transfer.
- Unknown devices cannot send without approval.
- Trusted devices can be revoked.
- Clipboard behavior is platform-compliant.
- History does not retain sensitive content unnecessarily.
- Permission explanations match actual behavior.
- Relay or signaling behavior is disclosed if present.
