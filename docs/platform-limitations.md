# BeamDrop Platform Limitations

## Purpose

BeamDrop must reflect native platform rules in its product design. These limits
are not edge cases; they shape how transfer, clipboard, background, permissions,
and discovery features are built.

## iPhone

### Clipboard

iPhone cannot silently monitor clipboard in the background. BeamDrop must not
advertise automatic background clipboard sync on iOS. Supported workflows:

- Share Sheet send.
- Shortcuts action.
- Paste into BeamDrop and send.
- Manual copy from received content.

### Background Execution

iOS may suspend apps in the background. Long transfers need user-visible
foreground progress and careful handling of interruption. Resume is required for
large files so a suspended or interrupted app can continue safely where possible.

### Local Network Permission

iOS requires local network permission for nearby device communication. BeamDrop
must explain that this permission allows local transfer without cloud upload.

### Camera Permission

Camera is needed for QR pairing. The permission prompt must be preceded by an
explanation that BeamDrop uses the camera only to scan pairing codes.

## Android

### Clipboard

Android background clipboard access is restricted. BeamDrop clipboard sending
must be user-triggered where required by OS restrictions. Supported workflows:

- Share action.
- Foreground BeamDrop send screen.
- Quick Settings tile where platform rules allow.
- Manual paste into BeamDrop.

### Background Limits

Android may restrict background services, network activity, and clipboard access.
Large transfers should use foreground service patterns where appropriate and show
a persistent notification during active transfer.

### Storage Access

Android storage access varies by version. BeamDrop must use platform file
pickers and scoped storage where required instead of broad storage assumptions.

## macOS

### Clipboard

Desktop apps can support stronger clipboard workflows with user permission.
macOS may support opt-in watched clipboard behavior, but BeamDrop must make it
visible, revocable, and clear about what is sent.

### Local Network and Firewall

macOS firewall settings can block inbound transfer connections. BeamDrop should
provide diagnostics and manual IP fallback.

### Finder and Share Integration

macOS should support native share extensions or Finder-friendly flows where
practical, without using a web wrapper.

## Windows

### Clipboard

Windows can support stronger clipboard workflows with user permission. Any
automatic clipboard send mode must be opt-in, visible, and easy to disable.

### Firewall

Windows Defender Firewall or corporate policy may block local inbound transfer
ports. BeamDrop needs diagnostics and clear remediation steps.

### Shell Integration

Windows should use native WinUI 3 and Windows App SDK patterns for file pickers,
notifications, share targets where available, and app lifecycle.

## Public and Corporate Wi-Fi

Public and corporate Wi-Fi may block:

- Multicast discovery.
- mDNS or similar local discovery traffic.
- Peer-to-peer client connections.
- Inbound firewall ports.
- Cross-subnet traffic.

BeamDrop must include:

- Manual IP or hostname entry.
- QR fallback with endpoint hints.
- Network diagnostics.
- Clear explanation that local discovery may be blocked by the network.

## Permission Explanation Requirements

Every platform must explain permissions before OS prompts:

- Camera: scan QR pairing codes.
- Local network: find and transfer to nearby devices without cloud upload.
- Notifications: show incoming transfer requests and transfer completion.
- Files/photos: send selected files or save received files.
- Clipboard: enable only the platform-supported clipboard workflow.

## Platform Acceptance Criteria

- iPhone clipboard UX is manual and compliant.
- Android clipboard UX is user-triggered where required.
- macOS and Windows clipboard automation is opt-in.
- Local transfer works without login.
- Manual IP and QR fallback exist for blocked discovery.
- Permissions are explained before system prompts.
