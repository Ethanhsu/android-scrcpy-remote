#!/bin/bash
# Switch a USB-connected Android device to Wi-Fi ADB (tcpip 5555).
# After this, you can unplug USB and control the device over the network.
# Requires: device connected via USB with USB debugging enabled.
set -euo pipefail

SCRCPY_DIR="$HOME/tools/scrcpy"
export PATH="$SCRCPY_DIR:$PATH"
if [ -x "$HOME/android-sdk/platform-tools/adb" ]; then
  ADB="$HOME/android-sdk/platform-tools/adb"
elif [ -x "$SCRCPY_DIR/adb" ]; then
  ADB="$SCRCPY_DIR/adb"
fi
[ -x "$ADB" ] || { echo "ERROR: adb not found. Run install.sh first." >&2; exit 1; }

SERIAL=$("$ADB" devices | awk '/device$/ && $1 !~ /:/{print $1; exit}')
if [ -z "$SERIAL" ]; then
  echo "ERROR: no USB device found. Plug in the device first." >&2
  exit 1
fi

echo "Device: $SERIAL ($("$ADB" -s "$SERIAL" shell getprop ro.product.model 2>/dev/null))"

# Find the device's Wi-Fi IP
DEVICE_IP=$("$ADB" -s "$SERIAL" shell ip -4 addr show wlan0 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
if [ -z "$DEVICE_IP" ]; then
  # fallback: parse `ifconfig` or `netcfg`
  DEVICE_IP=$("$ADB" -s "$SERIAL" shell netcfg 2>/dev/null | grep -oP 'inet addr:\K[\d.]+' | head -1)
fi
if [ -z "$DEVICE_IP" ]; then
  echo "WARN: could not auto-detect device Wi-Fi IP." >&2
  echo "      Check the device's Wi-Fi settings and run: adb connect <ip>:5555" >&2
  exit 1
fi

echo "Switching adbd to TCP mode (port 5555)..."
"$ADB" -s "$SERIAL" tcpip 5555

sleep 1
echo "Connecting over Wi-Fi at $DEVICE_IP:5555 ..."
"$ADB" connect "$DEVICE_IP:5555"

# Remember for scrcpy-remote.sh --tcp
CFG_DIR="$HOME/.config/android-scrcpy-remote"
mkdir -p "$CFG_DIR"
echo "$DEVICE_IP:5555" > "$CFG_DIR/last-device"
echo "Remembered $DEVICE_IP:5555 in $CFG_DIR/last-device"

echo ""
echo "Done. You can now unplug USB."
echo "  Mirror:  scrcpy-remote.sh --tcp"
echo "  Revert:  plug USB back in, then run: adb -s $SERIAL usb"
