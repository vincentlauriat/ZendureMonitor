#!/usr/bin/env bash
# Build a Release ZendureMonitor.app, Developer ID sign with Hardened Runtime,
# notarize via Apple, staple the ticket, package as a distributable .dmg and
# Sparkle-sign it for auto-updates.
#
# ┌──────────────────────────────────────────────────────────────────────────┐
# │ SPARKLE SIGNING KEY — DO NOT REGENERATE                                  │
# │                                                                          │
# │ Updates are EdDSA-signed with the private key in the login keychain      │
# │ under account "ZendureMonitor" (used by sign_update below). Its public   │
# │ half is embedded in the app as SUPublicEDKey in project.yml:             │
# │     14HExMrwENK/Pg8quUbjfXG1szAT3ojoOGPLBgpgx2g=                         │
# │                                                                          │
# │ NEVER run `generate_keys` again for this account and NEVER change        │
# │ SUPublicEDKey — installed apps would reject all future updates.          │
# │ Backup: ~/.sparkle-keys/ZendureMonitor-ed25519-backup.txt                │
# └──────────────────────────────────────────────────────────────────────────┘
#
# Usage: ./Scripts/release.sh <version>   e.g. ./Scripts/release.sh 1.0.0
# Outputs release/ZendureMonitor-<version>.dmg (notarized) and appcast.xml.
# Does NOT push to GitHub — prints the suggested `gh release create` command.

set -euo pipefail

VERSION="${1:?Usage: ./Scripts/release.sh <version>  (e.g. 1.0.0)}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# 1. Sanity check: project.yml must declare the same MARKETING_VERSION
if ! grep -q "MARKETING_VERSION: \"$VERSION\"" project.yml; then
  echo "✗ MARKETING_VERSION in project.yml does not match $VERSION" >&2
  grep "MARKETING_VERSION" project.yml | sed 's/^/    /' >&2
  exit 1
fi

# 2. Regenerate xcodeproj
command -v xcodegen >/dev/null || { echo "✗ brew install xcodegen" >&2; exit 1; }
echo "→ xcodegen generate"
xcodegen generate >/dev/null

# 3. Build Release. CODE_SIGNING_ALLOWED=NO works around the macOS
# `com.apple.provenance` xattr that breaks codesign in CLI; we sign manually
# below after a clean xattr scrub.
echo "→ xcodebuild Release"
xcodebuild -project ZendureMonitor.xcodeproj \
  -scheme ZendureMonitor \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | tail -3

APP="$ROOT/build/Build/Products/Release/ZendureMonitor.app"
[ -d "$APP" ] || { echo "✗ Build did not produce $APP" >&2; exit 1; }

# 4. Stage to a clean directory (ditto --noextattr survives the xattrs that
# make in-place `codesign --force` fail), then sign deepest-first.
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Vincent LAURIAT (KFLACS69T9)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-AppliMacVincentGithub}"

STAGING_DIR="$(mktemp -d)"
STAGING="$STAGING_DIR/ZendureMonitor.app"
echo "→ Staging to $STAGING_DIR"
ditto --norsrc --noextattr --noacl "$APP" "$STAGING"

# Apple's timestamp server is intermittently flaky — retry up to 5 times.
# Optional 2nd arg: entitlements file (app + widget have different ones).
codesign_ts() {
  local target="$1" entitlements="${2:-}" attempt
  local args=(--force --options runtime --timestamp --sign "$SIGNING_IDENTITY")
  [ -n "$entitlements" ] && args+=(--entitlements "$entitlements")
  for attempt in 1 2 3 4 5; do
    codesign "${args[@]}" "$target" && return 0
    [ "$attempt" -lt 5 ] && { echo "  ↻ codesign failed ($attempt/5), retry in 5s…"; sleep 5; }
  done
  echo "✗ codesign $target failed after 5 attempts" >&2
  return 1
}

# Extensions (.appex) are signed BEFORE the app that contains them, each with
# its own entitlements (sandbox + App Group — mandatory for app extensions).
if [ -d "$STAGING/Contents/PlugIns" ]; then
  for appex in "$STAGING/Contents/PlugIns/"*.appex; do
    [ -e "$appex" ] || continue
    name="$(basename "$appex" .appex)"
    echo "→ Codesigning $name.appex"
    codesign_ts "$appex" "$ROOT/$name/$name.entitlements"
  done
