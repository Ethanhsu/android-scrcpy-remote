# Windows

Prebuilt scrcpy **5.0.1 win64** plus a launcher, in a ready-to-run folder.
Unlike the Linux `install.sh` at the repo root, everything you need is
already here — no download step.

## Contents

| File | Purpose |
|------|---------|
| `scrcpy.exe` | scrcpy 5.0.1 (official win64 build) |
| `scrcpy-remote.pyw` | **GUI launcher** — pick one or more devices and mirror |
| `scrcpy-remote.bat` | Command-line launcher (auto-detect / picker / `--serial`) |
| `adb.exe`, `AdbWin*.dll` | Bundled ADB |
| `scrcpy-server` | Device-side server (pushed to the phone automatically) |
| `*.dll` | scrcpy runtime deps (SDL3, FFmpeg, libusb) |

## Quick start (GUI, recommended)

Requires Python 3 with Tk (preinstalled on most Windows Python installs).

Double-click **`scrcpy-remote.pyw`**, or:

```
pythonw scrcpy-remote.pyw
```

1. Click **Refresh** to scan for connected devices.
2. Check the box next to each device you want to mirror.
3. Click **Mirror selected** — one scrcpy window opens per device.
4. Optional: add scrcpy args like `-m 1080` or `--always-on-top`.
5. **Stop all** terminates every running scrcpy window.

The log pane streams each device's scrcpy output, tagged with its serial.
scrcpy runs with `CREATE_NO_WINDOW`, so no stray console windows appear.

## Quick start (command line)

```
scrcpy-remote.bat                      auto-detect (picker if >1 device)
scrcpy-remote.bat --list               list ADB devices
scrcpy-remote.bat --serial <id>        target one device (e.g. 192.168.22.114:5555)
scrcpy-remote.bat --usb / --tcp        filter by transport
scrcpy-remote.bat -m 1080              pass extra args straight to scrcpy
```

Or use scrcpy directly:

```
scrcpy.exe --serial <device-id>
```

## Connecting devices

- **USB**: enable *USB debugging* in the device's developer options, plug in,
  and accept the RSA prompt on the device.
- **Wi-Fi ADB**: on the device, `adb tcpip 5555`, then on the PC
  `adb connect <device-ip>:5555`.

## Multi-device

scrcpy fully supports multiple devices. The GUI launches one scrcpy process
per selected device (staggered ~1.5 s apart to avoid ADB contention). Each
window is independent — close one and the others keep running.
