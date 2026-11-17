"""Pack the Windows build into downloads/ as 7-Zip volumes.

GitHub refuses files over 100 MB, so the archive is written whole, verified
by extraction, then cut into 90 MB volumes (.7z.001, .7z.002, ...) that
7-Zip and WinRAR open as one archive; the whole file is removed.

    python3 tools/pack_release.py <build_dir> <project_dir>
"""
import glob
import hashlib
import os
import sys
import tempfile

import py7zr

NAME = 'OSTATOK_1_38_0_WIN.7z'
VOLUME = 90_000_000


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def main(build, project):
    out = os.path.join(project, 'downloads')
    whole = os.path.join(out, NAME)
    for old in glob.glob(whole + '*'):
        os.remove(old)
    filters = [{'id': py7zr.FILTER_X86}, {'id': py7zr.FILTER_LZMA2, 'preset': 9 | py7zr.PRESET_EXTREME}]
    with py7zr.SevenZipFile(whole, 'w', filters=filters) as z:
        for n in sorted(os.listdir(build)):
            z.write(os.path.join(build, n), n)
    tmp = tempfile.mkdtemp()
    with py7zr.SevenZipFile(whole) as z:
        z.extractall(tmp)
    for n in os.listdir(build):
        assert sha(os.path.join(build, n)) == sha(os.path.join(tmp, n)), n
    total = os.path.getsize(whole)
    with open(whole, 'rb') as f:
        i = 1
        while True:
            chunk = f.read(VOLUME)
            if not chunk:
                break
            with open('%s.%03d' % (whole, i), 'wb') as v:
                v.write(chunk)
            i += 1
    os.remove(whole)
    print('packed %.2f MB into %d volumes, verified' % (total / 1e6, i - 1))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else '.')
