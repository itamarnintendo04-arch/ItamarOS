#!/usr/bin/env python3
"""Read-only inspection of Windows-compatible data partitions. No disk writes or mounts."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess

SUPPORTED = {"ntfs", "ntfs3", "exfat"}

def discover():
    if not shutil.which("lsblk"):
        return []
    try:
        cmd = ["lsblk", "-J", "-b", "-o", "NAME,PATH,TYPE,FSTYPE,SIZE,MOUNTPOINTS,LABEL,RO"]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=6, check=False)
        if result.returncode:
            return []
        devices = json.loads(result.stdout).get("blockdevices", [])
    except (OSError, subprocess.TimeoutExpired, TypeError, ValueError):
        return []
    found = []
    def walk(entry):
        fstype = str(entry.get("fstype") or "").lower()
        if entry.get("type") == "part" and fstype in SUPPORTED:
            mounts = entry.get("mountpoints") or []
            mounted = [p for p in mounts if isinstance(p, str) and p.startswith("/") and p != "/"]
            found.append({
                "device": str(entry.get("path") or ""),
                "label": str(entry.get("label") or "Windows-compatible volume"),
                "filesystem": fstype,
                "size_bytes": int(entry.get("size") or 0),
                "mountpoint": mounted[0] if mounted else None,
                "read_only": bool(int(entry.get("ro") or 0)),
            })
        for child in entry.get("children") or []:
            if isinstance(child, dict):
                walk(child)
    for device in devices:
        if isinstance(device, dict):
            walk(device)
    return found

def open_existing_volume(volume):
    """Only open already-mounted volumes in the system file manager."""
    mountpoint = volume.get("mountpoint")
    if not isinstance(mountpoint, str) or not mountpoint.startswith("/"):
        return False
    if not os.path.isdir(mountpoint) or not os.path.ismount(mountpoint):
        return False
    opener = shutil.which("xdg-open")
    if not opener:
        return False
    try:
        subprocess.Popen([opener, mountpoint], start_new_session=True)
        return True
    except OSError:
        return False

def gui():
    import tkinter as tk
    from tkinter import ttk, messagebox
    root = tk.Tk()
    root.title("ItamarOS — Shared Storage")
    root.geometry("740x530")
    frame = ttk.Frame(root, padding=20)
    frame.pack(fill="both", expand=True)
    ttk.Label(frame, text="Shared Storage", font=("Sans", 18, "bold")).pack(anchor="w")
    ttk.Label(frame, text="Windows and ItamarOS can use the same physical drive and share files "
              "on a separate NTFS/exFAT volume. Each operating system still needs its own system partition. "
              "Storage is not duplicated.", wraplength=690).pack(anchor="w", pady=10)
    ttk.Label(frame, text="This tool only reads existing volume details. It never mounts, formats or repartitions anything.",
              foreground="#a14b24", wraplength=690).pack(anchor="w")
    items = discover()
    table = ttk.Treeview(frame, columns=("fs", "size", "mount"), show="tree headings")
    for col, title in [("#0", "Volume"), ("fs", "Filesystem"), ("size", "Capacity"), ("mount", "Access")]:
        table.heading(col, text=title)
    table.column("#0", width=240)
    table.column("fs", width=90)
    table.column("size", width=90)
    table.column("mount", width=220)
    table.pack(fill="both", expand=True, pady=12)
    for i, item in enumerate(items):
        table.insert("", "end", iid=str(i),
            text=item["label"] + " (" + item["device"] + ")",
            values=(item["filesystem"].upper(),
                    str(round(item["size_bytes"] / (1024 ** 3), 1)) + " GiB",
                    item["mountpoint"] or "Not mounted"))
    if not items:
        ttk.Label(frame, text="No NTFS/exFAT volumes detected.").pack(anchor="w")
    def open_selected():
        selected = table.selection()
        if not selected:
            messagebox.showinfo("Select a volume", "Select a shared volume first.")
            return
        if not open_existing_volume(items[int(selected[0])]):
            messagebox.showwarning("Not accessible", "Only previously mounted volumes can be opened. "
                    "Windows must be fully shut down, not hibernated. BitLocker volumes must be unlocked normally.")
    ttk.Button(frame, text="Open already-mounted volume", command=open_selected).pack(anchor="w")
    ttk.Label(frame, text="For dual boot: back up important data; keep Windows and ItamarOS in different "
              "system partitions; do not write to hibernated NTFS; and choose shared data storage manually "
              "in a verified installer. The shared partition is optional.", wraplength=690).pack(anchor="w", pady=15)
    root.mainloop()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gui", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    if args.gui:
        gui()
    else:
        print(json.dumps({"read_only": True, "shared_volumes": discover()}, indent=2))

if __name__ == "__main__":
    main()
