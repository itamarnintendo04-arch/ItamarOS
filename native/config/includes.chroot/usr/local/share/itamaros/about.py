#!/usr/bin/env python3
"""About ItamarOS: branded native system information, no device changes."""
from __future__ import annotations
import json
from pathlib import Path
import tkinter as tk
from tkinter import ttk
from hardware import detect

LOGO = Path("/usr/share/pixmaps/itamaros.png")
VERSION = Path("/usr/local/share/itamaros/version.json")

def main() -> None:
    data = detect()
    try:
        version = json.loads(VERSION.read_text(encoding="utf-8")).get("version", "1.1")
    except (OSError, ValueError, TypeError):
        version = "1.1"
    root = tk.Tk()
    root.title("About ItamarOS")
    root.geometry("560x520")
    root.minsize(360, 440)
    frame = ttk.Frame(root, padding=25)
    frame.pack(fill="both", expand=True)
    try:
        logo = tk.PhotoImage(file=str(LOGO))
        root.iconphoto(True, logo)
        small = logo.subsample(max(1, logo.width() // 145))
        root.brand_icon = logo
        root.brand_image = small
        ttk.Label(frame, image=small).pack(pady=(0, 15))
    except (OSError, tk.TclError):
        pass
    ttk.Label(frame, text="ItamarOS", font=("Sans", 26, "bold")).pack()
    ttk.Label(frame, text=f"Linux desktop edition · Version {version}",
              font=("Sans", 12)).pack(pady=(5, 18))
    info = [
        ("Manufacturer", data.get("manufacturer", "Unknown")),
        ("Model", data.get("model", "Unknown")),
        ("Processor", data.get("cpu", "Unknown")),
        ("Memory", data.get("ram", "Unknown")),
        ("Architecture", data.get("architecture", "Unknown")),
    ]
    for title, value in info:
        ttk.Label(frame, text=f"{title}: {value}", wraplength=500).pack(anchor="w", pady=3)
    ttk.Label(frame, text="ItamarOS is an independent Debian-based development project. "
              "Hardware is detected read-only. The build is not a verified installation release.",
              wraplength=500, foreground="#45647e").pack(pady=(20, 10))
    ttk.Button(frame, text="Close", command=root.destroy).pack(pady=12)
    root.mainloop()

if __name__ == "__main__":
    main()
