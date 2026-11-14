#!/bin/bash
# adb-remote — TCP/IP ADB helper: connect/disconnect/status over Wi-Fi.
# Usage:
#   adb-remote.sh connect <ip:port>    adb connect to a TCP device
#   adb-remote.sh disconnect [ip:port] adb disconnect (default: all TCP devices)
#   adb-remote.sh devices              list all ADB devices (USB + TCP)
#   adb-remote.sh shell <cmd...>       run a command on the (first) device
#   adb-remote.sh status               device info summary
set -euo pipefail

SCRCPY_DIR="$HOME/tools/scrcpy"
export PATH="$SCRCPY_DIR:$PATH"
if [ -x "$HOME/android-sdk/platform-tools/adb" ]; then
  ADB="$HOME/android-sdk/platform-tools/adb"
elif [ -x "$SCRCPY_DIR/adb" ]; then
  ADB="$SCRCPY_DIR/adb"
fi
[ -x "$ADB" ] || { echo "ERROR: adb not found. Run install.sh first." >&2; exit 1; }

cmd="${1:-help}"
shift || true

case "$cmd" in
  connect)
    [ $# -ge 1 ] || { echo "Usage: adb-remote.sh connect <ip:port>" >&2; exit 1; }
    "$ADB" connect "$@"
    ;;
  disconnect)
    if [ $# -ge 1 ]; then
      "$ADB" disconnect "$@"
    else
      # disconnect only TCP devices (serials containing ':')
      while read -r serial; do
        [ -n "$serial" ] && "$ADB" disconnect "$serial"
      done < <("$ADB" devices | awk '/device$/ && $1 ~ /:/{print $1}')
    fi
    ;;
  devices)
    "$ADB" devices -l
    ;;
  shell)
    SERIAL=$("$ADB" devices | awk '/device$/{print $1; exit}')
    [ -n "$SERIAL" ] || { echo "No device." >&2; exit 1; }
    exec "$ADB" -s "$SERIAL" shell "$@"
    ;;
  status)
    "$ADB" devices
    while read -r serial; do
      [ -z "$serial" ] && continue
      echo "=== $serial ==="
      "$ADB" -s "$serial" shell getprop ro.product.model 2>/dev/null || true
      "$ADB" -s "$serial" shell getprop ro.build.version.release 2>/dev/null || true
      "$ADB" -s "$serial" shell dumpsys battery 2>/dev/null | grep -E 'level|status|health' || true
    done < <("$ADB" devices | awk '/device$/{print $1}')
    ;;
  *)
    echo "Usage: adb-remote.sh {connect <ip:port>|disconnect [ip]|devices|shell <cmd>|status}" >&2
    exit 1
    ;;
esac
