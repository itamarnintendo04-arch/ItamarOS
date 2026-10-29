#!/usr/bin/env python3
"""Read-only hardware review before launching Calamares."""
from __future__ import annotations
import shutil
import subprocess
import tkinter as tk
from tkinter import messagebox, ttk
from hardware import detect

def main() -> None:
    hw = detect()
    root = tk.Tk()
    root.title("ItamarOS 1.1 — Preinstallation hardware review")
    root.geometry("690x620")
    root.minsize(500, 520)
    frame = ttk.Frame(root, padding=20)
    frame.pack(fill="both", expand=True)
    ttk.Label(frame, text=f"ItamarOS 1.1 — {hw['manufacturer']} {hw['model']}",
              font=("Sans", 17, "bold"), wraplength=640).pack(anchor="w", pady=(0, 10))
    ttk.Label(frame, text="Hardware type and manufacturer are detected automatically and cannot be changed in this installer.",
              wraplength=640, foreground="#415f85").pack(anchor="w", pady=(0, 12))
    details = [
        ("Manufacturer", hw["manufacturer"]),
        ("Model", hw["model"]),
        ("Device", hw["device_type"]),
        ("Processor", hw["cpu"]),
        ("Architecture", hw["architecture"]),
        ("RAM", hw["ram"]),
        ("Graphics", ", ".join(hw.get("graphics", [])[:2]) or "Unknown"),
        ("Battery", ", ".join(str(b.get("charge_percent")) + "% " + b.get("status", "") for b in hw.get("batteries", [])) or "Not detected"),
        ("Boot mode", "UEFI" if hw["uefi_boot"] else "Legacy/unknown"),
    ]
    for key, value in details:
        ttk.Label(frame, text=f"{key}: {value}", wraplength=620).pack(anchor="w", pady=2)
    disks = hw["storage"]
    ttk.Label(frame, text="Detected disks (read-only):", font=("Sans", 11, "bold")).pack(anchor="w", pady=(14, 5))
    for disk in disks:
        ttk.Label(frame, text=f"• {disk['device']} — {disk['model']} — {disk['size']}",
                  wraplength=620).pack(anchor="w")
    can_run = hw["compatible_live_build"] and hw["ram_bytes"] >= 2 * (1024 ** 3) and bool(disks)
    if not can_run:
        ttk.Label(frame, text="Hardware review did not pass. Installation is disabled here.",
                  foreground="#b32525").pack(anchor="w", pady=14)
    ttk.Label(frame,
              text="IMPORTANT: This review only reads hardware details. It does not test all "
                   "drivers or Secure Boot, and cannot guarantee compatibility. "
                   "Installation can erase or replace files and operating systems. "
                   "Back up data and test the ISO in a virtual machine first.",
              wraplength=620, foreground="#a02424").pack(anchor="w", pady=14)
    ttk.Label(frame, text="Type INSTALL to enable the standard Calamares installation wizard:").pack(anchor="w")
    entry = ttk.Entry(frame)
    entry.pack(fill="x", pady=9)
    def proceed() -> None:
        if not can_run or entry.get() != "INSTALL":
            messagebox.showwarning("Not ready", "Verify compatibility and type INSTALL exactly.")
            return
        if not messagebox.askyesno("Confirm installer launch",
                                   "Open Calamares? Its disk partition choices may destroy data. "
                                   "Nothing has been selected or formatted yet."):
            return
        installer = shutil.which("calamares")
        if not installer:
            messagebox.showerror("Missing installer", "Calamares was not found.")
            return
        try:
            # No disk arguments are passed; Calamares makes its own user-confirmed choices.
            subprocess.Popen(["pkexec", installer], start_new_session=True)
        except OSError as exc:
            messagebox.showerror("Installer error", str(exc))
    button = ttk.Button(frame, text="Review and open Calamares", command=proceed)
    button.pack(pady=18)
    ttk.Label(frame, text="No automatic partition selection, formatting or disk writes occur in this checker.",
              foreground="#506784", wraplength=600).pack(anchor="w")
    root.mainloop()

if __name__ == "__main__":
    main()
