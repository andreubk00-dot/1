#!/usr/bin/env python3
"""Package the Yandex Games build: index.html and 13 local audio tracks only."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import re, sys
root=Path(__file__).resolve().parents[1]
html=(root/'index.html').read_text(encoding='utf-8')
assert '<script src="/sdk.js"></script>' in html, 'Missing Yandex SDK'
assert 'window.ED_YANDEX_BUILD=true' in html
assert 'out.version=21' in html, 'Unexpected save migration'
assert 'onRewarded:' in html and 'showRewardedVideo' in html
assert 'v1.8.20' in html
assert 'onrender.com/' not in html, 'External links must not be present'
audio=sorted((root/'audio').glob('*.ogg'))
assert len(audio)==13,f'Expected 13 audio files, got {len(audio)}'
# Literal local sample paths must resolve before publishing.
for path in set(re.findall(r"audio/[a-zA-Z0-9_-]+\\.ogg",html)):
    assert (root/path).is_file(), f'Missing local audio {path}'
dist=root/'dist';dist.mkdir(exist_ok=True)
name=dist/'endless-defenders-yandex-v1.8.20.zip'
with ZipFile(name,'w',compression=ZIP_DEFLATED,compresslevel=7) as z:
    z.write(root/'index.html','index.html')
    for file in audio:z.write(file,'audio/'+file.name)
with ZipFile(name) as z:
    assert z.testzip() is None
    assert len(z.namelist())==14
    assert z.namelist()[0]=='index.html'
print('OK: '+str(name)+'; 1 HTML + '+str(len(audio))+' audio files; bytes='+str(name.stat().st_size))
