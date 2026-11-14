# Changelog

## 0.1.0 — 2026-11-14

- Initial release.
- `install.sh` — one-shot installer: downloads scrcpy 5.0.1 (SHA256-verified), sets PATH, installs udev rules.
- `scrcpy-remote.sh` — launcher with USB / TCP/IP auto-detection, `--list`, `--status`, passes extra args through to scrcpy.
- `adb-wireless-setup.sh` — switches USB device to Wi-Fi ADB (`adb tcpip 5555`), remembers IP for `--tcp` mode.
- `adb-remote.sh` — TCP ADB helper: connect / disconnect / devices / shell / status.
- `51-android-usb.rules` — udev rules for 15 common Android vendor IDs.
- Full-featured Vysor replacement: full-resolution mirroring, mouse/keyboard control, recording, audio, hardware decode (VA-API).