fi

echo "→ Codesigning Sparkle.framework nested binaries (deepest first)"
SPARKLE_FW="$STAGING/Contents/Frameworks/Sparkle.framework"
SPARKLE_VER="$SPARKLE_FW/Versions/B"
codesign_ts "$SPARKLE_VER/Autoupdate"
codesign_ts "$SPARKLE_VER/XPCServices/Downloader.xpc"
codesign_ts "$SPARKLE_VER/XPCServices/Installer.xpc"
codesign_ts "$SPARKLE_VER/Updater.app"
codesign_ts "$SPARKLE_FW"

echo "→ Codesigning the app itself with Developer ID + Hardened Runtime"
codesign_ts "$STAGING" "$ROOT/ZendureMonitor.entitlements"
codesign --verify --strict --deep "$STAGING"

# 5. Package as DMG (app + /Applications alias)
RELEASE_DIR="$ROOT/release"
mkdir -p "$RELEASE_DIR"
DMG="$RELEASE_DIR/ZendureMonitor-$VERSION.dmg"
rm -f "$DMG"

DMG_LAYOUT_DIR="$STAGING_DIR/dmg-layout"
mkdir -p "$DMG_LAYOUT_DIR"
ditto --norsrc --noextattr --noacl "$STAGING" "$DMG_LAYOUT_DIR/ZendureMonitor.app"
ln -s /Applications "$DMG_LAYOUT_DIR/Applications"

echo "→ Creating $DMG"
hdiutil create -volname "ZendureMonitor $VERSION" -srcfolder "$DMG_LAYOUT_DIR" \
  -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG" >/dev/null

rm -rf "$STAGING_DIR"

# 6. Notarize + staple
echo "→ Submitting to Apple notary service (2–5 min)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

# 7. Sparkle EdDSA signature + appcast.xml
SPARKLE_TOOLS="$ROOT/.sparkle-tools"
if [ ! -x "$SPARKLE_TOOLS/bin/sign_update" ]; then
  echo "→ Fetching Sparkle 2.9.1 tools (one-time setup)"
  mkdir -p "$SPARKLE_TOOLS"
  curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/2.9.1/Sparkle-2.9.1.tar.xz" \
    | tar -xJ -C "$SPARKLE_TOOLS"
fi

echo "→ Signing $DMG with Sparkle EdDSA key"
SPARKLE_SIG_LINE=$("$SPARKLE_TOOLS/bin/sign_update" --account "ZendureMonitor" "$DMG")

# Sparkle compares <sparkle:version> against CFBundleVersion (build number),
# not the marketing version — read the real one baked into the app.
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Contents/Info.plist")

echo "→ Writing appcast.xml (sparkle:version=$BUILD_NUMBER, shortVersionString=$VERSION)"
PUB_DATE=$(date -R)
cat > "$ROOT/appcast.xml" <<APPCAST
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>ZendureMonitor</title>
    <link>https://raw.githubusercontent.com/vincentlauriat/ZendureMonitor/main/appcast.xml</link>
    <description>ZendureMonitor release feed</description>
    <language>en</language>
    <item>
      <title>v$VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$BUILD_NUMBER</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/vincentlauriat/ZendureMonitor/releases/tag/v$VERSION</sparkle:releaseNotesLink>
      <enclosure
        url="https://github.com/vincentlauriat/ZendureMonitor/releases/download/v$VERSION/ZendureMonitor-$VERSION.dmg"
        type="application/octet-stream"
        $SPARKLE_SIG_LINE />
    </item>
  </channel>
</rss>
APPCAST

DMG_SIZE=$(ls -lh "$DMG" | awk '{print $5}')
echo ""
echo "✅ Built, signed, notarized, stapled and Sparkle-signed: $DMG ($DMG_SIZE)"
echo "✅ appcast.xml written for v$VERSION"
echo ""
echo "Next steps:"
echo "  1. git add appcast.xml && git commit -m 'chore: appcast for v$VERSION' && push/merge to main"
echo "  2. gh release create v$VERSION $DMG --title \"v$VERSION\" --notes-file release/release-notes-$VERSION.md"
