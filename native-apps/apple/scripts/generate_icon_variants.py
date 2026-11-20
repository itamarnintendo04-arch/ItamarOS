"""Generate six MULTICOLOR distorted alternate iPhone icons from each original logo.

These are not single-hue recolors. Every version includes a full-spectrum
gradient, chromatic separation and distinct deterministic distortions while
preserving the original app's artwork/silhouette.

The alternate asset names (Blue/Green/Purple/Pink/Orange/Red) are retained for
backward compatibility with existing XcodeGen settings and installed apps.
The labels shown to users are Rainbow Glitch, Prism Shift, RGB Split,
Holographic, Liquid Spectrum and Neon Noise.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
MODES = {
    "Blue": "Rainbow Glitch",
    "Green": "Prism Shift",
    "Purple": "RGB Split",
    "Pink": "Holographic",
    "Orange": "Liquid Spectrum",
    "Red": "Neon Noise",
}
APPS = [
    ("ItamarOS", ROOT / "iOS/Assets.xcassets", "AppIcon", "Icon.png"),
    ("BrowserOS", ROOT / "BrowserOS/Assets.xcassets", "BrowserOSIcon", "Icon.png"),
    ("Screen Balance", ROOT / "ScreenBalance/Assets.xcassets", "ScreenBalanceIcon", "Icon.png"),
    ("ItamarCut", ROOT / "ItamarCut/Assets.xcassets", "ItamarCutIcon", "Icon.png"),
    ("Voice Recorder", ROOT / "VoiceRecorder/Assets.xcassets", "VoiceRecorderIcon", "Icon.png"),
]
MOBILE_INSTALLER = (
    "ItamarOS Installer", ROOT / "ItamarOSInstallerMobile/Assets.xcassets",
    "AppIcon", "AppIcon.png"
)


def json_file(path: Path, image_name: str, is_icon: bool) -> None:
    path.mkdir(parents=True, exist_ok=True)
    item = {"filename": image_name, "idiom": "universal"}
    if is_icon:
        item.update({"platform": "ios", "size": "1024x1024"})
    (path / "Contents.json").write_text(
        json.dumps({"images": [item], "info": {"author": "xcode", "version": 1}}, indent=2)
        + "\n", encoding="utf-8"
    )


def spectral_art(original: Image.Image, variant_index: int) -> Image.Image:
    """Repaint with a spatial rainbow AND distort RGB channels/scanlines."""
    base = original.convert("RGB")
    w, h = base.size
    brightness = base.convert("L").tobytes()
    hsv = bytearray(w * h * 3)
    period = 255.0

    # Each style has independent, spatially varying hue mapping. None uses
    # a uniform hue and all keep the original logo's light/dark structure.
    for y in range(h):
        fy = y / h
        offset = y * w
        for x in range(w):
            fx = x / w
            if variant_index == 0:  # rainbow scanline glitch
                hue = 2.1 * x / w * period + 0.35 * y / h * period
                hue += 16 * math.sin(y / 18)
            elif variant_index == 1:  # multi-color prismatic diagonal
                hue = 1.7 * (fx + 0.85 * fy) * period + 18 * math.sin((x + y) / 105)
            elif variant_index == 2:  # RGB interference bands
                hue = 3.0 * fx * period + 24 * math.sin(y / 13)
            elif variant_index == 3:  # pearlescent hologram ripples
                hue = (fy * 2.3 + fx * 1.25) * period + 34 * math.sin((x - y) / 65)
            elif variant_index == 4:  # liquid wave, sweeping all colors
                hue = 1.9 * fy * period + 0.9 * fx * period + 45 * math.sin(x / 65 + y / 92)
            else:  # saturated neon interference checker
                hue = 2.25 * fx * period + 1.8 * fy * period + 31 * math.sin(x / 27 + y / 32)
            v = brightness[offset + x]
            index = (offset + x) * 3
            hsv[index] = int(hue) % 256
            hsv[index + 1] = 226 if variant_index != 3 else 192
            hsv[index + 2] = max(17, min(255, round(v * 0.94 + 25)))

    rainbow = Image.frombytes("HSV", (w, h), bytes(hsv)).convert("RGB")
    image = Image.blend(base, rainbow, 0.80 if variant_index != 2 else 0.66)

    # Chromatic aberration and raster tear distortion. The RGB channels come
    # from different positions, making edges split into several colors.
    red, green, blue = image.split()
    distance = [6, 9, 15, 5, 11, 8][variant_index]
    red = ImageChops.offset(red, distance, 0)
    blue = ImageChops.offset(blue, -distance, 2 if variant_index % 2 == 0 else -2)
    split = Image.merge("RGB", (red, green, blue))
    image = Image.blend(image, split, 0.46 if variant_index == 2 else 0.25)

    # Selected thin slices visibly shift horizontally without destroying the
    # recognizable base icon. Deterministic: builds always produce same files.
    stripe_count = [8, 4, 10, 6, 5, 12][variant_index]
    for n in range(stripe_count):
        y = (n * 211 + 97 + variant_index * 47) % max(1, h - 26)
        thickness = 3 + (n * 7 + variant_index * 2) % 16
        shift = ((n * 13 + variant_index * 19) % 35) - 17
        if shift == 0:
            shift = 7
        stripe = image.crop((0, y, w, min(h, y + thickness)))
        warped = ImageChops.offset(stripe, shift, 0)
        image.paste(Image.blend(stripe, warped, 0.65), (0, y))

    return ImageEnhance.Color(image).enhance(1.24)


def generate(asset_catalog: Path, primary: str, source: str) -> None:
    original = asset_catalog / f"{primary}.appiconset" / source
    if not original.is_file():
        raise FileNotFoundError(
            f"Missing original icon: {original}. Run the app-specific icon generator first."
        )
    with Image.open(original) as opened:
        base = opened.convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)

    preview = asset_catalog / "ItamarIconPreviewOriginal.imageset"
    json_file(preview, "preview.png", False)
    base.resize((160, 160), Image.Resampling.LANCZOS).save(
        preview / "preview.png", optimize=True
    )

    for index, (legacy_name, label) in enumerate(MODES.items()):
        icon = spectral_art(base, index)
        icon_dir = asset_catalog / f"ItamarIcon{legacy_name}.appiconset"
        json_file(icon_dir, "Icon.png", True)
        icon.save(icon_dir / "Icon.png", optimize=True)
        small = asset_catalog / f"ItamarIconPreview{legacy_name}.imageset"
        json_file(small, "preview.png", False)
        icon.resize((160, 160), Image.Resampling.LANCZOS).save(
            small / "preview.png", optimize=True
        )
        print(f"Created {label} (multicolor) in {icon_dir}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", help="App name or 'ItamarOS Installer'; all by default")
    args = parser.parse_args()
    apps = APPS + [MOBILE_INSTALLER]
    if args.app:
        apps = [app for app in apps if app[0].casefold() == args.app.casefold()]
        if not apps:
            parser.error("Unknown non-game app: " + args.app)
    for name, catalog, primary, source in apps:
        print("Processing", name)
        generate(catalog, primary, source)
