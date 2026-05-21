# Privacy

LudeVitals is a local macOS system monitor. It reads system metrics from macOS APIs, displays them in the menu bar and popover, and does not send them anywhere.

## What the app reads

- CPU, memory, thermal, fan, battery, and network-interface counters from local macOS APIs.
- Process names and resource usage for the top-process list.
- Basic hardware and OS state needed to interpret those metrics.

Network metrics are byte counters and the active interface name. LudeVitals does not capture packets, inspect URLs, read hostnames, or record payloads.

## What the app stores

- Preferences such as display mode, temperature unit, sampling interval, and custom menu-bar options are stored locally with `UserDefaults`.
- Launch-at-login state is managed by macOS through `SMAppService`.
- Short sparkline history is kept in memory only. LudeVitals does not persist long-term metric history in the current release.

## What the app does not do

- No telemetry or analytics.
- No auto-update checks.
- No crash-reporting service.
- No advertising, tracking, or third-party service integration.
- No network requests from the app.
- No privileged helper, root daemon, or background service outside the app process.

## Sandbox and local access

Current builds are not App Sandbox sandboxed. The entitlement file sets `com.apple.security.app-sandbox` to `false`.

This is intentional for the current architecture: Apple Silicon temperature and fan readings use local IOKit / IOHID / AppleSMC access paths that do not fit App Store-style sandboxing. The app runs as your current macOS user and does not gain administrator privileges, but the App Sandbox is not containing its file or process access. Treat the app like other unsandboxed local utilities: install only from verified releases or from source you trust.

## Crash logs

LudeVitals does not receive crash logs automatically. If you choose to share a `.ips` file from `~/Library/Logs/DiagnosticReports/`, review it first.

Before posting a crash log publicly, redact:

- Your macOS username and home-directory paths.
- Email addresses, tokens, local project paths, or other private file paths.
- Device serial numbers or other identifiers if they appear.

Keep the exception type, crashed thread, LudeVitals stack frames, macOS version, and Mac model. Those fields are usually enough to debug crashes without exposing personal data.

## Reporting privacy issues

If LudeVitals makes an unexpected network connection, writes data you did not expect, or exposes local data, please report it privately using the process in [SECURITY.md](SECURITY.md).
