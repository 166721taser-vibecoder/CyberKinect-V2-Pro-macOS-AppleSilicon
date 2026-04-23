#!/bin/bash
# Move to the script's directory for relative paths to work
cd "$(dirname "$0")"

echo "🌀 Installing CyberKinect-V2-Pro (Apple Silicon macOS) v1.0..."

# Architecture check
ARCH=$(uname -m)
if [ "$ARCH" != "arm64" ]; then
    echo "⚠️ Warning: This build is optimized for Apple Silicon (M1/M2/M3)."
    echo "You are on $ARCH. Compilation might need adjustments."
fi

# Deps
if ! command -v brew &> /dev/null; then echo "❌ Install Homebrew first!"; exit 1; fi
brew install libfreenect2 libusb

# Build
echo "🏗 Building..."
xcrun -sdk macosx metal -c Sources/Shaders.metal -o Shaders.air
xcrun -sdk macosx metallib Shaders.air -o default.metallib

arch -arm64 swiftc Sources/main.swift Bridge/KinectBridge.o \
  -o CyberKinect_Bin \
  -I Bridge \
  -L Libraries \
  -L /opt/homebrew/lib \
  -lfreenect2 -lusb-1.0 -lstdc++

# Package
mkdir -p CyberKinect.app/Contents/MacOS
mkdir -p CyberKinect.app/Contents/Resources
cp CyberKinect_Bin CyberKinect.app/Contents/MacOS/CyberKinect
cp default.metallib CyberKinect.app/Contents/Resources/
cp Resources/AppIcon.icns CyberKinect.app/Contents/Resources/
cp Libraries/libfreenect2.dylib CyberKinect.app/Contents/MacOS/libfreenect2.0.2.dylib
cp Libraries/libusb-1.0.0.dylib CyberKinect.app/Contents/MacOS/libusb-1.0.0.dylib

# Plist
echo '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleExecutable</key><string>CyberKinect</string><key>CFBundleIconFile</key><string>AppIcon</string><key>CFBundleIdentifier</key><string>com.vj.cyberkinect</string><key>CFBundleName</key><string>CyberKinect</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>1.0</string><key>NSMicrophoneUsageDescription</key><string>Audio reactivity</string><key>LSMinimumSystemVersion</key><string>12.0</string></dict></plist>' > CyberKinect.app/Contents/Info.plist

install_name_tool -change @rpath/libfreenect2.0.2.dylib @executable_path/libfreenect2.0.2.dylib CyberKinect.app/Contents/MacOS/CyberKinect
install_name_tool -change /opt/homebrew/opt/libusb/lib/libusb-1.0.0.dylib @executable_path/libusb-1.0.0.dylib CyberKinect.app/Contents/MacOS/CyberKinect
codesign --force --sign - CyberKinect.app
xattr -cr CyberKinect.app

echo "✅ DONE! CyberKinect.app is ready."
