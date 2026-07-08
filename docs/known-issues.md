# BeamDrop Known Issues

## Current E2E Status

No real-device end-to-end matrix run has been completed in this environment.
The items below are release blockers unless explicitly scoped out of an
internal-only build.

| ID | Severity | Area | Status | Issue | Fix or reason not fixed |
| --- | --- | --- | --- | --- | --- |
| KI-001 | Critical | E2E matrix | Open | Android/Windows/macOS/iPhone directional transfer matrix has not been executed on real devices. | Requires physical devices and OS permission dialogs; documented manual plan and local diagnostic script. |
| KI-002 | Critical | Transfer security | Open | Authenticated transfer encryption is documented as required but not proven by E2E tests. | Requires protocol/client implementation and cross-platform verification before production. |
| KI-003 | Critical | Resume | Open | Full interrupted large-file resume is not proven across all platform pairs. | Resume planner/unit logic exists; real chunk resume flow needs device E2E evidence. |
| KI-004 | Critical | Android build | Open | Android release build was not verified in this sandbox because Gradle native services/cache access was blocked. | Run `scripts/build-android.sh` on configured Android build host. |
| KI-005 | Critical | iPhone build | Open | Swift package tests can run with cache access, but Xcode archive/TestFlight validation is not proven. | Requires Apple signing and physical/simulator device run. |
| KI-006 | Critical | macOS build | Open | Swift package build/test can run with cache access, but signed/notarized app behavior is not proven. | Requires Developer ID signing, hardened runtime, notarization, and app install QA. |
| KI-007 | Critical | Windows packaging | Open | Windows core tests pass, but MSIX/installer packaging and signing are not proven. | Requires Windows runner/build host with signing certificate and package validation. |
| KI-008 | Major | Protocol validation | Open | CI currently validates JSON syntax; full JSON Schema semantic validation is not yet automated offline. | Add pinned schema validator dependency/tooling without network fetch during CI. |
| KI-009 | Major | Discovery fallback | Open | mDNS-blocked network fallback has not been run across all device pairs. | Use manual QR/manual endpoint fallback tests and `scripts/run-local-network-test.sh`. |
| KI-010 | Major | Clipboard UX | Open | Android/iPhone manual clipboard UX and desktop pause behavior are not proven by real-device UI tests. | Unit policy exists for some paths; requires manual QA screenshots. |

## Fixed During QA Preparation

| ID | Area | Fix |
| --- | --- | --- |
| FIX-001 | QA planning | Expanded E2E matrix and manual cases to cover all requested directional pairs and core flows. |
| FIX-002 | Local diagnostics | Added a practical local network diagnostic script for service browse and endpoint reachability checks. |
| FIX-003 | Release evidence | Added explicit known-issue and signoff records so unrun flows cannot be hidden. |
