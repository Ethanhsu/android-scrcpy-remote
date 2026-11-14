# Android Scrcpy Remote

Local, free, full-featured replacement for Vysor — mirrors an Android device to the host at full resolution with mouse/keyboard control, over USB or TCP/IP (Wi-Fi ADB). Built on [scrcpy](https://github.com/Genymobile/scrcpy) (v5.0.1), zero cost, no watermark, no resolution lock.

## Why not Vysor?

Vysor's free version caps the device view at 1/4 of the screen. This project uses scrcpy under the hood: full device screen at any resolution, hardware-accelerated decoding (VA-API / NVDEC on your RTX 3090), low latency, and all of Vysor's paid features (recording, audio, wireless, multi-device) for free.

## What's in this repo

```
android-scrcpy-remote/
├── install.sh              # One-shot installer: downloads scrcpy, sets PATH, udev rules
├── scrcpy-remote.sh        # Main launcher: USB or TCP/IP, with device auto-detection
├── adb-wireless-setup.sh   # Switches a USB-connected device to Wi-Fi ADB (tcpip)
├── adb-remote.sh           # Remote ADB helper: connect/disconnect/status over TCP
├── 51-android-usb.rules    # udev rules for non-root USB ADB access
├── windows/                # Windows: prebuilt scrcpy 5.0.1 win64 + GUI/CLI launchers
│   ├── scrcpy-remote.pyw   #   GUI launcher: pick one or more devices, mirror, stop
│   ├── scrcpy-remote.bat   #   CLI launcher: auto-detect / picker / --serial
│   ├── scrcpy.exe          #   scrcpy 5.0.1 win64
│   └── ...                 #   bundled adb + runtime DLLs (ready-to-run, no install)
└── README.md
```

The Linux scripts at the root are the primary entry point — `install.sh` downloads the official scrcpy release (SHA256-verified) into `~/tools/scrcpy/`. The `windows/` folder is a self-contained, ready-to-run Windows build (no install step).

## Requirements

- Linux host (x86_64), any distro with SDL3 + FFmpeg libs (scrcpy release binaries are self-contained)
- Android 8.0+ device with USB debugging enabled
- Optional: `adb` for TCP/IP mode (bundled with scrcpy; `~/android-sdk/platform-tools/adb` also used if present)

## Quick start (USB)

```bash
./install.sh          # once
./scrcpy-remote.sh    # auto-detects connected device, full screen + control
```

## Quick start (TCP/IP / Wi-Fi ADB)

```bash
# 1. Device connected via USB, enable USB debugging
./adb-wireless-setup.sh        # runs `adb tcpip 5555` + finds device IP
# 2. Unplug USB. From here on, Wi-Fi only.
./scrcpy-remote.sh --tcp       # connects to the remembered IP:5555
```

`scrcpy-remote.sh --tcp` remembers the last device IP in `~/.config/android-scrcpy-remote/last-device` so you can re-run it without flags after the device reconnects to Wi-Fi.

## Usage

### scrcpy-remote.sh

```bash
./scrcpy-remote.sh [options] [extra scrcpy args]

Options:
  --usb            Force USB mode (default if device is on USB)
  --tcp            Force TCP/IP mode (uses remembered IP or --ip)
  --ip <addr>      TCP device address, e.g. 192.168.1.50:5555
  --list           List connected devices (USB + TCP) and exit
  --status         Show device status (model, IP, battery, screen)
  --help           Show help
```

All other arguments are passed straight to scrcpy, e.g.:

```bash
./scrcpy-remote.sh -m 1080          # cap at 1080p (lower latency)
./scrcpy-remote.sh -f               # start fullscreen
./scrcpy-remote.sh --max-fps 60     # frame rate cap
./scrcpy-remote.sh --record out.mp4 # record while mirroring
./scrcpy-remote.sh --show-touches   # show touch points
./scrcpy-remote.sh --turn-screen-off# turn device screen off while mirroring
./scrcpy-remote.sh --hwdec=vaapi    # force NVIDIA/Intel VA-API hardware decode
```

### adb-remote.sh

```bash
./adb-remote.sh connect <ip:port>   # adb connect to a TCP device
./adb-remote.sh disconnect [ip]     # adb disconnect (default: all TCP)
./adb-remote.sh devices             # list all ADB devices
./adb-remote.sh shell <cmd>         # run a command on the device
./adb-remote.sh status              # device info summary
```

## scrcpy keyboard/mouse cheatsheet

| Action | Key / Mouse |
|--------|-------------|
| Back | `Backspace` or right-mouse-button |
| Home | `Home` key |
| Recents | `PrtScn` or `Ctrl+H` |
| App switch | `Ctrl+Tab` |
| Rotate device | `Ctrl+Q` |
| Screenshot | `Ctrl+W` |
| Pause/resume video | `Ctrl+P` |
| Power | `Ctrl+L` |
| Volume up/down | `Ctrl+↑` / `Ctrl+↓` |
| Type text | just type |
| Scroll | mouse wheel |
| Long press | hold left mouse button |
| Multi-touch | hold left mouse + move |

## How it works

- **USB mode**: scrcpy talks to the device over the ADB USB transport (no root needed; udev rules give non-root access to the USB device node).
- **TCP/IP mode**: the device's `adbd` is switched to listen on `0.0.0.0:5555` via `adb tcpip 5555` (requires USB once). After that, `adb connect <ip>:5555` over Wi-Fi (LAN or Tailscale) provides the transport, and scrcpy mirrors through it. Latency over Wi-Fi is typically 30–80 ms — fine for control, not for gaming.

## Tailscale / remote access

If the phone and the host are on different networks but both have Tailscale, just use the phone's Tailscale IP in `--ip <ts-ip>:5555`. No port forwarding needed. (The phone needs the Tailscale app, or run `adb connect` from a machine that has both.)

## Uninstall

```bash
rm -rf ~/tools/scrcpy
sudo rm /etc/udev/rules.d/51-android-usb.rules
sed -i '/tools\/scrcpy/d' ~/.bashrc
```

## License

scrcpy is MIT-licensed. This repo's scripts are MIT.
