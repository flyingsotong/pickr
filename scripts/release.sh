#!/usr/bin/env bash
# Pickr release: archive + export for the Mac App Store.
#
# WHY THIS EXISTS: signing must happen in the GUI (Aqua) session. An SSH session gets its own
# security session in which the login keychain is locked, so `codesign` cannot reach the private
# key and dies with errSecInternalComponent ("User interaction is not allowed"). Everything
# before signing — compiling, linking, choosing the identity — works fine over SSH, which makes
# the failure look like a toolchain problem when it is not.
#
# Run it from a Terminal window on the Mac, or launch it into the GUI session with:
#     open ~/bin/pickr-release.command
#
# Produces ~/PickrRelease/Pickr.xcarchive, a .pkg in ~/PickrRelease/export, and release.log.
set -uo pipefail

REPO="${REPO:-$HOME/github-projects/pickr}"
OUT="${OUT:-$HOME/PickrRelease}"
ARCHIVE="$OUT/Pickr.xcarchive"
EXPORT="$OUT/export"
LOG="$OUT/release.log"

export PATH=/opt/homebrew/bin:$PATH

mkdir -p "$OUT"
exec > >(tee -a "$LOG") 2>&1

echo "=================== $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==================="
cd "$REPO" || { echo "RELEASE_FAILED: no repo at $REPO"; exit 1; }

echo "== toolchain =="
xcodebuild -version
echo "== source under release =="
git log --oneline -1
git status --porcelain | head -5

# Pull before archiving, always. Editing happens on the VPS and building happens here, so a
# release that skips this silently ships the previous commit — which has already happened once.
# Generated files are reverted first so the pull cannot conflict with xcodegen output.
echo
echo "== syncing source =="
git checkout -- Pickr.xcodeproj/project.pbxproj Info.plist 2>/dev/null
git pull --ff-only
echo "== releasing commit =="
git log --oneline -1

rm -rf "$ARCHIVE" "$EXPORT"

echo
echo "== archive =="
xcodebuild -project Pickr.xcodeproj -scheme Pickr -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  archive
ARC=$?
echo "archive exit: $ARC"
if [ "$ARC" -ne 0 ]; then
  echo "RELEASE_FAILED: archive ($ARC)"
  exit "$ARC"
fi

cat > "$OUT/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>ZB4AZ43PV4</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
PLIST

echo
echo "== export (creates the Apple Distribution cert if it does not exist yet) =="
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -allowProvisioningUpdates
EXP=$?
echo "export exit: $EXP"
if [ "$EXP" -ne 0 ]; then
  echo "RELEASE_FAILED: export ($EXP)"
  exit "$EXP"
fi

echo
echo "== artifacts =="
ls -lh "$EXPORT"
echo "== signed identity =="
codesign -dv --verbose=2 "$ARCHIVE/Products/Applications/Pickr.app" 2>&1 | grep -E "Authority|TeamIdentifier"
echo "RELEASE_OK"
