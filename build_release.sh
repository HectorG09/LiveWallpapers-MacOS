#!/bin/bash
set -e

VERSION="1.0.4"

cd "$(dirname "$0")"

echo "Building release $VERSION..."
swift build -c release

echo "Creating app bundle..."
rm -rf LiveWallpapers.app
mkdir -p LiveWallpapers.app/Contents/MacOS
mkdir -p LiveWallpapers.app/Contents/Resources
cp .build/release/LiveWallpapers LiveWallpapers.app/Contents/MacOS/LiveWallpapers
chmod +x LiveWallpapers.app/Contents/MacOS/LiveWallpapers

if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns LiveWallpapers.app/Contents/Resources/AppIcon.icns
fi

cat > LiveWallpapers.app/Contents/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>LiveWallpapers</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.LiveWallpapers</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>LiveWallpapers</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "Signing app..."
codesign --force --deep --sign - LiveWallpapers.app

echo "Clearing quarantine..."
xattr -cr LiveWallpapers.app

echo "Done: LiveWallpapers.app"
