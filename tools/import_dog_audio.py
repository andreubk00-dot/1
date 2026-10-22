#!/usr/bin/env python3
"""Build the dog's voice (audio/dog/*.wav) from public-domain (CC0) recordings.

Sources (all CC0 1.0, OpenGameArt; listed in audio/CREDITS_CC0.md) are not
kept in the repository - download them into SRC and run:

    python3 tools/import_dog_audio.py <SRC> <project root>

SRC/dog_barking_mono.wav                 HaelDB, "Dog barking mono"
SRC/x/Dog/Dog 1.wav,
SRC/x/Dog/Sad Dog.wav                    pauliuw, "Dog sounds" (dog.7z unpacked to x/)
SRC/dog-growl.ogg                        bonebrah, "Dog Growl"
SRC/dog-frieda-grunt-96khz-01.flac       qubodup, "Dog grunt"

Each clip is cut from its recording by time (seconds), low rumble and room
hiss trimmed, faded, and levelled to one loudness per kind, as mono 44.1 kHz
16-bit WAV - the names the game already plays.
"""
import os
import sys
import numpy as np
import soundfile as sf
from math import gcd
from scipy.signal import resample_poly, butter, sosfilt

SR = 44100

# name: (file, start, end, kind)
CLIPS = {
    "bark_1": ("dog_barking_mono.wav", 0.00, 0.30, "bark"),
    "bark_2": ("dog_barking_mono.wav", 0.50, 0.78, "bark"),
    "bark_3": ("dog_barking_mono.wav", 1.67, 2.04, "bark"),
    "bark_4": ("dog_barking_mono.wav", 0.00, 0.78, "bark"),     # two in a row
    "growl_1": ("dog-growl.ogg", 0.00, 0.61, "growl"),
    "growl_2": ("dog-frieda-grunt-96khz-01.flac", 0.03, 0.52, "growl"),
    "yelp_1": ("x/Dog/Dog 1.wav", 6.16, 6.56, "yelp"),
    "whine_1": ("x/Dog/Sad Dog.wav", 0.86, 1.58, "whine"),
    "whine_2": ("x/Dog/Sad Dog.wav", 1.72, 2.72, "whine"),
}
# RMS each kind is levelled to, and its peak ceiling
LEVEL = {"bark": (0.20, 0.92), "growl": (0.12, 0.80), "yelp": (0.16, 0.88), "whine": (0.10, 0.70)}
# band kept per kind (Hz)
BAND = {"bark": (110, 9000), "growl": (60, 6000), "yelp": (420, 11000), "whine": (520, 9000)}


def load(path):
    d, sr = sf.read(path, always_2d=True)
    m = d.mean(axis=1)
    if sr != SR:
        g = gcd(SR, sr)
        m = resample_poly(m, SR // g, sr // g)
    return m.astype(np.float64)


def gate(x, floor_frac=0.06):
    # a soft gate over the room noise between and under the sounds
    w = int(0.01 * SR)
    env = np.convolve(np.abs(x), np.ones(w) / w, "same")
    thr = env.max() * floor_frac
    g = np.clip((env - thr * 0.5) / (thr * 0.5 + 1e-9), 0.0, 1.0)
    g = np.convolve(g, np.ones(w) / w, "same")
    return x * (0.12 + 0.88 * g)


def declick(x):
    # stray clicks in the top band are patched over from their neighbours
    hp = sosfilt(butter(4, 4500, btype="high", fs=SR, output="sos"), x)
    a = np.abs(hp)
    w = int(0.02 * SR)
    med = np.convolve(a, np.ones(w) / w, "same")
    hits = np.where(a > 5.0 * med + 1e-4)[0]
    y = x.copy()
    r = int(0.0012 * SR)
    for i in hits:
        lo, hi = max(1, i - r), min(len(x) - 2, i + r)
        y[lo:hi] = np.linspace(y[lo - 1], y[hi + 1], hi - lo)
    return sosfilt(butter(4, 5000, btype="low", fs=SR, output="sos"), y)


def build(src, root):
    out = os.path.join(root, "audio", "dog")
    os.makedirs(out, exist_ok=True)
    cache = {}
    for name, (f, a, b, kind) in CLIPS.items():
        if f not in cache:
            cache[f] = load(os.path.join(src, f))
        x = cache[f][int(a * SR):int(b * SR)].copy()
        lo, hi = BAND[kind]
        # a steep low cut: the "Sad Dog" takes sit on a ~90 Hz recorder buzz
        x = sosfilt(butter(6 if kind in ("whine", "yelp") else 2, [lo, hi], btype="band", fs=SR, output="sos"), x)
        if kind in ("whine", "yelp"):
            x = declick(x)
        if kind != "growl":
            x = gate(x)
        n = len(x)
        fi, fo = int(0.004 * SR), int(min(0.06, n / SR * 0.25) * SR)
        x[:fi] *= np.linspace(0, 1, fi)
        x[n - fo:] *= np.linspace(1, 0, fo) ** 2
        rms, peak = LEVEL[kind]
        x *= rms / max(1e-9, np.sqrt(np.mean(x ** 2)))
        m = np.abs(x).max()
        if m > peak:
            x *= peak / m
        sf.write(os.path.join(out, name + ".wav"), x.astype(np.float32), SR, subtype="PCM_16")
        print("%-8s %.2fs  rms %.3f  peak %.2f" % (name, n / SR, np.sqrt(np.mean(x ** 2)), np.abs(x).max()))


if __name__ == "__main__":
    build(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else ".")
