"""Parse _world_prop_region() from main_script_mod.gd -> {kind: (x,y,w,h)}."""
import re
def load(path):
    s = open(path, encoding='utf-8').read()
    a = s.index('func _world_prop_region(kind):')
    b = s.index('\nfunc ', a + 10)
    body = s[a:b]
    out = {}
    for kinds, rect in re.findall(r'((?:"[a-z_0-9]+",?\s*)+):\s*\n?\s*return Rect2\((\d+),(\d+),(\d+),(\d+)\)', body):
        pass
    cur = []
    for line in body.splitlines():
        ks = re.findall(r'"([a-z_0-9]+)"', line)
        m = re.search(r'Rect2\((\d+),\s*(\d+),\s*(\d+),\s*(\d+)\)', line)
        if ks and line.strip().endswith(':'):
            cur = ks
        if m and cur:
            for k in cur:
                out[k] = tuple(int(v) for v in m.groups())
            cur = []
        elif ks and m:
            for k in ks:
                out[k] = tuple(int(v) for v in m.groups())
    return out
