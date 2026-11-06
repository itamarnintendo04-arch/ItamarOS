#!/usr/bin/env python3
"""Create distinct 1024px iOS icons for ItamarOS apps on the macOS build runner."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parent
APPS=[
 ("ItamarOSGames","GamesIcon",(26,22,99),(119,60,247),"G", "✦"),
 ("SkyboundIsles","SkyboundIcon",(21,107,189),(92,210,162),"S", "▲"),
 ("VoiceRecorder","VoiceRecorderIcon",(82,22,72),(230,65,132),"V", "●"),
]
for folder,name,top,bottom,letter,detail in APPS:
    icon_dir=ROOT/folder/"Assets.xcassets"/(name+".appiconset")
    icon_dir.mkdir(parents=True,exist_ok=True)
    im=Image.new("RGB",(1024,1024))
    pix=im.load()
    for y in range(1024):
        t=y/1023
        rgb=tuple(int(top[k]*(1-t)+bottom[k]*t) for k in range(3))
        for x in range(1024):pix[x,y]=rgb
    d=ImageDraw.Draw(im)
    d.rounded_rectangle((125,125,899,899),radius=190,outline=(255,255,255),width=19)
    d.ellipse((240,240,784,784),outline=(235,242,255),width=28)
    fonts=["/System/Library/Fonts/Supplemental/Arial Bold.ttf","/System/Library/Fonts/Helvetica.ttc"]
    font=next((ImageFont.truetype(f,430) for f in fonts if Path(f).exists()),ImageFont.load_default())
    d.text((512,493),letter,font=font,anchor="mm",fill=(255,255,255),stroke_width=2)
    im.save(icon_dir/"Icon.png")
    (icon_dir/"Contents.json").write_text(json.dumps({"images":[{"filename":"Icon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}},indent=2))
