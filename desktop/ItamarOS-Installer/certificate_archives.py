"""Safely import user-selected ZIP certificates without exposing TXT passwords to Wi-Fi.

The ZIP archive's directory paths are NEVER used as extraction paths.
Only recognized P12 and provisioning file types are persisted under per-batch
user-local application data. TXT contents are read into memory only.
"""
from __future__ import annotations

import os
import stat
import uuid
import zipfile
from dataclasses import dataclass
from pathlib import Path

import desktop_certificates

MAX_ARCHIVES = 20
MAX_ARCHIVE_SIZE = 80_000_000
MAX_ENTRIES = 100
MAX_EXTRACTED_TOTAL = 80_000_000
MAX_TXT_SIZE = 16_384
MAX_P12_SIZE = 20_000_000
MAX_PROFILE_SIZE = 5_000_000


@dataclass(frozen=True)
class ArchivedIdentity:
    archive_name: str
    certificate_name: str
    p12_path: str
    profile_path: str
    txt_notes: tuple[tuple[str, str], ...]


def _decode_note(raw: bytes) -> str:
    # Text notes are shown as-is for the user to read, never interpreted as
    # executable instructions and never automatically submitted as a password.
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        return raw.decode("utf-16", errors="replace")
    return raw.decode("utf-8-sig", errors="replace")


def _private_dir(root: Path) -> Path:
    destination = root / "imported-certificates" / uuid.uuid4().hex
    destination.mkdir(mode=0o700, parents=True, exist_ok=False)
    if os.name != "nt":
        destination.chmod(0o700)
    return destination


def _write_private(path: Path, raw: bytes) -> None:
    # A random name is used instead of a ZIP-supplied path (zip-slip defense).
    fd = os.open(str(path), os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    with os.fdopen(fd, "wb") as handle:
        handle.write(raw)


def extract_archives(paths: list[str], root: Path | None = None) -> list[ArchivedIdentity]:
    """Return P12 identities and per-archive TXT hints from one or more ZIPs.

    Paths to P12/profile files remain local and persistent so registry entries
    still work after a program restart; password hints are NOT written to disk.
    """
    if not paths or len(paths) > MAX_ARCHIVES:
        raise ValueError("Choose between 1 and 20 ZIP archives.")
    storage = root if root is not None else desktop_certificates.ROOT
    results: list[ArchivedIdentity] = []
    try:
        for archive_name in paths:
            archive_path = Path(archive_name).resolve(strict=True)
            if archive_path.suffix.lower() != ".zip" or archive_path.stat().st_size > MAX_ARCHIVE_SIZE:
                raise ValueError("Choose ZIP archives smaller than 80 MB.")
            with zipfile.ZipFile(archive_path) as archive:
                files = [info for info in archive.infolist() if not info.is_dir()]
                if len(files) > MAX_ENTRIES:
                    raise ValueError("ZIP contains too many files.")
                if sum(info.file_size for info in files) > MAX_EXTRACTED_TOTAL:
                    raise ValueError("ZIP uncompressed size is too large.")
                allowed: list[tuple[zipfile.ZipInfo, str]] = []
                for info in files:
                    suffix = Path(info.filename).suffix.lower()
                    if suffix not in {".p12", ".mobileprovision", ".txt"}:
                        continue
                    mode = info.external_attr >> 16
                    if stat.S_IFMT(mode) == stat.S_IFLNK:
                        raise ValueError("ZIP contains an unsupported symbolic link.")
                    if info.flag_bits & 1:
                        raise ValueError("Password-protected ZIP files are not supported.")
                    max_size = {".p12": MAX_P12_SIZE, ".mobileprovision": MAX_PROFILE_SIZE,
                                ".txt": MAX_TXT_SIZE}[suffix]
                    if info.file_size > max_size:
                        raise ValueError("An archive entry exceeds its safe size limit.")
                    allowed.append((info, suffix))
                if not any(suffix == ".p12" for _, suffix in allowed):
                    raise ValueError("ZIP has no P12 signing certificate.")
                target_dir = _private_dir(storage)
                certificates: list[tuple[str, str, str]] = []
                profiles: list[tuple[str, str]] = []
                notes: list[tuple[str, str]] = []
                for info, suffix in allowed:
                    # Read no more than the declared limit + 1, even if the
                    # archive header lies about its expanded size.
                    limit = {".p12": MAX_P12_SIZE, ".mobileprovision": MAX_PROFILE_SIZE,
                             ".txt": MAX_TXT_SIZE}[suffix]
                    with archive.open(info) as member:
                        raw = member.read(limit + 1)
                    if len(raw) > limit:
                        raise ValueError("ZIP member expands beyond its allowed size.")
                    display_name = Path(info.filename.replace("\\", "/")).name[:160]
                    stem = Path(display_name).stem.lower()
                    if suffix == ".txt":
                        notes.append((display_name, _decode_note(raw)))
                        continue
                    out_path = target_dir / (uuid.uuid4().hex + suffix)
                    _write_private(out_path, raw)
                    if suffix == ".p12":
                        certificates.append((display_name, stem, str(out_path)))
                    else:
                        profiles.append((stem, str(out_path)))
                for name, stem, p12_path in certificates:
                    matching = [profile for profile_stem, profile in profiles if profile_stem == stem]
                    profile_path = (matching[0] if len(matching) == 1 else
                                    profiles[0][1] if len(profiles) == 1 else "")
                    results.append(ArchivedIdentity(
                        archive_name=archive_path.name,
                        certificate_name=name,
                        p12_path=p12_path,
                        profile_path=profile_path,
                        txt_notes=tuple(notes),
                    ))
    except (zipfile.BadZipFile, RuntimeError) as exc:
        raise ValueError("Unable to read ZIP: unsupported or damaged archive.") from exc
    return results
