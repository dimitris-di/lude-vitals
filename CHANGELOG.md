# Changelog

All notable changes to LudeVitals are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Gate top-process scan on popover-open to cut idle CPU.
- Cache static SMC fan keys and `SCDynamicStore` across ticks.
- `SamplingScheduler` now drops sample ticks when a sample is already in flight (no Task pile-up).
- `RingBuffer` rewritten as a real O(1) ring over a fixed-size buffer.
- Replaced `MainActor.assumeIsolated` boot with `@main` on `AppDelegate`.
- `customOptions` persistence to `UserDefaults` is now debounced (300 ms).
- Status item resize is idempotent; no relayout when content width hasn't changed.
- Popover and preferences now use semantic SwiftUI text styles (Dynamic Type aware).
- VoiceOver labels and values on every numeric tile and row.
- `Card` accessory is now generic over `View` rather than `AnyView`.
- Replaced deprecated `codesign --deep` with binary-first signing.
- `make install` now waits for the old instance to fully exit before replacing the bundle.

### Added
- `make benchmark` target prints binary size and idle CPU/RSS.
- `make icon` target regenerates `Resources/AppIcon.icns` via `scripts/generate-icon.sh`.
- `LudeVitals.entitlements` (no sandbox; ready for future Hardened Runtime + notarization).
- `Info.plist` now sets `CFBundleIconFile` and `NSHumanReadableCopyright`.
- Memory pressure sysctl return value is now checked (was silently swallowed).
- `Tests/LudeVitalsTests/` with unit coverage for `RingBuffer`, `Fmt`, and menu bar formatters (run via `swift test`; requires full Xcode locally, CI runs them on every PR).
- Tag-driven release workflow at `.github/workflows/release.yml` that builds the DMG, computes `SHA256SUMS`, and uploads to a draft GitHub release.
- `VERSION` file at the repo root as the single source of truth for app version; `Makefile` reads from it.
- Split `Views/PopoverRoot.swift` (656 lines) into `Views/Components/*.swift` and `Views/Formatters.swift`.
- All samplers and their backends are now `@MainActor`-isolated; the `AnySampler` protocol is `@MainActor` for Swift 6 strict-concurrency readiness.
- `SMCKeyData` stride is now checked with `precondition` (release-retained) rather than `assert`.
- README now documents the comparison against Stats, iStat Menus, and Activity Monitor.

### Fixed
- `BatterySampler` no longer leaks a `CFTypeRef` per sample from `IORegistryEntryCreateCFProperty`.
- `SMCFanReader.connection` is now closed in `deinit`.
- `proc_listpids` buffer is sized correctly (was under-allocating on busy systems).
- CPU tick-mismatch on sleep/wake now returns a clean zero sample instead of garbage deltas.
- Increased-Contrast users get bumped opacities so card borders and gradients remain visible.
- Empty-state strings (missing temp, no network interface, no battery time, no top processes yet) read as legible text (`n/a`, `No process samples yet`) instead of `··`.
- File renamed: `IOReportFanReader.swift` → `SMCFanReader.swift` to match the class inside.
- README perf claims updated to reflect actual measurements (`~19 MB physical footprint, under 50 MB RSS, < 0.3% idle CPU`).

## [0.1.0] - 2026-05-21

### Added

- Menu bar status item with four display modes: Minimal (temperature only), Balanced (temperature + RAM), Full (CPU + RAM + temperature + network), and Custom.
- Click-through popover (400×580) with hero tiles for CPU, RAM, and temperature; per-core CPU breakdown with P-core / E-core grouping on Apple Silicon; memory section with pressure indicator and breakdown; thermal section with sensor readouts and fan RPM; network up/down rates and primary interface; battery percentage, time remaining, cycle count, health, and instantaneous wattage; top processes by CPU or memory.
- Preferences window: launch-at-login via `SMAppService`, temperature unit (°C / °F), sampling interval (1–5 s), and per-metric custom display toggles.
- Ad-hoc signed DMG distribution. Builds for Apple Silicon Macs running macOS 14 Sonoma or later.

### Known limitations

- Not yet signed or notarized: Gatekeeper requires `xattr -dr com.apple.quarantine /Applications/LudeVitals.app` after install.
- Apple Silicon only. Intel SMC thermal backend is on the roadmap.
- Long-term metric history is not yet persisted (60-snapshot in-memory ring buffer drives the sparklines).
