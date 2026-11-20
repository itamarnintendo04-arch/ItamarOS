"""Bundle actual ItamarOS iOS icon artwork into the desktop executable."""
from __future__ import annotations
import runpy
import shutil
import urllib.request
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
APPLE = ROOT / "native-apps" / "apple"
HERE = Path(__file__).resolve().parents[1]
ASSETS = HERE / "resources"
ASSETS.mkdir(parents=True, exist_ok=True)

ICON_SOURCES = {
    "itamaros": APPLE / "iOS/Assets.xcassets/AppIcon.appiconset/Icon.png",
    "cloud-climb": APPLE / "CloudClimb/Assets.xcassets/CloudClimbAppIcon.appiconset/Icon.png",
    "itamaros-games": APPLE / "ItamarOSGames/Assets.xcassets/GamesIcon.appiconset/Icon.png",
    "skybound-isles": APPLE / "SkyboundIsles/Assets.xcassets/SkyboundIcon.appiconset/Icon.png",
    "itamarcut": APPLE / "ItamarCut/Assets.xcassets/ItamarCutIcon.appiconset/Icon.png",
    "voice-recorder": APPLE / "VoiceRecorder/Assets.xcassets/VoiceRecorderIcon.appiconset/Icon.png",
    "browseros": APPLE / "BrowserOS/Assets.xcassets/BrowserOSIcon.appiconset/Icon.png",
    "screen-balance": APPLE / "ScreenBalance/Assets.xcassets/ScreenBalanceIcon.appiconset/Icon.png",
}

# Official app source generators: the resulting image is the same design as the iOS app.
for script in [APPLE / "BrowserOS/generate_icon.py", APPLE / "ScreenBalance/generate_icon.py"]:
    if script.exists():
        print("Generating official app icon from source:", script.name)
        runpy.run_path(str(script), run_name="__main__")

for slug, source in ICON_SOURCES.items():
    if not source.is_file():
        print("NO ORIGINAL APP LOGO:", slug)
        continue
    with Image.open(source) as src:
        resized = src.convert("RGBA").resize((256, 256), Image.Resampling.LANCZOS)
        resized.save(ASSETS / (slug + ".png"), optimize=True)
    print("Bundled official logo:", slug)

brand = ROOT / "assets/branding/itamaros-mark-512.png"
if brand.exists():
    with Image.open(brand) as image:
        image.convert("RGBA").resize((220, 220), Image.Resampling.LANCZOS).save(ASSETS / "brand.png")
    print("Bundled official ItamarOS logo")

# Arena Rush doesn't yet have a committed iOS icon in the source tree.
# Add a distinct first-party design to the Installer, without claiming it is an existing iOS asset.
canvas = Image.new("RGBA", (256,256), "#151143")
d = ImageDraw.Draw(canvas)
d.rounded_rectangle((9,9,247,247),radius=55,fill="#2e1a71",outline="#ef85ef",width=5)
d.ellipse((43,48,213,214), fill="#19245d",outline="#ff6b9c",width=15)
d.polygon([(141,28),(74,141),(123,139),(98,222),(185,105),(137,108)],fill="#ffcb48")
d.arc((45,44,212,210),start=200,end=335,fill="#65f5ff",width=10)
canvas.save(ASSETS / "arena-rush.png")

# Fetch only first-party Authenticator logo, not third-party image sources.
AUTH = ("https://raw.githubusercontent.com/itamarnintendo04-arch/"
        "ItamarOS-Authenticator/main/assets/icon-source.png")
try:
    req = urllib.request.Request(AUTH, headers={"User-Agent":"ItamarOS Installer Asset Build"})
    with urllib.request.urlopen(req, timeout=18) as response:
        content = response.read(5 * 1024 * 1024)
    from io import BytesIO
    with Image.open(BytesIO(content)) as img:
        img.convert("RGBA").resize((256,256), Image.Resampling.LANCZOS).save(ASSETS / "authenticator.png", optimize=True)
    print("Bundled actual ItamarOS Authenticator icon")
except (OSError, ValueError) as exc:
    print("Authenticator logo unavailable for bundling:", exc)
    # The app can request this URL at run time and show "Logo unavailable" otherwise.

print("Prepared artwork:", sorted(p.name for p in ASSETS.iterdir()))

# Bundle the official first-party release registry so the Wi-Fi companion
# always has a safe catalog even while GitHub is temporarily unavailable.
CATALOG = ROOT / "catalog" / "ios-apps.json"
if CATALOG.is_file():
    shutil.copyfile(CATALOG, ASSETS / "official-ios-apps.json")
    print("Bundled official main-repository iOS download catalog")
else:
    raise FileNotFoundError("Missing official release registry: " + str(CATALOG))
