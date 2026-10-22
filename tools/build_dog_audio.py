#!/usr/bin/env python3
"""Deterministically build the dev73 dog voice (audio/dog/*.wav).

A source-filter voice: a jittered glottal pulse train shaped by a pitch
contour, passed through three formant resonators, with breath noise. A bark is
a short rising-falling burst, a growl a low rough rumble that swells and
pulses, a yelp a high snapped cry, a whine a nasal sliding tone.
"""
from pathlib import Path
import numpy as np
from scipy.signal import lfilter
import soundfile as sf

SR = 44100
OUT = Path(__file__).resolve().parents[1] / 'audio' / 'dog'


def resonator(x, f, bw):
    r = np.exp(-np.pi * bw / SR)
    a = [1.0, -2.0 * r * np.cos(2 * np.pi * f / SR), r * r]
    b = [1.0 - r]
    return lfilter(b, a, x)


def pulses(f0, rng, jitter, rough):
    """A glottal source following the pitch contour f0 (one value a sample)."""
    n = len(f0)
    jit = 1.0 + jitter * np.cumsum(rng.normal(0, 1, n)) / np.sqrt(np.arange(1, n + 1))
    phase = np.cumsum(2 * np.pi * f0 * jit / SR)
    saw = (phase / (2 * np.pi)) % 1.0
    src = (1.0 - saw) ** 3 - 0.25          # a sharp closing pulse
    # subharmonic roughness: every other pulse a little weaker
    sub = 1.0 - rough * (np.floor(phase / (2 * np.pi)) % 2)
    return src * sub


def voice(dur, contour, formants, seed, jitter=0.02, rough=0.2, breath=0.15, env=None):
    rng = np.random.default_rng(seed)
    n = int(SR * dur)
    t = np.arange(n) / SR
    f0 = np.interp(t / dur, np.linspace(0, 1, len(contour)), contour)
    src = pulses(f0, rng, jitter, rough)
    src = src + breath * rng.normal(0, 1, n)
    y = np.zeros(n)
    for f, bw, g in formants:
        y += g * resonator(src, f, bw)
    if env is not None:
        y *= env(t, dur)
    return y


def bark_env(t, dur):
    a = 1.0 - np.exp(-t / 0.006)
    return a * np.exp(-np.maximum(0.0, t - dur * 0.35) / (dur * 0.22))


def norm(y, peak):
    y = y - np.mean(y)
    fade = min(len(y) // 8, 600)
    y[-fade:] *= np.linspace(1, 0, fade)
    return y / max(1e-9, np.max(np.abs(y))) * peak


def bark(seed, f_lo, f_hi, dur):
    y = voice(dur, [f_lo, f_hi, f_hi * 0.92, f_lo * 0.8], [(650, 160, 1.0), (1450, 220, 0.75), (2700, 380, 0.35)],
              seed, jitter=0.03, rough=0.35, breath=0.2, env=bark_env)
    # the 'w' onset: a breathy chuff before the voice
    rng = np.random.default_rng(seed + 7)
    n = len(y)
    chuff = resonator(rng.normal(0, 1, n), 900, 700) * np.exp(-np.arange(n) / SR / 0.018) * 0.6
    return norm(y + chuff, 0.85)


def double_bark(seed):
    a = bark(seed, 360, 520, 0.16)
    b = bark(seed + 1, 330, 470, 0.15)
    gap = np.zeros(int(SR * 0.11))
    return np.concatenate([a, gap, b * 0.85])


def growl(seed, dur):
    rng = np.random.default_rng(seed)
    n = int(SR * dur)
    t = np.arange(n) / SR
    contour = 95 + 14 * np.sin(2 * np.pi * 0.7 * t + rng.uniform(0, 6)) + rng.normal(0, 2, n).cumsum() / 60
    src = pulses(np.clip(contour, 70, 140), rng, 0.08, 0.55) + 0.5 * rng.normal(0, 1, n)
    y = resonator(src, 380, 120) + 0.7 * resonator(src, 900, 200) + 0.25 * resonator(src, 2100, 400)
    # a rumble that swells and pulses with the breath
    am = 0.65 + 0.35 * np.sin(2 * np.pi * 23 * t + rng.uniform(0, 6))
    swell = np.minimum(1.0, t / (dur * 0.3)) * np.minimum(1.0, (dur - t) / (dur * 0.25))
    return norm(y * am * swell, 0.70)


def yelp(seed):
    y = voice(0.2, [950, 1350, 1250, 780], [(1100, 180, 1.0), (2300, 260, 0.6), (3600, 420, 0.25)],
              seed, jitter=0.03, rough=0.25, breath=0.3,
              env=lambda t, d: (1 - np.exp(-t / 0.004)) * np.exp(-np.maximum(0, t - 0.06) / 0.05))
    y2 = voice(0.16, [880, 1150, 700], [(1100, 180, 1.0), (2300, 260, 0.6)], seed + 3, jitter=0.03, rough=0.25,
               breath=0.3, env=lambda t, d: (1 - np.exp(-t / 0.004)) * np.exp(-np.maximum(0, t - 0.04) / 0.05))
    return norm(np.concatenate([y, np.zeros(int(SR * 0.07)), y2 * 0.7]), 0.80)


def whine(seed):
    rng = np.random.default_rng(seed)
    dur = 0.85
    n = int(SR * dur)
    t = np.arange(n) / SR
    f0 = np.interp(t / dur, [0, 0.3, 0.7, 1], [620, 880, 820, 600]) * (1 + 0.02 * np.sin(2 * np.pi * 6 * t))
    src = np.sin(np.cumsum(2 * np.pi * f0 / SR)) + 0.35 * np.sin(np.cumsum(4 * np.pi * f0 / SR))
    src += 0.08 * rng.normal(0, 1, n)
    y = resonator(src, 900, 300) + 0.5 * resonator(src, 1800, 300)
    env = np.minimum(1, t / 0.08) * np.minimum(1, (dur - t) / 0.25)
    return norm(y * env, 0.55)


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    clips = {
        'bark_1.wav': bark(7301, 380, 540, 0.17),
        'bark_2.wav': bark(7303, 340, 500, 0.15),
        'bark_3.wav': double_bark(7305),
        'growl_1.wav': growl(7311, 1.3),
        'growl_2.wav': growl(7313, 1.0),
        'yelp_1.wav': yelp(7321),
        'whine_1.wav': whine(7331),
    }
    for name, y in clips.items():
        sf.write(str(OUT / name), y.astype(np.float32), SR, subtype='PCM_16')
    print('Generated', len(clips), 'dog WAV files in', OUT)


if __name__ == '__main__':
    build()
