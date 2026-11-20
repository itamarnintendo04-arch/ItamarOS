"""Generate the mobile Installer icon from existing ItamarOS branded artwork."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
dest=HERE/"Assets.xcassets/AppIcon.appiconset"
dest.mkdir(parents=True,exist_ok=True)
n=1024
im=Image.new("RGB",(n,n))
pix=im.load()
for y in range(n):
    for x in range(n):
        pix[x,y]=(8+int(x/n*9),20+int(y/n*24),57+int(x/n*28))
d=ImageDraw.Draw(im)
d.rounded_rectangle((45,45,979,979),radius=218,outline="#4ce4f2",width=28)
brand=ROOT/"assets/branding/itamaros-mark-512.png"
with Image.open(brand) as mark:
    icon=mark.convert("RGBA").resize((525,525),Image.Resampling.LANCZOS)
    im.paste(icon,((n-525)//2,120),icon)
d.rounded_rectangle((315,640,710,826),radius=64,fill="#0e394c",outline="#41f4d7",width=19)
d.line([(510,675),(510,755)],fill="#f1ffff",width=40)
d.polygon([(420,735),(600,735),(510,804)],fill="#f1ffff")
im.save(dest/"AppIcon.png")
print("Generated",dest/"AppIcon.png")
