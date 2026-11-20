#!/usr/bin/env bash
# Tını'yı derler ve /Applications'a kurar. Kullanım: bash kurulum/kur.sh
# TINI_APP=<yol> ile başka bir yere paketler.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${TINI_APP:-/Applications/Tını.app}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "1/3 Derleniyor…"
(cd "$ROOT" && swift build -c release -q)

echo "2/3 Simge çiziliyor…"
swift "$ROOT/kurulum/simge.swift" "$WORK/icon.png"
mkdir -p "$WORK/AppIcon.iconset"
for s in 16 32 128 256 512; do
  sips -z $s $s "$WORK/icon.png" --out "$WORK/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$WORK/icon.png" --out "$WORK/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$WORK/AppIcon.iconset" -o "$WORK/AppIcon.icns"

echo "3/3 Paketleniyor…"
pkill -x Tini 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/Tini" "$APP/Contents/MacOS/Tini"
cp "$WORK/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Tını</string>
  <key>CFBundleDisplayName</key><string>Tını</string>
  <key>CFBundleIdentifier</key><string>com.oguzhankodal.tini</string>
  <key>CFBundleExecutable</key><string>Tini</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key><string>Ses</string>
      <key>CFBundleTypeRole</key><string>Viewer</string>
      <key>LSHandlerRank</key><string>Alternate</string>
      <key>LSItemContentTypes</key><array><string>public.audio</string></array>
    </dict>
  </array>
</dict>
</plist>
PLIST
codesign --force --deep --sign - "$APP" >/dev/null
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null || true
echo "Hazır: $APP"
open "$APP"
