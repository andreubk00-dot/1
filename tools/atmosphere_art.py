"""OSTATOK atmosphere/weather art generator.
Builds native-resolution wet-road overlays used by runtime weather blending.
"""
from PIL import Image, ImageDraw
import random, os


def build_wet_surface(path):
    out = Image.new('RGBA', (256, 48), (0,0,0,0))
    for i in range(4):
        rng = random.Random(80080 + i)
        tile = Image.new('RGBA', (64,48), (0,0,0,0))
        d = ImageDraw.Draw(tile)
        if i == 0:
            d.ellipse((5,20,59,36), fill=(47,63,65,62))
            d.ellipse((14,23,52,32), fill=(86,103,103,40))
            d.line((18,24,45,24), fill=(172,177,155,42))
            d.line((25,29,51,29), fill=(105,122,120,35))
        elif i == 1:
            d.polygon([(6,27),(17,19),(39,18),(57,25),(50,34),(24,37),(9,33)], fill=(39,55,57,58))
            d.line((15,23,43,21), fill=(159,163,143,38))
            d.line((27,31,50,29), fill=(94,110,109,30))
        elif i == 2:
            for x,y,w in [(8,27,18),(26,22,25),(17,34,31)]:
                d.line((x,y,x+w,y-rng.randint(0,2)), fill=(137,146,132,rng.randint(26,42)), width=1)
            d.ellipse((10,25,56,38), fill=(43,59,61,42))
        else:
            d.ellipse((12,18,50,32), fill=(45,61,62,54))
            d.ellipse((23,23,57,36), fill=(41,56,59,46))
            d.line((19,21,41,20), fill=(174,176,151,34))
            d.point((52,27), fill=(171,176,158,52))
        # sparse specular pin-pricks; deliberately subtle at nearest filtering
        for _ in range(5):
            x=rng.randrange(8,57); y=rng.randrange(20,37)
            d.point((x,y), fill=(175,183,169,rng.choice([25,30,38])))
        out.alpha_composite(tile, (i*64,0))
    out.save(path)


def build_all(project_dir):
    build_wet_surface(os.path.join(project_dir, 'wet_surface_v1.png'))


if __name__ == '__main__':
    import sys
    build_all(sys.argv[1] if len(sys.argv) > 1 else '.')
