#!/bin/bash
# One-shot installer for android-scrcpy-remote.
# Downloads official scrcpy (SHA256-verified) into ~/tools/scrcpy,
# adds it to PATH, and installs udev rules for USB ADB access.
set -euo pipefail

SCRCPY_VERSION="5.0.1"
SCRCPY_URL="https://github.com/Genymobile/scrcpy/releases/download/v${SCRCPY_VERSION}/scrcpy-linux-x86_64-v${SCRCPY_VERSION}.tar.gz"
SCRCPY_SHA256="9f969d30cc574816077edecda65719c1c70b0aee1df1ba5fa00779ac07b8fd6e"
SCRCPY_DIR="$HOME/tools/scrcpy"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Checking existing installation..."
if [ -x "$SCRCPY_DIR/scrcpy" ]; then
  existing=$("$SCRCPY_DIR/scrcpy" --version 2>/dev/null | head -1 || echo "unknown")
  echo "    scrcpy already installed at $SCRCPY_DIR ($existing)"
else
  echo "==> Downloading scrcpy v${SCRCPY_VERSION}..."
  tmp="$(mktemp -d)"
  curl -sL --fail -o "$tmp/scrcpy.tar.gz" "$SCRCPY_URL"
  echo "==> Verifying SHA256..."
  echo "${SCRCPY_SHA256}  $tmp/scrcpy.tar.gz" | sha256sum --check -
  echo "==> Extracting to $SCRCPY_DIR..."
  mkdir -p "$SCRCPY_DIR"
  tar -xzf "$tmp/scrcpy.tar.gz" -C "$SCRCPY_DIR" --strip-components=1
  rm -rf "$tmp"
fi

echo "==> Adding to PATH (~/.bashrc)..."
if ! grep -q 'tools/scrcpy' ~/.bashrc 2>/dev/null; then
  echo 'export PATH="$HOME/tools/scrcpy:$HOME/.local/bin:$PATH"' >> ~/.bashrc
  echo "    PATH updated."
else
  echo "    PATH already set."
fi

echo "==> Installing udev rules for USB ADB (needs sudo)..."
if [ -f "$SCRIPT_DIR/51-android-usb.rules" ]; then
  sudo cp "$SCRIPT_DIR/51-android-usb.rules" /etc/udev/rules.d/
  sudo udevadm control --reload-rules
  sudo udevadm trigger
  echo "    udev rules installed (re-plug your device for them to take effect)."
else
  echo "    WARNING: 51-android-usb.rules not found next to install.sh — skipping."
fi

echo "==> Verifying..."
"$SCRCPY_DIR/scrcpy" --version | head -1

echo ""
echo "Done. Usage:"
echo "  $SCRIPT_DIR/scrcpy-remote.sh            # USB"
echo "  $SCRIPT_DIR/scrcpy-remote.sh --tcp      # Wi-Fi ADB (set up first with adb-wireless-setup.sh)"
