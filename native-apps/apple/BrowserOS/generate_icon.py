#!/usr/bin/env python3
"""Create a 1024px BrowserOS icon using Pillow during CI."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math, json
n=1024
im=Image.new("RGB",(n,n))
px=im.load()
for y in range(n):
    for x in range(n):
        glow=max(0,1-math.hypot((x-350)/920,(y-280)/920))
        px[x,y]=(int(8+30*glow+26*x/n),int(16+70*glow),int(64+120*glow))
d=ImageDraw.Draw(im)
d.rounded_rectangle((20,20,1004,1004),radius=220,outline="#2ef1f9",width=15)
d.ellipse((185,190,835,840),fill="#135ac4",outline="#57f4fa",width=24)
d.arc((90,340,940,810),start=15,end=170,fill="#4af8f6",width=44)
d.arc((140,190,940,900),start=192,end=340,fill="#ac58ff",width=32)
d.polygon([(365,280),(480,310),(510,390),(450,440),(370,410),(330,340)],fill="#37ddff")
d.polygon([(550,250),(690,300),(730,390),(660,430),(590,380)],fill="#8d68ff")
d.polygon([(310,510),(400,520),(455,610),(420,720),(345,650)],fill="#28c5f6")
d.rounded_rectangle((110,430,915,635),radius=92,fill="#121f62",outline="#54e7fc",width=13)
d.ellipse((165,485,232,552),outline="#f7fbff",width=12)
d.line((223,542,251,574),fill="#f7fbff",width=13)
try:
    font=ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf",88)
except OSError:
    try: font=ImageFont.truetype("DejaVuSans-Bold.ttf",88)
    except OSError: font=ImageFont.load_default()
d.text((290,485),"BrowserOS",font=font,fill="white")
out=Path(__file__).parent/"Assets.xcassets"/"BrowserOSIcon.appiconset"
out.mkdir(parents=True,exist_ok=True)
im.save(out/"Icon.png",optimize=True)
(out/"Contents.json").write_text(json.dumps({"images":[{"filename":"Icon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}))
