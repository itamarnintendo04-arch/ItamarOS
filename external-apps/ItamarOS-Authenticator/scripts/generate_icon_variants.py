"""Build Authenticator alternate iPhone Home Screen icons from the existing logo."""
from __future__ import annotations
import json
from pathlib import Path
from PIL import Image

ASSETS = Path(__file__).resolve().parents[1] / "ItamarOSAuthenticator" / "Assets.xcassets"
PRIMARY = ASSETS / "AppIcon.appiconset" / "AppIcon.png"
COLORS = {"Blue": 149, "Green": 98, "Purple": 193,
          "Pink": 232, "Orange": 22, "Red": 0}

def save_asset(folder: Path, image: Image.Image, name: str, appicon: bool):
    folder.mkdir(parents=True, exist_ok=True)
    record = {"filename": name, "idiom": "universal"}
    if appicon:
        record.update({"platform": "ios", "size": "1024x1024"})
    (folder / "Contents.json").write_text(
        json.dumps({"images": [record], "info": {"author": "xcode", "version": 1}},
                   indent=2) + "\n", encoding="utf-8")
    image.save(folder / name, optimize=True)

def shift(base: Image.Image, hue: int) -> Image.Image:
    _, s, v = base.convert("HSV").split()
    sat = s.point(lambda value: 0 if value < 12 else min(235, round(value * 0.85 + 27)))
    return Image.merge("HSV", (Image.new("L", base.size, color=hue), sat, v)).convert("RGB")

def main():
    if not PRIMARY.is_file():
        raise FileNotFoundError(f"Build primary AppIcon.png first: {PRIMARY}")
    with Image.open(PRIMARY) as img:
        base = img.convert("RGB").resize((1024,1024), Image.Resampling.LANCZOS)
    save_asset(ASSETS / "ItamarIconPreviewOriginal.imageset",
               base.resize((160,160), Image.Resampling.LANCZOS), "preview.png", False)
    for name, hue in COLORS.items():
        alt = shift(base, hue)
        save_asset(ASSETS / f"ItamarIcon{name}.appiconset", alt, "Icon.png", True)
        save_asset(ASSETS / f"ItamarIconPreview{name}.imageset",
                   alt.resize((160,160), Image.Resampling.LANCZOS), "preview.png", False)
    print("Generated all six original-logo app icon colors")

if __name__ == "__main__":
    main()
