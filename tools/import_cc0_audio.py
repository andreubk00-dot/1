"""Build the game's sound set from public-domain (CC0) recordings.

Every source is CC0 1.0 (no rights reserved, no attribution required); the
list with authors and pages is in audio/CREDITS_CC0.md. Sources are not kept
in the repository - download them (see the credits) into SRC with the layout
below and run:

    python3 tools/import_cc0_audio.py <SRC> <project root>

SRC/ffsl/Prepared SFX Library/...   The Free Firearm Sound Library (OGA)
SRC/oga/<opengameart slug>/...      OpenGameArt packs, archives unpacked to x/
SRC/music/...                       OpenGameArt CC0 music tracks

Output keeps the game's existing names and format (mono, 44.1 kHz, 16-bit
WAV) so the code paths stay the same; music is OGG Vorbis.
"""
import os
import sys
import glob
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly, butter, sosfilt

SR = 44100


def load(path):
    d, sr = sf.read(path, always_2d=True)
    m = d.mean(axis=1)
    if sr != SR:
        from math import gcd
        g = gcd(SR, sr)
        m = resample_poly(m, SR // g, sr // g)
    return m.astype(np.float64)


def onset(x, frac=0.12):
    a = np.abs(x)
    i = int(np.argmax(a > a.max() * frac))
    return max(0, i - int(0.004 * SR))


def segment(x, start, length):
    s = int(start)
    return x[s:s + int(length * SR)].copy()


def fade(x, fade_in=0.002, tail=0.45, shape=3.0):
    n = len(x)
    fi = max(1, int(fade_in * SR))
    x[:fi] *= np.linspace(0.0, 1.0, fi)
    ft = max(1, int(n * tail))
    x[n - ft:] *= np.linspace(1.0, 0.0, ft) ** shape
    return x


def norm(x, peak):
    m = np.abs(x).max()
    return x * (peak / m) if m > 0 else x


def at_db(x, db):
    # set the bed's RMS level (the old synthesized beds were mixed around these)
    r = np.sqrt(np.mean(x * x))
    return x * (10 ** (db / 20.0) / r) if r > 0 else x


def lowpass(x, hz, order=4):
    return sosfilt(butter(order, hz, 'low', fs=SR, output='sos'), x)


def highpass(x, hz, order=2):
    return sosfilt(butter(order, hz, 'high', fs=SR, output='sos'), x)


def save(x, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sf.write(path, np.clip(x, -1.0, 1.0), SR, subtype='PCM_16')
    print('%-52s %.2fs' % (os.path.relpath(path, ROOT), len(x) / SR))


def loudest(x, length, hop=0.02):
    # start of the loudest window of the given length (for moans, creaks)
    w = int(length * SR)
    e = np.convolve(x * x, np.ones(w), 'valid')[::int(hop * SR)]
    return int(np.argmax(e)) * int(hop * SR)


def split_hits(x, min_gap=0.12, frac=0.18, length=0.32):
    # slice a take with several footsteps into single steps
    env = np.convolve(np.abs(x), np.ones(int(0.01 * SR)) / (0.01 * SR), 'same')
    thr = env.max() * frac
    hits, last = [], -10 ** 9
    for i in np.flatnonzero((env[1:] >= thr) & (env[:-1] < thr)):
        if i - last > min_gap * SR:
            hits.append(i)
            last = i
    return [segment(x, max(0, h - int(0.006 * SR)), length) for h in hits]


SRC = sys.argv[1]
ROOT = sys.argv[2] if len(sys.argv) > 2 else '.'
FF = os.path.join(SRC, 'ffsl', 'Prepared SFX Library')
OGA = os.path.join(SRC, 'oga')
W = os.path.join(ROOT, 'audio', 'weapons')

# --- gunshots: the near-distance take of the closest real firearm -----------
SHOTS = {
    # game id      library folder / take      tail (s)
    'makarov':  ('Walther PPQ/X_39P.wav', 0.85),   # 9 mm pistol
    'tt33':     ('1911/A_42P.wav', 0.95),          # heavier service pistol
    'pps43':    ('PPSh/P_30P.wav', 0.75),          # 7.62x25 Tokarev SMG
    'akm':      ('AK-47/C_28P.wav', 1.25),         # 7.62x39
    'aks74u':   ('AR-15/D_32P.wav', 1.10),         # small-calibre carbine
    'sks':      ('SKS/U_14P.wav', 1.25),           # 7.62x39 carbine
    'mosin':    ('Mosin Nagant/M_21P.wav', 1.55),  # 7.62x54R
    'shotgun':  ('Nova/O_21P.wav', 1.35),          # 12 ga pump
    'izh81':    ('CD/H_21P.wav', 1.35),            # 12 ga pump
    'toz34':    ('Model 12/K_22P.wav', 1.45),      # 12 ga, heavier report
}
def punch(x, target_db=-17.5, peak=0.92):
    # a recorded report is one sharp spike and a quiet body; a soft tanh
    # saturation lifts the body until the first 0.2 s sit as loud as the old
    # synthesized shots did (otherwise every gun reads ~3 dB quieter in game)
    head = int(0.2 * SR)
    y = norm(x, peak)
    for k in np.arange(1.0, 8.01, 0.25):
        y = norm(np.tanh(k * norm(x, 1.0)), peak)
        if 20 * np.log10(np.sqrt(np.mean(y[:head] ** 2))) >= target_db:
            break
    return y


for wid, (take, tail) in SHOTS.items():
    x = load(os.path.join(FF, take))
    x = segment(x, onset(x), tail)
    x = highpass(x, 40)
    save(punch(fade(x, tail=0.6, shape=2.4)), os.path.join(W, '%s_shot.wav' % wid))

# suppressed PM: the same pistol, the crack filtered off and the report short
x = load(os.path.join(FF, 'Walther PPQ/X_31P.wav'))
x = segment(x, onset(x), 0.42)
x = lowpass(highpass(x, 120), 1500)
save(norm(fade(x, tail=0.7, shape=2.8), 0.62), os.path.join(W, 'makarov_suppressed_shot.wav'))

# --- reloads and actions ----------------------------------------------------
def take(rel, start=None, length=None, peak=0.7, tail=0.25):
    x = load(os.path.join(OGA, rel))
    s = onset(x, 0.08) if start is None else int(start * SR)
    x = segment(x, s, length if length else len(x) / SR)
    return norm(fade(x, tail=tail, shape=2.0), peak)

save(take('handgun-reload-sound-effect/reload.wav', peak=0.7), os.path.join(W, 'pistol_reload.wav'))
save(take('gun-reload-sounds/assaultriflereload1_0.wav', peak=0.7), os.path.join(W, 'rifle_reload.wav'))
save(take('2-gun-reloads/x/gun_reload.1.ogg', peak=0.7), os.path.join(W, 'smg_reload.wav'))
save(take('shotgun-reload-sound-effects/x/ShotgunSounds/Shell in Chamber.mp3', length=1.2, peak=0.7), os.path.join(W, 'shell_reload.wav'))
save(take('gun-reload-sounds/gunreload1.wav', peak=0.7), os.path.join(W, 'bolt_reload.wav'))
save(take('shotgun-reload-sound-effects/x/ShotgunSounds/Rack.mp3', length=0.9, peak=0.75), os.path.join(W, 'pump_cycle.wav'))
save(take('gun-reload-sounds/shotguncock_0.wav', peak=0.72), os.path.join(W, 'bolt_cycle.wav'))
save(take('gun-reload-sound-effects/clipload2.wav', length=0.12, peak=0.55, tail=0.5), os.path.join(W, 'dry_fire.wav'))

# --- footsteps by surface ---------------------------------------------------
STEPS = os.path.join(ROOT, 'audio', 'world', 'steps')
FZ = os.path.join(OGA, 'fantozzis-footsteps-grasssand-stone/x/Fantozzi-footsteps/ogg')
KDD = os.path.join(OGA, 'different-steps-on-wood-stone-leaves-gravel-and-mud/x')


def step(x, length=0.30, peak=0.6):
    x = segment(x, onset(x, 0.1), length)
    return norm(fade(highpass(x, 60), tail=0.55, shape=2.2), peak)

for i, f in enumerate(sorted(glob.glob(os.path.join(FZ, 'Fantozzi-Stone*.ogg')))):
    save(step(load(f)), os.path.join(STEPS, 'stone_%d.wav' % (i + 1)))
for i, f in enumerate(sorted(glob.glob(os.path.join(FZ, 'Fantozzi-Sand*.ogg')))):
    save(step(load(f), peak=0.5), os.path.join(STEPS, 'grass_%d.wav' % (i + 1)))
for i, f in enumerate(sorted(glob.glob(os.path.join(KDD, 'wood0*.ogg')))):
    save(step(load(f), length=0.24, peak=0.55), os.path.join(STEPS, 'wood_%d.wav' % (i + 1)))
gravel = sorted(glob.glob(os.path.join(OGA, '42-snow-and-gravel-footsteps/x/*/*gravel_0*.flac')))[:6]
for i, f in enumerate(gravel):
    save(step(load(f), length=0.34, peak=0.55), os.path.join(STEPS, 'gravel_%d.wav' % (i + 1)))
# the generic walk / sprint steps (kept for anything that asks for them)
save(step(load(os.path.join(FZ, 'Fantozzi-StoneL1.ogg')), peak=0.6), os.path.join(ROOT, 'audio/world/footstep_walk.wav'))
save(step(load(os.path.join(FZ, 'Fantozzi-StoneR2.ogg')), length=0.26, peak=0.7), os.path.join(ROOT, 'audio/world/footstep_sprint.wav'))

# --- doors (the world-sfx budget is 0.16 - 0.50 s) ---------------------------
DS = os.path.join(OGA, 'door-open-door-close-set/x/qubodup-DoorSet/ogg')
save(take(os.path.join(DS, 'qubodup-DoorOpen01.ogg'), length=0.48, peak=0.6, tail=0.45), os.path.join(ROOT, 'audio/world/door_open.wav'))
save(take(os.path.join(DS, 'qubodup-DoorClose04.ogg'), length=0.45, peak=0.65, tail=0.5), os.path.join(ROOT, 'audio/world/door_close.wav'))

# --- infected (0.20 - 0.90 s) -----------------------------------------------
moan = load(os.path.join(OGA, 'zombie-moans/darsycho__zombie-moans_0.ogg'))
x = segment(moan, loudest(moan, 0.82), 0.82)
save(norm(fade(x, fade_in=0.03, tail=0.4, shape=1.6), 0.8), os.path.join(ROOT, 'audio/infected/infected_call.wav'))
x = load(os.path.join(OGA, 'zombie-noises-and-moans/x/fastzombie1.ogg'))
save(norm(fade(segment(x, onset(x), 0.34), tail=0.35), 0.8), os.path.join(ROOT, 'audio/infected/infected_attack.wav'))
pain = load(os.path.join(OGA, 'zombie-pain/zombie_pain.wav'))
x = segment(pain, onset(pain), 0.30)
save(norm(fade(x, tail=0.45, shape=1.8), 0.75), os.path.join(ROOT, 'audio/infected/infected_hurt.wav'))
x = load(os.path.join(OGA, 'zombie-noises-and-moans/x/zombienoise3.ogg'))
x = segment(x, onset(x), 0.62)
save(norm(fade(x, tail=0.5, shape=1.8), 0.8), os.path.join(ROOT, 'audio/infected/infected_death.wav'))

# --- rain bed: a 4 s seamless loop (crossfaded) ------------------------------
rain = load(os.path.join(OGA, 'amb-rain-loop-1/amb_rain_loop_1.wav'))
n, xf = 4 * SR, int(0.5 * SR)
a = rain[10 * SR:10 * SR + n + xf].copy()
loop = a[:n].copy()
r = np.linspace(0.0, 1.0, xf)
loop[:xf] = a[:xf] * r + a[n:n + xf] * (1.0 - r)
save(at_db(loop, -18.0), os.path.join(ROOT, 'audio/ambience/rain.wav'))

# --- music: CC0 tracks, re-encoded to OGG Vorbis ----------------------------
MUSIC = os.path.join(ROOT, 'audio', 'music')
os.makedirs(MUSIC, exist_ok=True)
TRACKS = {
    'empty_city.ogg': 'EmptyCity.ogg',
    'contemplation.ogg': 'Contemplation.mp3',
    'long_winter.ogg': 'Long Winter.mp3',
    'end_of_hope.ogg': 'at the end of hope.mp3',
    'the_plague.ogg': 'The Plague.mp3',
    'tragic_ambient.ogg': 'ambientmain_0.ogg',
    'cold_silence.ogg': 'cold_silence.ogg',
}
for out, src in TRACKS.items():
    if os.path.exists(os.path.join(MUSIC, out)):
        continue                      # Vorbis output is not bit-stable: keep the committed one
    d, sr = sf.read(os.path.join(SRC, 'music', src), always_2d=True)
    d = d / max(1e-9, np.sqrt(np.mean(d * d))) * 0.12     # even loudness across tracks
    peak = np.abs(d).max()
    if peak > 0.95:
        d *= 0.95 / peak
    # libsndfile's Vorbis encoder crashes on one huge write: feed it in blocks
    with sf.SoundFile(os.path.join(MUSIC, out), 'w', sr, d.shape[1], format='OGG', subtype='VORBIS', compression_level=0.55) as f:
        for i in range(0, len(d), 16384):
            f.write(d[i:i + 16384])
    print('%-52s %.0fs' % (os.path.relpath(os.path.join(MUSIC, out), ROOT), len(d) / sr))

# --- Kenney packs (CC0): interface, impacts, extra footsteps -----------------
KN = os.path.join(SRC, 'kenney')
KI = os.path.join(KN, 'kenney_interface-sounds', 'Audio')
KR = os.path.join(KN, 'kenney_rpg-audio', 'Audio')
KP = os.path.join(KN, 'kenney_impact-sounds', 'Audio')


def clip(path, length, peak, min_len=0.0, tail=0.4, hp=0.0):
    x = load(path)
    x = segment(x, onset(x, 0.06), length)
    if hp:
        x = highpass(x, hp)
    if len(x) < int(min_len * SR):
        x = np.concatenate([x, np.zeros(int(min_len * SR) - len(x))])
    return norm(fade(x, tail=tail, shape=2.0), peak)

# UI (0.10 - 0.20 s)
save(clip(os.path.join(KI, 'open_001.ogg'), 0.15, 0.32, 0.12), os.path.join(ROOT, 'audio/ui/ui_open.wav'))
save(clip(os.path.join(KI, 'close_001.ogg'), 0.15, 0.32, 0.12), os.path.join(ROOT, 'audio/ui/ui_close.wav'))
save(clip(os.path.join(KI, 'confirmation_001.ogg'), 0.19, 0.32, 0.12), os.path.join(ROOT, 'audio/ui/ui_confirm.wav'))
# hand-to-hand and handling (world budget 0.16 - 0.50 s)
save(clip(os.path.join(KR, 'knifeSlice.ogg'), 0.30, 0.45, 0.18), os.path.join(ROOT, 'audio/world/melee_swing.wav'))
save(clip(os.path.join(KP, 'impactPunch_heavy_000.ogg'), 0.30, 0.8, 0.18), os.path.join(ROOT, 'audio/world/melee_hit.wav'))
save(clip(os.path.join(KR, 'dropLeather.ogg'), 0.30, 0.6, 0.18), os.path.join(ROOT, 'audio/world/item_drop.wav'))
x = np.concatenate([clip(os.path.join(KP, 'impactMetal_medium_000.ogg'), 0.20, 0.6), np.zeros(int(0.04 * SR)),
                    clip(os.path.join(KP, 'impactMetal_light_002.ogg'), 0.18, 0.45)])
save(x, os.path.join(ROOT, 'audio/world/workbench.wav'))
# a blow landing on the player (infected budget 0.20 - 0.90 s)
save(clip(os.path.join(KP, 'impactPunch_medium_001.ogg'), 0.28, 0.75, 0.22), os.path.join(ROOT, 'audio/infected/player_hit.wav'))
save(clip(os.path.join(KP, 'impactSoft_heavy_002.ogg'), 0.26, 0.65, 0.22), os.path.join(ROOT, 'audio/infected/spit_hit.wav'))

# more footstep takes for variety (appended after the OpenGameArt ones)
EXTRA = {'stone': 'footstep_concrete', 'wood': 'footstep_wood', 'grass': 'footstep_grass'}
START = {'stone': 7, 'wood': 4, 'grass': 7}
for surf, stem in EXTRA.items():
    for i in range(5):
        x = load(os.path.join(KP, '%s_%03d.ogg' % (stem, i)))
        save(step(x, length=0.26, peak=0.55), os.path.join(STEPS, '%s_%d.wav' % (surf, START[surf] + i)))

# --- ambience beds: 4 s seamless loops (crossfaded) --------------------------
def loop4(x, at, peak, lp=0.0):
    n, xf = 4 * SR, int(0.6 * SR)
    a = x[int(at * SR):int(at * SR) + n + xf].copy()
    if lp:
        a = lowpass(a, lp)
    out = a[:n].copy()
    r = np.linspace(0.0, 1.0, xf)
    out[:xf] = a[:xf] * r + a[n:n + xf] * (1.0 - r)
    return norm(out, peak)

amb = os.path.join(SRC, 'oga')
day = load(os.path.join(amb, 'amb-outside-1/amb_outdoor1_loop.wav'))
save(at_db(loop4(highpass(day, 50), 6.0, 0.22), -32.0), os.path.join(ROOT, 'audio/ambience/outdoor_day.wav'))
crickets = load(os.path.join(amb, 'crickets-ambient-noise-loopable/crickets_1.mp3'))
wind = load(os.path.join(amb, 'mild-wind-background-noise/wind background noise 2.wav'))
n = min(len(crickets), len(wind))
night = norm(crickets[:n], 1.0) * 0.55 + norm(lowpass(wind[:n], 900), 1.0) * 0.45
save(at_db(loop4(night, 3.0, 0.16), -36.5), os.path.join(ROOT, 'audio/ambience/outdoor_night.wav'))
# indoors: the same wind through walls - low, muffled, close to silence
save(at_db(loop4(wind, 12.0, 0.07, lp=320), -38.5), os.path.join(ROOT, 'audio/ambience/interior_roomtone.wav'))
