# Security Model

LudeVitals is a local-only macOS menu bar app. This document explains the security posture, what protects you, and what doesn't.

## Sandboxing: off, intentionally

`LudeVitals.entitlements` sets `com.apple.security.app-sandbox=false`. App Sandbox blocks every kernel surface the app needs:

- **IOKit / AppleSmartBattery registry** — `BatterySampler.swift`
- **`IOHIDEventSystemClient`** (private symbols, Apple Silicon die temperatures) — `Metrics/Backends/IOHIDThermalReader.swift`
- **`AppleSMC` userclient** (fan RPM) — `Metrics/Backends/SMCFanReader.swift`
- **`SCDynamicStore`** (primary interface lookup) — `NetworkSampler.swift`

Running sandboxed would reduce the app to a useless shell. We accept the trade-off and compensate with the controls below.

## Hardened Runtime: on

Even un-sandboxed, Hardened Runtime is enabled on release builds. It:

- blocks `DYLD_INSERT_LIBRARIES` injection
- forbids JIT and unsigned executable memory
- enables library validation: loaded dylibs must match the app's Team ID or be platform binaries (CDHash-pinned)

## Code signing

Local and CI builds today are **ad-hoc signed** (`-` identity). `.github/workflows/release.yml` conditionally switches to full **Developer ID Application** signing plus notarization when the signing secrets are present in the repo. Until then, ad-hoc is the documented default and users are warned to install only from verified releases.

## Network surface: zero

There is no `URLSession`, no analytics SDK, no crash reporter, no auto-update check, no telemetry endpoint anywhere in the source tree. Every metric is read from the kernel, rendered, and discarded with the next sample. The privacy claim is **structurally enforced** by the absence of any network client, not by a policy.

## Private API usage

`IOHIDThermalReader.swift` resolves six symbols via `dlsym` against the IOKit framework:

- `IOHIDEventSystemClientCreate`
- `IOHIDEventSystemClientSetMatching`
- `IOHIDEventSystemClientCopyServices`
- `IOHIDServiceClientCopyEvent`
- `IOHIDServiceClientCopyProperty`
- `IOHIDEventGetFloatValue`

`SMCFanReader.swift` reads SMC keys: `FNum` (fan count), and per-fan `F{i}Ac` (actual RPM), `F{i}Mn` (min), `F{i}Mx` (max).

All of these degrade gracefully: a missing `dlsym` resolution returns an empty thermal reading, a missing SMC connection returns an empty fan list, and the rest of the app stays up. There is no fatal path through private API.

## What is NOT collected

- Process names surface in the popover process list and live only in memory; they are never persisted, logged, or transmitted.
- The Mac model identifier is not read.
- Serial numbers, UUIDs, and IORegistry identifiers are not read.
- No outbound traffic of any kind leaves the device.

## Mac App Store

Structurally ineligible: sandbox-off plus private API use. This is intentional and will not change. Distribution is via signed releases on GitHub.

## Disclosure

Report vulnerabilities per [`SECURITY.md`](../SECURITY.md).

---

Last reviewed: 2026-05-21
