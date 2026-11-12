"""Синтез всех звуков и музыки игры (numpy + scipy) → snd/*.ogg через ffmpeg.

    python tools/audio/make_audio.py           — всё
    python tools/audio/make_audio.py step_tile — только звуки, чьё имя начинается так
Петли называются loop_*, музыка mus_*. Варианты одного звука: name_1, name_2…
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "snd")
SR = 44100
rng = np.random.default_rng(1961)
ONLY = sys.argv[1] if len(sys.argv) > 1 else ""


# ---------------------------------------------------------------- инструменты

def T(sec):
    return np.arange(int(sec * SR)) / SR


def noise(sec):
    return rng.normal(0, 1, int(sec * SR))


def pink(sec):
    n = int(sec * SR)
    w = rng.normal(0, 1, n)
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1, -2.494956002, 2.017265875, -0.522189400]
    return signal.lfilter(b, a, w) * 4


def brown(sec):
    x = np.cumsum(rng.normal(0, 1, int(sec * SR)))
    x = signal.lfilter(*signal.butter(1, 20 / (SR / 2), "high"), x)
    return x / (np.abs(x).max() + 1e-9)


def lp(x, f, o=2):
    return signal.lfilter(*signal.butter(o, min(f, SR / 2 - 100) / (SR / 2)), x)


def hp(x, f, o=2):
    return signal.lfilter(*signal.butter(o, f / (SR / 2), "high"), x)


def bp(x, f1, f2, o=2):
    return signal.lfilter(*signal.butter(o, [f1 / (SR / 2), min(f2, SR / 2 - 100) / (SR / 2)], "band"), x)


def env_exp(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def adsr(n, a=0.01, d=0.1, s=0.7, r=0.2):
    e = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n)
    e[:na] = np.linspace(0, 1, na)
    nd = min(nd, n - na)
    e[na:na + nd] = np.linspace(1, s, nd)
    nr = min(nr, n)
    e[n - nr:] *= np.linspace(1, 0, nr)
    return e


def add(*xs):
    n = max(len(x) for x in xs)
    y = np.zeros(n)
    for x in xs:
        y[:len(x)] += x
    return y


def pad(x, sec):
    return np.concatenate([x, np.zeros(int(sec * SR))])


def mix(dst, src, at=0.0, gain=1.0):
    p = int(at * SR)
    if p < 0:
        src = src[-p:]
        p = 0
    if p >= len(dst):
        return dst
    m = min(len(src), len(dst) - p)
    dst[p:p + m] += src[:m] * gain
    return dst


def modal(freqs, decays, amps, sec, strike=0.002):
    """Удар по металлу/стеклу: сумма затухающих синусоид."""
    t = T(sec)
    y = np.zeros(len(t))
    for f, d, a in zip(freqs, decays, amps):
        y += np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * np.exp(-t / d) * a
    y += lp(noise(sec), 6000) * np.exp(-t / strike) * 0.5
    return y


def reverb(x, sec=1.6, wet=0.3, damp=5000, decay=4.0):
    n = int(sec * SR)
    t = np.arange(n) / SR
    ir = rng.normal(0, 1, n) * np.exp(-t * decay)
    ir = lp(ir, damp)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    y = signal.fftconvolve(x, ir)
    out = np.zeros(len(y))
    out[:len(x)] += x * (1 - wet)
    out += y * wet
    return out


def friction(sec, f0, f1, jitter=0.15, rough=0.5):
    """Скрип: осциллятор с дрожащей частотой (трение)."""
    n = int(sec * SR)
    f = np.linspace(f0, f1, n)
    j = lp(rng.normal(0, 1, n), 30) * 40
    f = f * (1 + jitter * j / (np.abs(j).max() + 1e-9))
    ph = np.cumsum(2 * np.pi * f / SR)
    saw = (ph / np.pi) % 2 - 1
    stick = (lp(rng.random(n), 80) > 0.5 - rough * 0.3).astype(float)
    y = saw * (0.4 + 0.6 * lp(stick, 200))
    y = bp(y, 300, 4000)
    return y


def bubble(f0, dur=0.06):
    t = T(dur)
    f = f0 * (1 + 3.0 * t / dur)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / (dur * 0.35))


def drops(sec, rate, fmin=800, fmax=3000, amp=0.3):
    y = np.zeros(int(sec * SR))
    k = int(sec * rate)
    for _ in range(k):
        b = bubble(rng.uniform(fmin, fmax), rng.uniform(0.02, 0.07)) * rng.uniform(0.3, 1.0) * amp
        mix(y, b, rng.uniform(0, sec - 0.08))
    return y


def loopify(x, xf=0.5):
    """Бесшовная петля: перекрёстное наложение хвоста на начало."""
    n = int(xf * SR)
    a = x[:n].copy()
    b = x[-n:].copy()
    w = np.linspace(0, 1, n)
    y = x[:-n].copy()
    y[:n] = a * w + b * (1 - w)
    return y


def norm(x, peak=0.9):
    m = np.abs(x).max()
    return x * (peak / m) if m > 1e-9 else x


def fade(x, a=0.005, r=0.02):
    n = len(x)
    na, nr = min(int(a * SR), n), min(int(r * SR), n)
    x = x.copy()
    x[:na] *= np.linspace(0, 1, na)
    x[n - nr:] *= np.linspace(1, 0, nr)
    return x


def save(name, x, peak=0.9, loop=False, stereo=False):
    if ONLY and not name.startswith(ONLY):
        return
    if loop:
        x = loopify(x)
    else:
        x = fade(x)
    x = norm(x, peak)
    x = np.clip(x, -1, 1)
    tmp = os.path.join(tempfile.gettempdir(), name + ".wav")
    data = x if not stereo else x
    ch = 1
    if data.ndim == 2:
        ch = 2
        data = data.T.reshape(-1)
    with wave.open(tmp, "w") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((data * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(tmp)
    print(name, flush=True)


# ---------------------------------------------------------------- шаги

def thump(f=90, dur=0.08, amp=1.0):
    t = T(dur)
    return np.sin(2 * np.pi * f * t * (1 - t * 2)) * np.exp(-t / (dur * 0.25)) * amp


def step_tile(wet=False):
    y = np.zeros(int(0.3 * SR))
    heel = bp(noise(0.03), 1200, 6000) * env_exp(int(0.03 * SR), 0.004) * 0.9
    toe = bp(noise(0.03), 900, 4500) * env_exp(int(0.03 * SR), 0.005) * 0.5
    mix(y, heel)
    mix(y, thump(rng.uniform(80, 110), 0.07, 0.8))
    mix(y, toe, rng.uniform(0.05, 0.09))
    if wet:
        sl = hp(noise(0.12), 1500) * env_exp(int(0.12 * SR), 0.03) * 0.6
        mix(y, sl, 0.005)
        mix(y, drops(0.25, 25, 1500, 3500, 0.2), 0.01)
    return reverb(y, 0.5, 0.15)


def step_water():
    y = np.zeros(int(0.5 * SR))
    spl = hp(noise(0.3), 700) * env_exp(int(0.3 * SR), 0.07)
    mix(y, spl * 0.9)
    mix(y, drops(0.4, 60, 600, 2500, 0.35), 0.02)
    t = T(0.18)
    mix(y, np.sin(2 * np.pi * np.cumsum(220 - 600 * t) / SR) * np.exp(-t / 0.05) * 0.4)
    return y


def step_wood():
    y = np.zeros(int(0.3 * SR))
    mix(y, thump(rng.uniform(110, 150), 0.1, 1.0))
    mix(y, bp(noise(0.05), 300, 1500) * env_exp(int(0.05 * SR), 0.01) * 0.6)
    if rng.random() < 0.4:
        mix(y, friction(0.15, 500, 700, 0.3) * np.hanning(int(0.15 * SR)) * 0.15, 0.04)
    return y


def step_concrete():
    y = np.zeros(int(0.3 * SR))
    mix(y, bp(noise(0.06), 1500, 7000) * env_exp(int(0.06 * SR), 0.008) * 0.8)
    mix(y, thump(85, 0.07, 0.7))
    grit = hp(noise(0.08), 3000) * (rng.random(int(0.08 * SR)) > 0.97) * 0.8
    mix(y, grit, 0.01)
    return y


def step_lino():
    y = np.zeros(int(0.25 * SR))
    mix(y, lp(noise(0.04), 1800) * env_exp(int(0.04 * SR), 0.008) * 0.7)
    mix(y, thump(95, 0.07, 0.8))
    return y


def step_snow():
    n = int(0.3 * SR)
    y = np.zeros(n)
    for _ in range(220):
        p = int(rng.uniform(0, 0.2) * SR * (rng.random() ** 0.6))
        c = hp(rng.normal(0, 1, 60), 2000) * env_exp(60, 0.0004)
        mix(y, c * rng.uniform(0.2, 1.0), p / SR)
    y = bp(y, 1500, 9000) * np.exp(-np.arange(n) / (0.1 * SR))
    mix(y, thump(70, 0.08, 0.4))
    return y


def step_coal():
    n = int(0.35 * SR)
    y = np.zeros(n)
    for _ in range(90):
        p = rng.uniform(0, 0.25) * rng.random()
        c = modal([rng.uniform(1500, 5000)], [0.006], [1.0], 0.03, 0.0005)
        mix(y, c * rng.uniform(0.1, 0.6), p)
    mix(y, thump(80, 0.08, 0.6))
    return y


def make_steps():
    for i in range(1, 5):
        save(f"step_tile_{i}", step_tile(), 0.8)
        save(f"step_tile_wet_{i}", step_tile(True), 0.8)
        save(f"step_water_{i}", step_water(), 0.8)
        save(f"step_wood_{i}", step_wood(), 0.8)
        save(f"step_concrete_{i}", step_concrete(), 0.8)
        save(f"step_lino_{i}", step_lino(), 0.7)
        save(f"step_snow_{i}", step_snow(), 0.7)
        save(f"step_coal_{i}", step_coal(), 0.75)


# ---------------------------------------------------------------- дыхание, сердце

def breath(dur, inhale=True, amp=1.0, f1=400, f2=2200):
    n = int(dur * SR)
    e = np.sin(np.linspace(0, np.pi, n)) ** (1.5 if inhale else 0.8)
    if not inhale:
        e = e * np.linspace(1.2, 0.6, n)
    x = bp(noise(dur), f1, f2) + bp(noise(dur), 2500, 5000) * 0.3
    return x * e * amp


def make_body():
    save("breath_in", breath(0.6, True), 0.5)
    save("breath_out", breath(0.9, False), 0.5)
    g = np.zeros(int(1.2 * SR))
    mix(g, breath(0.35, True, 1.6, 500, 3000))
    mix(g, breath(0.8, False, 1.0), 0.35)
    save("breath_gasp", g, 0.8)
    # тяжёлая одышка: 4 цикла
    y = np.zeros(int(5.2 * SR))
    for k in range(4):
        mix(y, breath(0.45, True, 1.0), k * 1.3)
        mix(y, breath(0.7, False, 0.8), k * 1.3 + 0.5)
    save("loop_breath_heavy", y, 0.6, loop=True)
    # сердце 72 уд/мин
    beat = 60 / 72
    y = np.zeros(int(beat * 4 * SR + 0.6 * SR))
    for k in range(4):
        mix(y, thump(55, 0.15, 1.0), k * beat)
        mix(y, thump(48, 0.13, 0.7), k * beat + 0.22)
    y = lp(y, 200)
    save("loop_heartbeat", y[:int(beat * 4 * SR) + int(0.5 * SR)], 0.8, loop=True)
    # падение тела
    y = np.zeros(int(1.2 * SR))
    mix(y, thump(60, 0.3, 1.0))
    mix(y, lp(noise(0.3), 800) * env_exp(int(0.3 * SR), 0.06) * 0.6)
    save("thud_body", reverb(y, 1.0, 0.2), 0.9)


# ---------------------------------------------------------------- двери, металл

def creak(sec, f0, f1, amp=1.0, wood=True):
    y = friction(sec, f0, f1, 0.25)
    if wood:
        y = bp(y, 250, 2500) + bp(y, 600, 900) * 2
    else:
        y = bp(y, 800, 6000)
    e = adsr(len(y), 0.05, 0.1, 0.8, 0.15)
    return y * e * amp


def latch(metal=0.6):
    return modal([1800, 3400, 5100], [0.03, 0.02, 0.015], [1, 0.6, 0.3], 0.15) * metal


def make_doors():
    # дерево
    y = np.zeros(int(1.6 * SR))
    mix(y, latch(0.5))
    mix(y, creak(1.1, 380, 260), 0.08)
    save("door_wood", reverb(y, 1.0, 0.2), 0.7)
    y = np.zeros(int(3.6 * SR))
    mix(y, creak(3.2, 300, 170, 1.0), 0.1)
    save("door_wood_slow", reverb(y, 1.3, 0.25), 0.8)
    y = np.zeros(int(1.0 * SR))
    mix(y, creak(0.4, 250, 330, 0.6), 0.0)
    mix(y, thump(110, 0.12, 1.0), 0.4)
    mix(y, latch(0.6), 0.42)
    save("door_wood_close", reverb(y, 0.9, 0.2), 0.8)
    # сталь
    y = np.zeros(int(1.6 * SR))
    mix(y, latch(0.8))
    mix(y, creak(1.0, 700, 500, 0.8, False), 0.1)
    save("door_steel", reverb(y, 1.2, 0.25), 0.7)
    y = np.zeros(int(3.5 * SR))
    mix(y, creak(3.0, 600, 350, 0.9, False), 0.1)
    save("door_steel_slow", reverb(y, 1.4, 0.3), 0.8)
    y = np.zeros(int(1.5 * SR))
    mix(y, modal([140, 310, 620, 1250], [0.3, 0.25, 0.15, 0.1], [1, 0.6, 0.4, 0.2], 1.2), 0.0)
    mix(y, latch(0.9), 0.02)
    save("door_steel_close", reverb(y, 1.4, 0.3), 0.85)
    # решётка
    y = np.zeros(int(2.0 * SR))
    mix(y, creak(1.5, 900, 600, 0.8, False), 0.05)
    for k in range(6):
        mix(y, modal([rng.uniform(800, 2400)], [0.08], [0.4], 0.2), 0.05 + k * 0.2)
    save("door_grate", reverb(y, 1.2, 0.3), 0.7)
    save("door_grate_slow", reverb(np.concatenate([y, np.zeros(SR)]), 1.4, 0.3), 0.75)
    y = np.zeros(int(1.2 * SR))
    mix(y, modal([500, 1300, 2600], [0.2, 0.12, 0.08], [1, 0.5, 0.3], 1.0))
    save("door_grate_close", reverb(y, 1.2, 0.3), 0.8)
    # хлопок
    y = np.zeros(int(2.0 * SR))
    mix(y, thump(70, 0.25, 1.2))
    mix(y, lp(noise(0.2), 2500) * env_exp(int(0.2 * SR), 0.03) * 0.8)
    mix(y, latch(0.7), 0.01)
    for k in range(5):
        mix(y, modal([rng.uniform(300, 900)], [0.04], [0.15], 0.1), 0.05 + k * 0.05)
    save("door_slam", reverb(y, 1.8, 0.35), 0.95)
    # заперто: дёргают ручку
    y = np.zeros(int(0.8 * SR))
    for k in range(3):
        mix(y, add(latch(0.6), thump(130, 0.05, 0.4)), k * 0.18)
    save("door_locked", reverb(y, 0.6, 0.15), 0.7)
    y = np.zeros(int(0.7 * SR))
    mix(y, latch(0.5))
    mix(y, modal([2500, 4100], [0.02, 0.015], [1, 0.5], 0.1), 0.15)
    mix(y, latch(0.7), 0.3)
    save("unlock", y, 0.7)
    # шкафчики
    def locker(open_):
        y = np.zeros(int(0.9 * SR))
        mix(y, latch(0.6))
        mix(y, modal([420, 980, 1900], [0.12, 0.08, 0.05], [0.6, 0.4, 0.2], 0.5), 0.02 if open_ else 0.15)
        if open_:
            mix(y, creak(0.3, 900, 700, 0.4, False), 0.05)
        return reverb(y, 0.8, 0.2)
    save("locker_open", locker(True), 0.7)
    save("locker_close", locker(False), 0.7)
    y = np.zeros(int(1.4 * SR))
    mix(y, modal([300, 760, 1500, 2900], [0.3, 0.2, 0.12, 0.06], [1, 0.8, 0.5, 0.3], 1.2))
    mix(y, creak(0.4, 1200, 600, 0.8, False), 0.02)
    mix(y, lp(noise(0.3), 3000) * env_exp(int(0.3 * SR), 0.05), 0.0)
    save("locker_rip", reverb(y, 1.3, 0.3), 0.95)


# ---------------------------------------------------------------- вода

def stream(sec, bright=1.0):
    x = pink(sec)
    x = bp(x, 300, 6000 * bright) + hp(noise(sec), 4000) * 0.15 * bright
    mod = 1 + 0.3 * lp(rng.normal(0, 1, len(x)), 6) * 8
    y = x * mod
    y += drops(sec, 120 * bright, 400, 2500, 0.25)
    return y


def make_water():
    save("loop_tap", stream(6.0, 0.7), 0.6, loop=True)
    sh = stream(6.0, 1.3) + hp(noise(6.0), 2500) * 0.4
    save("loop_shower", sh, 0.65, loop=True)
    y = np.zeros(int(1.4 * SR))
    mix(y, creak(0.35, 1200, 900, 0.5, False))
    st = stream(1.0, 0.8) * np.linspace(0, 1, int(1.0 * SR))
    mix(y, st, 0.3)
    mix(y, modal([140, 330], [0.2, 0.15], [0.4, 0.2], 0.6), 0.25)
    save("tap_open", y, 0.7)
    y = np.zeros(int(0.9 * SR))
    mix(y, stream(0.4, 0.8) * np.linspace(1, 0, int(0.4 * SR)))
    mix(y, creak(0.3, 900, 1200, 0.5, False), 0.1)
    save("tap_close", y, 0.6)
    y = np.zeros(int(1.5 * SR))
    mix(y, creak(0.35, 1200, 900, 0.5, False))
    air = bp(noise(0.8), 500, 3000) * np.hanning(int(0.8 * SR)) * 0.5
    mix(y, air, 0.3)
    for k in range(3):
        mix(y, thump(160, 0.06, 0.5), 0.4 + k * 0.17)
    save("tap_dry", reverb(y, 1.0, 0.25), 0.6)
    y = np.zeros(int(1.6 * SR))
    for k in range(5):
        burst = stream(0.12, 1.0) * np.hanning(int(0.12 * SR))
        mix(y, burst, k * 0.2 + rng.uniform(0, 0.05))
        mix(y, bp(noise(0.08), 300, 1500) * np.hanning(int(0.08 * SR)) * 0.6, k * 0.2 + 0.1)
    save("tap_spit", reverb(y, 1.0, 0.25), 0.7)
    # бульканье в трапе
    y = np.zeros(int(3.0 * SR))
    for _ in range(140):
        mix(y, bubble(rng.uniform(80, 420), rng.uniform(0.04, 0.14)) * rng.uniform(0.2, 1.0), rng.uniform(0, 2.8) ** 1.05)
    y += lp(brown(3.0), 300) * 0.4
    save("drain_gurgle", reverb(y, 1.2, 0.3), 0.85)
    y = np.zeros(int(2.0 * SR))
    for _ in range(40):
        mix(y, bubble(rng.uniform(60, 250), rng.uniform(0.05, 0.15)) * rng.uniform(0.3, 1.0), rng.uniform(0, 1.2))
    mix(y, bubble(55, 0.4) * 1.2, 1.3)
    save("drain_stop", reverb(y, 1.4, 0.3), 0.85)
    y = np.zeros(int(6.0 * SR))
    sweep = bp(pink(5.5), 150, 1500) * np.hanning(int(5.5 * SR))
    mix(y, sweep)
    for _ in range(200):
        mix(y, bubble(rng.uniform(60, 300), rng.uniform(0.05, 0.12)) * 0.5, rng.uniform(0, 5.4))
    save("drain_whoosh", reverb(y, 1.6, 0.3), 0.9)
    y = np.zeros(int(4.0 * SR))
    mix(y, stream(3.5, 1.4) * adsr(int(3.5 * SR), 0.05, 0.4, 0.6, 1.5) * 1.3)
    mix(y, lp(brown(3.5), 150) * 0.8 * adsr(int(3.5 * SR), 0.05, 0.4, 0.5, 1.5))
    save("water_gush", reverb(y, 2.0, 0.35), 0.9)
    y = np.zeros(int(4.0 * SR))
    mix(y, lp(pink(3.8), 600) * np.hanning(int(3.8 * SR)))
    for _ in range(60):
        mix(y, bubble(rng.uniform(70, 200), 0.12) * 0.6, rng.uniform(0.3, 3.4))
    save("water_swirl", reverb(y, 1.6, 0.3), 0.75)
    y = np.zeros(int(2.5 * SR))
    for k in range(5):
        mix(y, bubble(rng.uniform(1200, 2600), 0.05) * rng.uniform(0.5, 1), rng.uniform(0, 2.0))
    save("drip_burst", reverb(y, 2.0, 0.45, 6000, 2.5), 0.6)
    y = np.zeros(int(24 * SR))
    for k in range(38):
        mix(y, bubble(rng.uniform(900, 2800), rng.uniform(0.03, 0.06)) * rng.uniform(0.2, 1.0), rng.uniform(0, 23.5))
    save("loop_drips", reverb(y, 2.2, 0.45, 6000, 2.2)[:int(24 * SR)], 0.5, loop=True)
    y = hp(noise(2.5), 2500) * adsr(int(2.5 * SR), 0.05, 0.3, 0.7, 1.0)
    save("steam_hiss", y, 0.7)
    # мытьё в шайке
    y = np.zeros(int(6.0 * SR))
    for k in range(14):
        burst = stream(0.25, 1.0) * np.hanning(int(0.25 * SR))
        mix(y, burst * rng.uniform(0.4, 1.0), rng.uniform(0, 5.6))
    mix(y, bp(noise(6.0), 1500, 5000) * 0.08)
    save("loop_hoz_wash", reverb(y, 1.4, 0.35), 0.6, loop=True)


# ---------------------------------------------------------------- трубы

def pipe_hit(amp=1.0, f=None):
    f = f or rng.uniform(170, 260)
    return modal([f, f * 2.76, f * 5.4, f * 8.9], [0.35, 0.18, 0.09, 0.05], [1, 0.5, 0.3, 0.15], 1.0, 0.003) * amp


def make_pipes():
    # стук гидроудара: она выходит
    y = np.zeros(int(5.0 * SR))
    times = [0.0, 0.35, 0.55, 1.2, 1.35, 1.5, 2.3, 2.45, 3.1, 3.2, 3.3, 3.4]
    for k, tm in enumerate(times):
        mix(y, pipe_hit(rng.uniform(0.5, 1.0) * (1 - k * 0.04)), tm + rng.uniform(-0.02, 0.02))
    mix(y, lp(brown(5.0), 120) * 0.3)
    save("pipe_knock", reverb(y, 2.5, 0.45, 3000, 1.8), 0.95)
    y = np.zeros(int(2.5 * SR))
    mix(y, add(pipe_hit(1.0, 150), thump(60, 0.2, 0.6)))
    save("pipe_bang", reverb(y, 2.0, 0.4, 3000, 2.0), 0.95)
    y = np.zeros(int(3.0 * SR))
    mix(y, creak(2.6, 140, 90, 1.0, True) * 0.7, 0.1)
    save("pipe_creak", reverb(y, 2.2, 0.45, 2500, 1.8), 0.7)
    t = T(4.0)
    f = 70 + 15 * np.sin(2 * np.pi * 0.7 * t) + 10 * lp(rng.normal(0, 1, len(t)), 3) * 20
    ph = np.cumsum(2 * np.pi * f / SR)
    g = (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.3 * np.sin(3.1 * ph)) * adsr(len(t), 0.3, 0.5, 0.8, 1.5)
    g += bp(noise(4.0), 200, 900) * 0.2 * adsr(len(t), 0.3, 0.5, 0.8, 1.5)
    save("pipe_groan", reverb(g, 2.5, 0.45, 2000, 1.6), 0.9)
    y = creak(2.5, 520, 700, 1.0, False) * 0.8 + creak(2.5, 300, 350, 0.6, True)
    save("loop_valve", y, 0.6, loop=True)
    y = np.zeros(int(3.5 * SR))
    mix(y, creak(2.6, 420, 260, 1.0, False))
    mix(y, pipe_hit(0.8, 120), 2.7)
    save("valve_creak_big", reverb(y, 1.8, 0.35, 3000, 2.0), 0.9)
    y = np.zeros(int(3.0 * SR))
    mix(y, creak(2.4, 220, 160, 0.8, True) + lp(noise(2.4), 900) * 0.3 * np.hanning(int(2.4 * SR)))
    save("loop_pry", y, 0.6, loop=True)


# ---------------------------------------------------------------- Хозяйка

def make_monster():
    # дыхание: влажное, хриплое, медленное
    y = np.zeros(int(7.2 * SR))
    for k in range(2):
        b0 = k * 3.6
        inh = breath(1.4, True, 1.0, 250, 1600)
        rattle = np.sin(2 * np.pi * 38 * T(1.4)) * 0.5 + 0.5
        mix(y, inh * (0.6 + 0.4 * rattle), b0)
        exh = breath(1.8, False, 1.0, 200, 1200)
        gur = lp(noise(1.8), 300) * (np.sin(2 * np.pi * 23 * T(1.8)) > 0.6) * 0.6
        mix(y, exh + gur * np.hanning(len(gur)), b0 + 1.5)
        for c in range(4):
            mix(y, hp(noise(0.01), 2000) * 0.6, b0 + rng.uniform(0, 3.2))
    save("loop_hoz_breath", reverb(y, 1.0, 0.2), 0.7, loop=True)
    # ногти по кафелю: щёлк-щёлк, четыре конечности
    y = np.zeros(int(2.4 * SR))
    for k in range(16):
        tm = k * 0.15 + rng.uniform(-0.02, 0.02)
        for c in range(rng.integers(1, 4)):
            click = modal([rng.uniform(2500, 5500), rng.uniform(6000, 9000)], [0.004, 0.003], [1, 0.5], 0.03, 0.0003)
            mix(y, click * rng.uniform(0.4, 1.0), tm + c * 0.012)
    save("loop_nails", reverb(y, 0.8, 0.25, 7000, 4.0), 0.7, loop=True)
    # шлёпок мокрой босой ступни
    for i in range(1, 4):
        y = np.zeros(int(0.5 * SR))
        mix(y, thump(rng.uniform(70, 95), 0.08, 0.8))
        sl = bp(noise(0.06), 600, 4000) * env_exp(int(0.06 * SR), 0.01)
        mix(y, sl * 1.2)
        mix(y, hp(noise(0.15), 2000) * env_exp(int(0.15 * SR), 0.03) * 0.4, 0.02)
        mix(y, drops(0.3, 12, 1500, 3000, 0.2), 0.03)
        save(f"hoz_step_{i}", reverb(y, 0.8, 0.25), 0.8)
    # принюхивается
    for i in range(1, 3):
        y = np.zeros(int(1.6 * SR))
        for k in range(rng.integers(3, 5)):
            s = bp(noise(0.12), 900, 3500) * np.sin(np.linspace(0, np.pi, int(0.12 * SR))) ** 2
            mix(y, s * rng.uniform(0.6, 1.0), k * 0.17)
        mix(y, breath(0.6, False, 0.5, 200, 1000), 0.8)
        save(f"hoz_sniff_{i}", reverb(y, 0.8, 0.2), 0.8)
    # крик: хриплый, срывающийся, с металлическим призвуком труб
    t = T(3.2)
    f = 520 * np.exp(-t * 0.18) + 40 * np.sin(2 * np.pi * 7 * t) * t + 60 * lp(rng.normal(0, 1, len(t)), 10) * 10
    ph = np.cumsum(2 * np.pi * f / SR)
    saw = (ph / np.pi) % 2 - 1
    v = saw * adsr(len(t), 0.05, 0.3, 0.8, 1.2)
    form = bp(v, 600, 1100) * 1.5 + bp(v, 1800, 2800) + bp(v, 3200, 4200) * 0.6
    sc = np.tanh(form * 3 + bp(noise(3.2), 1000, 6000) * 0.8 * adsr(len(t), 0.05, 0.3, 0.8, 1.2))
    sc += modal([180, 497, 976], [1.2, 0.8, 0.5], [0.3, 0.2, 0.1], 3.2) * 0.5
    save("hoz_scream", reverb(sc, 2.2, 0.35, 4000, 2.0), 0.95)
    # «за спиной»: дыхание прямо в ухо + низкий нарастающий гул
    y = np.zeros(int(3.0 * SR))
    mix(y, breath(1.0, False, 1.4, 200, 2500))
    mix(y, hp(noise(0.015), 3000) * 0.8, 0.2)
    dr = np.sin(2 * np.pi * 41 * T(2.8)) * np.linspace(0, 1, int(2.8 * SR)) * 0.5
    mix(y, dr, 0.1)
    save("hoz_behind", y, 0.9)
    y = np.zeros(int(2.5 * SR))
    mix(y, breath(1.6, False, 1.0, 200, 1500) * np.linspace(1, 0, int(1.6 * SR)))
    mix(y, drops(1.5, 8, 800, 2000, 0.3), 0.6)
    save("hoz_release", reverb(y, 1.5, 0.35), 0.7)
    # мокрые волосы
    y = np.zeros(int(1.2 * SR))
    sq = bp(noise(1.0), 800, 5000) * (0.5 + 0.5 * np.sin(2 * np.pi * 13 * T(1.0)) ** 2) * np.hanning(int(1.0 * SR))
    mix(y, sq)
    mix(y, drops(1.0, 25, 1000, 2500, 0.3))
    save("hair_wet", reverb(y, 1.0, 0.25), 0.7)
    y = np.zeros(int(2.0 * SR))
    mix(y, bp(noise(0.4), 300, 5000) * env_exp(int(0.4 * SR), 0.08) * 1.4)
    mix(y, thump(55, 0.3, 1.2))
    mix(y, pipe_hit(0.6, 110), 0.02)
    save("hair_yank", reverb(y, 1.5, 0.3), 0.95)
    y = np.zeros(int(3.0 * SR))
    for k in range(10):
        s = bp(noise(0.28), 500, 4000) * np.hanning(int(0.28 * SR)) * (0.5 + 0.5 * np.sin(2 * np.pi * 30 * T(0.28)))
        mix(y, s * rng.uniform(0.5, 1.0), k * 0.3)
    mix(y, drops(3.0, 30, 400, 1600, 0.3))
    save("loop_hair_pull", y, 0.7, loop=True)
    # испуг
    y = np.zeros(int(1.6 * SR))
    mix(y, np.tanh(noise(1.2) * 3) * adsr(int(1.2 * SR), 0.003, 0.2, 0.5, 0.8) * 0.6)
    for f in [233, 247, 311, 466, 493]:
        mix(y, np.sin(2 * np.pi * f * T(1.4)) * adsr(int(1.4 * SR), 0.005, 0.3, 0.5, 0.9) * 0.35)
    mix(y, creak(1.2, 2400, 1600, 0.8, False))
    mix(y, thump(45, 0.4, 1.5))
    save("jumpscare", y, 0.98)


# ---------------------------------------------------------------- сюжетные вещи

def make_story():
    y = np.zeros(int(2.0 * SR))
    mix(y, modal([900, 2300, 4100], [0.1, 0.06, 0.03], [1, 0.6, 0.4], 0.5) * 1.2)
    for k in range(12):
        mix(y, modal([rng.uniform(1500, 4000)], [0.03], [0.4], 0.08), 0.05 + k * 0.07 + rng.uniform(0, 0.03))
    save("chain_break", reverb(y, 1.2, 0.2), 0.9)
    y = np.zeros(int(2.0 * SR))
    mix(y, thump(120, 0.05, 0.6))
    mix(y, modal([1400, 2900], [0.05, 0.03], [0.6, 0.3], 0.2), 0.02)
    save("phone_pickup", y, 0.7)
    save("phone_hangup", y, 0.7)
    t = T(0.5)
    y = np.sin(2 * np.pi * 1318 * t) * np.exp(-t / 0.12) * (t < 0.25) + np.sin(2 * np.pi * 1760 * t) * np.exp(-(t - 0.18).clip(0) / 0.15) * (t >= 0.18)
    save("phone_ping", y, 0.6)
    # старый звонок: два колокольчика, 1.2 с звонит, 2 с тишина
    y = np.zeros(int(6.4 * SR))
    for rep in range(2):
        for k in range(int(1.2 * 20)):
            tm = rep * 3.2 + k / 20.0
            mix(y, modal([1060, 2550, 3800], [0.08, 0.05, 0.03], [1, 0.5, 0.3], 0.12, 0.0005) * 0.5, tm)
            mix(y, modal([1190, 2810], [0.08, 0.05], [0.7, 0.3], 0.12, 0.0005) * 0.5, tm + 0.025)
    save("loop_phone_ring", reverb(y, 1.2, 0.25)[:len(y)], 0.85, loop=False)
    y = np.zeros(int(1.0 * SR))
    mix(y, latch(0.8))
    mix(y, modal([300, 800, 1700], [0.1, 0.06, 0.04], [0.8, 0.4, 0.2], 0.4), 0.1)
    for k in range(8):
        mix(y, modal([rng.uniform(1500, 4000)], [0.02], [0.3], 0.05), 0.2 + k * 0.05)
    save("toolbox", y, 0.8)
    y = bp(noise(1.0), 1500, 7000) * (0.4 + 0.6 * lp(rng.random(int(1.0 * SR)), 40)) * np.hanning(int(1.0 * SR))
    save("cloth_rustle", y, 0.5)
    # шайка
    def basin(amp=1.0):
        y = np.zeros(int(2.2 * SR))
        for k in range(5):
            mix(y, modal([380, 1050, 2050, 3300], [0.5, 0.3, 0.15, 0.08], [1, 0.7, 0.5, 0.3], 1.0) * (amp * (0.8 ** k)), k * 0.12 * (0.9 ** k))
        return reverb(y, 2.0, 0.35, 5000, 2.2)
    save("basin_clang", basin(), 0.95)
    save("basin_drop", lp(basin(0.7), 2500), 0.7)
    y = np.zeros(int(2.0 * SR))
    mix(y, creak(1.0, 300, 200, 0.8, False))
    mix(y, modal([120, 290, 640], [0.4, 0.3, 0.15], [1, 0.6, 0.3], 1.0), 1.0)
    save("hatch_open", reverb(y, 1.5, 0.3), 0.9)
    def shovel():
        y = np.zeros(int(1.4 * SR))
        mix(y, bp(noise(0.5), 800, 5000) * np.hanning(int(0.5 * SR)) * 0.7)
        mix(y, step_coal() * 1.2, 0.5)
        mix(y, step_coal() * 0.8, 0.65)
        return y
    save("coal_shovel", reverb(shovel(), 1.0, 0.2), 0.8)
    save("loop_shovel", np.concatenate([shovel(), shovel()]), 0.7, loop=True)
    y = np.zeros(int(2.5 * SR))
    mix(y, modal([95, 240, 510, 900], [0.6, 0.4, 0.2, 0.1], [1, 0.7, 0.4, 0.2], 2.0) * 1.2)
    mix(y, thump(60, 0.2, 1.0))
    save("furnace_slam", reverb(y, 2.0, 0.35, 3000, 2.0), 0.95)
    y = np.zeros(int(1.2 * SR))
    mix(y, creak(0.5, 500, 300, 0.6, False))
    mix(y, modal([200, 520, 1100], [0.3, 0.15, 0.08], [1, 0.5, 0.3], 0.7), 0.45)
    save("damper", reverb(y, 1.2, 0.3), 0.85)
    t = T(6.0)
    wh = bp(noise(6.0), 1300, 2100) * 1.5 + np.sin(2 * np.pi * 1580 * t) * 0.3 * (1 + 0.2 * np.sin(2 * np.pi * 5 * t))
    wh += lp(brown(6.0), 150) * 0.6
    save("loop_boiler_whistle", wh, 0.75, loop=True)
    y = np.zeros(int(6.0 * SR))
    mix(y, lp(brown(5.5), 120) * env_exp(int(5.5 * SR), 1.2) * 2.0)
    mix(y, np.tanh(noise(1.0) * 4) * env_exp(int(1.0 * SR), 0.15))
    for k in range(40):
        mix(y, modal([rng.uniform(200, 3000)], [0.08], [0.3], 0.2), rng.uniform(0.2, 4.0))
    save("explosion", reverb(y, 3.0, 0.4, 2000, 1.2), 0.98)
    y = lp(brown(8.0), 250) * 1.2 + bp(pink(8.0), 300, 3000) * 0.3
    for k in range(260):
        mix(y, hp(noise(0.006), 2500) * rng.uniform(0.2, 1.0), rng.uniform(0, 7.9))
    save("loop_fire_big", y, 0.85, loop=True)
    # воспоминание: обратная волна, детское дыхание, ногти по жести
    y = np.zeros(int(9.0 * SR))
    sw = lp(noise(3.0), 1500) * np.linspace(0, 1, int(3.0 * SR)) ** 2
    mix(y, sw * 0.7)
    for k in range(5):
        mix(y, breath(0.5, k % 2 == 0, 0.6, 600, 4000), 3.0 + k * 0.6)
    for k in range(30):
        mix(y, creak(0.15, rng.uniform(1500, 2500), rng.uniform(1200, 2000), 0.25, False), 4.5 + k * 0.14)
    save("memory", reverb(y, 3.0, 0.5, 3000, 1.0), 0.85)
    y = np.zeros(int(1.5 * SR))
    mix(y, thump(80, 0.2, 1.2))
    mix(y, latch(0.8), 0.02)
    mix(y, modal([600, 1500], [0.08, 0.04], [0.5, 0.3], 0.3), 0.03)
    save("van_door", reverb(y, 0.8, 0.15, 6000, 6.0), 0.8)
    y = np.zeros(int(0.6 * SR))
    mix(y, bp(noise(0.3), 400, 3000) * np.hanning(int(0.3 * SR)))
    save("throw", y, 0.5)
    y = np.zeros(int(1.5 * SR))
    for k in range(4):
        mix(y, add(modal([rng.uniform(600, 900), 2100], [0.08, 0.04], [0.6, 0.3], 0.2), thump(120, 0.05, 0.4)), k * 0.3)
    save("ladder", reverb(y, 1.0, 0.25), 0.7)


# ---------------------------------------------------------------- интерфейс

def make_ui():
    y = modal([2200, 4400], [0.01, 0.006], [1, 0.4], 0.06, 0.0005)
    save("ui_click", y, 0.5)
    y = modal([3200], [0.006], [1], 0.04, 0.0003)
    save("ui_hover", y, 0.3)
    t = T(2.0)
    y = (np.sin(2 * np.pi * 330 * t) + 0.5 * np.sin(2 * np.pi * 495 * t)) * np.exp(-t / 0.6)
    save("objective", y, 0.4)
    y = bp(noise(0.5), 2000, 8000) * (0.4 + 0.6 * lp(rng.random(int(0.5 * SR)), 50)) * np.hanning(int(0.5 * SR))
    save("paper", y, 0.5)
    save("phone_open", modal([1500], [0.01], [1], 0.05, 0.0005), 0.4)
    y = np.zeros(int(0.4 * SR))
    mix(y, bp(noise(0.2), 1000, 5000) * np.hanning(int(0.2 * SR)) * 0.6)
    mix(y, thump(160, 0.05, 0.5), 0.12)
    save("pickup", y, 0.6)
    save("pickup_metal", modal([1100, 2600, 4200], [0.08, 0.05, 0.03], [1, 0.5, 0.3], 0.3), 0.6)
    y = np.zeros(int(0.5 * SR))
    mix(y, latch(0.6))
    mix(y, latch(0.5), 0.18)
    save("battery", y, 0.6)
    save("flash_click", modal([2600, 5200], [0.006, 0.004], [1, 0.4], 0.05, 0.0003) + np.pad(modal([2000], [0.006], [0.7], 0.05, 0.0003), (int(0.03 * SR), 0))[:int(0.05 * SR)], 0.5)
    y = modal([1700, 3500], [0.012, 0.006], [1, 0.4], 0.08, 0.0005)
    mix(y, thump(200, 0.03, 0.3))
    save("keypad", y, 0.5)
    t = T(0.4)
    save("keypad_err", np.sign(np.sin(2 * np.pi * 180 * t)) * 0.4 * adsr(len(t), 0.01, 0.05, 0.8, 0.05), 0.4)
    y = np.zeros(int(0.4 * SR))
    mix(y, latch(0.5))
    mix(y, bp(noise(0.05), 2000, 8000) * 0.5, 0.05)
    mix(y, latch(0.4), 0.12)
    save("camera_shutter", y, 0.5)


# ---------------------------------------------------------------- атмосфера и музыка

def drone(sec, freqs, amps, wob=0.1):
    t = T(sec)
    y = np.zeros(len(t))
    for f, a in zip(freqs, amps):
        fm = f * (1 + 0.003 * np.sin(2 * np.pi * wob * t + rng.uniform(0, 6)))
        ph = np.cumsum(2 * np.pi * fm / SR)
        saw = (ph / np.pi) % 2 - 1
        y += lp(saw, f * 4) * a
    return y


def piano(f, sec=4.0, amp=1.0):
    t = T(sec)
    y = np.zeros(len(t))
    for h in range(1, 8):
        fh = f * h * np.sqrt(1 + 0.0004 * h * h)
        y += np.sin(2 * np.pi * fh * t) * np.exp(-t * (0.6 + h * 0.5)) / h
    y += lp(noise(sec), 3000) * np.exp(-t / 0.01) * 0.05
    return y * amp


def make_amb_music():
    # гул здания: низкий фон, вода в трубах, редкие скрипы
    sec = 30.0
    y = lp(brown(sec), 90) * 0.5 + drone(sec, [49.5, 99.2, 148.6], [0.15, 0.06, 0.03], 0.05)
    y += bp(pink(sec), 200, 700) * 0.05 * (1 + np.sin(2 * np.pi * 0.05 * T(sec)))
    for k in range(5):
        mix(y, creak(rng.uniform(1.5, 3.0), rng.uniform(100, 180), rng.uniform(80, 140), 0.08, True), rng.uniform(1, 26))
    for k in range(6):
        mix(y, pipe_hit(0.05, rng.uniform(150, 250)), rng.uniform(1, 28))
    save("loop_amb_building", reverb(y, 3.0, 0.35, 2000, 1.4)[:int(sec * SR)], 0.6, loop=True)
    # меню: тёмный дрон и редкие ноты расстроенного пианино
    sec = 48.0
    y = drone(sec, [55, 82.4, 110, 164.8], [0.3, 0.15, 0.1, 0.05], 0.03) * 0.6
    notes = [220, 261.6, 207.7, 196, 233.1, 174.6]
    for k in range(12):
        mix(y, piano(notes[k % len(notes)] * rng.choice([1, 0.5]) * (1 + rng.uniform(-0.006, 0.006)), 5.0, 0.6), 2 + k * 3.8)
    y += drops(sec, 0.4, 900, 2000, 0.4)
    save("mus_menu", reverb(y, 4.0, 0.45, 3000, 0.9)[:int(sec * SR)], 0.6, loop=True)
    # напряжение: низкие пульсации, кластер
    sec = 24.0
    t = T(sec)
    pulse = (np.sin(2 * np.pi * 0.75 * t) > 0.8).astype(float)
    pulse = lp(pulse, 30) * np.sin(2 * np.pi * 41 * t)
    y = pulse * 0.6 + drone(sec, [61.7, 65.4, 92.5, 98], [0.15, 0.12, 0.08, 0.06], 0.08) * 0.8
    y += bp(noise(sec), 2000, 6000) * 0.02 * (1 + np.sin(2 * np.pi * 0.1 * t))
    save("mus_tension", reverb(y, 3.0, 0.4, 2500, 1.2)[:int(sec * SR)], 0.7, loop=True)
    # погоня: быстрый пульс, тремоло струнных, удары
    sec = 16.0
    t = T(sec)
    bpm = 150
    beat = 60 / bpm
    y = np.zeros(len(t))
    for k in range(int(sec / beat)):
        mix(y, thump(48, 0.18, 1.0), k * beat)
        if k % 2 == 1:
            mix(y, bp(noise(0.08), 1500, 6000) * env_exp(int(0.08 * SR), 0.02) * 0.4, k * beat)
    trem = (0.5 + 0.5 * np.sin(2 * np.pi * 12 * t))
    strings = drone(sec, [196, 207.7, 293.7, 311.1], [0.2, 0.2, 0.15, 0.15], 0.5) * trem
    y += hp(strings, 150) * 0.8
    for k in range(4):
        mix(y, creak(1.5, 2200, 1400, 0.25, False), k * 4.0 + 1.0)
    save("mus_chase", reverb(y, 1.5, 0.25, 4000, 2.5)[:int(sec * SR)], 0.85, loop=True)
    # финал: медленное пианино
    sec = 60.0
    y = drone(sec, [65.4, 98, 130.8], [0.15, 0.1, 0.06], 0.02) * 0.5
    melody = [261.6, 311.1, 392, 349.2, 311.1, 293.7, 261.6, 233.1, 261.6, 196, 207.7, 196]
    for k, f in enumerate(melody):
        mix(y, piano(f, 6.0, 0.7), 1.5 + k * 3.2)
        mix(y, piano(f / 2, 6.0, 0.35), 1.5 + k * 3.2)
        if k % 3 == 0:
            mix(y, piano(f * 1.5, 6.0, 0.25), 3.1 + k * 3.2)
    save("mus_ending", reverb(y, 4.0, 0.5, 3500, 0.8)[:int(sec * SR)], 0.6, loop=True)
    # стингеры
    y = np.zeros(int(4.0 * SR))
    sw = drone(3.5, [110, 116.5, 155.6], [0.3, 0.3, 0.2], 0.2) * np.linspace(0, 1, int(3.5 * SR)) ** 2
    mix(y, sw)
    save("sting_soft", reverb(y, 2.5, 0.4), 0.6)
    y = np.zeros(int(3.0 * SR))
    for f in [233.1, 246.9, 349.2, 370]:
        mix(y, np.sin(2 * np.pi * f * T(2.5)) * env_exp(int(2.5 * SR), 0.6) * 0.4)
    mix(y, creak(0.8, 3000, 2000, 0.5, False))
    mix(y, thump(50, 0.3, 1.0))
    save("sting_mirror", reverb(y, 2.0, 0.4), 0.9)


def main():
    os.makedirs(OUT, exist_ok=True)
    make_steps()
    make_body()
    make_doors()
    make_water()
    make_pipes()
    make_monster()
    make_story()
    make_ui()
    make_amb_music()
    print("готово")


if __name__ == "__main__":
    main()
