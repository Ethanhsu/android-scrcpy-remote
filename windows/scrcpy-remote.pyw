"""
scrcpy-remote GUI — pick one or more Android devices and mirror them.

Usage:
    pythonw scrcpy-remote.pyw          (no console)
    python  scrcpy-remote.pyw          (with console, for debugging)

Features:
    - Scans adb for connected devices (USB + Wi-Fi)
    - Checkbox list: tick any device(s) to mirror
    - "Mirror selected" launches scrcpy for each checked device
    - Refresh button to rescan
    - Per-device status indicator
    - scrcpy args field (e.g. -m 1080 for lower resolution)
"""
import os
import re
import subprocess
import sys
import threading
import tkinter as tk
from tkinter import ttk, messagebox

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

def find_scrcpy():
    """Locate scrcpy.exe: prefer same dir, then PATH, then common locations."""
    candidates = [
        os.path.join(SCRIPT_DIR, "scrcpy.exe"),
        os.path.join(os.path.expanduser("~"), "android-sdk", "platform-tools", "scrcpy.exe"),
    ]
    # Also search PATH
    for d in os.environ.get("PATH", "").split(os.pathsep):
        p = os.path.join(d, "scrcpy.exe")
        if os.path.isfile(p):
            candidates.append(p)
    for c in candidates:
        if os.path.isfile(c):
            return c
    return None

def find_adb():
    """Locate adb.exe: prefer platform-tools, then same dir as scrcpy, then PATH."""
    candidates = [
        os.path.join(os.path.expanduser("~"), "android-sdk", "platform-tools", "adb.exe"),
        os.path.join(SCRIPT_DIR, "adb.exe"),
    ]
    for d in os.environ.get("PATH", "").split(os.pathsep):
        p = os.path.join(d, "adb.exe")
        if os.path.isfile(p):
            candidates.append(p)
    for c in candidates:
        if os.path.isfile(c):
            return c
    return None

def get_devices(adb):
    """Run 'adb devices -l' and return list of (serial, model, transport)."""
    try:
        out = subprocess.check_output(
            [adb, "devices", "-l"],
            timeout=8,
            stderr=subprocess.DEVNULL,
        ).decode("utf-8", errors="replace")
    except Exception:
        return []

    devices = []
    for line in out.splitlines():
        line = line.strip()
        if not line or line.startswith("List of") or line.startswith("*"):
            continue
        # Format: SERIAL<tab>device<space>product:... model:... ...
        m = re.match(r"^(\S+)\s+device\b(.*)", line)
        if not m:
            continue
        serial = m.group(1)
        info = m.group(2).strip()
        model = ""
        tm = re.search(r"model:(\S+)", info)
        if tm:
            model = tm.group(1)
        transport = "Wi-Fi" if ":" in serial else "USB"
        devices.append((serial, model, transport))
    return devices

