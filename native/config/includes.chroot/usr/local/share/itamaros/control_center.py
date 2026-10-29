#!/usr/bin/env python3
"""ItamarOS native control centre; KDE System Settings remains authoritative."""
from __future__ import annotations
import os
import shutil
import subprocess
import tkinter as tk
from tkinter import messagebox, ttk
from hardware import detect

SECTIONS = [
    ("Display & Brightness", "screen", "Resolution, scaling, Night Color and multiple displays"),
    ("Sound & Microphone", "audio", "Speakers, microphone, output and input devices"),
    ("Network & Wi-Fi", "network", "Wi-Fi, Ethernet, VPN and hotspot"),
    ("Bluetooth", "bluetooth", "Pair headphones, controllers, keyboards and other Bluetooth devices"),
    ("Connected Devices & USB", "devices", "Inspect removable drives, peripherals and device information"),
    ("Power & Battery", "power", "Battery, sleep, lid and energy modes"),
    ("Mouse & Touchpad", "input", "Pointer speed, scrolling, tapping, clicks and gestures"),
    ("Game Controllers", "controllers", "Controller support and device configuration"),
    ("Touchscreen & Tablet", "tablet", "Touch input, stylus and connected drawing tablets"),
    ("Keyboard", "keyboard", "Layout, shortcuts and accessibility"),
    ("Printers & Scanners", "print", "Printers and scanning devices"),
    ("Storage & Disks", "storage", "Mounted devices, free capacity and disk information"),
    ("Files & Backups", "files", "Browse files and configure backup destinations"),
    ("Accounts & Passwords", "users", "Users, account changes and passwords"),
    ("Language & Region", "locale", "Languages, fonts and regional formats"),
    ("Date & Time", "clock", "Clock, time zones and automatic time"),
    ("Privacy & Permissions", "privacy", "App permissions, history and privacy"),
    ("Notifications", "notifications", "Notifications and do-not-disturb"),
    ("Accessibility", "accessibility", "Screen reader, text and accessibility"),
    ("Appearance & Wallpapers", "appearance", "Theme, colors, wallpaper and icons"),
    ("Security & Firewall", "security", "Firewall and security through system settings"),
    ("Camera", "camera", "Manage connected cameras and application access"),
    ("Search & Indexing", "search", "File search, indexing and desktop search settings"),
    ("Startup & Login", "startup", "Login screen, autostart apps and session management"),
    ("Information & Firmware", "firmware", "Check firmware and connected device information"),
    ("Software Updates", "updates", "ItamarOS version checks and signed Debian updates"),
    ("Apps & App Store", "apps", "Install and manage apps through KDE Discover"),
    ("About & Hardware", "hardware", "CPU, RAM, disks, vendor and system information"),
]

def launch(argv: list[str]) -> None:
    executable = shutil.which(argv[0])
    if not executable:
        messagebox.showwarning("Not available", f"{argv[0]} is not installed on this edition.")
        return
    try:
        subprocess.Popen([executable, *argv[1:]], start_new_session=True)
    except OSError as exc:
        messagebox.showerror("Unable to launch", str(exc))

def make() -> None:
    data = detect()
    name = data["manufacturer"]
    product = data["model"]
    root = tk.Tk()
    root.title(f"ItamarOS Control Center — {name}")
    root.geometry("920x650")
    root.minsize(650, 490)
    root.configure(bg="#e9f1fd")
    header = ttk.Frame(root, padding=20)
    header.pack(fill="x")
    ttk.Label(header, text=f"ItamarOS 1.1 — {name} {product}",
              font=("Sans", 18, "bold"), wraplength=840).pack(anchor="w")
    ttk.Label(header,
              text=f"{data['device_type'].title()}  ·  {data['architecture']}  ·  "
                   f"{data['cpu']}  ·  RAM {data['ram']}", wraplength=800).pack(anchor="w", pady=(8, 0))
    ttk.Label(header, text="ItamarOS computer settings; hardware information is read-only.",
              foreground="#52657b").pack(anchor="w", pady=(8, 0))
    top_buttons = ttk.Frame(root, padding=(20, 4))
    top_buttons.pack(fill="x")
    ttk.Button(top_buttons, text="Open all KDE Settings", command=lambda: launch(["systemsettings"])).pack(side="left", padx=4)
    ttk.Button(top_buttons, text="Software Updates", command=lambda: launch(["python3", "/usr/local/share/itamaros/update_check.py", "--gui"])).pack(side="left", padx=4)
    ttk.Button(top_buttons, text="Software Center", command=lambda: launch(["plasma-discover"])).pack(side="left", padx=4)
    canvas = tk.Canvas(root, bg="#e9f1fd", highlightthickness=0)
    scroll = ttk.Scrollbar(root, orient="vertical", command=canvas.yview)
    body = ttk.Frame(canvas, padding=15)
    body.bind("<Configure>", lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
    canvas.create_window((0, 0), window=body, anchor="nw")
    canvas.configure(yscrollcommand=scroll.set)
    canvas.pack(side="left", fill="both", expand=True, padx=(10, 0), pady=10)
    scroll.pack(side="right", fill="y", pady=10)
    for i, (title, category, desc) in enumerate(SECTIONS):
        block = ttk.LabelFrame(body, text=title, padding=9)
        block.grid(row=i // 2, column=i % 2, sticky="nsew", padx=8, pady=7)
        ttk.Label(block, text=desc, wraplength=340).pack(anchor="w", pady=(0, 8))
        if category == "updates":
            cmd = ["python3", "/usr/local/share/itamaros/update_check.py", "--gui"]
        elif category == "apps":
            cmd = ["plasma-discover"]
        else:
            cmd = ["systemsettings"]
        ttk.Button(block, text="Open", command=lambda c=cmd: launch(c)).pack(anchor="e")
    body.columnconfigure(0, minsize=320, weight=1)
    body.columnconfigure(1, minsize=320, weight=1)
    root.mainloop()

if __name__ == "__main__":
    make()
