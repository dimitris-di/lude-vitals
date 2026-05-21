# Security Policy

## Reporting a vulnerability

If you find a security issue in LudeVitals, please report it privately.

**Email:** demetrisd25@gmail.com

Please do **not** open a public GitHub issue for security reports, crash logs that may expose private data, or proof-of-concept details before we have coordinated disclosure.

We aim to:

- Acknowledge the report within 7 days.
- Triage or ask follow-up questions within 14 days.
- Ship a fix or mitigation for confirmed issues within 30 days when the fix is under project control.
- Credit reporters in release notes unless they ask not to be credited.

Please include:

- A description of the issue and its impact
- Steps to reproduce
- Your macOS version and Mac model
- The LudeVitals version and install source (release DMG, source build, or fork)
- Whether the DMG checksum matched `SHA256SUMS`, if the issue involves distribution

If you include a crash log, redact usernames, home-directory paths, email addresses, tokens, local project paths, and device serial numbers. Keep the exception type, crashed thread, LudeVitals stack frames, macOS version, and Mac model.

## Security posture

LudeVitals is a local macOS menu bar app. It:

- Does not connect to the network.
- Does not include telemetry, analytics, auto-update checks, or a crash-reporting service.
- Does not run as root or install a privileged helper.
- Is not App Sandbox sandboxed in current builds (`com.apple.security.app-sandbox=false`) so it can read local system metrics and Apple Silicon sensor data through IOKit / IOHID / AppleSMC paths.

The unsandboxed posture is intentional but security-relevant. A bug that causes unexpected file, process, network, or persistence behavior is in scope.

## What counts as a security issue

The most likely categories of security-relevant bugs are:

- **Unsafe use of private IOKit / IOHID symbols**: undefined behavior in the dlsym'd functions could in principle be leveraged for memory corruption.
- **Improper handling of Mach / sysctl return values** that lead to memory disclosure or out-of-bounds reads in samplers.
- **Unexpected network access or telemetry** from the app process.
- **Unsandboxed local access bugs** that expose files, process data, or persistence behavior unrelated to system monitoring.
- **Code-signing or distribution issues** that allow a tampered binary to look legitimate.

Known limitations by themselves are not security vulnerabilities: current releases are not Developer ID signed or notarized, and Gatekeeper may warn on first launch. A way to make a tampered binary pass documented checksum or trust checks is in scope.

## Supported versions

This project is pre-1.0. We support the latest released version on the `main` branch. Older versions do not receive security backports.
