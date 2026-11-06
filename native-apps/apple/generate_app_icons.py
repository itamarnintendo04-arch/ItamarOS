#!/usr/bin/env python3
"""Generate illustrated, distinct app icons without modifying the original ItamarOS icon."""
from pathlib import Path
import json
import subprocess
ROOT=Path(__file__).resolve().parent
APPS=[("ItamarOSGames","GamesIcon","games"),("SkyboundIsles","SkyboundIcon","sky"),("VoiceRecorder","VoiceRecorderIcon","voice"),("CloudClimb","CloudClimbAppIcon","cloud"),("ItamarCut","ItamarCutIcon","cut")]
HEAD='<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><defs><linearGradient id="bg" x2="1" y2="1"><stop stop-color="{a}"/><stop offset="1" stop-color="{b}"/></linearGradient></defs><rect width="1024" height="1024" fill="url(#bg)"/>'
def art(kind):
    if kind=="games":
        return '<ellipse cx="512" cy="480" rx="390" ry="220" fill="none" stroke="#00d9ff" stroke-width="36" opacity=".7"/><path d="M280 335 Q220 350 190 510 L155 670 Q155 755 240 748 L385 655 H639 L784 748 Q869 755 869 670 L834 510 Q804 350 744 335Z" fill="#f4f3ff" stroke="#a7b9fa" stroke-width="18"/><path d="M325 440v170 M240 525h170" stroke="#19245b" stroke-width="49" stroke-linecap="round"/><circle cx="680" cy="455" r="34" fill="#ffcb30"/><circle cx="755" cy="515" r="34" fill="#ff416f"/><circle cx="612" cy="515" r="34" fill="#1cd9ee"/><circle cx="680" cy="575" r="34" fill="#46d868"/><path d="M438 310 L512 190 586 310Z" fill="#ffd64d" stroke="#fff0a0" stroke-width="13"/>'
    if kind=="sky":
        return '<ellipse cx="512" cy="855" rx="430" ry="70" fill="#65d8ff" opacity=".4"/><path d="M140 470 L420 350 830 430 760 690 450 810 190 670Z" fill="#604a63"/><path d="M140 470 L420 350 830 430 610 565 310 590Z" fill="#63d84d"/><path d="M450 555 L570 565 520 835 470 865Z" fill="#8ef7ff"/><path d="M610 565 L660 555 600 800 540 845Z" fill="#d8ffff"/><path d="M430 380 L490 200 550 380Z" fill="#e8dc9a"/><rect x="465" y="320" width="65" height="135" fill="#e8dc9a"/><path d="M265 470 L300 345 340 470 M660 470 L700 330 750 470" fill="#1b954b" stroke="#136c43" stroke-width="17"/>'
    if kind=="cut":
        return '<rect x="165" y="215" width="690" height="570" rx="95" fill="#201339" stroke="#ffda7b" stroke-width="24"/><path d="M235 285 H785 V395 H235Z" fill="#ef57c1"/><path d="M280 285 L355 395 M445 285 L520 395 M610 285 L685 395" stroke="#201339" stroke-width="34"/><path d="M290 600 H735 M290 660 H600" stroke="#5fd7ff" stroke-width="24" stroke-linecap="round"/><path d="M475 435 L475 585 625 510Z" fill="#fff"/>'
    if kind=="voice":
        return '<circle cx="512" cy="480" r="300" fill="none" stroke="#ff588f" stroke-width="27" opacity=".65"/><rect x="432" y="235" width="160" height="345" rx="80" fill="#f9eaff"/><path d="M360 475 A152 152 0 0 0 664 475 M512 628 V755 M408 755 H616" fill="none" stroke="#fff" stroke-width="32" stroke-linecap="round"/><path d="M180 475 V560 M235 420 V620 M290 470 V575 M734 470 V575 M789 420 V620 M844 475 V560" fill="none" stroke="#ff82c0" stroke-width="24" stroke-linecap="round"/>'
    return '<path d="M0 680 Q220 520 400 700 T1024 670 V1024 H0Z" fill="#7bcf3c"/><path d="M0 780 Q210 620 420 770 T1024 760 V1024 H0Z" fill="#3bbd56"/><path d="M600 570 L840 570 840 750 600 750Z" fill="#9b724f"/><path d="M555 545 L890 545 820 460 625 460Z" fill="#76dc35"/><path d="M760 470 V295" stroke="#8e4d31" stroke-width="16"/><path d="M760 295 L860 330 760 360Z" fill="#ff4e5c"/><g fill="#fff"><circle cx="340" cy="400" r="145"/><circle cx="475" cy="385" r="120"/><circle cx="260" cy="460" r="100"/></g><circle cx="335" cy="425" r="16" fill="#19284e"/><circle cx="425" cy="425" r="16" fill="#19284e"/><path d="M350 475 Q385 510 420 475" fill="none" stroke="#19284e" stroke-width="12" stroke-linecap="round"/>'
for folder,name,kind in APPS:
    a,b={"games":("#10134b","#7422c2"),"sky":("#0688ec","#14337d"),"voice":("#4c104e","#d41f62"),"cloud":("#009dff","#72dcff"),"cut":("#4b157a","#eb3e9b")}[kind]
    svg=HEAD.format(a=a,b=b)+art(kind)+'</svg>'
    dest=ROOT/folder/"Assets.xcassets"/(name+".appiconset")
    dest.mkdir(parents=True,exist_ok=True)
    svgfile=dest/"icon-source.svg"
    svgfile.write_text(svg)
    subprocess.run(["rsvg-convert","--width=1024","--height=1024","--output",str(dest/"Icon.png"),str(svgfile)],check=True)
    (dest/"Contents.json").write_text(json.dumps({"images":[{"filename":"Icon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}},indent=2))
