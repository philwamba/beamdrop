# BeamDrop Onboarding Flow

## Goal

Onboarding should get a new user to one of two outcomes quickly:

- Pair a trusted device with QR code.
- Understand why a permission is needed before a native OS prompt.

Onboarding must not feel like a marketing tour.

## Flow

### Screen 1: Welcome

Title:

- "BeamDrop"

Body:

- "Send files, links, text, screenshots, and clipboard content between your
  trusted devices."

Primary action:

- Continue.

### Screen 2: Local-First Transfer

Message:

- "BeamDrop sends directly over your local network where possible. Local transfer
  works without login or cloud upload."

Secondary note:

- "Some public or corporate Wi-Fi networks block discovery. Manual IP and QR
  fallback are available."

### Screen 3: Trusted Devices

Message:

- "Pair devices with QR code. Unknown devices cannot send files without your
  approval."

Actions:

- Pair a device.
- Skip for now.

### Screen 4: Permissions

Show permission cards only for permissions relevant at this moment:

- Local network.
- Notifications.
- Camera when scanning QR.
- Files/photos when sending or saving.

Do not ask for every permission on first launch.

### Screen 5: Clipboard Policy

Platform-specific:

- iPhone: "iPhone does not allow silent background clipboard monitoring. Use
  Share Sheet, Shortcuts, or Paste to send clipboard content."
- Android: "Android restricts background clipboard access. BeamDrop sends
  clipboard content from user-triggered actions."
- macOS/Windows: "Desktop clipboard features can be enabled with your permission
  and can be paused anytime."

## Visual Requirements

- Native navigation.
- Minimal illustration or no illustration.
- Device and QR visuals may be used if they are literal and refined.
- No web landing-page hero.
- No oversized gradients or decorative objects.

## Completion

After onboarding:

- If a device was paired, go to Home with that trusted device visible.
- If skipped, go to Home empty state with Pair with QR as primary action.

## Accessibility

- All screens support dynamic text.
- Continue actions have descriptive labels.
- Permission explanations are readable by screen readers before OS prompts.
- Reduced motion disables nonessential transitions.
