#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
    echo "release metadata check failed: $*" >&2
    exit 1
}

version="$(tr -d '[:space:]' < VERSION)"
plist_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Info.plist)"

[[ -n "$version" ]] || fail "VERSION is empty"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]] || fail "VERSION must be SemVer-like, got '$version'"
[[ "$plist_version" == "$version" ]] || fail "VERSION ($version) does not match Info.plist CFBundleShortVersionString ($plist_version)"
[[ "$build_number" =~ ^[0-9]+$ ]] && (( build_number > 0 )) || fail "Info.plist CFBundleVersion must be a positive integer, got '$build_number'"

for file in LICENSE THIRD_PARTY_NOTICES.md Resources/AppIcon.icns; do
    [[ -s "$file" ]] || fail "$file is missing or empty"
done

if grep -Eq 'systemSymbolName|waveform\.path\.ecg' scripts/generate-icon.sh; then
    fail "icon generator still references SF Symbol APIs or symbol names"
fi

if [[ "${GITHUB_REF_TYPE:-}" == "tag" && -n "${GITHUB_REF_NAME:-}" ]]; then
    tag_version="${GITHUB_REF_NAME#v}"
    [[ "$tag_version" == "$version" ]] || fail "tag ${GITHUB_REF_NAME} does not match VERSION ($version)"
fi

echo "Release metadata OK: $version"
