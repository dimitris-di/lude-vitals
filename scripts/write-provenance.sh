#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

output="${1:-release-provenance.json}"
if [[ $# -gt 0 ]]; then
    shift
fi

if [[ $# -eq 0 ]]; then
    set -- LudeVitals-*.dmg SHA256SUMS
fi

artifacts=()
for artifact in "$@"; do
    if [[ -f "$artifact" ]]; then
        artifacts+=("$artifact")
    fi
done

if [[ "${#artifacts[@]}" -eq 0 ]]; then
    echo "write provenance failed: no artifact files found" >&2
    exit 1
fi

json_string() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

file_size() {
    stat -f%z "$1" 2>/dev/null || stat -c%s "$1"
}

version="$(tr -d '[:space:]' < VERSION)"
plist_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)"
commit="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
ref="${GITHUB_REF_NAME:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)}"
run_id="${GITHUB_RUN_ID:-local}"
created_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
dirty="null"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git diff --quiet && git diff --cached --quiet; then
        dirty="false"
    else
        dirty="true"
    fi
fi

{
    echo "{"
    echo "  \"name\": \"LudeVitals release provenance\","
    echo "  \"version\": \"$(json_string "$version")\","
    echo "  \"infoPlistVersion\": \"$(json_string "$plist_version")\","
    echo "  \"source\": {"
    echo "    \"commit\": \"$(json_string "$commit")\","
    echo "    \"ref\": \"$(json_string "$ref")\","
    echo "    \"githubRunId\": \"$(json_string "$run_id")\","
    echo "    \"dirty\": $dirty"
    echo "  },"
    echo "  \"createdAt\": \"$(json_string "$created_at")\","
    echo "  \"artifacts\": ["

    first=1
    for artifact in "${artifacts[@]}"; do
        digest="$(shasum -a 256 "$artifact" | awk '{print $1}')"
        size="$(file_size "$artifact")"
        if [[ "$first" -eq 0 ]]; then
            echo ","
        fi
        first=0
        printf '    {\n'
        printf '      "path": "%s",\n' "$(json_string "$artifact")"
        printf '      "sha256": "%s",\n' "$digest"
        printf '      "sizeBytes": %s\n' "$size"
        printf '    }'
    done

    echo
    echo "  ]"
    echo "}"
} > "$output"

echo "Wrote $output"
