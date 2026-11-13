#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"
app_dir="$PWD/dist/Snowfall.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/Snowfall" "$app_dir/Contents/MacOS/Snowfall"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleExecutable</key><string>Snowfall</string>
    <key>CFBundleIdentifier</key><string>io.github.ponyfly6.snowfall</string>
    <key>CFBundleName</key><string>Snowfall</string>
    <key>CFBundleDisplayName</key><string>桌面飘雪</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticTermination</key><false/>
    <key>CFBundleIconFile</key><string>AppIcon</string>
</dict></plist>
PLIST
if [[ -f Resources/AppIcon.icns ]]; then
    cp Resources/AppIcon.icns "$app_dir/Contents/Resources/AppIcon.icns"
fi
codesign --force --sign - "$app_dir"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$PWD/dist/Snowfall-macOS.zip"
print "Built $app_dir"
