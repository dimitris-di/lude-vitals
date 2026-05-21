#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

app="${APP_BUNDLE:-LudeVitals.app}"
dmg="${DMG_PATH:-}"
expect_developer_id="${EXPECT_DEVELOPER_ID:-0}"
expect_gatekeeper="${EXPECT_GATEKEEPER:-0}"
codesign_log=".release/codesign-app.txt"

fail() {
    echo "release artifact verification failed: $*" >&2
    exit 1
}

[[ -d "$app" ]] || fail "$app does not exist"

mkdir -p .release
codesign --verify --strict --verbose=2 "$app"
codesign -dv --verbose=4 "$app" >"$codesign_log" 2>&1 || fail "unable to inspect $app signature"

if [[ "$expect_developer_id" == "1" ]]; then
    grep -q 'Authority=Developer ID Application' "$codesign_log" || fail "$app is not signed with a Developer ID Application identity"
fi

if [[ "$expect_gatekeeper" == "1" ]]; then
    [[ -n "$dmg" && -f "$dmg" ]] || fail "DMG_PATH must point to a DMG when EXPECT_GATEKEEPER=1"
    spctl --assess --type execute --verbose "$app"
    xcrun stapler validate "$dmg"
    spctl --assess --type open --context context:primary-signature --verbose "$dmg"
fi

echo "Release artifacts OK"
