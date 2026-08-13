#!/bin/zsh
# One-time Android/Flutter toolchain setup for a MacInCloud RDP session.
#
# Mirrors the woodlands-fishing xcodegen fix: MacInCloud's Homebrew tree
# hits ownership/permission errors for non-owner installs, and sudo isn't
# reliable across plans — so everything here is a direct download into
# the user's own home directory instead of `brew install`. The home
# directory persists between sessions on the same MacInCloud account, so
# this is effectively a one-time cost; re-run it any time, it's idempotent
# (skips anything already installed).
#
# This machine is for BUILDING Android apps, not running an emulator —
# nested virtualization on a shared cloud Mac makes the emulator
# impractical. Verification happens by sideloading the built .apk
# directly onto a real device instead (see README below).
#
# Usage: bash scripts/macincloud-setup.sh

set -e

# --- Flutter SDK (official git-clone method, no Homebrew) ---
if [ ! -d ~/flutter ]; then
  echo "Cloning Flutter stable..."
  git clone https://github.com/flutter/flutter.git -b stable ~/flutter
fi
grep -q 'HOME/flutter/bin' ~/.zshrc 2>/dev/null || echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zshrc
export PATH="$HOME/flutter/bin:$PATH"

# --- Android SDK command-line tools only (no full Android Studio GUI) ---
mkdir -p ~/android-sdk/cmdline-tools
if [ ! -d ~/android-sdk/cmdline-tools/latest ]; then
  ARCH=$(uname -m)
  if [ "$ARCH" = "arm64" ]; then
    URL="https://edgedl.me.gvt1.com/android/studio/ide-zips/commandlinetools-mac_arm64-15859902_latest.zip"
  else
    URL="https://edgedl.me.gvt1.com/android/studio/ide-zips/commandlinetools-mac_x86_64-15859902_latest.zip"
  fi
  echo "Downloading Android command-line tools for $ARCH..."
  curl -L -o /tmp/cmdline-tools.zip "$URL"
  unzip -o -q /tmp/cmdline-tools.zip -d ~/android-sdk/cmdline-tools
  # The zip extracts to cmdline-tools/cmdline-tools/ — sdkmanager expects
  # cmdline-tools/latest/ specifically.
  mv ~/android-sdk/cmdline-tools/cmdline-tools ~/android-sdk/cmdline-tools/latest
fi

grep -q 'ANDROID_HOME' ~/.zshrc 2>/dev/null || cat >> ~/.zshrc <<'ZRC'
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
ZRC
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

echo "Accepting SDK licenses + installing platform-tools (adb)..."
yes | sdkmanager --licenses > /dev/null
sdkmanager "platform-tools"

echo ""
echo "=== flutter doctor ==="
flutter doctor -v

echo ""
echo "Setup done. Next time, just: source ~/.zshrc"
echo "To build a debug APK for sideloading: flutter build apk --debug"
echo "Output lands at build/app/outputs/flutter-apk/app-debug.apk"
