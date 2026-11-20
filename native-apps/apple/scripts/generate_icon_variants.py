"""Generate real iOS alternate app icons and preview images from each app's original icon.

Run after the primary app icon is prepared and before xcodegen.
Requires Pillow. Does not alter the original icon.
"""
from __future__ import annotations

import json
from pathlib import Path
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
VARIANTS = {
    "Blue": 149,    # Hue units in Pillow's 0..255 HSV color space.
    "Green": 98,
    "Purple": 193,
    "Pink": 232,
    "Orange": 22,
    "Red": 0,
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

def json_file(path: Path, image_name: str, icon: bool) -> None:
    path.mkdir(parents=True, exist_ok=True)
    if icon:
        obj = {"images": [{"filename": image_name, "idiom": "universal",
                            "platform": "ios", "size": "1024x1024"}],
               "info": {"author": "xcode", "version": 1}}
    else:
        obj = {"images": [{"filename": image_name, "idiom": "universal"}],
               "info": {"author": "xcode", "version": 1}}
    (path / "Contents.json").write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")

def make_colors(icon: Image.Image, hue: int) -> Image.Image:
    """Shift logo color without replacing its silhouette, contrast, or neutral highlights."""
    original = icon.convert("RGB")
    _, saturation, value = original.convert("HSV").split()
    adjusted = saturation.point(lambda p: 0 if p < 12 else min(235, round(p * 0.85 + 27)))
    return Image.merge("HSV", (
        Image.new("L", original.size, color=hue),
        adjusted,
        value
    )).convert("RGB")

def generate(asset_catalog: Path, primary: str, source: str) -> None:
    original = asset_catalog / f"{primary}.appiconset" / source
    if not original.is_file():
        raise FileNotFoundError(
            f"Missing original icon: {original}. Run its app-specific icon generator first."
        )
    with Image.open(original) as opened:
        base = opened.convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)
    preview_dir = asset_catalog / "ItamarIconPreviewOriginal.imageset"
    json_file(preview_dir, "preview.png", icon=False)
    base.resize((160,160), Image.Resampling.LANCZOS).save(
        preview_dir / "preview.png", optimize=True)
    for color, hue in VARIANTS.items():
        icon = make_colors(base, hue)
        icon_dir = asset_catalog / f"ItamarIcon{color}.appiconset"
        json_file(icon_dir, "Icon.png", icon=True)
        icon.save(icon_dir / "Icon.png", optimize=True)
        small = asset_catalog / f"ItamarIconPreview{color}.imageset"
        json_file(small, "preview.png", icon=False)
        icon.resize((160,160), Image.Resampling.LANCZOS).save(
            small / "preview.png", optimize=True)
    print(f"Generated six alternate Home Screen icons: {asset_catalog}")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", help="Optional original app name or 'Installer'; all others otherwise")
    args = parser.parse_args()
    targets = APPS + [MOBILE_INSTALLER]
    if args.app:
        targets = [target for target in targets if target[0].casefold() == args.app.casefold()]
        if not targets:
            parser.error("Unknown non-game app: " + args.app)
    for app_name, catalog, primary, original_name in targets:
        print("Processing", app_name)
        generate(catalog, primary, original_name)
