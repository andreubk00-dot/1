"""OSTATOK environment material generator.
Builds native-resolution interior floor, wall, trim and floor-detail atlases.
No filtering or scaling is baked into the source art; Godot consumes these at 1:1.
"""
from PIL import Image, ImageDraw
import random, os


def _px(draw, x, y, c):
    draw.point((x, y), fill=c)


def _crack(draw, rng, x, y, length, c):
    pts=[(x,y)]
    cx,cy=x,y
    for _ in range(length):
        cx += rng.choice([-1,0,1])
        cy += rng.choice([0,1])
        pts.append((cx,cy))
    draw.line(pts, fill=c, width=1)
    if length > 5 and rng.random() < .65:
        bx,by=pts[length//2]
        draw.line([(bx,by),(bx+rng.choice([-2,2]),by+rng.randint(2,4))], fill=c, width=1)


def build_floor(path):
    out=Image.new('RGBA',(256,128),(0,0,0,0))
    palettes=[
        # clinic, retail, industrial, residential
        ((70,76,70,255),(57,63,58,255),(84,88,79,255),(45,49,46,255)),
        ((92,82,66,255),(76,67,55,255),(109,95,73,255),(58,51,43,255)),
        ((61,62,58,255),(47,49,46,255),(74,74,68,255),(35,37,35,255)),
        ((79,65,50,255),(62,51,40,255),(98,78,57,255),(44,37,31,255)),
    ]
    for row, pal in enumerate(palettes):
        base, dark, light, deep=pal
        for v in range(8):
            rng=random.Random(9021 + row*100 + v)
            tile=Image.new('RGBA',(32,32),base)
            d=ImageDraw.Draw(tile)
            # material structure
            if row == 0:  # clinic linoleum / old tile seams
                if v % 2 == 0:
                    d.line([(15,0),(15,31)], fill=dark)
                    d.line([(0,15),(31,15)], fill=dark)
                    d.line([(16,0),(16,31)], fill=(81,85,78,110))
                    d.line([(0,16),(31,16)], fill=(81,85,78,110))
                else:
                    d.line([(0,31),(31,31)], fill=dark)
                    d.line([(31,0),(31,31)], fill=dark)
            elif row == 1:  # retail square tile
                for g in (0,16,31):
                    d.line([(g,0),(g,31)], fill=dark)
                    d.line([(0,g),(31,g)], fill=dark)
                d.line([(1,1),(14,1)], fill=(118,104,79,90))
                d.line([(17,17),(30,17)], fill=(118,104,79,70))
            elif row == 2:  # poured concrete
                if v in (2,6):
                    d.line([(0,8),(31,8)], fill=(49,50,47,160))
                if v in (3,7):
                    d.line([(23,0),(23,31)], fill=(50,51,48,145))
            else:  # boards / worn residential floor
                for yy in (7,15,23,31):
                    d.line([(0,yy),(31,yy)], fill=deep)
                offset=(v*7)%16
                for yy in (0,8,16,24):
                    xx=(offset + yy*3) % 24
                    d.line([(xx,yy),(xx,yy+6)], fill=dark)
            # wear noise kept sparse so rooms do not shimmer visually
            for _ in range(20 if row != 3 else 12):
                x=rng.randrange(1,31); y=rng.randrange(1,31)
                c=dark if rng.random()<.7 else light
                a=rng.choice([55,70,85,100])
                _px(d,x,y,(c[0],c[1],c[2],a))
            # authored variants
            if v in (1,5):
                _crack(d,rng,rng.randint(7,24),rng.randint(2,8),rng.randint(8,15),(31,34,32,190))
            if v == 2:
                d.ellipse((20,20,27,25),fill=(72,44,35,105))
                d.point((18,23),fill=(72,44,35,90))
            if v == 3:
                d.rectangle((4,25,12,27),fill=(44,45,41,90))
                d.point((15,26),fill=(40,42,39,100))
            if v == 6 and row in (0,2):
                d.rectangle((2,2,8,3),fill=(118,110,87,80))
                d.rectangle((4,4,12,5),fill=(118,110,87,45))
            if v == 7:
                d.ellipse((5,4,15,10),fill=(28,31,29,65))
            out.alpha_composite(tile,(v*32,row*32))
    out.save(path)


def build_wall(path):
    out=Image.new('RGBA',(256,28),(0,0,0,0))
    bases=[
        (76,81,75,255),(73,78,72,255),(84,82,72,255),(65,70,67,255),
        (81,76,65,255),(59,64,62,255),(69,73,69,255),(63,67,64,255),
    ]
    for i,base in enumerate(bases):
        rng=random.Random(4700+i)
        tile=Image.new('RGBA',(32,28),base)
        d=ImageDraw.Draw(tile)
        # top cap and lower washable band
        d.rectangle((0,0,31,2),fill=(34,38,36,255))
        d.line([(0,3),(31,3)],fill=(99,103,94,150))
        d.rectangle((0,20,31,27),fill=(52,59,56,255))
        d.line([(0,19),(31,19)],fill=(28,32,31,235))
        d.line([(0,20),(31,20)],fill=(92,94,82,90))
        # mottling and chips
        for _ in range(12):
            x=rng.randrange(2,30); y=rng.randrange(5,19)
            d.point((x,y),fill=(45,49,46,rng.choice([55,75,95])))
        if i in (1,6,7):
            _crack(d,rng,rng.randint(5,25),4,rng.randint(8,14),(32,36,34,210))
        if i == 2:
            d.rectangle((9,7,23,14),fill=(48,49,43,255),outline=(27,29,27,255))
            d.rectangle((11,9,21,10),fill=(105,87,63,180))
        if i == 3:
            d.rectangle((4,6,6,17),fill=(43,48,47,220))
            d.rectangle((25,8,27,18),fill=(43,48,47,180))
        if i == 4:
            d.rectangle((7,6,25,12),fill=(91,77,55,190),outline=(41,42,37,240))
            d.line([(10,9),(21,9)],fill=(135,116,82,150))
        if i == 5:
            d.rectangle((0,13,31,15),fill=(39,43,42,175))
            for x in (5,16,27): d.rectangle((x,5,x+1,7),fill=(104,104,91,120))
        out.alpha_composite(tile,(i*32,0))
    out.save(path)


def build_trim(path):
    out=Image.new('RGBA',(128,32),(0,0,0,0))
    d=ImageDraw.Draw(out)
    metal=(52,58,55,255); hi=(95,96,82,190); deep=(24,28,27,255); dirt=(78,68,50,170)
    # top horizontal 0..31 x 0..15
    d.rectangle((0,5,31,10),fill=metal); d.line((0,5,31,5),fill=hi); d.line((0,10,31,10),fill=deep)
    for x in (4,15,27): d.point((x,7),fill=dirt)
    # front edge 32..63
    d.rectangle((32,4,63,12),fill=(46,51,48,255)); d.line((32,4,63,4),fill=(103,99,78,160)); d.line((32,12,63,12),fill=(18,21,20,255))
    d.rectangle((40,7,47,9),fill=(67,63,50,180)); d.rectangle((55,6,59,8),fill=(34,38,36,190))
    # left/right vertical
    for x0 in (64,80):
        d.rectangle((x0+5,0,x0+10,31),fill=metal); d.line((x0+5,0,x0+5,31),fill=hi); d.line((x0+10,0,x0+10,31),fill=deep)
        for y in (5,17,27): d.point((x0+7,y),fill=dirt)
    # threshold 96..127
    d.rectangle((96,4,127,12),fill=(73,69,52,255)); d.line((96,4,127,4),fill=(123,112,77,180)); d.line((96,12,127,12),fill=deep)
    for x in range(98,127,8): d.line((x,6,x+4,10),fill=(46,48,41,160))
    out.save(path)


def build_floor_details(path):
    out=Image.new('RGBA',(384,32),(0,0,0,0))
    for i in range(8):
        tile=Image.new('RGBA',(48,32),(0,0,0,0)); d=ImageDraw.Draw(tile); rng=random.Random(1190+i)
        if i == 0:  # grime patch
            d.ellipse((7,13,36,24),fill=(25,28,26,90)); d.ellipse((14,16,30,22),fill=(17,20,18,65))
        elif i == 1:  # cracks
            _crack(d,rng,13,5,15,(29,32,30,210)); _crack(d,rng,31,7,11,(29,32,30,180))
        elif i == 2:  # papers
            for x,y in ((8,12),(17,10),(26,14),(34,11)):
                d.polygon([(x,y),(x+8,y+1),(x+6,y+6),(x-1,y+5)],fill=(139,137,111,210),outline=(58,59,51,210))
        elif i == 3:  # blood
            d.ellipse((10,12,34,25),fill=(91,28,24,190)); d.ellipse((20,8,30,18),fill=(112,35,29,175)); d.point((38,20),fill=(100,31,27,160))
        elif i == 4:  # broken tiles
            for x,y in ((7,15),(15,10),(23,16),(31,12)):
                d.polygon([(x,y),(x+6,y-2),(x+9,y+3),(x+4,y+6)],fill=(90,92,82,190),outline=(37,40,37,220))
        elif i == 5:  # cable
            pts=[(4,20),(12,17),(20,20),(28,15),(38,17),(44,11)]; d.line(pts,fill=(26,28,27,235),width=2); d.point((5,19),fill=(100,83,53,180))
        elif i == 6:  # puddle
            d.ellipse((7,14,40,25),fill=(45,56,55,100)); d.line((14,17,30,17),fill=(99,109,101,60))
        else:  # bottles / small debris
            d.rectangle((9,15,13,23),fill=(46,76,59,200),outline=(25,34,29,220)); d.rectangle((27,17,31,24),fill=(84,70,47,190),outline=(34,32,26,220)); d.rectangle((37,18,41,21),fill=(74,77,67,180))
        out.alpha_composite(tile,(i*48,0))
    out.save(path)


def build_all(project_dir):
    build_floor(os.path.join(project_dir,'interior_floor_tiles_v4.png'))
    build_wall(os.path.join(project_dir,'interior_wall_band_v3.png'))
    build_trim(os.path.join(project_dir,'interior_trim_v3.png'))
    build_floor_details(os.path.join(project_dir,'floor_detail_v4.png'))

if __name__ == '__main__':
    import sys
    build_all(sys.argv[1] if len(sys.argv)>1 else '.')
