# Troubleshooting

## Checksum verification fails

Do not open the DMG or clear quarantine if the checksum does not match.

1. Delete the DMG and `SHA256SUMS`.
2. Download both files again from the same GitHub release.
3. Run the check again:

   ```bash
   cd ~/Downloads
   grep 'LudeVitals-0.1.0.dmg' SHA256SUMS | shasum -a 256 -c -
   ```

If it still fails, open a bug and include the release URL, browser or download command, and the checksum you computed with `shasum -a 256 LudeVitals-0.1.0.dmg`.

## Gatekeeper blocks the app

Current releases are ad-hoc signed, not Developer ID signed or notarized. Gatekeeper may block first launch even when the release is legitimate.

Use this order:

1. Verify the DMG checksum from the release.
2. Drag `LudeVitals.app` to `/Applications`.
3. Right-click `LudeVitals.app` in Finder, choose **Open**, then choose **Open** again.

If Finder still blocks a checksum-verified app, you can remove the quarantine flag for that app bundle:

```bash
xattr -dr com.apple.quarantine /Applications/LudeVitals.app
open /Applications/LudeVitals.app
```

Only run `xattr -dr com.apple.quarantine` after verifying the checksum or building from source you trust. Removing quarantine tells macOS to stop applying Gatekeeper's downloaded-file checks to that bundle.

## Source build says the app is damaged

Prefer a real Git clone:

```bash
git clone https://github.com/dimitris-di/lude-vitals.git
cd lude-vitals
make install
```

If you built from a ZIP download, AirDrop copy, or another quarantined source tree, quarantine attributes can follow the local build output. After you verify the source is the code you intend to run, remove quarantine from the built bundle:

```bash
xattr -dr com.apple.quarantine LudeVitals.app
```

## The menu bar item does not appear

- Wait two seconds after launch; the first sample is taken on a timer.
- Check Activity Monitor for an existing `LudeVitals` process.
- Quit stale instances with `make kill`, then run `make run` or open `/Applications/LudeVitals.app`.
- On crowded menu bars, macOS may hide status items behind the notch or Control Center area. Quit other menu bar apps temporarily to confirm.

## Temperatures show `n/a`

Apple does not expose Apple Silicon die temperatures through public APIs. LudeVitals uses private local IOHID symbols and degrades to `n/a` if macOS changes those symbols or the model does not expose the expected sensors.

The rest of the app should continue working. Please file a bug with your macOS version and Mac model identifier.

## Fan RPM is empty

Fanless Macs, including MacBook Air models, do not report fan RPM because there is no fan. That is expected.

If your Mac has a fan and RPM is missing, include your model identifier and macOS version in the bug report.

## Launch at login does not stick

- Move `LudeVitals.app` to `/Applications` before enabling launch at login.
- Toggle the setting off and on again in LudeVitals Settings.
- Check **System Settings** -> **General** -> **Login Items** for LudeVitals.

## The app crashed

Crash logs are stored in `~/Library/Logs/DiagnosticReports/` and usually end in `.ips`.

Before attaching a crash log to a public issue, redact usernames, home-directory paths, email addresses, tokens, local project paths, and device serial numbers. Keep the exception type, crashed thread, LudeVitals stack frames, macOS version, and Mac model.

For security-sensitive crashes, follow [SECURITY.md](../SECURITY.md) instead of opening a public issue.
