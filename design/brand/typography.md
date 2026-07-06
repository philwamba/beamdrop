# BeamDrop Typography

## Typography Principles

BeamDrop typography should feel native, precise, and information-dense without
becoming cramped. Use platform system fonts by default.

- Android: Roboto through Material 3 typography.
- iOS/macOS: San Francisco through SwiftUI text styles.
- Windows: Segoe UI through WinUI text styles.

Do not ship a custom typeface for MVP unless a specific platform limitation
requires it. Native system fonts improve performance, accessibility, and trust.

## Type Roles

### App Title

Use sparingly for screen identity:

- Home title.
- Window title.
- Onboarding title.

Do not use oversized hero typography inside tool screens.

### Section Title

Used for grouped content:

- Nearby devices.
- Recent transfers.
- Trusted devices.
- Clipboard policy.

### Body

Used for explanations, permission education, and privacy notes. Body copy should
be concise and line lengths should remain readable.

### Metadata

Used for:

- Device platform.
- Last seen.
- Transfer size.
- Route label.
- Hash verification state.

Metadata should be quieter than primary labels but still meet contrast.

### Monospace

Use only for manual IP, ports, diagnostic IDs, and hash snippets. Do not expose
full hashes in primary UI unless needed for support or verification detail.

## Scaling

BeamDrop must support:

- Android font scale.
- iOS Dynamic Type.
- macOS larger text where available.
- Windows text scaling.

Layouts must not break at larger text sizes. Device cards and transfer rows must
support wrapping or adaptive vertical height.

## Copy Rules

- Use sentence case for labels.
- Use platform-standard title casing only where the OS expects it.
- Keep button labels action-oriented: "Send", "Pair", "Resume", "Reject".
- Avoid vague labels: "Continue" is acceptable only in onboarding.
- Avoid technical nouns as buttons: use "Scan QR" instead of "Initiate pairing".

## Numeric Formatting

- File sizes use platform locale formatting.
- Transfer speed uses concise units: `42 MB/s`.
- Remaining time should appear only when stable enough to be useful.
- Percent progress can be shown with a progress bar and numeric label for
  accessibility.

## Accessibility Requirements

- Text must meet WCAG AA contrast.
- Text must remain readable at increased system font sizes.
- Buttons must not clip text.
- Screen readers must get meaningful labels, not only visual file names.
- Progress text must be announced for long-running transfers.
