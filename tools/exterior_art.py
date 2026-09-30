"""OSTATOK exterior-world art generator.
Builds facade, roof and street-detail atlases plus an upgraded ground chunk.
All art is native-resolution pixel art consumed by Godot with nearest filtering.
"""
from PIL import Image, ImageDraw
import random, os


def crack(d, rng, x, y, length, color):
    pts=[(x,y)]; cx,cy=x,y
    for _ in range(length):
        cx += rng.choice([-1,0,1]); cy += rng.choice([0,1])
        pts.append((cx,cy))
    d.line(pts, fill=color, width=1)
    if length > 6 and rng.random() < .7:
        bx,by=pts[len(pts)//2]
        d.line([(bx,by),(bx+rng.choice([-3,-2,2,3]),by+rng.randint(2,5))], fill=color, width=1)


def build_facade(path):
    out=Image.new('RGBA',(256,32),(0,0,0,0))
    palettes=[
        ((67,78,73,255),(42,49,47,255),(94,103,94,255)),   # clinic / municipal
        ((64,72,68,255),(38,44,42,255),(88,94,87,255)),    # cracked neutral
        ((89,77,59,255),(56,48,39,255),(118,98,72,255)),   # retail plaster
        ((61,64,61,255),(38,41,39,255),(82,84,78,255)),    # industrial concrete
        ((80,69,53,255),(51,45,37,255),(111,92,66,255)),   # faded commercial
        ((50,55,53,255),(31,35,34,255),(72,76,70,255)),    # heavy industry
        ((71,72,65,255),(44,46,42,255),(95,94,81,255)),    # residential
        ((58,63,60,255),(35,39,38,255),(83,86,79,255)),    # damaged generic
    ]
    for i,(base,dark,light) in enumerate(palettes):
        rng=random.Random(7900+i)
        tile=Image.new('RGBA',(32,28),base); d=ImageDraw.Draw(tile)
        # top lintel and deep plinth create a consistent facade silhouette
        d.rectangle((0,0,31,2),fill=dark)
        d.line((0,3,31,3),fill=(light[0],light[1],light[2],150))
        d.rectangle((0,22,31,27),fill=(dark[0],dark[1],dark[2],255))
        d.line((0,21,31,21),fill=(light[0],light[1],light[2],95))
        # subtle masonry/plaster breakup
        for _ in range(15):
            x=rng.randrange(2,30); y=rng.randrange(5,21)
            col=dark if rng.random()<.62 else light
            d.point((x,y),fill=(col[0],col[1],col[2],rng.choice([55,70,90,110])))
        if i in (1,7):
            crack(d,rng,rng.randint(5,25),4,rng.randint(9,15),(27,31,30,220))
        if i in (3,5):
            # concrete panel joints / service stain
            d.line((15,4,15,21),fill=(34,37,36,120))
            d.line((16,4,16,21),fill=(90,91,83,50))
            d.rectangle((3,6,6,19),fill=(31,36,35,130))
        if i in (2,4):
            # faded shop paint band
            d.rectangle((4,7,27,11),fill=(112,91,62,80))
            d.line((6,12,24,12),fill=(45,42,36,130))
        if i == 0:
            d.rectangle((7,7,24,9),fill=(82,102,92,80))
            d.point((25,17),fill=(139,117,74,140))
        if i == 6:
            # patched residential plaster
            d.rectangle((18,10,27,18),fill=(60,61,55,130))
            d.line((19,10,26,10),fill=(104,100,83,70))
        out.alpha_composite(tile,(i*32,0))
    out.save(path)


def build_facade_details(path):
    out=Image.new('RGBA',(256,48),(0,0,0,0))
    # 0 pharmacy canopy
    d=ImageDraw.Draw(out)
    x=0
    d.rectangle((x+6,18,x+57,26),fill=(48,60,55,255),outline=(22,27,26,255))
    d.line((x+8,18,x+55,18),fill=(102,116,101,200))
    for sx in range(x+10,x+56,9): d.rectangle((sx,26,sx+2,30),fill=(31,36,34,255))
    d.rectangle((x+13,15,x+50,17),fill=(78,91,82,220))
    # 1 striped shop awning
    x=64
    d.polygon([(x+7,17),(x+57,17),(x+53,30),(x+11,30)],fill=(92,73,52,255),outline=(35,31,27,255))
    for sx in range(x+13,x+54,10): d.polygon([(sx,18),(sx+5,18),(sx+3,29),(sx-2,29)],fill=(128,104,72,190))
    d.line((x+10,31,x+54,31),fill=(28,29,27,255))
    # 2 industrial canopy / roller housing
    x=128
    d.rectangle((x+4,15,x+59,23),fill=(54,59,57,255),outline=(24,28,27,255))
    d.rectangle((x+8,23,x+55,28),fill=(43,47,45,255))
    for sx in range(x+10,x+55,8): d.line((sx,24,sx,27),fill=(84,86,78,140))
    d.line((x+4,14,x+59,14),fill=(96,97,88,140))
    # 3 residential concrete ledge / torn shade
    x=192
    d.rectangle((x+8,19,x+55,23),fill=(65,66,60,255),outline=(29,31,29,255))
    d.line((x+10,18,x+53,18),fill=(101,98,82,120))
    d.rectangle((x+15,24,x+20,27),fill=(42,43,39,180))
    d.rectangle((x+43,24,x+48,26),fill=(42,43,39,160))
    out.save(path)


def build_roof_tile(path):
    rng=random.Random(7979)
    im=Image.new('RGBA',(64,64),(43,48,46,255)); d=ImageDraw.Draw(im)
    # weathered roofing felt / metal membrane grid
    for y in (0,16,32,48,63): d.line((0,y,63,y),fill=(27,31,30,190))
    for x in (0,32,63): d.line((x,0,x,63),fill=(31,35,34,150))
    for y in (1,17,33,49): d.line((0,y,63,y),fill=(72,76,69,55))
    for _ in range(38):
        x=rng.randrange(2,62); y=rng.randrange(2,62)
        c=(28,31,30,rng.choice([45,60,80])) if rng.random()<.72 else (86,82,65,45)
        d.point((x,y),fill=c)
    # tar repairs
    d.rectangle((7,39,22,46),fill=(27,30,29,115))
    d.line((7,39,22,39),fill=(76,74,63,45))
    crack(d,rng,48,7,15,(22,26,25,190))
    im.save(path)


def build_roof_props(path):
    out=Image.new('RGBA',(256,64),(0,0,0,0)); d=ImageDraw.Draw(out)
    # HVAC cell
    x=0
    d.rectangle((x+13,18,x+51,48),fill=(57,63,60,255),outline=(23,27,26,255))
    d.rectangle((x+16,14,x+48,19),fill=(82,87,80,255),outline=(30,34,32,255))
    for yy in range(24,44,5): d.line((x+19,yy,x+44,yy),fill=(31,36,34,220))
    d.rectangle((x+18,20,x+46,22),fill=(102,104,93,85))
    # twin vents
    x=64
    for dx,h in ((17,27),(31,33),(44,24)):
        d.rectangle((x+dx,48-h,x+dx+5,48),fill=(55,61,59,255),outline=(25,28,27,255))
        d.rectangle((x+dx-2,47-h,x+dx+7,50-h),fill=(90,93,84,255),outline=(30,33,31,255))
    d.line((x+11,49,x+53,49),fill=(22,25,24,180))
    # duct / service box
    x=128
    d.rectangle((x+11,18,x+53,49),fill=(54,60,57,255),outline=(24,27,26,255))
    d.rectangle((x+15,22,x+49,45),fill=(65,70,65,255),outline=(37,40,38,255))
    for yy in (26,31,36,41): d.line((x+18,yy,x+46,yy),fill=(38,42,40,180))
    d.rectangle((x+18,16,x+46,19),fill=(94,94,84,140))
    # antenna mast
    x=192
    d.line((x+32,10,x+32,52),fill=(71,77,74,255),width=2)
    d.line((x+13,31,x+51,31),fill=(58,64,61,255),width=2)
    d.line((x+20,19,x+44,43),fill=(58,64,61,220))
    d.line((x+44,19,x+20,43),fill=(58,64,61,220))
    d.rectangle((x+27,51,x+37,54),fill=(33,37,35,255))
    out.save(path)


def build_street_details(path):
    out=Image.new('RGBA',(384,48),(0,0,0,0))
    for i in range(6):
        tile=Image.new('RGBA',(64,48),(0,0,0,0)); d=ImageDraw.Draw(tile); rng=random.Random(7990+i)
        if i==0: # oil/water patch
            d.ellipse((8,20,56,35),fill=(22,28,28,105)); d.ellipse((18,23,47,31),fill=(54,67,66,55)); d.line((20,24,42,24),fill=(103,111,100,35))
        elif i==1: # pothole
            d.ellipse((16,15,48,35),fill=(26,28,27,220)); d.ellipse((21,18,44,31),fill=(42,43,39,230)); d.arc((14,13,51,37),185,350,fill=(94,88,70,120))
            for _ in range(7): d.point((rng.randrange(12,53),rng.randrange(13,37)),fill=(110,103,82,90))
        elif i==2: # faded crossing / warning stripe
            for x in range(5,59,13): d.rectangle((x,13,x+7,34),fill=(151,141,91,75))
            d.line((4,35,59,35),fill=(82,79,62,70))
        elif i==3: # drain grate
            d.rectangle((12,17,52,31),fill=(26,31,30,230),outline=(77,78,69,170))
            for x in range(16,50,6): d.line((x,19,x,29),fill=(95,94,82,130))
        elif i==4: # asphalt patch
            d.polygon([(7,16),(20,10),(49,13),(58,25),(46,36),(16,35)],fill=(37,40,39,165),outline=(25,28,27,190))
            crack(d,rng,24,13,13,(22,25,24,190))
        else: # paper / bottle cluster
            d.polygon([(11,20),(23,17),(25,25),(14,28)],fill=(127,123,99,180),outline=(54,55,48,180))
            d.polygon([(28,25),(39,20),(45,27),(35,32)],fill=(112,109,90,160),outline=(50,51,45,180))
            d.rectangle((49,22,53,32),fill=(45,72,56,185),outline=(24,33,28,210))
        out.alpha_composite(tile,(i*64,0))
    out.save(path)


def build_ground(base_path, path):
    im=Image.open(base_path).convert('RGBA').copy(); d=ImageDraw.Draw(im); rng=random.Random(79079)
    # reinforce worn curb edges / intersection storytelling without changing logical geometry
    for y in (274,493):
        for x in range(0,768,24):
            if rng.random()<.55:
                d.line((x,y,x+rng.randint(7,18),y),fill=(104,102,82,45))
    for x in (274,493):
        for y in range(0,768,24):
            if rng.random()<.55:
                d.line((x,y,x,y+rng.randint(7,18)),fill=(104,102,82,45))
    # faded pedestrian markings near central crossing
    for x in range(312,455,24): d.rectangle((x,300,x+11,307),fill=(146,137,87,55))
    for y in range(336,457,24): d.rectangle((300,y,307,y+11),fill=(146,137,87,48))
    # asphalt repairs / potholes placed away from building anchors
    for cx,cy,rx,ry in [(385,224,20,8),(223,390,24,9),(546,405,18,7),(384,575,22,8)]:
        d.ellipse((cx-rx,cy-ry,cx+rx,cy+ry),fill=(38,41,40,120),outline=(27,30,29,130))
    # a few tar seams
    for pts in [[(346,342),(355,347),(365,344),(377,350)],[(516,365),(527,370),(538,367)],[(242,534),(250,529),(262,532)]]:
        d.line(pts,fill=(24,27,26,150),width=1)
    im.save(path)


def build_all(project_dir):
    build_facade(os.path.join(project_dir,'facade_wall_tiles_v3.png'))
    build_facade_details(os.path.join(project_dir,'facade_detail_v1.png'))
    build_roof_tile(os.path.join(project_dir,'roof_tile_v2.png'))
    build_roof_props(os.path.join(project_dir,'roof_props_v3.png'))
    build_street_details(os.path.join(project_dir,'street_detail_v1.png'))
    build_ground(os.path.join(project_dir,'ground_chunk_v10.png'),os.path.join(project_dir,'ground_chunk_v11.png'))

if __name__=='__main__':
    import sys
    build_all(sys.argv[1] if len(sys.argv)>1 else '.')
