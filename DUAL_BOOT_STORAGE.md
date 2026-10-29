# ItamarOS + Windows: Dual-boot shared storage

**One physical drive can host both systems.** Each operating system needs its own system files and partitions. A **shared NTFS/exFAT data volume** can be read from both operating systems, so user files occupy space **once** rather than being copied twice. This does not combine their system partitions, multiply available capacity, or automatically share account settings, apps or saves.

## Recommended safe setup (not implemented automatically)

- Keep Windows system, recovery and EFI partitions intact.
- Install ItamarOS into a **separate Linux system partition**, after verified ISO boot testing.
- Optionally choose an existing suitable NTFS data partition or a deliberately created shared NTFS/exFAT partition for documents, photos and video.
- Do **not** assume Windows `C:\\` is a safe shared data partition. The ItamarOS installer must not silently repartition, resize or format it.
- Back up data and BitLocker recovery keys; check that backups can be restored.
- Disable Windows Fast Startup/hibernation before accessing NTFS in Linux. Never write to a Windows-hibernated volume.
- Encrypted/BitLocker partitions need supported, authorized unlocking; they are not auto-unlocked here.
- Sharing an NTFS/exFAT folder is different from sharing Linux `/home` or browser profile data.

## Built implementation

The native app `ItamarOS Shared Storage` runs `shared_storage.py`, discovers compatible partitions via **read-only lsblk**, and can open **already mounted** filesystems in Dolphin. It does not execute `mount`, `mkfs`, `parted` or alter disks. In ItamarOS Preinstall, selecting dual boot shows instructions only and launches Calamares with no preselected disk. Any future shared partition operation must be explicit, reviewed and separately tested.

This is still a **source prototype**; no ItamarOS Linux installer ISO has been released as tested, safe-to-use media.
