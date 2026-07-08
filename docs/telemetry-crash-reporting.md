# Telemetry and Crash Reporting

Status: **designed and scoped, intentionally not enabled**. BeamDrop is
privacy-positioned: no telemetry, analytics, or crash reporting SDK ships in
any current build, and nothing leaves the device. This document is the
decision record and the integration contract for when (and if) a production
pipeline is turned on.

## Decision

| Concern | Decision | Rationale |
| --- | --- | --- |
| Usage analytics | **Never** | Product promise: local-first, no tracking. |
| Crash reporting | Opt-in only, off by default | Useful for release quality, but must not undermine the privacy posture. |
| Diagnostic logs | Local only, user-exported | The existing local audit log (e.g. macOS `audit-log.json`) already records pairing/transfer events on-device. Users can attach an export to a bug report manually. |
| Server logs | Process stdout only, no export | Signaling/relay log connection lifecycle and cleanup counts via the Nest logger; nothing is shipped off-box. |

## Rules for any future crash pipeline

1. **Opt-in, per install, revocable.** A settings toggle, default off, with
   plain-language description. No pre-checked boxes, no re-asking after "no".
2. **Redaction before write, not before send.** Crash payloads must never
   contain: file names, file paths, clipboard text or previews, device names,
   peer device IDs, public keys or fingerprints, IP addresses, SSIDs. Breadcrumb
   and exception-message scrubbing happens at capture time so unredacted data
   never touches disk.
3. **Symbolication server-side.** Ship dSYM/mapping/PDB files to the crash
   backend at release build time; never embed source context in the binary
   payload.
4. **No third-party SDK auto-init.** Vendor SDKs (Sentry, Crashlytics, etc.)
   must be initialized manually after the consent check — auto-init at process
   start would capture pre-consent crashes.
5. **Kill switch.** A remote-config-free, build-constant switch so an internal
   build can hard-disable the pipeline regardless of stored consent.

## What "production integration" still requires (not done, needs accounts)

- Choosing and provisioning a backend (self-hosted Sentry keeps data
  first-party; SaaS requires a DPA review against the privacy policy).
- Per-platform DSN/key management via the release signing pipeline (not in
  the repo).
- Consent UI on all four platforms plus wording review against the privacy
  policy and store listings.
- Symbol upload steps in the platform release workflows.

Until all of the above exist, builds must ship with no crash/telemetry code
paths compiled in — which is the current state.
