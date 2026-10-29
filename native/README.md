# ItamarOS native Linux edition — v1.1 build prototype

This folder is a **source recipe**, not a built/tested operating-system installer. It targets **amd64 PC only**, using Debian 13 (Trixie) KDE Plasma and the Debian Calamares live installer. More architectures (ARM phones/TVs) need separate kernels, bootloaders, drivers, permissions and hardware support. **Do not flash this recipe onto a phone or TV.**

## Main system components

- KDE Plasma with complete native Settings and hardware/device integration.
- `itamaros-control-center`: GUI summary of CPU, RAM, GPU, storage, network, vendor/model and launchers for KDE settings.
- `itamaros-hardware`: **read-only** hardware JSON for live installer compatibility checks.
- `itamaros-preinstall`: safe read-only inspection *before* opening Calamares; actual installation always uses Calamares's own wizard, explicit partition selection and final confirmation.
- `itamaros-updater`: check GitHub stable manifest, show a notification on newer version, and open KDE Discover to update through the signed Debian repository. **No unsigned arbitrary executable is downloaded or run.**
- `itamaros-update-check.timer`: persistent per-user timer checks at login and every 15 minutes while the machine and user session are active. A powered-off computer cannot check.
- ItamarOS Player: **VLC engine** launched from the desktop, giving actual VLC codec support on native Linux (subject to installed codecs/licensing). The separately written browser Player is a limited demo.
- **Itamio**: a YouTube viewer/launcher for officially embedded videos, separate from YouTube and not an alternative hosting service.
- ItamarOS Games: launch a local browser hub with offline HTML games and browser-stored scores.

## Build prerequisites (Debian 13 amd64 dedicated machine/VM)

Typical packages: `live-build debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin syslinux-common isolinux`. Build needs root privileges, substantial internet access and disk space.

```bash
sudo apt update
sudo apt install live-build debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin syslinux-common isolinux
sudo bash native/build.sh
```

The source build script bundles the offline game hub JavaScript and stylesheet from the main `apps/` folder. The output *if it successfully builds* is `dist/*.iso` and a matching `.sha256`. It is **not automatically released**, certified, signed, boot-tested or guaranteed to boot every computer. Perform a clean VM boot test and installer dry-run before distribution.

## Safe installation procedure — only after real, tested ISO release

1. Save your important files to separate backup media. Confirm they are accessible.
2. Compare your device with the published compatibility list, architecture, UEFI/Secure Boot and RAM/storage requirements.
3. Download the exact ISO and published SHA-256 from the official GitHub Release. Validate the file hash. Never rename the browser HTML demo as ISO.
4. Boot the **ISO in a virtual machine first**, with a disposable virtual disk.
5. On a supported spare PC, create USB installation media and boot the *Live* environment (details depend on the PC manufacturer).
6. Open **ItamarOS Preinstall** to inspect CPU, disks, memory, firmware and manufacturer. No disk is selected or modified during this stage.
7. Calamares is the only partitioning/install program. Manually review whether you want free-space dual boot, a fully separated drive, or complete drive replacement. Erasing or shrinking a partition can permanently destroy data. Require full backup and careful confirmation.
8. Finish the wizard, reboot, then use KDE System Settings and Software Updates.

No auto-partitioning of a detected drive, silent erasure, bypassing boot protections, or forced installer execution is implemented.

## Status

**Unverified build recipe**: ISO and installer are *not yet available as downloadable ItamarOS releases*. Published GitHub Releases and checksums must be treated as the authoritative release source.
