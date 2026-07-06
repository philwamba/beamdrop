# BeamDrop Transfer Flow

## Purpose

BeamDrop transfers files, folders, text, links, screenshots, and clipboard
content between trusted devices. The transfer flow must be local-first, explicit,
secure, resumable for large files, and clear to both sender and receiver.

## Sender Flow

1. User chooses content from a native entry point:
   - File picker.
   - Folder picker.
   - Share Sheet or Android share intent.
   - Screenshot share action.
   - Clipboard send action.
2. User selects a trusted device or enters a fallback endpoint.
3. BeamDrop builds a transfer manifest.
4. BeamDrop connects to receiver.
5. Receiver approval is requested when required.
6. Sender streams chunks.
7. Sender displays progress, speed, destination device, and status.
8. Sender records success, failure, cancellation, or resume availability.

For the Android-Windows MVP, sender and receiver use the same newline-delimited
local TCP transfer frame: one camelCase JSON envelope, one newline, then streamed
payload bytes. The default chunk size is 4 MB. The sender must not load a large
file fully into memory.

## Receiver Flow

1. Receiver gets an incoming transfer request.
2. BeamDrop evaluates sender trust state.
3. Unknown devices require approval before content is accepted.
4. Trusted devices may still show approval depending on settings and content
   type.
5. Receiver chooses destination if needed.
6. BeamDrop writes chunks to staging.
7. BeamDrop verifies file hash.
8. BeamDrop commits verified files to destination.
9. Receiver records transfer history.

For Android-Windows local transfers, the receiver reads the JSON envelope first,
rejects unknown or revoked sender device IDs, validates the sender public key
against the trusted peer record, stages incoming bytes, verifies the final
SHA-256 hash, then commits the file. Failed, rejected, cancelled, corrupted, and
incomplete transfers must appear in history.

## Transfer Types

### Files

Files require name, size, MIME/type hint where available, file hash, and chunk
metadata for large transfers.

### Folders

Folders require relative paths. BeamDrop must prevent path traversal and must not
write outside the selected destination.

### Text

Text transfers should show a preview and size. Text should be copied, saved, or
opened through native actions on the receiving platform.

### Links

Links should show host and full URL preview. BeamDrop should handle unusual URL
schemes cautiously and let the receiver choose whether to open or copy.

### Screenshots

Screenshots should use native share/capture flows. Desktop screenshots may come
from OS capture tools or app integration. Mobile screenshots should use share
targets where appropriate.

### Clipboard

iPhone clipboard sending must be manual through Share Sheet, Shortcuts, or Paste.
Android clipboard sending must be user-triggered where OS restrictions require.
Desktop clipboard workflows may be stronger with explicit permission.

## Chunking Requirements

All large file transfers must be chunked. Chunking must support:

- Progress updates.
- Backpressure.
- Cancellation.
- Resume.
- Per-file final hash verification.
- Optional per-chunk verification.

Chunk data must be staged until verification succeeds.

## Resume Requirements

Transfer resume is required for large files. Resume must work after:

- Temporary network loss.
- App restart where platform persistence allows.
- Sender pause and retry.
- Receiver pause and retry.

Resume must not continue if:

- Trust was revoked.
- Manifest hash changed.
- Destination staging data is corrupt.
- File hash verification fails.

The current Android-Windows MVP includes resume planning and chunk metadata. Full
persisted cross-restart resume is not complete yet and must not be presented as
finished UI behavior.

## File Hash Verification

File hash verification is required before success. If verification fails:

- Mark transfer `Corrupted`.
- Do not expose staged file as complete.
- Offer retry from the sender.
- Keep diagnostics suitable for support logs.

If the payload ends before `sizeBytes`, mark transfer `Incomplete`. If the user
cancels, mark transfer `Cancelled`. If the network or file system fails for any
other reason, mark transfer `Failed`.

## Progress UI Requirements

Transfer progress must show:

- Sender and receiver device names.
- Transfer type.
- Item count.
- Total size.
- Current item.
- Bytes transferred.
- Speed estimate.
- Time remaining where reliable.
- Pause, cancel, retry, or resume actions where supported.

## Local and Relay Route Labels

The MVP route is local. Future relay routes must be labeled clearly. The user
should understand whether BeamDrop is transferring directly over the local
network, using manual IP, or using a future relay.

## Transfer Error States

- Receiver rejected transfer.
- Sender disconnected.
- Receiver app backgrounded.
- Network blocked by Wi-Fi or firewall.
- Insufficient disk space.
- Destination unavailable.
- Hash verification failed.
- Unsupported protocol version.
- Device trust revoked.
- Unknown peer rejected.
- Incomplete payload.
- Transfer cancelled.

Each error must include a next action such as retry, resume, diagnostics, change
destination, pair again, or cancel.
