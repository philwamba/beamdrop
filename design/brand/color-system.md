# BeamDrop Color System

## Color Principles

BeamDrop uses color to communicate trust, route, status, and action priority. It
must not look like a web dashboard or a childish sharing app. The default visual
mode should be neutral, premium, and native.

Platform system colors should be used where they improve native feel:

- Android: Material 3 dynamic color may be supported, with BeamDrop roles mapped
  to Material color roles.
- iOS/macOS: use semantic system colors for grouped backgrounds, labels,
  separators, and destructive actions.
- Windows: use WinUI theme resources and system accent where appropriate.

## Core Brand Roles

Recommended base roles:

- `Beam`: primary action/accent. Use sparingly for send, pair, and active route.
- `Ink`: primary text and high-emphasis icons.
- `Mist`: background and grouped surfaces.
- `Line`: dividers, separators, and quiet borders.
- `Trust`: paired and verified states.
- `Caution`: interrupted, manual, or attention-needed states.
- `Danger`: destructive, revoked, blocked, or failed states.

## Suggested Reference Palette

These values are design references, not hard platform overrides:

- Beam 600: `#2563EB`
- Beam 700: `#1D4ED8`
- Ink 950: `#111827`
- Ink 700: `#374151`
- Mist 50: `#F8FAFC`
- Mist 100: `#F1F5F9`
- Line 200: `#E2E8F0`
- Trust 600: `#0F766E`
- Caution 600: `#B45309`
- Danger 600: `#DC2626`

Dark mode equivalents should preserve contrast and avoid saturated neon:

- Beam 400: `#60A5FA`
- Ink 50: `#F9FAFB`
- Ink 300: `#D1D5DB`
- Mist 950: `#0B1220`
- Mist 900: `#111827`
- Line 800: `#1F2937`
- Trust 400: `#2DD4BF`
- Caution 400: `#FBBF24`
- Danger 400: `#F87171`

## Semantic Usage

Primary action:

- Send.
- Pair device.
- Accept receive request.
- Resume transfer.

Secondary action:

- Scan QR.
- Manual IP.
- Change destination.
- View diagnostics.

Destructive action:

- Revoke trusted device.
- Reject transfer.
- Cancel active transfer when data may be discarded.
- Clear history.

Status:

- Trust: paired, verified, complete.
- Caution: manual route, waiting, interrupted, limited permission.
- Danger: failed, revoked, blocked, hash mismatch.

## Surfaces

Mobile:

- Use platform grouped backgrounds.
- Use cards only for device rows, transfer rows, and dialogs/sheets.
- Avoid full-screen dashboard panels.

Desktop:

- Main content uses native window background.
- Sidebars use platform materials.
- Drag-and-drop area uses a subtle dashed or outlined surface, not a loud upload
  widget.

## Contrast Requirements

- Normal text: WCAG 2.2 AA minimum 4.5:1.
- Large text and icons: minimum 3:1.
- Focus indicators: minimum 3:1 against adjacent color.
- Error and success cannot be color-only; pair with icon and text.

## Prohibited Color Treatments

- Large purple/blue gradients as the main identity.
- Overuse of beige, tan, or brown neutral themes.
- Decorative gradient orbs.
- Neon status colors.
- Red for unknown devices unless the state is actually dangerous.
