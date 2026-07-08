# BeamDrop Security Model

## Security Objectives

BeamDrop must protect user content during discovery, pairing, transfer, storage,
and history display. The core security model is explicit trust: devices must be
paired or approved before receiving files, and trusted devices can be revoked.

## Assets to Protect

- Files and folders selected for transfer.
- Text, links, screenshots, and clipboard content.
- Device identity private keys.
- Trusted device records.
- Transfer manifests and history.
- Staged partial transfers.
- Local endpoint information.

## Threat Model

BeamDrop must consider:

- Unknown nearby devices attempting to send files.
- Malicious devices spoofing names.
- Public Wi-Fi clients probing local services.
- Corporate Wi-Fi blocking or inspecting traffic.
- Interrupted transfers leaving partial files.
- Tampered relay traffic in future remote mode.
- Stolen or retired devices that were previously trusted.
- Clipboard content exposure through overbroad automation.

## Trust Rules

- Unknown devices cannot send files without approval.
- Trusted devices are established through QR pairing.
- Trusted devices can be revoked.
- Revoked devices must not regain trust automatically.
- Display names are not identity. Cryptographic device identity is identity.
- Receive approval UI must show trust state clearly.

## Pairing Security

QR pairing must be short-lived and explicit. The QR code may bootstrap identity
verification and endpoint discovery, but it must not embed a long-lived shared
secret. The receiving device must show the device name, platform, and pairing
confirmation before trust is stored.

Pairing should protect against:

- QR replay after expiration.
- Name spoofing.
- Pairing with an unintended nearby device.
- Silent trust creation.

## Transfer Security

Production transfer sessions must use reviewed authenticated encryption.
Release candidates must pass the private security conformance suite before any
public distribution. Public documentation should describe guarantees and
requirements, not implementation-sensitive derivation details.

The local protocol additionally enforces explicit trust, manifest validation,
chunking, and final SHA-256 verification of the assembled payload.

Received files must remain in a staging location until verification succeeds.
If verification fails, the transfer must be marked failed and staged content
must not be presented as a completed download.

Transfer manifests must be rejected before content is accepted when they have:

- Missing or invalid final SHA-256.
- Negative sizes or inconsistent chunk counts.
- File names that contain path separators, traversal segments, control
  characters, or platform-invalid characters.
- Sender identity or public key values that do not match a trusted peer.

Transfer completion must be recorded only after the staged file hash matches the
manifest hash.

## Local Network Exposure

BeamDrop may expose a local listener for discovery or transfer. That listener
must:

- Bind only as needed.
- Authenticate peers before accepting content.
- Enforce transfer size and manifest validation.
- Rate limit repeated unknown connection attempts.
- Stop when the app or OS no longer permits background operation.

Public and corporate Wi-Fi may block local discovery or peer connections.
BeamDrop should not weaken authentication to make fallback easier. Manual IP and
QR fallback must use the same trust and encryption model.

## Clipboard Security

iPhone cannot silently monitor clipboard in the background. Android background
clipboard access is restricted. BeamDrop must not implement hidden clipboard
collection on mobile.

Desktop clipboard features may be stronger, but only with user permission.
Desktop watched-clipboard modes must:

- Be opt-in.
- Explain exactly what is watched and when.
- Show visible status.
- Allow pause and disable.
- Avoid storing clipboard content longer than necessary.
- Block sensitive-looking content from automatic or tray-initiated send by
  default, including passwords, tokens, private keys, and card-like values.

## Revocation

Trusted devices must be revocable from a trusted devices screen. Revocation must:

- Remove the device from automatic trust.
- Stop active transfers when appropriate.
- Prevent resume from that device unless re-paired.
- Record the revocation in local trust state.

BeamDrop should support re-pairing a revoked device only through a deliberate QR
pairing flow.

## Optional Relay Security

Future relay support must not change the content privacy expectation. Relay
servers should not be able to read transferred content. Relayed transfer UI must
make the route visible because relay may affect performance and metadata.

Relay and signaling services must not be required for local MVP.

Optional relay requirements:

- File encryption happens client-side before upload.
- Relay stores encrypted temporary blobs only.
- Relay records metadata only: transfer ID, object key, encrypted size, content
  type, status, sender/receiver device IDs where needed, and expiration time.
- Relay must enforce maximum encrypted blob size.
- Relay tokens must expire and be unguessable.
- Expired blobs must be removed by cleanup.
- Relay logs must not contain plaintext content, clipboard content, encryption
  keys, or decrypted metadata.
- Relay tokens are bearer credentials and must be short-lived, random, and
  scoped to the encrypted blob metadata they were issued for.

Optional signaling requirements:

- Signaling transports presence and coordination metadata only.
- Signaling must not carry plaintext files or clipboard content.
- Signaling events must be rate limited and logged without sensitive payloads.
- Auth/session handling is a placeholder until account or trust-bound remote
  identity is designed.

Abuse prevention notes:

- Rate limit token creation, upload/download attempts, and signaling events.
- Enforce size caps before accepting uploads.
- Expire relay tokens aggressively.
- Track failed token and upload attempts for future abuse detection.
- Prefer per-device quotas before enabling any public relay deployment.

## Permission Explanations

Before OS permission prompts, BeamDrop must explain:

- Why camera is needed for QR pairing.
- Why local network is needed for nearby transfers.
- Why notifications are useful for incoming transfer requests.
- Why file/photo access is needed to send or save selected content.
- Why clipboard access differs between iPhone, Android, macOS, and Windows.

## Security Acceptance Criteria

- Unknown sender approval is enforced.
- QR pairing is required for trusted device creation.
- Trusted device revocation blocks future trusted sessions.
- Transfer encryption is enabled for all content.
- File hash verification blocks corrupted output.
- Unsafe receive file names are rejected rather than sanitized into a different
  path.
- Missing final SHA-256 prevents transfer completion.
- Large transfer resume validates manifest and completed chunks.
- Clipboard features follow platform privacy restrictions.
