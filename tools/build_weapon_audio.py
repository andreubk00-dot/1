#!/usr/bin/env python3
"""Deterministically generate OSTATOK's temporary firearm/reload WAV set.

These are original procedural project assets used during development. 1.29 remains the
final audio/atmosphere pass, but 1.18 weapons must never ship as silent placeholders.
"""
from pathlib import Path
import math, random, struct, wave

SR = 44100
OUT = Path(__file__).resolve().parents[1] / "audio" / "weapons"
OUT.mkdir(parents=True, exist_ok=True)


def _write(name, samples):
    peak = max(1e-9, max(abs(x) for x in samples))
    scale = 0.92 / peak if peak > 0.92 else 1.0
    pcm = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x * scale)) * 32767)) for x in samples)
    with wave.open(str(OUT / name), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SR)
        wav.writeframes(pcm)


def _lowpass(values, alpha):
    result, v = [], 0.0
    for x in values:
        v += alpha * (x - v)
        result.append(v)
    return result


def _highpass(values, alpha=0.985):
    result, prev_x, prev_y = [], 0.0, 0.0
    for x in values:
        y = alpha * (prev_y + x - prev_x)
        result.append(y)
        prev_x, prev_y = x, y
    return result


def gunshot(name, seed, duration, boom, crack, metallic, tail, pitch):
    rng = random.Random(seed)
    count = int(SR * duration)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(count)]
    low = _lowpass(noise, 0.055 + 0.025 * boom)
    high = _highpass(noise, 0.965)
    samples = []
    for i in range(count):
        t = i / SR
        impulse = math.exp(-t * (95.0 - 25.0 * boom))
        body = math.exp(-t * (18.0 - 5.0 * tail))
        room = math.exp(-t * (7.5 - 2.2 * tail))
        bass = math.sin(2.0 * math.pi * (70.0 + 38.0 * pitch) * t) * body * boom
        mid = math.sin(2.0 * math.pi * (170.0 + 95.0 * pitch) * t + 0.4) * body * 0.18
        metal = math.sin(2.0 * math.pi * (1450.0 + 500.0 * pitch) * t) * math.exp(-t * 55.0) * metallic
        value = (
            noise[i] * 0.58 * impulse
            + high[i] * 0.34 * crack * math.exp(-t * 42.0)
            + low[i] * 0.72 * body
            + bass * 0.42
            + mid
            + metal * 0.16
            + low[i] * 0.17 * room
        )
        reflection = int(0.035 * SR)
        if i > reflection:
            value += noise[i - reflection] * 0.05 * math.exp(-(t - 0.035) * 15.0) * tail
        samples.append(value)
    _write(name, samples)


def reload_sound(name, seed, kind):
    rng = random.Random(seed)
    duration = {"pistol": 0.42, "rifle": 0.52, "smg": 0.48, "shell": 0.36, "bolt": 0.55}[kind]
    count = int(SR * duration)
    samples = [0.0] * count

    def click(at, amp, freq, decay=70.0, noise_amp=0.12):
        start = int(at * SR)
        for i in range(start, count):
            t = (i - start) / SR
            if t > 0.10:
                break
            samples[i] += amp * math.sin(2.0 * math.pi * freq * t) * math.exp(-t * decay)
            samples[i] += rng.uniform(-1.0, 1.0) * noise_amp * math.exp(-t * decay * 1.2)

    patterns = {
        "pistol": [(0.02, 0.48, 1800), (0.19, 0.42, 1250), (0.31, 0.58, 2100)],
        "rifle": [(0.02, 0.52, 1150), (0.23, 0.48, 850), (0.40, 0.62, 1500)],
        "smg": [(0.02, 0.50, 1500), (0.18, 0.38, 980), (0.34, 0.62, 1700)],
        "shell": [(0.03, 0.33, 1850), (0.15, 0.50, 1200), (0.27, 0.32, 2300)],
        "bolt": [(0.02, 0.55, 1300), (0.16, 0.42, 850), (0.31, 0.48, 1050), (0.45, 0.65, 1550)],
    }
    for at, amp, freq in patterns[kind]:
        click(at, amp, freq)
    for i in range(count):
        t = i / SR
        samples[i] += rng.uniform(-1.0, 1.0) * 0.018 * math.sin(math.pi * min(1.0, t / duration))
    _write(name, samples)




