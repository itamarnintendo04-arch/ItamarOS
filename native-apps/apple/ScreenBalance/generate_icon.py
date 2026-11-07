#!/usr/bin/env python3
"""Generate the Screen Balance iOS app icon with Pillow during GitHub Actions builds.
This vector-like recreation follows the separately supplied original artwork.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import math

N=1024
im=Image.new("RGB",(N,N))
px=im.load()
for y in range(N):
    for x in range(N):
        d=math.hypot((x-512)/730,(y-512)/730)
        glow=max(0,1-d)
        px[x,y]=(int(3+3*glow),int(29+40*glow),int(26+28*glow))
d=ImageDraw.Draw(im)
d.rounded_rectangle((18,18,1006,1006),radius=220,outline="#13f09c",width=14)
# The screen, rising bars, landscape, sun and an active person.
d.rounded_rectangle((280,180,694,816),radius=90,outline="#a4ffe0",width=27)
d.rounded_rectangle((418,225,556,243),radius=10,fill="#a4ffe0")
for x,y,h in [(380,405,72),(466,360,118),(552,305,173)]:
    d.rounded_rectangle((x,y,x+54,y+h),radius=16,fill="#35e66d")
d.ellipse((364,580,465,681),fill="#ffe753")
d.polygon([(304,680),(419,610),(510,670),(590,602),(669,677),(669,736),(304,736)],fill="#1cd365")
# Leaf
d.ellipse((690,274,890,404),fill="#a0ff6b")
d.line((716,405,855,294),fill="#0b6d39",width=12)
# Curved balance swoosh
d.arc((115,345,927,805),10,174,fill="#82fa58",width=25)
# Person
d.ellipse((665,483,740,558),fill="#e2fff0")
d.line([(704,562),(676,657),(733,708),(798,797)],fill="#d9fff0",width=43,joint="curve")
d.line([(682,630),(599,725)],fill="#d9fff0",width=38)
d.line([(698,601),(785,641)],fill="#d9fff0",width=35)
out=Path(__file__).parent/"Assets.xcassets"/"ScreenBalanceIcon.appiconset"
out.mkdir(parents=True,exist_ok=True)
im.save(out/"Icon.png",optimize=True)
(out/"Contents.json").write_text('{"images":[{"filename":"Icon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}')
print("Generated",out/"Icon.png")
