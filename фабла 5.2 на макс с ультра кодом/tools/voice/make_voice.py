"""Голоса: «Диксон» по станционной рации, «Громов» по рации на груди, номерная станция.
Windows TTS (Павел, Ирина) → обработка «под эфир» → voice/<ключ>.ogg. Тексты берутся из src/texts.gd (VOICE).

    python tools/voice/make_voice.py [ключи…]
"""
import json, os, re, subprocess, sys, tempfile
import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "voice")
SR = 44100
R = np.random.default_rng(7)

src = open(os.path.join(ROOT, "src", "texts.gd"), encoding="utf-8").read()
block = src[src.index("const VOICE"):]
block = block[:block.index("\n}")]
lines = dict(re.findall(r'"([a-z0-9_]+)":\s*"([^"]*)"', block))
want = [k for k in lines if not sys.argv[1:] or k in sys.argv[1:]]


def params(k):
    if k.startswith("num_"):
        return "Irina", 0.78, 0.95
    if k.startswith("gr_"):
        return "Pavel", 0.86, 0.72
    return "Pavel", 0.92, 0.9


tmp = tempfile.mkdtemp(prefix="leer_voice_")
items = []
for k in want:
    v, rate, pitch = params(k)
    items.append({"key": k, "text": lines[k], "voice": v, "rate": rate, "pitch": pitch, "out": os.path.join(tmp, k + ".wav")})
jp = os.path.join(tmp, "lines.json")
json.dump(items, open(jp, "w", encoding="utf-8"), ensure_ascii=False)
ps = os.path.join(ROOT, "tools", "voice", "tts.ps1")
r = subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ps, "-Json", jp], capture_output=True, text=True, encoding="utf-8", errors="replace")
print(r.stdout[-1500:], r.stderr[-1500:])


def bp(x, lo, hi):
    sos = signal.butter(2, [lo / (SR / 2), hi / (SR / 2)], "band", output="sos")
    return signal.sosfilt(sos, x)


def lp(x, fc):
    sos = signal.butter(2, fc / (SR / 2), "low", output="sos")
    return signal.sosfilt(sos, x)


def load(path):
    sr, d = wavfile.read(path)
    d = d.astype(float)
    if d.ndim > 1:
        d = d.mean(axis=1)
    d /= (np.abs(d).max() + 1e-9)
    if sr != SR:
        d = signal.resample_poly(d, SR, sr)
    return d


def wobble(x, depth=0.012, rate=0.7):
    """Голос чуть плывёт по высоте — как лента или как тот, кто только учится говорить."""
    n = len(x)
    t = np.arange(n) / SR
    pos = np.cumsum(1.0 + depth * np.sin(2 * np.pi * rate * t) + depth * 0.5 * np.sin(2 * np.pi * rate * 2.7 * t + 1.0))
    pos = pos / pos[-1] * (n - 1)
    return np.interp(pos, np.arange(n), x)


def ghost(x, sec=0.35, wet=0.3):
    """Обратное эхо: слово «всасывается» из тишины раньше, чем сказано."""
    n = int(sec * SR)
    ir = R.standard_normal(n) * np.exp(-np.arange(n) / SR * (6.9 / sec))
    ir = lp(ir, 3000)
    ir /= np.sqrt((ir ** 2).sum())
    y = signal.fftconvolve(x[::-1], ir)[::-1]
    out = np.zeros(len(y))
    out[-len(x):] += x * (1 - wet)
    out += y * wet
    return out


def stutter(x, times=3):
    """Заикание: короткие куски повторяются."""
    out = []
    i = 0
    n = len(x)
    marks = sorted(R.uniform(0.15, 0.85, times) * n)
    for m in marks:
        m = int(m)
        if m <= i:
            continue
        out.append(x[i:m])
        sl = int(R.uniform(0.05, 0.11) * SR)
        chunk = x[max(m - sl, 0):m]
        for _ in range(int(R.integers(2, 4))):
            out.append(chunk)
        i = m
    out.append(x[i:])
    return np.concatenate(out)


def static(n, lo, hi, level):
    crack = lp(np.abs(R.standard_normal(n)), 30.0)
    crack = (crack / crack.max()) ** 2
    return bp(R.standard_normal(n), lo, hi) * (0.4 + 0.6 * crack) * level


os.makedirs(OUT, exist_ok=True)
for it in items:
    if not os.path.exists(it["out"]):
        print("нет", it["out"])
        continue
    x = load(it["out"])
    k = it["key"]
    pad = np.zeros(int(0.3 * SR))
    if k.startswith("dx_"):
        y = wobble(x, 0.010, 0.6)
        y = bp(y, 350, 2800)
        y = np.tanh(y * 3.0)
        if k in ("dx_n3_b", "dx_n5_b", "dx_n5_c"):
            y = stutter(y, 2)
        y = np.concatenate([pad, y, pad])
        y = y * 0.8 + static(len(y), 400, 4500, 0.16)
        cl = R.standard_normal(int(0.04 * SR)) * 0.5
        y[:len(cl)] += cl
        y[-len(cl):] += cl
    elif k.startswith("gr_"):
        y = wobble(x, 0.02, 0.45)
        if k in ("gr_n3_f", "gr_n3_d", "gr_n4_d"):
            y = stutter(y, 3)
        y = ghost(y, 0.4, 0.28)
        y = bp(y, 300, 3300)
        y = np.tanh(y * 5.0)
        y = np.concatenate([pad, y, pad])
        t = np.arange(len(y)) / SR
        y *= 0.8 + 0.2 * np.sign(np.sin(2 * np.pi * 43 * t))
        y = y * 0.8 + static(len(y), 500, 4500, 0.22)
        sq = bp(R.standard_normal(int(0.2 * SR)), 500, 4500) * np.exp(-np.arange(int(0.2 * SR)) / SR / 0.06) * 0.9
        y[:len(sq)] += sq
        y[-len(sq):] += sq[::-1]
    else:
        y = bp(x, 400, 2400)
        y = np.tanh(y * 2.0)
        y = np.concatenate([pad, y, pad])
        y = y * 0.7 + static(len(y), 300, 3200, 0.28)
        t = np.arange(len(y)) / SR
        y *= 0.75 + 0.25 * np.sin(2 * np.pi * 0.31 * t)
    y = y / (np.abs(y).max() + 1e-9) * 0.9
    tw = os.path.join(tmp, "p_" + k + ".wav")
    wavfile.write(tw, SR, (y * 32767).astype(np.int16))
    to = os.path.join(tmp, k + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tw, "-c:a", "libvorbis", "-q:a", "4", to], check=True)
    with open(to, "rb") as f:
        data = f.read()
    with open(os.path.join(OUT, k + ".ogg"), "wb") as f:
        f.write(data)
    print("  ", k, f"{len(y) / SR:.1f}s")
