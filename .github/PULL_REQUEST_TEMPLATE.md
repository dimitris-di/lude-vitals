<!-- Thanks for contributing to LudeVitals. Please fill in the sections below. -->

## Summary

<!-- One or two sentences describing what this PR changes. -->

## Motivation

<!-- Why is this change needed? Link to the related issue if one exists. -->

## Screenshots

<!-- For UI-affecting changes, attach before/after screenshots of the menu bar and/or popover. Delete this section for non-UI changes. -->

## Test plan

<!-- How did you verify this? At minimum: `make app && make run`, then describe what you observed. -->

- [ ] `swift build -c release --arch arm64` succeeds
- [ ] `make app` produces a launchable bundle
- [ ] Manually exercised the affected code path

## Checklist

- [ ] Builds cleanly with no new warnings
- [ ] No force-unwraps at module boundaries
- [ ] No new network access, telemetry, analytics, auto-update, crash reporting, or third-party services added
- [ ] No new third-party dependencies, or notices/licenses updated
- [ ] Privacy/security docs updated if data handling, entitlements, signing, or distribution changed
- [ ] Code follows the existing style (no narrative comments, focused diff)
- [ ] Docs/CHANGELOG updated if user-visible behavior changed
