"""Generate an original blue iPhone Studio app icon for the iOS asset catalog."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import json
S=1024
im=Image.new("RGB",(S,S))
p=im.load()
for y in range(S):
    for x in range(S):
        r=((x-280)**2+(y-190)**2)**0.5/S
        p[x,y]=(max(5,int(11+10*(1-r))),max(14,int(24+28*(1-r))),max(30,int(58+72*(1-r))))
d=ImageDraw.Draw(im)
for width in range(70,0,-2):
    color=(int(9+width*.22),int(110+width*.7),min(255,int(185+width)))
    d.arc((62,80,965,960),195,345,fill=color,width=3)
d.rounded_rectangle((314,125,708,875),radius=78,fill="#0a152b",outline="#75dfff",width=18)
d.rounded_rectangle((344,169,678,834),radius=49,fill="#1568c9")
d.rounded_rectangle((423,179,599,210),radius=17,fill="#06142d")
d.ellipse((420,405,604,589),fill="#c7f8ff")
d.ellipse((466,447,558,541),fill="#1568c9")
d.rounded_rectangle((581,603,839,865),radius=72,fill="#d4f5ff",outline="#1a9cfa",width=12)
d.ellipse((657,680,763,786),fill="#133e80")
dest=Path("Assets.xcassets/AppIcon.appiconset")
dest.mkdir(parents=True,exist_ok=True)
im.save(dest/"AppIcon.png")
(dest/"Contents.json").write_text(json.dumps({"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}},indent=2))
