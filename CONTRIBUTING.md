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

## Code style

- No narrative comments. Identifiers should explain themselves.
- One-line comments are acceptable for non-obvious workarounds (private API quirks, Mach API gotchas).
- No force-unwraps at module boundaries — return `.zero` or `nil` defaults from samplers.
- Keep the sampling path allocation-free where reasonable. This app should not contribute to its own readings.

## Adding a new metric

1. Extend `MetricSnapshot.swift` with the new field on the appropriate sub-struct.
2. Implement the reader in `Sources/LudeVitals/Metrics/` conforming to `AnySampler`.
3. Wire it into `SamplingScheduler` and `AppDelegate.applicationDidFinishLaunching`.
4. Add a UI section in `PopoverRoot.swift`.

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
