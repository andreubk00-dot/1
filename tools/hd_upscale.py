"""OSTATOK 1.53: HD twins of the last 1x world textures.

The world draws its art at 2 texels per world unit (HD); a handful of old 1x
textures were still drawn at 1 texel per unit and showed pixels twice the size
of everything round them (settlement grounds, floor stains, street details,
puddle sheen, door leaves, wall corners, settlement props). Each is doubled
with Scale2x - edges keep their pixel-art steps, diagonals get the in-between
texel - and the flat areas get a faint per-texel grain from the source's own
palette, so they carry detail at the new density instead of 2 x 2 blocks.

    python3 tools/hd_upscale.py <project_dir>

Writes art/world_hd/x2/<name>.png for every name in SOURCES.
"""
import os
import sys

import numpy as np
from PIL import Image

SOURCES = [
    "settlement_ground_asphalt_v1.png", "settlement_ground_concrete_slabs_v1.png", "settlement_ground_cobble_v1.png",
    "settlement_ground_dirt_road_v1.png", "settlement_ground_grass_v1.png", "settlement_ground_grass_dry_v1.png",
    "settlement_ground_lawn_v1.png", "settlement_ground_dirt_yard_v1.png", "settlement_ground_gravel_v1.png",
    "settlement_ground_oil_concrete_v1.png", "settlement_ground_pavers_v1.png", "settlement_ground_pavement_v1.png",
    "floor_detail_v5.png", "street_detail_v2.png", "wet_surface_v2.png", "settlement_door_leaves_v1.png",
    "wall_corner_v2.png", "door_topdown_v2.png", "settlement_props_v1.png", "poi_props_v1.png",
]


def scale2x(a, wrap):
    """Scale2x on an (H, W, C) array, comparing whole pixels."""
    if wrap:
        pad = np.pad(a, ((1, 1), (1, 1), (0, 0)), mode='wrap')
    else:
        pad = np.pad(a, ((1, 1), (1, 1), (0, 0)), mode='edge')
    E = pad[1:-1, 1:-1]
    B = pad[:-2, 1:-1]
    D = pad[1:-1, :-2]
    F = pad[1:-1, 2:]
    H = pad[2:, 1:-1]
    eq = lambda x, y: np.all(x == y, axis=2)
    bh = ~eq(B, H)
    df = ~eq(D, F)
    E0 = np.where((eq(D, B) & bh & df)[..., None], D, E)
    E1 = np.where((eq(B, F) & bh & df)[..., None], F, E)
    E2 = np.where((eq(D, H) & bh & df)[..., None], D, E)
    E3 = np.where((eq(H, F) & bh & df)[..., None], F, E)
    h, w = a.shape[:2]
    out = np.zeros((h * 2, w * 2, a.shape[2]), a.dtype)
    out[0::2, 0::2] = E0
    out[0::2, 1::2] = E1
    out[1::2, 0::2] = E2
    out[1::2, 1::2] = E3
    return out


def build(P):
    out = os.path.join(P, 'art', 'world_hd', 'x2')
    os.makedirs(out, exist_ok=True)
    rng = np.random.default_rng(153)
    for name in SOURCES:
        path = os.path.join(P, name)
        if not os.path.exists(path):
            print('skip', name)
            continue
        im = Image.open(path).convert('RGBA')
        a = np.array(im)
        tiled = name.startswith('settlement_ground_')
        b = scale2x(a, tiled)
        # grain on opaque texels only, inside each doubled cell: two of the four
        # sub-texels a shade lighter / darker, so a flat 2 x 2 block reads as
        # four texels of the same material
        rgb = b[..., :3].astype(float)
        alpha = b[..., 3]
        g = rng.choice([-1.0, 0.0, 0.0, 1.0], size=alpha.shape) * (5.0 if tiled else 3.0)
        rgb = np.clip(rgb + g[..., None] * (alpha[..., None] > 200), 0, 255)
        b = np.dstack([rgb.astype(np.uint8), alpha])
        Image.fromarray(b, 'RGBA').save(os.path.join(out, name))
        print('x2', name, im.size, '->', (im.width * 2, im.height * 2), flush=True)


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
