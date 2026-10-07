#!/usr/bin/env python3
"""Deterministically generate OSTATOK's first world-interaction SFX set.

Original procedural project assets, matching the temporary weapon-audio pipeline.
AI hearing/noise values live in gameplay code and are intentionally independent.
"""
from pathlib import Path
import math, random, struct, wave

SR = 44100
OUT = Path(__file__).resolve().parents[1] / "audio" / "world"
OUT.mkdir(parents=True, exist_ok=True)


def write(name, samples, peak_target=0.86):
    peak = max(1e-9, max(abs(x) for x in samples))
    scale = peak_target / peak if peak > peak_target else 1.0
    pcm = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x * scale)) * 32767)) for x in samples)
    with wave.open(str(OUT / name), "wb") as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(SR); wav.writeframes(pcm)


def lowpass(values, alpha):
    out=[]; v=0.0
    for x in values:
        v += alpha*(x-v); out.append(v)
    return out


def highpass(values, alpha=0.97):
    out=[]; px=0.0; py=0.0
    for x in values:
        y=alpha*(py+x-px); out.append(y); px=x; py=y
    return out


def footstep(name, seed, duration, strength, grit):
    rng=random.Random(seed); n=int(SR*duration)
    raw=[rng.uniform(-1,1) for _ in range(n)]
    low=lowpass(raw,0.07); hi=highpass(raw,0.965)
    s=[]
    for i in range(n):
        t=i/SR
        thump=math.sin(2*math.pi*88*t)*math.exp(-t*30)*0.52*strength
        sole=low[i]*math.exp(-t*24)*0.78*strength
        scrape=hi[i]*math.exp(-t*34)*0.20*grit
        s.append(thump+sole+scrape)
    write(name,s,0.76)


def door(name, seed, opening):
    rng=random.Random(seed); duration=0.38 if opening else 0.30; n=int(SR*duration)
    raw=[rng.uniform(-1,1) for _ in range(n)]; band=lowpass(highpass(raw,0.985),0.16)
    s=[]
    for i in range(n):
        t=i/SR; x=t/duration
        creak_freq=(150+260*x) if opening else (330-190*x)
        creak=math.sin(2*math.pi*creak_freq*t+0.35*math.sin(t*29))*math.sin(math.pi*x)**2*0.22
        scrape=band[i]*math.sin(math.pi*x)**2*0.25
        latch_t=0.035 if opening else duration-0.075
        dt=max(0,t-latch_t)
        latch=(math.sin(2*math.pi*1650*dt)*math.exp(-dt*75)*0.42 if t>=latch_t else 0)
        s.append(creak+scrape+latch)
    write(name,s,0.72)


def impact(name, seed, kind):
    rng=random.Random(seed)
    duration={"drop":0.22,"melee_hit":0.19,"workbench":0.46}[kind]; n=int(SR*duration)
    s=[0.0]*n
    def hit(at, amp, freq, decay, noise=0.14):
        start=int(at*SR)
        for i in range(start,min(n,start+int(0.12*SR))):
            t=(i-start)/SR
            s[i]+=amp*math.sin(2*math.pi*freq*t)*math.exp(-t*decay)
            s[i]+=rng.uniform(-1,1)*noise*math.exp(-t*decay*1.15)
    if kind=="drop":
        hit(0.008,0.62,115,38,0.20); hit(0.042,0.32,980,64,0.12)
    elif kind=="melee_hit":
        hit(0.004,0.70,105,34,0.23); hit(0.025,0.42,1350,70,0.16)
    else:
        for at,amp,freq in [(0.02,0.42,1150),(0.15,0.58,720),(0.29,0.46,1550),(0.39,0.36,920)]:
            hit(at,amp,freq,62,0.11)
    write(name,s,0.78)


def swing():
    rng=random.Random(405); duration=0.22; n=int(SR*duration)
    raw=highpass([rng.uniform(-1,1) for _ in range(n)],0.98); s=[]
    for i in range(n):
        t=i/SR; x=t/duration
        env=math.sin(math.pi*x)**2
        s.append(raw[i]*env*0.27 + math.sin(2*math.pi*(330+520*x)*t)*env*0.07)
    write("melee_swing.wav",s,0.58)

footstep("footstep_walk.wav",401,0.18,0.78,0.65)
footstep("footstep_sprint.wav",402,0.21,1.00,0.82)
door("door_open.wav",403,True)
door("door_close.wav",404,False)
swing()
impact("melee_hit.wav",406,"melee_hit")
impact("item_drop.wav",407,"drop")
impact("workbench.wav",408,"workbench")
print(f"Generated {len(list(OUT.glob('*.wav')))} world WAV files in {OUT}")
