# Changelog

## 1.0.0 — 2026-11-15

- Stable release of the multi-device GUI launcher (Windows) + Linux/macOS shell tooling.
- `windows/scrcpy-remote.pyw` — Tkinter GUI: pick one or more devices and mirror (multi-device, per-device status).
- `windows/scrcpy-remote.bat` — CLI launcher: USB/TCP auto-detection, multi-device picker, `--serial`, `--list`, pass-through args.
- Linux/macOS: `install.sh`, `scrcpy-remote.sh`, `adb-wireless-setup.sh`, `adb-remote.sh`, `51-android-usb.rules`.

## 0.1.0 — 2026-11-14

- Initial release.
- `install.sh` — one-shot installer: downloads scrcpy 5.0.1 (SHA256-verified), sets PATH, installs udev rules.
- `scrcpy-remote.sh` — launcher with USB / TCP/IP auto-detection, `--list`, `--status`, passes extra args through to scrcpy.
- `adb-wireless-setup.sh` — switches USB device to Wi-Fi ADB (`adb tcpip 5555`), remembers IP for `--tcp` mode.
- `adb-remote.sh` — TCP ADB helper: connect / disconnect / devices / shell / status.
- `51-android-usb.rules` — udev rules for 15 common Android vendor IDs.
- Full-featured Vysor replacement: full-resolution mirroring, mouse/keyboard control, recording, audio, hardware decode (VA-API).
