"""Six visually DISTINCT full-image distortions of every original ItamarOS icon.

Each style transforms the entire image, rather than adjusting one hue or adding
a tiny decorative element. Keep the real source logo recognizable while making
different silhouettes, textures, color-channel layouts and spatial geometry.

Uses Pillow only. The legacy Xcode asset IDs are intentionally preserved to
avoid changing the existing ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES list.
"""
from __future__ import annotations

import argparse
import json
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps

WORK_SIZE = 512
FINAL_SIZE = 1024

# Stable asset IDs, deliberately different compositions at all scales.
MODES = {
    "Blue": "Rainbow Glitch",      # wide, broken horizontal image bands
    "Green": "Prism Shatter",       # fractured triangular glass geometry
    "Purple": "RGB Ghost",         # heavily separated red/green/blue silhouettes
    "Pink": "Hologram Waves",      # iridescent and strongly rippled whole image
    "Orange": "Liquid Vortex",     # swirling, rainbow-twisted image
    "Red": "Neon Pixel Storm",     # pixelated image and neon block interruptions
}

ROOT = Path(__file__).resolve().parents[1]
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



def json_file(folder: Path, filename: str, is_icon: bool) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    image = {"filename": filename, "idiom": "universal"}
    if is_icon:
        image.update({"platform": "ios", "size": "1024x1024"})
    (folder / "Contents.json").write_text(
        json.dumps({"images": [image], "info": {"author": "xcode", "version": 1}}, indent=2)
        + "\n", encoding="utf-8"
    )


def full_spectrum(base: Image.Image, mode: int) -> Image.Image:
    """Recolor EVERY coordinate with several hues, preserving logo luminance."""
    w, h = base.size
    source = ImageOps.grayscale(base)
    brightness = source.point(lambda pixel: min(255, int(37 + pixel * .83)))
    hsv = bytearray(w * h * 3)
    for y in range(h):
        fy = y / h
        for x in range(w):
            fx = x / w
            cx, cy = fx - 0.5, fy - 0.5
            angle = math.atan2(cy, cx)
            radius = math.hypot(cx, cy)
            if mode == 0:
                hue = 2.3 * fx + .55 * fy + .15 * math.sin(y / 22)
            elif mode == 1:
                hue = 1.25 * (fx + fy) + .38 * math.floor((fx + fy) * 5)
            elif mode == 2:
                hue = 1.7 * fx - 1.5 * fy + .18 * math.sin((x + y) / 35)
            elif mode == 3:
                hue = 1.3 * fy + 1.2 * fx + .24 * math.sin((x - y) / 34)
            elif mode == 4:
                hue = 2.5 * angle / (2 * math.pi) + 1.7 * radius
            else:
                hue = 2.8 * fx + 2.1 * fy + .3 * math.sin(x / 13 + y / 18)
            pos = (y * w + x) * 3
            hsv[pos] = int(hue * 255) % 256
            hsv[pos + 1] = 218 if mode not in (2, 3) else 190
            hsv[pos + 2] = 255
    rainbow = Image.frombytes("HSV", (w, h), bytes(hsv)).convert("RGB")
    illumination = Image.merge("RGB", (brightness,) * 3)
    spectral = ImageChops.multiply(rainbow, illumination)
    # A small amount of the original logo keeps brand-specific design cues.
    return Image.blend(base, spectral, .88 if mode != 2 else .73)


def split_channels(image: Image.Image, red_shift: tuple[int, int],
                   green_shift: tuple[int, int],
                   blue_shift: tuple[int, int]) -> Image.Image:
    r, g, b = image.split()
    return Image.merge("RGB", (ImageChops.offset(r, *red_shift),
                              ImageChops.offset(g, *green_shift),
                              ImageChops.offset(b, *blue_shift)))


def rainbow_glitch(base: Image.Image) -> Image.Image:
    image = full_spectrum(base, 0)
    width, height = image.size
    # Large discontinuities across whole icon, not a handful of thin lines.
    for n, (top, tall, shift) in enumerate([
        (17, 34, 44), (67, 57, -36), (136, 30, 69), (188, 48, -51),
        (264, 39, 34), (317, 51, -59), (399, 44, 52), (456, 35, -28),
    ]):
        band = image.crop((0, top, width, min(height, top + tall)))
        image.paste(ImageChops.offset(band, shift, 0), (0, top))
    image = split_channels(image, (20, 0), (-8, 3), (-24, -3))
    draw = ImageDraw.Draw(image, "RGBA")
    for i in range(15):
        y = (i * 61 + 21) % height
        draw.rectangle((0, y, width, y + 2), fill=(240, 253, 255, 130))
    return image


