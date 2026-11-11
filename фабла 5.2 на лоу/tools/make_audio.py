"""Synthesizes every sound of the game with numpy and processes the TTS radio voices."""
import glob, os, wave
import numpy as np

SR = 22050
ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "assets", "snd")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(9)


def save(name, x, peak=0.9):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    w = wave.open(os.path.join(OUT, name + ".wav"), "wb")
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((x * 32767).astype(np.int16).tobytes())
    w.close()


def t(sec):
    return np.arange(int(SR * sec)) / SR


def noise(sec):
    return rng.standard_normal(int(SR * sec))


def band(x, lo, hi):
    f = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    f[(fr < lo) | (fr > hi)] = 0
    return np.fft.irfft(f, len(x))


def shape(x, lo, hi, slope=2.0):
    """soft band: 1/f^slope tilt inside band"""
    f = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    g = np.where((fr >= lo) & (fr <= hi), 1.0 / np.maximum(fr, lo) ** (slope / 2), 0)
    return np.fft.irfft(f * g, len(x))


def env(n, a, d):
    e = np.ones(n)
    na, nd = int(a * SR), int(d * SR)
    if na: e[:na] = np.linspace(0, 1, na)
    if nd: e[-nd:] *= np.linspace(1, 0, nd)
    return e


def decay(sec, k):
    return np.exp(-t(sec) * k)


def loopify(x, fade=0.5):
    n = int(fade * SR)
    a, b = x[:n], x[-n:]
    k = np.linspace(0, 1, n)
    y = x[:-n].copy()
    y[:n] = a * k + b * (1 - k)
    return y


def lfo(sec, rate, depth=1.0):
    x = shape(noise(sec), 0.01, rate, 0)
    x = x / (np.max(np.abs(x)) or 1)
    return 1 + depth * x


def mix(*parts):
    n = max(len(p) for p in parts)
    y = np.zeros(n)
    for p in parts:
        y[:len(p)] += p
    return y


def place(total, items):
    y = np.zeros(int(total * SR))
    for at, x in items:
        i = int(at * SR)
        x = x[:len(y) - i]
        y[i:i + len(x)] += x
    return y


# ---------------- loops
w = shape(noise(14), 60, 1800, 2.4) * lfo(14, 0.5, 0.8) + 0.5 * band(noise(14), 500, 1400) * lfo(14, 0.25, 0.95) ** 2 * 0.02
save("loop_wind", loopify(w, 1.5), 0.8)
w = shape(noise(12), 30, 260, 2.0) * lfo(12, 0.3, 0.7)
save("loop_wind_in", loopify(w, 1.5), 0.6)

tt = t(6)
g = sum(np.sin(2 * np.pi * 46 * k * tt + k) / k for k in range(1, 9))
g *= 1 + 0.35 * np.sign(np.sin(2 * np.pi * 23 * tt))
g += 0.25 * band(noise(6), 800, 3000) * (0.5 + 0.5 * np.sin(2 * np.pi * 23 * tt))
save("loop_gen", loopify(g, 0.3), 0.8)

s = band(noise(5), 300, 5000) * lfo(5, 9, 0.5) + 0.15 * np.sin(2 * np.pi * 1000 * t(5)) * lfo(5, 3, 1)
save("loop_static", loopify(s, 0.3), 0.8)

tt = t(16)
d = sum(np.sin(2 * np.pi * f * tt + rng.uniform(0, 6)) * (1 + 0.5 * np.sin(2 * np.pi * rng.uniform(0.05, 0.2) * tt)) for f in (38, 41.3, 57, 76.5, 113))
d += 0.6 * shape(noise(16), 20, 200, 3) / 30 * 2000
save("loop_drone", loopify(d, 2.0), 0.8)

tt = t(8)
d = sum(np.sin(2 * np.pi * f * tt * (1 + 0.004 * np.sin(2 * np.pi * 0.31 * tt + i))) for i, f in enumerate((220, 233, 311, 329.6, 466)))
d = d * lfo(8, 0.6, 0.5) + 2 * band(noise(8), 2000, 6000) * lfo(8, 0.4, 0.9)
save("loop_tension", loopify(d, 1.0), 0.7)


