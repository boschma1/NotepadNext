#!/usr/bin/env bash
# release.sh — build, tag, push, and ship a NotepadMacMac release.
#
# Workflow:
#   1. Bump the version in BOTH Info.plist and AppConfig.swift (must match).
#   2. Make any other code changes for the release. Leave them uncommitted.
#   3. (Optional) write release notes to a markdown file.
#   4. Run:  ./scripts/release.sh [-m "Commit message"] [--notes-file notes.md]
#
# The script will:
#   - Verify Info.plist and AppConfig.swift versions match.
#   - Verify the v<version> tag does not already exist.
#   - swift build -c release --arch arm64.
#   - Copy the binary into NotepadMacMac.app and re-codesign ad-hoc.
#   - Stage everything, show a confirmation, then commit + tag + push.
#   - Create a GitHub release with two assets:
#       NotepadMacMac-v<version>-macOS-arm64.zip   (versioned, archival)
#       NotepadMacMac-latest.zip                   (stable filename for
#                                                   the /releases/latest/
#                                                   download/ URL)
#
# Stable download URL that always points at the newest release:
#   https://github.com/boschma1/NotepadMacMac/releases/latest/download/NotepadMacMac-latest.zip

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: scripts/release.sh [options]

Options:
  -m, --message MSG     Commit + tag message (default: "Release vX.Y.Z").
  -t, --title TITLE     GitHub release title (default: "vX.Y.Z").
  -n, --notes-file PATH Markdown file with release notes
                        (default: use the commit message).
  -y, --yes             Skip the interactive confirmation.
      --dry-run         Build and stage everything, but don't commit,
                        tag, push, or create the release.
  -h, --help            Show this help and exit.

Version is read from NotepadMacMac.app/Contents/Info.plist
(CFBundleShortVersionString). AppConfig.swift must agree.
EOF
}

NOTES_FILE=""
COMMIT_MESSAGE=""
RELEASE_TITLE=""
ASSUME_YES=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--message)    COMMIT_MESSAGE="$2"; shift 2;;
        -t|--title)      RELEASE_TITLE="$2";  shift 2;;
        -n|--notes-file) NOTES_FILE="$2";     shift 2;;
        -y|--yes)        ASSUME_YES=1;        shift;;
        --dry-run)       DRY_RUN=1;           shift;;
        -h|--help)       usage; exit 0;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2;;
    esac
done

# --- Locate repo root --------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# --- Sanity checks -----------------------------------------------------------
command -v gh >/dev/null  || { echo "ERROR: gh CLI not installed."  >&2; exit 1; }
command -v swift >/dev/null || { echo "ERROR: swift not installed." >&2; exit 1; }
command -v ditto >/dev/null || { echo "ERROR: ditto not installed." >&2; exit 1; }

INFO_PLIST="NotepadMacMac.app/Contents/Info.plist"
APP_CONFIG="Sources/NotepadMacMac/Config/AppConfig.swift"

[[ -f "$INFO_PLIST" ]] || { echo "ERROR: $INFO_PLIST not found." >&2; exit 1; }
[[ -f "$APP_CONFIG" ]] || { echo "ERROR: $APP_CONFIG not found." >&2; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")"
APP_CONFIG_VERSION="$(grep 'static let version' "$APP_CONFIG" | sed -E 's/.*"([^"]+)".*/\1/')"
TAG="v$VERSION"

if [[ -z "$VERSION" ]]; then
    echo "ERROR: could not read version from $INFO_PLIST." >&2
    exit 1
fi

if [[ "$VERSION" != "$APP_CONFIG_VERSION" ]]; then
    echo "ERROR: version mismatch." >&2
    echo "  $INFO_PLIST          → $VERSION" >&2
    echo "  $APP_CONFIG (version) → $APP_CONFIG_VERSION" >&2
    exit 1
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "ERROR: tag $TAG already exists locally." >&2
    exit 1
fi

if git ls-remote --tags origin "refs/tags/$TAG" | grep -q "$TAG"; then
    echo "ERROR: tag $TAG already exists on origin." >&2
    exit 1
fi

COMMIT_MESSAGE="${COMMIT_MESSAGE:-Release $TAG}"
RELEASE_TITLE="${RELEASE_TITLE:-$TAG}"

if [[ -n "$NOTES_FILE" && ! -f "$NOTES_FILE" ]]; then
    echo "ERROR: notes file '$NOTES_FILE' not found." >&2
    exit 1
fi

# --- Build -------------------------------------------------------------------
echo "→ Building NotepadMacMac $TAG (release, arm64)…"
swift build -c release --arch arm64

echo "→ Refreshing app bundle and re-signing ad-hoc…"
cp -f .build/arm64-apple-macosx/release/NotepadMacMac \
      NotepadMacMac.app/Contents/MacOS/NotepadMacMac
codesign --force --deep --sign - NotepadMacMac.app >/dev/null

# --- Stage + confirm ---------------------------------------------------------
git add -A

echo
echo "=========================================================="
echo " About to release $TAG"
echo "=========================================================="
echo "  Commit message : $COMMIT_MESSAGE"
echo "  Release title  : $RELEASE_TITLE"
echo "  Notes          : ${NOTES_FILE:-(commit message)}"
echo "  Dry run        : $([[ $DRY_RUN -eq 1 ]] && echo yes || echo no)"
echo
echo "Staged changes:"
git --no-pager diff --cached --stat
echo

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "→ Dry-run; not committing, tagging, pushing, or releasing."
    exit 0
fi

if [[ "$ASSUME_YES" -ne 1 ]]; then
    read -r -p "Proceed? [y/N] " REPLY
    [[ "$REPLY" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
fi

# --- Commit + tag + push -----------------------------------------------------
echo "→ git commit…"
git commit -m "$COMMIT_MESSAGE"

echo "→ git tag ${TAG}…"
git tag -a "$TAG" -m "$COMMIT_MESSAGE"

echo "→ git push origin main…"
git push origin main

echo "→ git push origin ${TAG}…"
git push origin "$TAG"

# --- Build release zips ------------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

VERSIONED_ZIP="$TMP/NotepadMacMac-$TAG-macOS-arm64.zip"
LATEST_ZIP="$TMP/NotepadMacMac-latest.zip"

echo "→ Packaging zips…"
ditto -c -k --sequesterRsrc --keepParent NotepadMacMac.app "$VERSIONED_ZIP"
cp "$VERSIONED_ZIP" "$LATEST_ZIP"

# --- Create GitHub release ---------------------------------------------------
GH_ARGS=( "--title" "$RELEASE_TITLE" )
if [[ -n "$NOTES_FILE" ]]; then
    GH_ARGS+=( "--notes-file" "$NOTES_FILE" )
else
    GH_ARGS+=( "--notes" "$COMMIT_MESSAGE" )
fi

echo "→ gh release create ${TAG}…"
gh release create "$TAG" "${GH_ARGS[@]}" "$VERSIONED_ZIP" "$LATEST_ZIP"

REPO_URL="$(git remote get-url origin | sed 's/\.git$//')"
echo
echo "✓ Released $TAG"
echo "  Release page  : $REPO_URL/releases/tag/$TAG"
echo "  Versioned zip : $REPO_URL/releases/download/$TAG/$(basename "$VERSIONED_ZIP")"
echo "  Stable URL    : $REPO_URL/releases/latest/download/NotepadMacMac-latest.zip"
