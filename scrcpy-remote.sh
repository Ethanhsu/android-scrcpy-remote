#!/bin/bash
# scrcpy-remote — Vysor replacement launcher.
# Mirrors an Android device at full resolution with mouse/keyboard control.
# Supports USB and TCP/IP (Wi-Fi ADB) transports.
#
# Usage: scrcpy-remote.sh [options] [extra scrcpy args]
#   --usb              Force USB mode
#   --tcp              Force TCP/IP mode (uses remembered IP or --ip)
#   --ip <addr>        TCP device address, e.g. 192.168.1.50:5555
#   --list             List connected ADB devices and exit
#   --status           Show device status and exit
#   --help             Show help
# Anything else is passed through to scrcpy.
set -euo pipefail

SCRCPY_DIR="$HOME/tools/scrcpy"
export PATH="$SCRCPY_DIR:$PATH"
CFG_DIR="$HOME/.config/android-scrcpy-remote"
LAST_DEVICE_FILE="$CFG_DIR/last-device"
ADB=""
# Prefer a full platform-tools adb if present (has adb + full tooling),
# otherwise use the adb bundled with scrcpy.
if [ -x "$HOME/android-sdk/platform-tools/adb" ]; then
  ADB="$HOME/android-sdk/platform-tools/adb"
elif [ -x "$SCRCPY_DIR/adb" ]; then
  ADB="$SCRCPY_DIR/adb"
fi
if [ -z "$ADB" ] || [ ! -x "$ADB" ]; then
  echo "ERROR: adb not found. Install android platform-tools or run install.sh." >&2
  exit 1
fi

usage() {
  grep '^#   ' "$0" | sed 's/^#   //'
}

MODE="auto"
TCP_IP=""

while [ $# -gt 0 ]; do
  case "$1" in
    --usb) MODE="usb"; shift ;;
    --tcp) MODE="tcp"; shift ;;
    --ip)  TCP_IP="$2"; shift 2 ;;
    --list)
      "$ADB" devices -l
      exit 0
      ;;
    --status)
      "$ADB" devices
      SERIAL=$("$ADB" devices | awk '/device$/{print $1; exit}')
      if [ -n "$SERIAL" ]; then
        echo "--- device $SERIAL ---"
        "$ADB" -s "$SERIAL" shell getprop ro.product.model 2>/dev/null
        "$ADB" -s "$SERIAL" shell ip -4 addr show 2>/dev/null | grep 'inet ' || true
        "$ADB" -s "$SERIAL" shell dumpsys battery 2>/dev/null | grep -E 'level|status' || true
      fi
      exit 0
      ;;
    --help) usage; exit 0 ;;
    *) break ;;
  esac
done
SCRCPY_ARGS=("$@")

ensure_device() {
  local want_mode="$1"
  local serial
  if [ "$want_mode" = "tcp" ]; then
    # Pick the TCP device (serial contains ':')
    serial=$("$ADB" devices | awk '/device$/ && $1 ~ /:/{print $1; exit}')
    if [ -z "$serial" ] && [ -n "$TCP_IP" ]; then
      "$ADB" connect "$TCP_IP" >/dev/null 2>&1 || true
      serial=$("$ADB" devices | awk -v ip="$TCP_IP" '$1==ip && /device$/{print $1; exit}')
    fi
    if [ -z "$serial" ]; then
      if [ -f "$LAST_DEVICE_FILE" ]; then
        local remembered
        remembered="$(cat "$LAST_DEVICE_FILE")"
        echo "No TCP device connected. Trying remembered $remembered ..."
        "$ADB" connect "$remembered" >/dev/null 2>&1 || true
        serial=$("$ADB" devices | awk -v ip="$remembered" '$1==ip && /device$/{print $1; exit}')
      fi
      if [ -z "$serial" ]; then
        echo "ERROR: no TCP/IP ADB device found." >&2
        echo "  - Is the device on the same network?" >&2
        echo "  - Run adb-wireless-setup.sh first (USB needed once)." >&2
        echo "  - Or pass --ip <device-ip>:5555" >&2
        exit 1
      fi
    fi
    mkdir -p "$CFG_DIR"
    echo "$serial" > "$LAST_DEVICE_FILE"
    echo "TCP device: $serial"
    echo "$serial"
    return
  fi
  # USB mode: serial without ':'
  serial=$("$ADB" devices | awk '/device$/ && $1 !~ /:/{print $1; exit}')
  if [ -z "$serial" ]; then
    echo "ERROR: no USB ADB device found." >&2
    echo "  - Connect device via USB, enable USB debugging, accept RSA prompt." >&2
    echo "  - Or use --tcp for Wi-Fi ADB." >&2
    exit 1
  fi
  echo "USB device: $serial"
  echo "$serial"
}

if ! command -v scrcpy >/dev/null 2>&1; then
  echo "ERROR: scrcpy not found. Run install.sh first." >&2
  exit 1
fi

if [ "$MODE" = "tcp" ]; then
  SERIAL=$(ensure_device tcp)
  exec scrcpy --serial "$SERIAL" "${SCRCPY_ARGS[@]}"
else
  # auto: prefer USB, fall back to TCP remembered device
  USB_SERIAL=$("$ADB" devices 2>/dev/null | awk '/device$/ && $1 !~ /:/{print $1; exit}' || true)
  if [ "$MODE" = "usb" ] || [ -n "$USB_SERIAL" ]; then
    if [ "$MODE" = "usb" ] && [ -z "$USB_SERIAL" ]; then
      SERIAL=$(ensure_device usb)
    else
      SERIAL="$USB_SERIAL"
      echo "USB device: $SERIAL"
    fi
    exec scrcpy --serial "$SERIAL" "${SCRCPY_ARGS[@]}"
  fi
  echo "No USB device — falling back to TCP/IP mode."
  SERIAL=$(ensure_device tcp)
  exec scrcpy --serial "$SERIAL" "${SCRCPY_ARGS[@]}"
fi