def thump(f, k=22, sec=0.3):
    tt = t(sec)
    return np.sin(2 * np.pi * f * tt * np.exp(-tt * 6)) * np.exp(-tt * k)


save("loop_heart", place(1.0, [(0.0, thump(60)), (0.26, thump(48) * 0.7)]))

tt = t(4)
b = band(noise(4), 150, 1200) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.5 * tt - 1.5)) ** 2
b *= 1 + 0.9 * np.sign(np.sin(2 * np.pi * 31 * tt))
b += 0.4 * band(noise(4), 2500, 6000) * (rng.random(len(tt)) > 0.997).astype(float).cumsum() % 2
save("loop_breath_m", loopify(b, 0.2), 0.8)

tt = t(5)
tr = sum(np.sin(2 * np.pi * 31 * k * tt) / k for k in range(1, 12)) * (1 + 0.4 * np.sin(2 * np.pi * 15.5 * tt))
tr += 0.3 * band(noise(5), 200, 2000)
save("loop_truck", loopify(tr, 0.3), 0.8)

# ---------------- one-shots
for i in range(4):
    x = shape(noise(0.22), 60, 900, 1.5) * decay(0.22, 26) + thump(70 + 12 * i, 30, 0.22) * 0.02
    save("step_wood%d" % (i + 1), x, 0.7)
    n = noise(0.34)
    x = band(n, 600 + 150 * i, 4500) * env(len(n), 0.03, 0.2) * lfo(0.34, 40, 0.8)
    save("step_snow%d" % (i + 1), x, 0.6)

