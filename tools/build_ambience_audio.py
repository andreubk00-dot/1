#!/usr/bin/env python3
"""Deterministically generate OSTATOK 1.29 ambience loops.

Presentation-only original procedural assets. They read existing world/weather state;
no survival or AI values are encoded here.
"""
from pathlib import Path
import math, random, struct, wave
SR=22050
DUR=4.0
N=int(SR*DUR)
OUT=Path(__file__).resolve().parents[1]/"audio"/"ambience"
OUT.mkdir(parents=True,exist_ok=True)

def lp(xs,a):
    out=[]; y=0.0
    for x in xs:
        y += a*(x-y); out.append(y)
    return out

def hp(xs,a=.985):
    out=[]; px=py=0.0
    for x in xs:
        y=a*(py+x-px); out.append(y); px=x; py=y
    return out

def seamless_noise(seed):
    # Blend two deterministic noise windows so the last samples converge to the first.
    rng=random.Random(seed)
    base=[rng.uniform(-1.0,1.0) for _ in range(N)]
    shift=N//2
    out=[]
    for i in range(N):
        x=i/(N-1)
        blend=0.5-0.5*math.cos(2*math.pi*x)
        j=(i+shift)%N
        out.append(base[i]*(1.0-blend)+base[j]*blend)
    return out

def write(name,samples,peak=.55):
    # Short edge crossfade makes the PCM itself loop cleanly even before Godot looping.
    edge=min(int(SR*.08),N//8)
    s=list(samples)
    for i in range(edge):
        t=i/max(1,edge-1)
        a=.5-.5*math.cos(math.pi*t)
        mixed=s[i]*(1-a)+s[N-edge+i]*a
        s[i]=mixed; s[N-edge+i]=mixed
    m=max(1e-9,max(abs(x) for x in s)); scale=peak/m if m>peak else 1.0
    pcm=b''.join(struct.pack('<h',int(max(-1,min(1,x*scale))*32767)) for x in s)
    with wave.open(str(OUT/name),'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm)

def day():
    raw=seamless_noise(6201); wind=lp(raw,.012); air=hp(lp(raw,.045),.997); out=[]
    for i in range(N):
        t=i/SR
        leaf=air[i]*(.12+.04*math.sin(2*math.pi*.17*t))
        distant=.012*math.sin(2*math.pi*1040*t)+.008*math.sin(2*math.pi*1310*t+1.4)
        out.append(wind[i]*.34+leaf+distant)
    write('outdoor_day.wav',out,.42)

def night():
    raw=seamless_noise(6202); air=lp(raw,.018); out=[]
    for i in range(N):
        t=i/SR
        pulse=max(0.0,math.sin(2*math.pi*2.7*t))**10
        cricket=(math.sin(2*math.pi*3260*t)+.55*math.sin(2*math.pi*3810*t))*pulse*.025
        out.append(air[i]*.24+cricket)
    write('outdoor_night.wav',out,.38)

def rain():
    raw=seamless_noise(6203); drops=hp(raw,.94); body=lp(raw,.16); out=[]
    for i in range(N):
        t=i/SR
        gust=.84+.16*math.sin(2*math.pi*.11*t+.6)
        out.append((drops[i]*.32+body[i]*.22)*gust)
    write('rain.wav',out,.50)

def interior():
    raw=seamless_noise(6204); hum=lp(raw,.006); out=[]
    for i in range(N):
        t=i/SR
        room=math.sin(2*math.pi*50*t)*.012 + math.sin(2*math.pi*100*t+.8)*.006
        out.append(hum[i]*.23+room)
    write('interior_roomtone.wav',out,.30)

day(); night(); rain(); interior()
print('Generated',len(list(OUT.glob('*.wav'))),'ambience WAV files in',OUT)
