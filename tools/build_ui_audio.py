#!/usr/bin/env python3
"""Deterministically generate OSTATOK 1.29 UI feedback SFX."""
from pathlib import Path
import math, random, struct, wave
SR=44100
OUT=Path(__file__).resolve().parents[1]/'audio'/'ui'; OUT.mkdir(parents=True,exist_ok=True)
def write(name,samples,peak=.52):
    m=max(1e-9,max(abs(x) for x in samples)); sc=peak/m if m>peak else 1.0
    pcm=b''.join(struct.pack('<h',int(max(-1,min(1,x*sc))*32767)) for x in samples)
    with wave.open(str(OUT/name),'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm)
def tone(name,dur,f0,f1,seed,noise=.025):
    rng=random.Random(seed); n=int(SR*dur); out=[]; phase=0.0
    for i in range(n):
        t=i/SR; x=t/dur; f=f0+(f1-f0)*x; phase+=2*math.pi*f/SR
        env=(1-math.exp(-t*70))*math.exp(-max(0,t-dur*.42)*28)
        click=rng.uniform(-1,1)*noise*math.exp(-t*85)
        out.append((math.sin(phase)+.25*math.sin(phase*2.01))*.26*env+click)
    write(name,out)
tone('ui_open.wav',.14,420,690,7301,.030)
tone('ui_close.wav',.12,620,360,7302,.028)
tone('ui_confirm.wav',.17,520,880,7303,.022)
print('Generated',len(list(OUT.glob('*.wav'))),'UI WAV files in',OUT)