def prism_shatter(base: Image.Image) -> Image.Image:
    image = full_spectrum(base, 1)
    w, h = image.size
    randomizer = random.Random(8053)
    # Whole-canvas triangular refraction: each shard samples from a displaced
    # region of the source and has its own light scattering/tint.
    output = Image.new("RGB", image.size, (18, 9, 41))
    points = [(x, y) for y in range(0, h + 130, 128)
              for x in range(0, w + 130, 128)]
    for gy in range(4):
        for gx in range(4):
            x, y = gx * 128, gy * 128
            center_x = x + 64 + randomizer.randint(-35, 35)
            center_y = y + 64 + randomizer.randint(-35, 35)
            corners = [(x, y), (x + 128, y), (x + 128, y + 128), (x, y + 128)]
            shards = [
                (corners[0], corners[1], (center_x, center_y)),
                (corners[1], corners[2], (center_x, center_y)),
                (corners[2], corners[3], (center_x, center_y)),
                (corners[3], corners[0], (center_x, center_y)),
            ]
            for k, triangle in enumerate(shards):
                mask = Image.new("L", image.size)
                ImageDraw.Draw(mask).polygon(triangle, fill=255)
                shifted = ImageChops.offset(
                    image,
                    randomizer.randint(-42, 42),
                    randomizer.randint(-42, 42)
                )
                if k % 2:
                    shifted = ImageEnhance.Contrast(shifted).enhance(1.35)
                output.paste(shifted, (0, 0), mask)
    draw = ImageDraw.Draw(output, "RGBA")
    for gy in range(4):
        for gx in range(4):
            x, y = gx * 128, gy * 128
            draw.line((x, y, x + 128, y + 128), fill=(5, 13, 31, 220), width=5)
            draw.line((x + 128, y, x, y + 128), fill=(218, 251, 255, 180), width=3)
    return output


def rgb_ghost(base: Image.Image) -> Image.Image:
    # Truly different from a rainbow gradient: three strong, separate, offset
    # copies of the logo on a dark background instead of single color tint.
    w, h = base.size
    light = ImageEnhance.Contrast(ImageOps.grayscale(base)).enhance(2.1)
    ghost = split_channels(
        Image.merge("RGB", (light, light, light)),
        (32, -24), (0, 0), (-33, 26)
    )
    spectral = full_spectrum(base, 2)
    dark_base = ImageEnhance.Brightness(base).enhance(.16)
    out = Image.blend(dark_base, ghost, .87)
    out = ImageChops.screen(out, ImageEnhance.Brightness(spectral).enhance(.38))
    outlines = light.filter(ImageFilter.FIND_EDGES)
    edges = split_channels(Image.merge("RGB", (outlines, outlines, outlines)),
                           (24, 0), (0, -16), (-23, 12))
    return ImageChops.screen(out, ImageEnhance.Brightness(edges).enhance(.74))


