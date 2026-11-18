"""OSTATOK 1.66: sounds of the High Risk hazards, synthesised (CC0, own work).

    python3 tools/hazard_sfx_v1.py <project_dir>

Writes audio/world/hazards/: explosion.wav (a tripwire grenade: crack, low
boom, debris), click.wav (the pin coming out), steam.wav (a valve venting),
hiss.wav (the warning puff), beep.wav (an old motion sensor), gas.wav (a
slow leak).
"""
import os
import sys
import wave

import numpy as np

SR = 22050


def write(path, x):
    x = np.clip(x / max(1e-6, np.abs(x).max()) * 0.9, -1, 1)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def lowpass(x, a):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def build(P):
    rng = np.random.default_rng(166)
    out = os.path.join(P, 'audio', 'world', 'hazards')
    os.makedirs(out, exist_ok=True)
    t = np.arange(int(SR * 2.2)) / SR
    noise = rng.standard_normal(t.size)
    crack = noise * np.exp(-t * 60)
    boom = lowpass(noise, 0.02) * np.exp(-t * 2.6) * 6
    sub = np.sin(2 * np.pi * (48 - 18 * t) * t) * np.exp(-t * 3.5) * 0.8
    debris = lowpass(noise, 0.3) * (np.exp(-((t - 0.5) ** 2) / 0.08)) * 0.25
    write(os.path.join(out, 'explosion.wav'), crack + boom + sub + debris)
    t = np.arange(int(SR * 0.12)) / SR
    write(os.path.join(out, 'click.wav'), rng.standard_normal(t.size) * np.exp(-t * 90) + np.sin(2 * np.pi * 2400 * t) * np.exp(-t * 70) * 0.6)
    t = np.arange(int(SR * 1.6)) / SR
    env = np.minimum(1, t * 20) * np.exp(-np.maximum(0, t - 0.9) * 4)
    n = rng.standard_normal(t.size)
    write(os.path.join(out, 'steam.wav'), (n - lowpass(n, 0.25)) * env)
    t = np.arange(int(SR * 0.45)) / SR
    n = rng.standard_normal(t.size)
    write(os.path.join(out, 'hiss.wav'), (n - lowpass(n, 0.4)) * np.sin(np.pi * t / t[-1]) * 0.5)
    t = np.arange(int(SR * 0.5)) / SR
    gate = ((t * 8) % 1 < 0.5).astype(float)
    write(os.path.join(out, 'beep.wav'), np.sign(np.sin(2 * np.pi * 1320 * t)) * gate * 0.4)
    t = np.arange(int(SR * 2.0)) / SR
    n = rng.standard_normal(t.size)
    write(os.path.join(out, 'gas.wav'), (lowpass(n, 0.18) - lowpass(n, 0.04)) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.7 * t)))
    print('hazard sounds written')


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
