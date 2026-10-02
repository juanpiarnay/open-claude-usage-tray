#!/bin/sh
# Builds build/OpenClaudeUsageTray.app (works with just the Xcode Command Line Tools).
set -e
cd "$(dirname "$0")"

swift build -c release
APP=build/OpenClaudeUsageTray.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/OpenClaudeUsageTray "$APP/Contents/MacOS/"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.juanpiarnay.open-claude-usage-tray</string>
    <key>CFBundleName</key><string>Open Claude Usage Tray</string>
    <key>CFBundleExecutable</key><string>OpenClaudeUsageTray</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --sign - --force "$APP"
echo "Built $APP"