def cycle_sound(name, seed, kind):
    """Short post-shot mechanical action: pump slide or manual bolt."""
    rng = random.Random(seed)
    duration = 0.32 if kind == "pump" else 0.42
    count = int(SR * duration)
    samples = [0.0] * count

    def click(at, amp, freq, decay):
        start = int(at * SR)
        for i in range(start, min(count, start + int(0.07 * SR))):
            t = (i - start) / SR
            samples[i] += amp * math.sin(2.0 * math.pi * freq * t) * math.exp(-t * decay)
            samples[i] += rng.uniform(-1.0, 1.0) * 0.10 * math.exp(-t * decay * 1.15)

    if kind == "pump":
        clicks = [(0.018,0.62,1800,55),(0.046,0.33,980,55),(0.238,0.72,1450,55),(0.265,0.30,720,50)]
        slide_start, slide_end, slide_amp = 0.025, 0.24, 0.11
    else:
        clicks = [(0.018,0.48,2200,52),(0.075,0.28,1250,50),(0.305,0.62,1700,48),(0.352,0.42,900,46)]
        slide_start, slide_end, slide_amp = 0.055, 0.30, 0.075

    for at, amp, freq, decay in clicks:
        click(at, amp, freq, decay)
    for i in range(count):
        t = i / SR
        if slide_start < t < slide_end:
            x = (t - slide_start) / max(1e-6, slide_end - slide_start)
            envelope = math.sin(math.pi * x) ** 2
            samples[i] += rng.uniform(-1.0, 1.0) * slide_amp * envelope
    _write(name, samples)

SHOTS = {
    "makarov": (101, 0.34, 0.62, 0.82, 0.20, 0.50, 0.62),
    "tt33": (102, 0.36, 0.64, 0.96, 0.24, 0.52, 0.72),
    "pps43": (103, 0.32, 0.58, 0.90, 0.36, 0.42, 0.76),
    "shotgun": (104, 0.52, 1.00, 0.65, 0.12, 0.95, 0.40),
    "toz34": (105, 0.55, 1.05, 0.72, 0.10, 1.00, 0.46),
    "izh81": (106, 0.50, 0.98, 0.70, 0.14, 0.88, 0.43),
    "sks": (107, 0.48, 0.92, 1.00, 0.20, 0.80, 0.66),
    "akm": (108, 0.46, 0.88, 1.04, 0.25, 0.76, 0.72),
    "aks74u": (109, 0.42, 0.72, 1.16, 0.30, 0.60, 0.92),
    "mosin": (110, 0.62, 1.18, 1.10, 0.14, 1.15, 0.58),
}

for weapon_id, params in SHOTS.items():
    gunshot(f"{weapon_id}_shot.wav", *params)
# The existing PM suppressor must change what the player hears, not only AI hearing radius.
gunshot("makarov_suppressed_shot.wav", 111, 0.30, 0.38, 0.18, 0.28, 0.26, 0.55)
# Dry-fire click is intentionally quiet and never emits an AI-hearing event.
def dry_fire():
    rng = random.Random(250)
    duration = 0.12
    count = int(SR * duration)
    samples = []
    for i in range(count):
        t = i / SR
        samples.append(
            0.40 * math.sin(2.0 * math.pi * 1900.0 * t) * math.exp(-t * 95.0)
            + rng.uniform(-1.0, 1.0) * 0.16 * math.exp(-t * 120.0)
        )
    _write("dry_fire.wav", samples)

dry_fire()

for filename, seed, profile in [
    ("pistol_reload.wav", 201, "pistol"),
    ("rifle_reload.wav", 202, "rifle"),
    ("smg_reload.wav", 203, "smg"),
    ("shell_reload.wav", 204, "shell"),
    ("bolt_reload.wav", 205, "bolt"),
]:
    reload_sound(filename, seed, profile)

cycle_sound("pump_cycle.wav", 301, "pump")
cycle_sound("bolt_cycle.wav", 302, "bolt")

print(f"Generated {len(list(OUT.glob('*.wav')))} WAV files in {OUT}")
