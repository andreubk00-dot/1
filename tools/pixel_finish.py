"""OSTATOK pixel finish: turns a rendered / generated texture into clean pixel art.

Renders and height-field shading leave soft gradients and per-texel noise, which
reads as a smoothed photo rather than pixel art. The finish:

  1. breaks long gradients with blocky (2x2 texel) jitter, so tone steps end in
     ragged pixel clusters instead of smooth contour lines,
  2. reduces the image to a small palette (k-means, no dithering): tones become
     flat bands of a few hand-picked-looking ramps,
  3. removes low-contrast stray texels (a texel unlike all 8 neighbours whose
     colour is close to the surrounding cluster) - deliberate high-contrast
     detail such as pebbles, blades and highlights stays.

Used by tools/wa_ground_districts.py and tools/blender/world_hd.py at save time;
run on its own to finish the art/world_hd atlases in place:

    python3 tools/pixel_finish.py <project_dir> [<atlas name> ...]
"""
import os
import sys
import numpy as np
from PIL import Image

OFFS = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]


def _shift(a, dy, dx, wrap):
    if wrap:
        return np.roll(np.roll(a, dy, 0), dx, 1)
    p = np.pad(a, [(1, 1), (1, 1)] + [(0, 0)] * (a.ndim - 2), mode='edge')
    h, w = a.shape[:2]
    return p[1 - dy:1 - dy + h, 1 - dx:1 - dx + w]


def blocky_noise(h, w, cell, seed):
    rng = np.random.default_rng(seed)
    g = rng.random(((h + cell - 1) // cell, (w + cell - 1) // cell))
    return np.repeat(np.repeat(g, cell, 0), cell, 1)[:h, :w]


def _clean(idx, pal, solid, wrap, thr):
    """replace isolated low-contrast texels by their dominant neighbour."""
    nb = [_shift(idx, dy, dx, wrap) for dy, dx in OFFS]
    same = sum((n == idx).astype(np.int32) for n in nb)
    cnt = [sum((nb[k] == nb[j]).astype(np.int32) for j in range(8)) for k in range(8)]
    best = np.argmax(np.stack(cnt), axis=0)
    mode = np.choose(best, nb)
    d = np.abs(pal[idx].astype(int) - pal[mode].astype(int)).sum(-1)
    fix = (same == 0) & (d < thr) & solid
    if not wrap:
        sol = [_shift(solid, dy, dx, False) for dy, dx in OFFS]
        fix &= np.all(np.stack(sol), axis=0)
    out = idx.copy()
    out[fix] = mode[fix]
    return out


def pixel_finish(img, colours=24, jitter=0.06, jitter_cell=2, clean=2, thr=70, seed=7, wrap=False):
    img = img.convert('RGBA')
    a = np.array(img)
    solid = a[..., 3] > 0
    rgb = a[..., :3].astype(float)
    h, w = solid.shape
    if jitter > 0:
        n = blocky_noise(h, w, jitter_cell, seed) - 0.5
        rgb *= (1.0 + jitter * n)[..., None]
    flat = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), 'RGB')
    if not solid.all():
        # palette only from visible texels: fill the rest with a visible colour
        fill = rgb[solid].mean(0) if solid.any() else np.zeros(3)
        f = np.array(flat)
        f[~solid] = fill.astype(np.uint8)
        flat = Image.fromarray(f, 'RGB')
    q = flat.quantize(colours, method=Image.Quantize.MEDIANCUT, kmeans=3, dither=Image.Dither.NONE)
    pal = np.array(q.getpalette()[:colours * 3], np.uint8).reshape(-1, 3)
    idx = np.array(q).astype(np.int32)
    for _ in range(clean):
        idx = _clean(idx, pal, solid, wrap, thr)
    out = a.copy()
    out[..., :3] = pal[idx]
    out[~solid] = 0
    return Image.fromarray(out, 'RGBA')


# art/world_hd atlases: cell size (HD px), colours per cell, tiles wrap?
ATLASES = {
    # facade_wall_tiles_hd is quantised per tile by world_hd.py already; a second
    # pass blurs the low-contrast grout grid of the tiled walls, so it is skipped
    'facade_bands_hd': ((64, 18), 12, True),
    'facade_windows_hd': ((96, 80), 20, False),
    'facade_features_hd': ((128, 96), 24, False),
    'entrance_hd': ((128, 160), 28, False),
    'door_leaf_hd': ((48, 64), 14, False),
    'facade_extras_hd': (None, 40, False),
    'facade_details_hd': ((96, 160), 20, False),
    'roof_details_hd': ((128, 128), 20, False),
    'roof_props_hd': ((128, 128), 20, False),
}
for _s in range(6):
    ATLASES['roof_tile_s%d_hd' % _s] = (None, 20, True)
    ATLASES['roof_edge_h_s%d_hd' % _s] = (None, 14, True)
    ATLASES['roof_edge_v_s%d_hd' % _s] = (None, 14, True)


def finish_atlas(path, cell, colours, wrap):
    im = Image.open(path).convert('RGBA')
    if cell is None:
        out = pixel_finish(im, colours, jitter=0.03, clean=1, wrap=wrap)
    else:
        out = im.copy()
        cw, ch = cell
        for y in range(0, im.height, ch):
            for x in range(0, im.width, cw):
                c = im.crop((x, y, x + cw, y + ch))
                if np.array(c)[..., 3].max() == 0:
                    continue
                out.paste(pixel_finish(c, colours, jitter=0.03, clean=1, wrap=wrap), (x, y))
    out.save(path)


def finish_world_hd(P, names=None):
    d = os.path.join(P, 'art', 'world_hd')
    for name, (cell, colours, wrap) in ATLASES.items():
        if names and name not in names:
            continue
        path = os.path.join(d, name + '.png')
        if os.path.exists(path):
            finish_atlas(path, cell, colours, wrap)
            print('pixel finish', name, flush=True)


if __name__ == '__main__':
    finish_world_hd(sys.argv[1] if len(sys.argv) > 1 else '.', sys.argv[2:] or None)
