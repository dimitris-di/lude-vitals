# Security Policy

## Reporting a vulnerability

If you find a security issue in LudeVitals, please report it privately.

**Email:** demetrisd25@gmail.com

Please do **not** open a public GitHub issue for security reports.

We aim to respond within 7 days. Please include:
- A description of the issue and its impact
- Steps to reproduce
- Your macOS version and Mac model

## What counts as a security issue

LudeVitals does not connect to the network, does not run as root, and does not require sandbox-exempt entitlements at install time. The most likely categories of security-relevant bugs are:

- **Unsafe use of private IOKit / IOHID symbols**: undefined behavior in the dlsym'd functions could in principle be leveraged for memory corruption.
- **Improper handling of Mach / sysctl return values** that lead to memory disclosure or out-of-bounds reads in samplers.
- **Code-signing or distribution issues** that allow a tampered binary to look legitimate.

If you find any of these, please report them. We aim to ship a fix or mitigation within 30 days, and will credit reporters in the release notes unless asked otherwise.

## Supported versions

This project is pre-1.0. We support the latest released version on the `main` branch. Older versions do not receive security backports.
