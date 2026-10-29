#!/usr/bin/env python3
"""Read-only Linux hardware inventory. No commands modify disks or firmware."""
from __future__ import annotations

import json
import os
import platform
import re
import shutil
import subprocess
import sys
from pathlib import Path

DMI = Path("/sys/class/dmi/id")
SIZE_GIB = 1024 ** 3

def read(path: Path, default: str = "") -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace").strip()
    except (OSError, UnicodeError):
        return default

def run(args: list[str], timeout: float = 5) -> str:
    if not shutil.which(args[0]):
        return ""
    try:
        proc = subprocess.run(args, capture_output=True, text=True,
                              check=False, timeout=timeout)
        return proc.stdout.strip() if proc.returncode == 0 else ""
    except (OSError, subprocess.TimeoutExpired):
        return ""

def human_size(value: int) -> str:
    if value < 0:
        return "Unknown"
    return f"{value / SIZE_GIB:.1f} GiB"

def total_memory() -> int:
    meminfo = read(Path("/proc/meminfo"))
    match = re.search(r"^MemTotal:\s+(\d+) kB", meminfo, re.MULTILINE)
    return int(match.group(1)) * 1024 if match else 0

def cpu_name() -> str:
    cpuinfo = read(Path("/proc/cpuinfo"))
    match = re.search(r"^(?:model name|Hardware|Processor)\s*:\s*(.+)", cpuinfo, re.MULTILINE)
    return match.group(1).strip() if match else platform.processor() or "Unknown"

def physical_disks() -> list[dict]:
    """Use lsblk read-only JSON, never list mount secrets, serials or UUIDs."""
    response = run(["lsblk", "-J", "-b", "-d", "-o", "NAME,TYPE,SIZE,MODEL,TRAN,ROTA,RM"])
    if not response:
        return []
    try:
        values = json.loads(response).get("blockdevices", [])
    except (ValueError, TypeError):
        return []
    return [
        {
            "device": str(v.get("name", "")),
            "model": str(v.get("model") or "Storage device").strip(),
            "size_bytes": int(v.get("size") or 0),
            "size": human_size(int(v.get("size") or 0)),
            "transport": str(v.get("tran") or "unknown"),
            "rotational": bool(int(v.get("rota") or 0)),
            "removable": bool(int(v.get("rm") or 0)),
        }
        for v in values if v.get("type") == "disk"
    ]

def vendor_label(value: str) -> str:
    v = value.lower().strip()
    names = {
        "dell": "Dell", "lenovo": "Lenovo", "hewlett": "HP",
        "hp": "HP", "asus": "ASUS", "asustek": "ASUS",
        "acer": "Acer", "apple": "Apple", "microsoft": "Microsoft",
        "msi": "MSI", "micro-star": "MSI", "gigabyte": "Gigabyte",
        "samsung": "Samsung", "lg electronics": "LG",
        "huawei": "Huawei", "framework": "Framework",
        "intel": "Intel", "system76": "System76",
        "raspberry": "Raspberry Pi", "qemu": "Virtual Machine",
        "innotek": "VirtualBox", "vmware": "VMware",
    }
    for key, name in names.items():
        if key in v:
            return name
    return value.strip() if value and value.lower() not in ("to be filled by o.e.m.", "unknown", "not specified") else "Computer"

def device_category() -> str:
    chassis = read(DMI / "chassis_type")
    # DMTF chassis types: tablet 30/31/32; laptops/notebooks 8/9/10/14
    if chassis in {"30", "31", "32"}:
        return "tablet"
    if chassis in {"8", "9", "10", "14"}:
        return "laptop"
    if chassis in {"3", "4", "5", "6", "7", "13", "15", "16", "17", "23", "24"}:
        return "desktop"
    return "computer"

def uptime_seconds() -> int:
    text = read(Path("/proc/uptime"))
    try:
        return int(float(text.split()[0]))
    except (ValueError, IndexError):
        return 0

def detect() -> dict:
    vendor = read(DMI / "sys_vendor") or read(DMI / "board_vendor")
    product = read(DMI / "product_name") or read(DMI / "board_name")
    bios_vendor = read(DMI / "bios_vendor")
    arch = platform.machine()
    return {
        "platform": "linux",
        "architecture": arch,
        "compatible_live_build": arch in {"x86_64", "amd64"},
        "device_type": device_category(),
        "manufacturer": vendor_label(vendor),
        "manufacturer_raw": vendor or "Unknown",
        "model": product or "Unknown",
        "cpu": cpu_name(),
        "cores_logical": os.cpu_count() or 1,
        "ram_bytes": total_memory(),
        "ram": human_size(total_memory()),
        "kernel": platform.release(),
        "graphics": run(["lspci", "-mm"])[:12000],
        "storage": physical_disks(),
        "network": sorted(x.name for x in Path("/sys/class/net").iterdir() if x.name != "lo") if Path("/sys/class/net").exists() else [],
        "desktop": os.environ.get("XDG_CURRENT_DESKTOP", "Unknown"),
        "bios_vendor": bios_vendor or "Unknown",
        "uefi_boot": Path("/sys/firmware/efi").exists(),
        "uptime_seconds": uptime_seconds(),
    }

if __name__ == "__main__":
    json.dump(detect(), sys.stdout, ensure_ascii=False, indent=2)
    print()
