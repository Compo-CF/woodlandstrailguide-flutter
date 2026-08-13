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
# 2026-08-13: a brand new Terminal window on this account turned out to
# be running BASH (see the "-bash" window title / "-bash: command not
# found" error style), not zsh, despite macOS's own "default shell is
# now zsh" banner — so PATH lines appended only to ~/.zshrc silently
# never took effect in a fresh window. Every PATH/env line below now
# gets written to BOTH ~/.zshrc and ~/.bash_profile so it works
# whichever shell a given Terminal window actually launches.
#
# Usage: bash scripts/macincloud-setup.sh

set -e

# Appends a line to both rc files, once each (idempotent).
persist_env() {
  local line="$1"
  for rc in ~/.zshrc ~/.bash_profile; do
    grep -qF "$line" "$rc" 2>/dev/null || echo "$line" >> "$rc"
  done
}

# --- Flutter SDK (official git-clone method, no Homebrew) ---
if [ ! -d ~/flutter ]; then
  echo "Cloning Flutter stable..."
  git clone https://github.com/flutter/flutter.git -b stable ~/flutter
fi
persist_env 'export PATH="$HOME/flutter/bin:$PATH"'
export PATH="$HOME/flutter/bin:$PATH"

# --- Android SDK command-line tools only (no full Android Studio GUI) ---
mkdir -p ~/android-sdk/cmdline-tools
if [ ! -d ~/android-sdk/cmdline-tools/latest ]; then
  ARCH=$(uname -m)
  if [ "$ARCH" = "arm64" ]; then
    URL="https://dl.google.com/android/repository/commandlinetools-mac_arm64-15859902_latest.zip"
  else
    URL="https://dl.google.com/android/repository/commandlinetools-mac_x86_64-15859902_latest.zip"
  fi
  echo "Downloading Android command-line tools for $ARCH..."
  curl -L -o /tmp/cmdline-tools.zip "$URL"
  unzip -o -q /tmp/cmdline-tools.zip -d ~/android-sdk/cmdline-tools
  # The zip extracts to cmdline-tools/cmdline-tools/ — sdkmanager expects
  # cmdline-tools/latest/ specifically.
  mv ~/android-sdk/cmdline-tools/cmdline-tools ~/android-sdk/cmdline-tools/latest
fi

persist_env 'export ANDROID_HOME="$HOME/android-sdk"'
persist_env 'export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"'
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# --- JDK 17+ (sdkmanager refuses to run on anything older; this machine's
# default `java` was 11.0.16.1). Standalone Temurin download, same
# no-Homebrew/no-sudo philosophy as everything else here. ---
JAVA_MAJOR=$(java -version 2>&1 | head -1 | grep -oE '"[0-9]+' | tr -d '"')
if [ -z "$JAVA_MAJOR" ] || [ "$JAVA_MAJOR" -lt 17 ] 2>/dev/null; then
  if [ ! -x ~/jdk17/Contents/Home/bin/java ]; then
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then ADOPTIUM_ARCH="aarch64"; else ADOPTIUM_ARCH="x64"; fi
    echo "System Java is too old ($JAVA_MAJOR) for sdkmanager — installing a standalone Temurin 17..."
    curl -L -o /tmp/jdk17.tar.gz "https://api.adoptium.net/v3/binary/latest/17/ga/mac/$ADOPTIUM_ARCH/jdk/hotspot/normal/eclipse?project=jdk"
    mkdir -p ~/jdk17
    tar -xzf /tmp/jdk17.tar.gz -C ~/jdk17 --strip-components=1
  fi
  persist_env 'export JAVA_HOME="$HOME/jdk17/Contents/Home"'
  persist_env 'export PATH="$JAVA_HOME/bin:$PATH"'
  export JAVA_HOME="$HOME/jdk17/Contents/Home"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

echo "Accepting SDK licenses + installing platform-tools (adb)..."
yes | sdkmanager --licenses > /dev/null
sdkmanager "platform-tools"

echo ""
echo "=== flutter doctor ==="
flutter doctor -v

echo ""
echo "Setup done. A brand new Terminal window should pick all of this up"
echo "automatically now (persisted to both ~/.zshrc and ~/.bash_profile)."
echo "If it somehow doesn't: source ~/.bash_profile (or ~/.zshrc)."
echo "To build a debug APK for sideloading: flutter build apk --debug --target-platform=android-arm64"
echo "Output lands at build/app/outputs/flutter-apk/app-debug.apk"