def hologram_waves(base: Image.Image) -> Image.Image:
    # Curved, shimmering refractions across the ENTIRE icon.
    img = ImageEnhance.Brightness(full_spectrum(base, 3)).enhance(1.15)
    w, h = img.size
    result = Image.new("RGB", (w, h))
    for y in range(h):
        dx = round(42 * math.sin(y / 31) + 14 * math.sin(y / 9))
        strip = img.crop((0, y, w, y + 1))
        result.paste(ImageChops.offset(strip, dx, 0), (0, y))
    shimmer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    paint = ImageDraw.Draw(shimmer, "RGBA")
    for i in range(32):
        x = -220 + i * 33
        paint.line((x, 0, x + 305, h), fill=(241, 249, 255, 65 if i % 3 else 130),
                   width=5 if i % 3 else 10)
    for i in range(10):
        radius = i * 31 + 25
        paint.ellipse((w // 2 - radius, h // 2 - radius,
                       w // 2 + radius, h // 2 + radius),
                      outline=(160, 254, 240, 84), width=3)
    return Image.alpha_composite(result.convert("RGBA"), shimmer).convert("RGB")


def liquid_vortex(base: Image.Image) -> Image.Image:
    # Radial coordinate distortion warps the main artwork into a visible swirl;
    # not merely replacing hues or drawing a swirl on top.
    img = full_spectrum(base, 4)
    w, h = img.size
    source = img.load()
    output = Image.new("RGB", img.size)
    target = output.load()
    cx, cy = (w - 1) / 2, (h - 1) / 2
    max_radius = math.hypot(cx, cy)
    for y in range(h):
        yy = y - cy
        for x in range(w):
            xx = x - cx
            radius = math.hypot(xx, yy)
            angle = math.atan2(yy, xx)
            twist = 5.5 * max(0, 1 - radius / max_radius) ** 2
            bend = 19 * math.sin(radius / 19 + angle * 4)
            sample_radius = max(0, radius + bend)
            sx = min(w - 1, max(0, int(cx + sample_radius * math.cos(angle + twist))))
            sy = min(h - 1, max(0, int(cy + sample_radius * math.sin(angle + twist))))
            target[x, y] = source[sx, sy]
    return ImageEnhance.Color(output).enhance(1.3)


def neon_pixel_storm(base: Image.Image) -> Image.Image:
    # Across-the-entire-surface chunky 8-bit corruption, not tiny noise specks.
    image = full_spectrum(base, 5)
    w, h = image.size
    pixelated = image.resize((28, 28), Image.Resampling.BILINEAR).resize(
        image.size, Image.Resampling.NEAREST
    )
    out = Image.blend(image, pixelated, .88)
    r = random.Random(9215)
    palette = [(255, 21, 159), (43, 255, 205), (250, 245, 26),
               (80, 75, 255), (238, 40, 40), (16, 240, 255)]
    draw = ImageDraw.Draw(out, "RGBA")
    for i in range(145):
        x = r.randint(0, w - 20)
        y = r.randint(0, h - 20)
        width = r.choice([12, 20, 32, 52, 84])
        height = r.choice([6, 12, 20, 30])
        cr, cg, cb = palette[i % len(palette)]
        draw.rectangle((x, y, min(w, x + width), min(h, y + height)),
                       fill=(cr, cg, cb, 150 if i % 4 else 230))
    for col in (61, 179, 334, 440):
        strip = out.crop((col, 0, min(w, col + 24), h))
        out.paste(ImageChops.offset(strip, 0, r.choice([-46, 34, 69])), (col, 0))
    return out


STYLES = (
    rainbow_glitch, prism_shatter, rgb_ghost,
    hologram_waves, liquid_vortex, neon_pixel_storm
)


def spectral_art(original: Image.Image, variant_index: int) -> Image.Image:
    if not 0 <= variant_index < len(STYLES):
        raise ValueError("Unknown ItamarOS alternate icon distortion.")
    sized = original.convert("RGB").resize((WORK_SIZE, WORK_SIZE), Image.Resampling.LANCZOS)
    return STYLES[variant_index](sized).resize(
        (FINAL_SIZE, FINAL_SIZE), Image.Resampling.LANCZOS
    )


def generate(asset_catalog: Path, primary: str, source: str) -> None:
    original = asset_catalog / f"{primary}.appiconset" / source
    if not original.is_file():
        raise FileNotFoundError(
            f"Missing original icon: {original}. Run the app-specific original icon generator first."
        )
    with Image.open(original) as opened:
        base = opened.convert("RGB").resize((FINAL_SIZE, FINAL_SIZE),
                                             Image.Resampling.LANCZOS)

    preview = asset_catalog / "ItamarIconPreviewOriginal.imageset"
    json_file(preview, "preview.png", False)
    base.resize((160, 160), Image.Resampling.LANCZOS).save(
        preview / "preview.png", optimize=True
    )

    for index, (asset_id, label) in enumerate(MODES.items()):
        icon = spectral_art(base, index)
        icon_dir = asset_catalog / f"ItamarIcon{asset_id}.appiconset"
        json_file(icon_dir, "Icon.png", True)
        icon.save(icon_dir / "Icon.png", optimize=True)
        small = asset_catalog / f"ItamarIconPreview{asset_id}.imageset"
        json_file(small, "preview.png", False)
        icon.resize((160, 160), Image.Resampling.LANCZOS).save(
            small / "preview.png", optimize=True
        )
        print(f"Generated whole-image {label}: {icon_dir}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", help="One app name, e.g. 'ItamarOS Installer'.")
    args = parser.parse_args()
    apps = APPS + [MOBILE_INSTALLER]
    if args.app:
        apps = [app for app in apps if app[0].casefold() == args.app.casefold()]
        if not apps:
            parser.error("Unknown non-game app: " + args.app)
    for name, catalog, primary, source in apps:
        print("Processing", name)
        generate(catalog, primary, source)
