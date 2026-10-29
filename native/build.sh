#!/usr/bin/env bash
# Build ItamarOS Live preview ISO (amd64) using Debian live-build.
# Use on Debian 13 in an isolated VM/runner. Does not touch user disks.
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR="${ITAMAROS_BUILD_DIR:-$REPO_DIR/.build/native-amd64}"
VERSION="${ITAMAROS_VERSION:-1.1}"
if [[ "$(uname -m)" != "x86_64" ]]; then echo 'This prototype ISO build supports amd64 only.' >&2; exit 1; fi
if [[ "${EUID}" -ne 0 ]]; then echo "Use sudo bash native/build.sh on a dedicated Debian build VM (requires root for live-build)." >&2; exit 1; fi
for cmd in lb debootstrap xorriso mksquashfs; do command -v "$cmd" >/dev/null || { echo "Missing $cmd; see native/README.md" >&2; exit 1; }; done
if [[ -e "$WORK_DIR" ]]; then echo "Refusing to reuse build directory: $WORK_DIR" >&2; exit 1; fi
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
lb config \
  --mode debian \
  --distribution trixie \
  --architectures amd64 \
  --binary-images iso-hybrid \
  --bootloaders "grub-efi syslinux" \
  --archive-areas "main contrib non-free-firmware" \
  --debian-installer none \
  --iso-application "ItamarOS Linux Live $VERSION" \
  --iso-publisher "ItamarOS community project" \
  --iso-volume "ItamarOS-$VERSION" \
  --image-name "ItamarOS-$VERSION-amd64" \
  --memtest none
cp -a "$SCRIPT_DIR/config/." config/
# GitHub contents API files are not executable by default; make live-build hooks executable.
find config/hooks -type f -name "*.hook.chroot" -exec chmod 0755 {} +
# Bundle the already-reviewed web games assets for the native offline games hub.
cp "$REPO_DIR/apps/games.js" config/includes.chroot/usr/local/share/itamaros/games.js
cp "$REPO_DIR/apps/more-games.js" config/includes.chroot/usr/local/share/itamaros/more-games.js
cp "$REPO_DIR/apps/addons.css" config/includes.chroot/usr/local/share/itamaros/games.css
echo "Starting live-build. This downloads many Debian packages and may take significant disk space."
lb build
shopt -s nullglob
images=(ItamarOS-*.iso live-image-*.iso)
if (("${#images[@]}"==0));then echo 'Build completed but no ISO was found.' >&2; exit 1;fi
mkdir -p "$REPO_DIR/dist"
for image in "${images[@]}"; do
  cp -- "$image" "$REPO_DIR/dist/"
  sha256sum "$REPO_DIR/dist/${image##*/}" | tee "$REPO_DIR/dist/${image##*/}.sha256"
done
echo "Build output: $REPO_DIR/dist (NOT YET VERIFIED IN A VM)"
