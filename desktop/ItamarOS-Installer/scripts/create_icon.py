"""Create Windows icon offline for ItamarOS Installer."""
from pathlib import Path
from PIL import Image, ImageDraw

size = 256
im = Image.new("RGBA", (size, size), "#0a1225")
draw = ImageDraw.Draw(im)
for y in range(size):
    draw.line((0, y, size, y),
              fill=(max(6, 10 + y // 16), max(13, 21 + y // 11), max(26, 43 + y // 8), 255))
outer = [(128,22),(223,73),(223,179),(128,235),(33,179),(33,73)]
inner = [(128,40),(206,82),(206,171),(128,217),(50,171),(50,82)]
draw.polygon(outer, fill="#31e6c7")
draw.polygon(inner, fill="#0b2638")
draw.rounded_rectangle((91,73,165,159), radius=13, fill="#1dc8af")
draw.line((128,92,128,141), fill="#efffff", width=15)
draw.polygon([(105,131),(151,131),(128,157)], fill="#efffff")
draw.rounded_rectangle((80,171,175,182), radius=6, fill="#4bf4d8")
out = Path(__file__).resolve().parents[1] / "assets"
out.mkdir(parents=True, exist_ok=True)
im.save(out / "installer.ico", sizes=[(256,256),(128,128),(64,64),(48,48),(32,32),(16,16)])
im.save(out / "installer.png")
print("Generated", out / "installer.ico")