tt = t(1.3)
creak = np.sin(2 * np.pi * (240 + 90 * np.sin(2 * np.pi * 1.3 * tt) + 40 * tt) * tt) * (1 + 0.7 * np.sign(np.sin(2 * np.pi * 37 * tt)))
creak = band(creak, 200, 3000) * env(len(tt), 0.1, 0.4)
save("door_open", creak, 0.6)
save("door_close", mix(thump(85, 14, 0.5), shape(noise(0.5), 80, 2500, 1.5) * decay(0.5, 16) * 0.05), 0.9)
save("creak", np.concatenate([creak * 0.7, np.zeros(SR // 3), creak[::-1] * 0.5]), 0.5)
bolt = place(0.5, [(0.0, band(noise(0.08), 1200, 6000) * decay(0.08, 50)), (0.14, thump(180, 40, 0.2) + band(noise(0.2), 900, 5000) * decay(0.2, 35))])
save("bolt", bolt, 0.8)
kn = thump(120, 26, 0.3) + shape(noise(0.3), 100, 1500, 1.5) * decay(0.3, 30) * 0.03
save("knock", place(1.9, [(0.0, kn), (0.55, kn * 0.9), (1.1, kn)]), 0.85)
save("knock_slow", place(4.2, [(0.0, kn), (1.4, kn), (2.8, kn)]), 0.85)
bg = thump(55, 9, 0.9) + shape(noise(0.9), 40, 3000, 1.2) * decay(0.9, 9) * 0.06
save("bang", bg, 0.95)
save("bang3", place(2.6, [(0.0, bg), (0.7, bg * 0.9), (1.25, bg)]), 0.95)
save("click", band(noise(0.06), 1500, 7000) * decay(0.06, 80), 0.6)
tt = t(0.9)
save("buzz", np.sign(np.sin(2 * np.pi * 420 * tt)) * (np.sin(2 * np.pi * 3.3 * tt) > -0.2) * env(len(tt), 0.01, 0.05), 0.45)
tt = t(0.18)
save("beep", np.sin(2 * np.pi * 880 * tt) * env(len(tt), 0.01, 0.05), 0.4)
fl = band(noise(0.7), 80, 7000) * (rng.random(int(SR * 0.7)) > 0.6) * np.repeat(rng.random(35) > 0.45, int(SR * 0.7) // 35 + 1)[:int(SR * 0.7)]
save("flicker", fl + 0.3 * np.sin(2 * np.pi * 100 * t(0.7)) * (fl != 0), 0.5)
tt = t(3.2)
ph = np.cumsum(46 * np.exp(-tt * 0.9) + 3) / SR
gd = sum(np.sin(2 * np.pi * k * ph) / k for k in range(1, 8)) * (1 + 0.6 * np.sign(np.sin(2 * np.pi * 0.5 * ph))) * np.exp(-tt * 0.7)
save("gen_die", gd + place(3.2, [(1.4, bg * 0.5), (2.1, bg * 0.3)]), 0.9)
tt = t(3.0)
ph = np.cumsum(np.minimum(46, 8 + 30 * tt ** 1.5)) / SR
gs = sum(np.sin(2 * np.pi * k * ph) / k for k in range(1, 8)) * np.minimum(1, 0.3 + tt / 2)
pull = band(noise(0.5), 300, 3000) * env(int(SR * 0.5), 0.05, 0.3) * lfo(0.5, 60, 0.9)
save("gen_start", mix(gs, pull * 3), 0.9)
save("gen_pull", mix(pull, place(0.9, [(0.45, thump(60, 12, 0.4))])), 0.8)
tt = t(3.0)
pr = band(noise(3.0), 300, 2500) * lfo(3.0, 18, 0.9) * env(len(tt), 0.2, 0.5) + 0.5 * np.sin(2 * np.pi * (300 + 200 * tt) * tt) * lfo(3.0, 25, 1) * 0.3
save("pour", pr, 0.6)
save("breaker", mix(thump(95, 16, 0.5), place(0.5, [(0.0, band(noise(0.1), 1000, 6000) * decay(0.1, 40))])), 0.9)
save("pickup", band(noise(0.25), 500, 4000) * env(int(SR * 0.25), 0.05, 0.15) * lfo(0.25, 30, 0.8), 0.4)
save("paper", band(noise(0.5), 1500, 7000) * env(int(SR * 0.5), 0.1, 0.3) * lfo(0.5, 25, 1.0), 0.35)
save("thud", thump(45, 8, 0.8), 0.95)

# stinger: dissonant brass-like swell + scream
tt = t(2.6)
st = sum(np.sign(np.sin(2 * np.pi * f * tt * (1 + 0.02 * tt))) for f in (116, 123, 174, 185, 277, 293))
st = band(st, 80, 4000) * np.minimum(1, tt * 30) * np.exp(-tt * 1.1)
save("stinger", mix(st, thump(40, 4, 1.2) * 8), 0.95)
tt = t(1.8)
sc = sum(np.sin(2 * np.pi * np.cumsum(f * (1 + 0.25 * np.sin(2 * np.pi * 37 * tt)) + 300 * tt) / SR) for f in (700, 913, 1340, 1777))
sc = sc * (1 + np.sign(np.sin(2 * np.pi * 53 * tt))) + 3 * band(noise(1.8), 800, 8000)
sc = np.tanh(sc * 1.5) * env(len(tt), 0.01, 0.5)
save("scream", sc, 0.98)
tt = t(1.2)
cr = np.sign(np.sin(2 * np.pi * np.cumsum(18 + 30 * tt ** 2) / SR)) * band(noise(1.2), 300, 2600) * env(len(tt), 0.05, 0.3)
save("croak", cr, 0.7)
wh = band(noise(3.0), 1800, 6000) * (0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(2.5, 4) * t(3.0) + np.cumsum(noise(3.0)) * 0.002)) ** 3 * env(int(SR * 3), 0.5, 1.0)
save("whisper", wh, 0.45)
rs = thump(70, 18, 0.35) + shape(noise(0.35), 60, 900, 2) * decay(0.35, 20) * 0.03
save("roofsteps", place(5.0, [(0.0, rs), (0.8, rs * 0.9), (1.5, rs), (2.4, rs * 0.8), (3.0, rs), (3.9, rs * 0.7)]), 0.8)
tt = t(1.0)
ring = (np.sin(2 * np.pi * 1250 * tt) + np.sin(2 * np.pi * 1630 * tt)) * (np.sin(2 * np.pi * 22 * tt) > 0) * env(len(tt), 0.01, 0.05)
save("phone", place(3.2, [(0.0, ring), (1.9, ring)]), 0.45)
tap = band(noise(0.05), 2500, 9000) * decay(0.05, 90)
save("glass_tap", place(2.2, [(0.0, tap), (0.4, tap), (0.8, tap), (1.7, tap)]), 0.5)
tt = t(2.0)
sw = band(noise(2.0), 100, 1500) * (tt / 2.0) ** 3
save("swell", np.concatenate([sw, bg[:SR // 2]]), 0.95)
tk = band(noise(0.03), 2000, 8000) * decay(0.03, 120)
save("ticker", place(1.2, [(i * 0.07 + rng.uniform(0, 0.02), tk) for i in range(16)]), 0.35)
tt = t(2.5)
save("horn", sum(np.sign(np.sin(2 * np.pi * f * tt)) for f in (233, 277)) * env(len(tt), 0.05, 0.3), 0.5)
save("freeze", band(noise(2.0), 3000, 9000) * env(int(SR * 2), 1.0, 0.8) * lfo(2.0, 14, 1), 0.3)
save("drag", shape(noise(3.0), 80, 1200, 1.5) * lfo(3.0, 5, 1.0) * env(int(SR * 3), 0.4, 0.8), 0.6)


# ---------------- voices
def load_wav(p):
    w = wave.open(p, "rb")
    sr, n, ch = w.getframerate(), w.getnframes(), w.getnchannels()
    x = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float64) / 32768
    if ch > 1:
        x = x.reshape(-1, ch).mean(axis=1)
    return np.interp(np.arange(0, len(x), sr / SR), np.arange(len(x)), x)


def stretch(x, k):
    return np.interp(np.arange(0, len(x), k), np.arange(len(x)), x)


def radio(x, hiss=0.05):
    x = np.concatenate([np.zeros(SR // 5), x, np.zeros(SR // 3)])
    y = np.tanh(band(x, 380, 2700) * 9)
    y = y * lfo(len(y) / SR + 0.01, 4, 0.25)[:len(y)]
    y = y + hiss * 6 * band(rng.standard_normal(len(y)), 300, 4000) / 3
    ck = band(noise(0.05), 800, 5000) * decay(0.05, 60) * 1.5
    y[:len(ck)] += ck
    y[-len(ck):] += ck[::-1]
    return y


for p in glob.glob(os.path.join(ROOT, "tools", "voice_raw", "*.wav")):
    name = os.path.splitext(os.path.basename(p))[0]
    x = load_wav(p)
    x = x / (np.max(np.abs(x)) or 1)
    if name.startswith("r_"):
        save("v_" + name, radio(x, 0.04), 0.8)
    else:
        low = stretch(x, 0.80)
        lower = stretch(x, 0.62)
        m = low.copy()
        m[:min(len(m), len(lower))] += 0.55 * lower[:min(len(m), len(lower))]
        tt2 = np.arange(len(m)) / SR
        m = m * (1 + 0.5 * np.sin(2 * np.pi * 63 * tt2))
        d = int(0.11 * SR)
        m[d:] += 0.4 * m[:-d]
        if "door" in name:
            y = shape(np.concatenate([m, np.zeros(SR // 2)]), 80, 900, 1.2)
            save("v_" + name, y, 0.9)
        else:
            y = radio(m, 0.12)
            gate = (lfo(len(y) / SR + 0.01, 7, 1.0)[:len(y)] > 0.45)
            save("v_" + name, y * (0.25 + 0.75 * gate), 0.85)
print("audio ok:", len(os.listdir(OUT)), "files")