class App:
    def __init__(self, root):
        self.root = root
        self.scrcpy = find_scrcpy()
        self.adb = find_adb()
        self.devices = []          # list of (serial, model, transport)
        self.check_vars = {}       # serial -> BooleanVar
        self.running = {}          # serial -> subprocess.Popen

        root.title("scrcpy — Android Remote Control")
        root.geometry("680x600")
        root.minsize(520, 440)

        # --- Scrcpy status bar ---
        top = ttk.Frame(root, padding=8)
        top.pack(fill="x")
        if self.scrcpy:
            ttk.Label(top, text=f"scrcpy: {self.scrcpy}", foreground="#060").pack(side="left")
        else:
            ttk.Label(top, text="scrcpy.exe NOT FOUND", foreground="#c00").pack(side="left")
        if self.adb:
            ttk.Label(top, text=f"  adb: {self.adb}", foreground="#060").pack(side="left")
        else:
            ttk.Label(top, text="  adb.exe NOT FOUND", foreground="#c00").pack(side="left")

        # --- Device list frame ---
        list_frame = ttk.LabelFrame(root, text="Connected devices", padding=6)
        list_frame.pack(fill="both", expand=True, padx=8, pady=4)

        # Treeview with checkbox column + serial + model + transport + status
        cols = ("serial", "model", "transport", "status")
        self.tree = ttk.Treeview(list_frame, columns=cols, selectmode="browse", show="headings")
        self.tree.heading("serial", text="Serial")
        self.tree.heading("model", text="Model")
        self.tree.heading("transport", text="Transport")
        self.tree.heading("status", text="Status")
        self.tree.column("serial", width=180, anchor="w")
        self.tree.column("model", width=100, anchor="w")
        self.tree.column("transport", width=60, anchor="center")
        self.tree.column("status", width=120, anchor="w")
        self.tree.pack(fill="both", expand=True)

        # Scrollbar
        vsb = ttk.Scrollbar(list_frame, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=vsb.set)
        vsb.pack(side="right", fill="y")

        # --- Args frame ---
        args_frame = ttk.Frame(root, padding=(8, 4))
        args_frame.pack(fill="x")
        ttk.Label(args_frame, text="scrcpy args:").pack(side="left")
        self.args_var = tk.StringVar(value="")
        ttk.Entry(args_frame, textvariable=self.args_var, width=40).pack(side="left", padx=6)
        ttk.Label(args_frame, text="(e.g. -m 1080  -f  --always-on-top)", foreground="#666").pack(side="left")

        # --- Button bar ---
        btns = ttk.Frame(root, padding=8)
        btns.pack(fill="x")
        self.btn_refresh = ttk.Button(btns, text="Refresh", command=self.refresh)
        self.btn_refresh.pack(side="left")
        self.btn_select_all = ttk.Button(btns, text="Select all", command=self.select_all)
        self.btn_select_all.pack(side="left", padx=4)
        self.btn_deselect_all = ttk.Button(btns, text="Deselect all", command=self.deselect_all)
        self.btn_deselect_all.pack(side="left")
        self.btn_mirror = ttk.Button(btns, text="Mirror selected", command=self.mirror_selected, style="Accent.TButton")
        self.btn_mirror.pack(side="left", padx=8)
        self.btn_stop_all = ttk.Button(btns, text="Stop all", command=self.stop_all)
        self.btn_stop_all.pack(side="right")

        # --- Log area ---
        log_frame = ttk.LabelFrame(root, text="Log", padding=4)
        log_frame.pack(fill="both", expand=True, padx=8, pady=(0, 8))
        log_inner = ttk.Frame(log_frame)
        log_inner.pack(fill="both", expand=True)
        self.log_text = tk.Text(log_inner, height=8, state="disabled", wrap="word", font=("Consolas", 9))
        self.log_text.pack(side="left", fill="both", expand=True)
        log_sbar = ttk.Scrollbar(log_inner, orient="vertical", command=self.log_text.yview)
        self.log_text.configure(yscrollcommand=log_sbar.set)
        log_sbar.pack(side="right", fill="y")

        self.refresh()

    # ---------- helpers ----------
    def log(self, msg):
        self.log_text.configure(state="normal")
        self.log_text.insert("end", msg + "\n")
        self.log_text.see("end")
        self.log_text.configure(state="disabled")

    # ---------- device scan ----------
    def refresh(self):
        if not self.adb:
            messagebox.showerror("adb not found", "adb.exe not found. Install Android platform-tools.")
            return
        self.log("Scanning for devices…")

        def scan():
            devs = get_devices(self.adb)
            self.root.after(0, lambda: self._update_devices(devs))

        threading.Thread(target=scan, daemon=True).start()

    def _update_devices(self, devs):
        self.devices = devs
        self.tree.delete(*self.tree.get_children())
        self.check_vars.clear()

        for serial, model, transport in devs:
            var = tk.BooleanVar(value=True)   # default: selected
            self.check_vars[serial] = var
            status = "running" if serial in self.running and self.running[serial].poll() is None else "idle"
            self.tree.insert("", "end", iid=serial,
                             values=(serial, model, transport, status))
            # Bind checkbox via tag — use a small trick: show a ☑/☐ prefix in serial column
            self._update_row_icon(serial)

        if not devs:
            self.log("No ADB devices found.")
        else:
            self.log(f"Found {len(devs)} device(s).")

    def _update_row_icon(self, serial):
        var = self.check_vars.get(serial)
        if var is None:
            return
        children = self.tree.get_children()
        if serial not in children:
            return
        prefix = "☑ " if var.get() else "☐ "
        vals = self.tree.item(serial, "values")
        if vals:
            vals = list(vals)
            vals[0] = prefix + vals[0].lstrip("☑☐ ").strip()
            self.tree.item(serial, values=vals)

    # ---------- selection ----------
    def on_tree_click(self, event):
        """Toggle checkbox on tree click."""
        item = self.tree.identify_row(event.y)
        if not item:
            return
        # Strip any icon prefix to get the real serial
        serial = self.tree.item(item, "values")[0].lstrip("☑☐ ").strip()
        if serial in self.check_vars:
            self.check_vars[serial].set(not self.check_vars[serial].get())
            self._update_row_icon(serial)

    def select_all(self):
        for s, var in self.check_vars.items():
            var.set(True)
            self._update_row_icon(s)

    def deselect_all(self):
        for s, var in self.check_vars.items():
            var.set(False)
            self._update_row_icon(s)

    def _selected_serials(self):
        return [s for s, v in self.check_vars.items() if v.get()]

    # ---------- scrcpy launch ----------
    def mirror_selected(self):
        if not self.scrcpy:
            messagebox.showerror("scrcpy not found", "scrcpy.exe not found. Place it in the same folder.")
            return
        serials = self._selected_serials()
        if not serials:
            messagebox.showinfo("No selection", "Check at least one device and click Mirror selected.")
            return

        # Stop any already-running instances for the selected serials first
        for s in serials:
            if s in self.running and self.running[s].poll() is None:
                self.log(f"Stopping existing scrcpy for {s}")
                try:
                    self.running[s].terminate()
                except Exception:
                    pass

        extra_args = self.args_var.get().strip()
        arg_list = extra_args.split() if extra_args else []
        self.btn_mirror.configure(state="disabled")

        # Launch devices one at a time with a stagger to avoid adb contention
        self._launch_queue(list(serials), arg_list, index=0)

    def _launch_queue(self, serials, arg_list, index):
        """Launch scrcpy for serials[index], then schedule the next after a delay."""
        if index >= len(serials):
            self.btn_mirror.configure(state="normal")
            return

        serial = serials[index]
        # Pre-check: is the device still connected?
        def do_launch():
            try:
                check = subprocess.check_output(
                    [self.adb, "devices"], timeout=5, stderr=subprocess.DEVNULL
                ).decode("utf-8", errors="replace")
                if serial not in check:
                    self.log(f"Device {serial} no longer connected — skipping.")
                    self._set_status(serial, "offline")
                    self._launch_queue(serials, arg_list, index + 1)
                    return

                cmd = [self.scrcpy, "--serial", serial] + arg_list
                CREATE_NO_WINDOW = 0x08000000
                p = subprocess.Popen(
                    cmd,
                    cwd=SCRIPT_DIR,
                    creationflags=CREATE_NO_WINDOW,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                )
                self.running[serial] = p
                self._set_status(serial, "running")
                self.log(f"Launched scrcpy for {serial}")

                # Tail the output thread (non-blocking)
                dev_serial = serial  # capture for closure
                def tail():
                    try:
                        for line in iter(p.stdout.readline, b""):
                            txt = line.decode("utf-8", errors="replace").rstrip()
                            if txt:
                                self.root.after(0, lambda t=txt, s=dev_serial: self.log(f"[{s}] {t}"))
                    except Exception:
                        pass
                    # When the process exits, update status
                    p.wait()
                    if dev_serial in self.running:
                        rc = p.returncode
                        self.root.after(0, lambda s=dev_serial, rc=rc: self._on_exit(s, rc))
                threading.Thread(target=tail, daemon=True).start()

            except Exception as e:
                self.log(f"FAILED to launch scrcpy for {serial}: {e}")
                self._set_status(serial, "failed")

            # Schedule next device after 1.5s stagger
            self.root.after(1500, lambda: self._launch_queue(serials, arg_list, index + 1))

        threading.Thread(target=do_launch, daemon=True).start()

    def _on_exit(self, serial, rc):
        self.running.pop(serial, None)
        if rc == 0:
            self._set_status(serial, "stopped")
            self.log(f"scrcpy for {serial} exited (code 0)")
        else:
            self._set_status(serial, f"error ({rc})")
            self.log(f"scrcpy for {serial} exited with error code {rc}")

    def _set_status(self, serial, status):
        if serial in self.tree.get_children():
            vals = list(self.tree.item(serial, "values"))
            vals[3] = status
            self.tree.item(serial, values=vals)

    def stop_all(self):
        for serial, p in list(self.running.items()):
            try:
                p.terminate()
                self.log(f"Stopped scrcpy for {serial}")
                self._set_status(serial, "stopped")
            except Exception as e:
                self.log(f"Error stopping {serial}: {e}")
            del self.running[serial]

    # ---------- window close ----------
    def on_close(self):
        if self.running:
            if messagebox.askyesno("Quit", "Stop running scrcpy windows and quit?"):
                self.stop_all()
                self.root.destroy()
        else:
            self.root.destroy()


def main():
    root = tk.Tk()
    app = App(root)
    root.protocol("WM_DELETE_WINDOW", app.on_close)

    # Style for accent button
    style = ttk.Style(root)
    try:
        style.configure("Accent.TButton", foreground="#060")
    except Exception:
        pass

    # Bind tree click for checkbox toggle
    app.tree.bind("<Button-1>", app.on_tree_click)

    root.mainloop()


if __name__ == "__main__":
    main()
