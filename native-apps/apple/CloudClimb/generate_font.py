"""Generate original block-letter ItamarOS Games display font."""
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from pathlib import Path
PATTERNS={
"A":["01110","10001","10001","11111","10001","10001","10001"],
"B":["11110","10001","10001","11110","10001","10001","11110"],
"C":["01111","10000","10000","10000","10000","10000","01111"],
"D":["11110","10001","10001","10001","10001","10001","11110"],
"E":["11111","10000","10000","11110","10000","10000","11111"],
"F":["11111","10000","10000","11110","10000","10000","10000"],
"G":["01111","10000","10000","10111","10001","10001","01111"],
"H":["10001","10001","10001","11111","10001","10001","10001"],
"I":["11111","00100","00100","00100","00100","00100","11111"],
"J":["00111","00010","00010","00010","10010","10010","01100"],
"K":["10001","10010","10100","11000","10100","10010","10001"],
"L":["10000","10000","10000","10000","10000","10000","11111"],
"M":["10001","11011","10101","10101","10001","10001","10001"],
"N":["10001","11001","10101","10011","10001","10001","10001"],
"O":["01110","10001","10001","10001","10001","10001","01110"],
"P":["11110","10001","10001","11110","10000","10000","10000"],
"R":["11110","10001","10001","11110","10100","10010","10001"],
"S":["01111","10000","10000","01110","00001","00001","11110"],
"T":["11111","00100","00100","00100","00100","00100","00100"],
"U":["10001","10001","10001","10001","10001","10001","01110"],
"V":["10001","10001","10001","10001","10001","01010","00100"],
"W":["10001","10001","10001","10101","10101","10101","01010"],
"X":["10001","10001","01010","00100","01010","10001","10001"],
"Y":["10001","10001","01010","00100","00100","00100","00100"],
"Z":["11111","00001","00010","00100","01000","10000","11111"],
"0":["01110","10011","10101","10101","11001","10001","01110"],
"1":["00100","01100","00100","00100","00100","00100","01110"],
"2":["11110","00001","00001","01110","10000","10000","11111"],
"3":["11110","00001","00001","01110","00001","00001","11110"],
" ":["00000"]*7}
fb=FontBuilder(1000,isTTF=True)
glyphs={".notdef":TTGlyphPen(None).glyph()}
metrics={".notdef":(700,30)}
cmap={}
for char,rows in PATTERNS.items():
    name="space" if char==" " else "uni%04X"%ord(char)
    pen=TTGlyphPen(None)
    for y,row in enumerate(rows):
        for x,v in enumerate(row):
            if v=="1":
                left=55+x*115+int(y*9)
                bottom=(6-y)*110+70
                right=left+103
                top=bottom+99
                pen.moveTo((left,bottom));pen.lineTo((right,bottom))
                pen.lineTo((right,top));pen.lineTo((left,top));pen.closePath()
    glyphs[name]=pen.glyph()
    metrics[name]=(690,30)
    cmap[ord(char)]=name
    if char.isalpha(): cmap[ord(char.lower())]=name
fb.setupGlyphOrder(list(glyphs))
fb.setupCharacterMap(cmap)
fb.setupGlyf(glyphs)
fb.setupHorizontalMetrics(metrics)
fb.setupHorizontalHeader(ascent=900,descent=-100)
fb.setupNameTable({"familyName":"ItamarOS Games","styleName":"Regular",
                   "uniqueFontIdentifier":"ItamarOSGamesOriginal1",
                   "fullName":"ItamarOS Games","psName":"ItamarOSGames"})
fb.setupOS2(sTypoAscender=900,sTypoDescender=-100,usWinAscent=900,usWinDescent=100)
fb.setupPost()
fb.setupMaxp()
out=Path(__file__).parent/"Fonts"/"ItamarOSGames.ttf"
out.parent.mkdir(parents=True,exist_ok=True)
fb.save(out)
print(out)
