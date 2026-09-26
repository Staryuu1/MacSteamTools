#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
SDK_PATH="${SDKROOT:-}"
if [[ -z "$SDK_PATH" ]]; then
    if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ]]; then
        SDK_PATH=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
    else
        SDK_PATH="$(xcrun --show-sdk-path)"
    fi
fi

# --- Build Swift app ---
swift build -c release --disable-sandbox --build-system native --sdk "$SDK_PATH"
APP="$PWD/dist/MacSteamTools.app"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp .build/release/MacSteamTools "$APP/Contents/MacOS/MacSteamTools"
cp -r Language "$APP/Contents/Resources/"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MacSteamTools</string>
<key>CFBundleIdentifier</key><string>local.macsteamtools.app</string>
<key>CFBundleName</key><string>MacSteamTools</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
printf 'Built: %s\n' "$APP"
