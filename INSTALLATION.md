# ItamarOS 1.1 – installation and downloads

## What's available today?

| Package | Availability | What it does |
|---|---|---|
| Browser demo | [Open online](https://itamaros-web-emulator.onrender.com/) | Runs inside your current OS/browser. No installation or disk modifications. |
| Windows demo app | [Check GitHub Releases](https://github.com/itamarnintendo04-arch/ItamarOS/releases) | Portable Electron shell showing the web demo. **Not a PC OS installer.** |
| Native ItamarOS PC amd64 ISO | **Not yet built, boot-tested or released** | Source recipe at [native/](native/README.md). Do not treat it as ready for installation. |
| Android/iOS/iPadOS/TV native OS installer | **Not available** | Devices require separately supported kernels, bootloaders, drivers and software signing. |

The current website **does not detect exact motherboard/CPU/RAM/storage/vendor** because web browsers restrict hardware access. The native ItamarOS installer obtains those details directly from Linux and displays them before Calamares opens.

## How to install the real OS – once a verified ISO has been published

1. **Back up your data**, including recovery keys if encrypted storage is enabled. Confirm that the backup opens on another device.
2. Confirm the computer is in the published hardware compatibility list. The prototype targets **64-bit AMD/Intel PCs (amd64)** with enough memory/storage. Exact requirements must be verified through ISO boot tests.
3. Download the ISO **only from an official GitHub Release** on the project's downloads page. Never run an unrelated executable marketed as the OS.
4. Check the SHA-256 against the release's published checksum. Future signed checks should be checked as well.
5. **Test in an isolated virtual machine**, with a virtual disk containing no important data. Verify networking, screen, sound, keyboard, storage, reboot and update checks.
6. Only after successful testing on supported hardware, create bootable installation media following the computer vendor's official documentation. Back up anything stored on the USB drive because writing an image may erase it.
7. Boot the live OS. Open **ItamarOS Preinstall** and review detected CPU, RAM, manufacturer/model, drives and firmware. The checker does not write to drives.
8. Only if compatible and your data is safely backed up, explicitly choose to open the **Calamares installer**. Review the target disk, partitions and final confirmation. **Replacing or resizing partitions can erase data permanently.** Never assume the installer will preserve Windows automatically.
9. Finish installation and reboot. **Settings** opens KDE Plasma's system settings and **Software Updates** uses Debian's signed APT updates through KDE Discover.

**Do not attempt this on your primary PC while the ItamarOS native installer remains untested.**

## How does update checking work?

The native PC edition has a user-session systemd timer that checks the official stable manifest after login and every 15 minutes. It can announce newer verified releases; it never silently downloads and executes installers. KDE Discover handles security and application updates from signed Debian repositories. If the device is shut down or offline, update checks cannot run until it is online.

The **web demo** uses a separate stable manifest and refreshes its website to update. The Windows desktop demo wraps the web experience, and an offline-capable emulator source also exists for Windows/Linux; neither is a self-updating native operating system.

## Version numbering

ItamarOS marketing versions: `1.1 → 1.5 → 1.9 → 2.1 → 2.5 → 2.9`. See [native/VERSIONING.md](native/VERSIONING.md). `1.1` is the current **source/prototype version**, not a statement that a stable installable ISO exists.
