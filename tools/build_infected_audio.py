#!/usr/bin/env python3
"""Deterministically build OSTATOK 1.29 infected/combat presentation SFX."""
from pathlib import Path
import math, random, struct, wave
SR=44100
OUT=Path(__file__).resolve().parents[1]/'audio'/'infected'; OUT.mkdir(parents=True,exist_ok=True)
def write(name,samples,peak=0.82):
    m=max(1e-9,max(abs(x) for x in samples)); sc=peak/m if m>peak else 1.0
    pcm=b''.join(struct.pack('<h',int(max(-1,min(1,x*sc))*32767)) for x in samples)
    with wave.open(str(OUT/name),'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm)
def lp(xs,a=.08):
    o=[]; y=0.0
    for x in xs: y+=a*(x-y); o.append(y)
    return o
def hp(xs,a=.975):
    o=[]; px=py=0.0
    for x in xs:
        y=a*(py+x-px); o.append(y); px=x; py=y
    return o
def vocal(name,seed,dur,f0,f1,rough=.20,amp=.46):
    rng=random.Random(seed); n=int(SR*dur); noise=lp([rng.uniform(-1,1) for _ in range(n)],.12); out=[]; phase=0.0
    for i in range(n):
        t=i/SR; x=t/dur; f=f0+(f1-f0)*x+18*math.sin(2*math.pi*3.1*t)
        phase += 2*math.pi*f/SR
        env=(1-math.exp(-t*30))*math.exp(-max(0,t-dur*.62)*8.5)
        throat=(math.sin(phase)+.38*math.sin(phase*2.03)+.17*math.sin(phase*.51))*amp
        out.append((throat+noise[i]*rough)*env)
    write(name,out)
def impact(name,seed,dur,body,metal=.0):
    rng=random.Random(seed); n=int(SR*dur); noise=hp([rng.uniform(-1,1) for _ in range(n)],.965); out=[]
    for i in range(n):
        t=i/SR
        low=math.sin(2*math.pi*body*t)*math.exp(-t*24)*.58
        crack=noise[i]*math.exp(-t*42)*.22
        ring=(math.sin(2*math.pi*1150*t)*math.exp(-t*62)*metal)
        out.append(low+crack+ring)
    write(name,out)
def spit():
    rng=random.Random(5106); dur=.38; n=int(SR*dur); raw=lp([rng.uniform(-1,1) for _ in range(n)],.18); out=[]
    for i in range(n):
        t=i/SR; x=t/dur; env=math.sin(math.pi*x)**1.5
        wet=raw[i]*env*.34; whistle=math.sin(2*math.pi*(460+620*x)*t)*env*.08
        out.append(wet+whistle)
    write('infected_spit.wav',out,.62)
vocal('infected_attack.wav',5101,.34,118,82,.24,.48)
vocal('infected_hurt.wav',5102,.26,155,104,.27,.42)
vocal('infected_death.wav',5103,.56,132,48,.30,.52)
vocal('infected_call.wav',5104,.82,178,92,.28,.56)
impact('player_hit.wav',5105,.24,92,.14)
spit()
impact('spit_hit.wav',5107,.26,74,.04)
print('Generated',len(list(OUT.glob('*.wav'))),'infected/combat WAV files in',OUT)
