# Contributing to LudeVitals

Thanks for considering a contribution. A few notes to keep things smooth.

## Before you start

- For non-trivial changes (new metrics, refactors, behavior changes), open an issue first so we can agree on direction.
- For typos, small fixes, and obvious bugs, just send a PR.

## Development setup

```bash
git clone https://github.com/dimitris-di/LudeVitals.git
cd LudeVitals
make run
```

That builds the app, assembles the bundle, and launches it. The menu bar icon should appear within ~2 seconds.

### Running tests

The test target requires full Xcode (not just Command Line Tools, which lacks the `XCTest` framework). With Xcode installed:

```bash
swift test
```

CI runs tests on every PR with the macos-14 runner, so even without local Xcode you can rely on the GitHub check.

## Code style

- No narrative comments. Identifiers should explain themselves.
- One-line comments are acceptable for non-obvious workarounds (private API quirks, Mach API gotchas).
- No force-unwraps at module boundaries; return `.zero` or `nil` defaults from samplers.

Expect a review within about a week. A merged PR has: green build, no new warnings, no force-unwraps in sampler paths, and a CHANGELOG entry if the change is user-visible.
- Keep the sampling path allocation-free where reasonable. This app should not contribute to its own readings.

## Adding a new metric

1. Extend `Sources/LudeVitals/Models/MetricSnapshot.swift` with the new field on the appropriate sub-struct (and a `.zero` default).
2. Implement the reader in `Sources/LudeVitals/Metrics/` conforming to `AnySampler` (the protocol lives in `Sources/LudeVitals/Services/SamplingScheduler.swift`).
3. Wire it into `SamplingScheduler` and `AppDelegate.applicationDidFinishLaunching`.
4. Add a UI section in `Sources/LudeVitals/Views/PopoverRoot.swift`.
5. If the metric is user-toggleable in the menu bar, add a flag to `CustomDisplayOptions` in `Models/Settings.swift` and the corresponding `Toggle` in `Views/PreferencesWindow.swift`.
6. Update the `## Features` section of `README.md` and add a `CHANGELOG.md` entry.

## Pull request checklist

- [ ] `make app` builds cleanly with no warnings
- [ ] No new force-unwraps
- [ ] No new network or analytics dependencies (this app is offline-only)
- [ ] If you touched a private-API code path, add a one-line comment explaining the field/key/selector

## Reporting bugs

Please include:
- macOS version
- Mac model (`system_profiler SPHardwareDataType | grep "Model Identifier"`)
- What you saw vs. what you expected
- If the app crashed, attach the most recent `.ips` from `~/Library/Logs/DiagnosticReports/`
