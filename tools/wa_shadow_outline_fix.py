"""Remove the ink outline that bk.to_sprite drew around baked sun shadows.

The outline pass rings every solid pixel, and dense shadow-catcher pixels
counted as solid, so a dark line traced the outer edge of the cast shadow.
In daylight it reads as part of the shadow; at night, when the shadow fades
(SUN_SHADOW_SHADER), the line stays behind as a hard silhouette around cars
and props. An outline pixel that touches no body pixel (4-neighbourhood) is
part of the shadow's ring: it becomes transparent at the outer edge, shadow
elsewhere.

usage: python3 tools/wa_shadow_outline_fix.py art/vehicles/world_cars_hd_v1.png ...
"""
import sys
import numpy as np
from PIL import Image

OUTLINE = (18, 16, 14)
SHADOW = (8, 10, 10)


def strip_shadow_ring(a):
    """a: HxWx4 uint8 RGBA array, fixed in place; returns (outer, inner) counts."""
    rgb, al = a[..., :3].astype(int), a[..., 3].astype(int)
    ink = (al == 255) & (rgb[..., 0] == OUTLINE[0]) & (rgb[..., 1] == OUTLINE[1]) & (rgb[..., 2] == OUTLINE[2])
    body = (al == 255) & ~ink
    shade = (al > 0) & (al < 255)

    def n4(m):
        g = np.zeros_like(m)
        g[1:] |= m[:-1]; g[:-1] |= m[1:]; g[:, 1:] |= m[:, :-1]; g[:, :-1] |= m[:, 1:]
        return g

    stray = ink & ~n4(body)
    # a ring pixel is a shadow-edge pixel only if a shadow pixel is near it;
    # otherwise it is a genuine silhouette line (thin pole, wire) and stays
    near_shade = n4(n4(shade))
    stray &= near_shade
    outer = stray & n4(al == 0)
    inner = stray & ~outer
    # shadow alpha for inner ring pixels: the most common shadow alpha around
    sh_alpha = int(np.median(al[shade])) if shade.any() else 80
    a[outer] = (0, 0, 0, 0)
    a[inner] = SHADOW + (sh_alpha,)
    return int(outer.sum()), int(inner.sum())


def fix(path):
    a = np.array(Image.open(path).convert('RGBA'))
    outer, inner = strip_shadow_ring(a)
    Image.fromarray(a.astype(np.uint8), 'RGBA').save(path)
    print(path, 'outer', outer, 'inner', inner)


if __name__ == '__main__':
    for p in sys.argv[1:]:
        fix(p)
