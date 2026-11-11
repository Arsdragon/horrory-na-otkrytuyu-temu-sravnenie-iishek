"""Кирпичики синтеза: шум, фильтры, огибающие, резонаторы, эхо, запись в OGG."""
import os, subprocess, tempfile
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "snd")
TMP = tempfile.mkdtemp(prefix="leer_snd_")
RNG = np.random.default_rng(1987)


def rng(seed=None):
    return RNG if seed is None else np.random.default_rng(seed)


def secs(t):
    return int(round(t * SR))


def tt(dur):
    return np.arange(secs(dur)) / SR


def white(n, r=None):
    return (r or RNG).standard_normal(n)


def pink(n, r=None):
    x = np.fft.rfft((r or RNG).standard_normal(n))
    f = np.fft.rfftfreq(n)
    f[0] = f[1] if n > 1 else 1.0
    x /= np.sqrt(f)
    y = np.fft.irfft(x, n)
    return y / (np.abs(y).max() + 1e-9)


def brown(n, r=None):
    x = np.fft.rfft((r or RNG).standard_normal(n))
    f = np.fft.rfftfreq(n)
    f[0] = f[1] if n > 1 else 1.0
    x /= f
    x[0] = 0
    y = np.fft.irfft(x, n)
    return y / (np.abs(y).max() + 1e-9)


def lp(x, fc, order=2):
    sos = signal.butter(order, min(fc, SR * 0.49) / (SR / 2), "low", output="sos")
    return signal.sosfilt(sos, x, axis=0)


def hp(x, fc, order=2):
    sos = signal.butter(order, max(fc, 5.0) / (SR / 2), "high", output="sos")
    return signal.sosfilt(sos, x, axis=0)


def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [max(lo, 5.0) / (SR / 2), min(hi, SR * 0.49) / (SR / 2)], "band", output="sos")
    return signal.sosfilt(sos, x, axis=0)


def peak(x, f, q):
    """Резонатор (полосовой пик)."""
    b, a = signal.iirpeak(min(f, SR * 0.45) / (SR / 2), q)
    return signal.lfilter(b, a, x)


def smooth_rand(n, rate_hz, r=None, lo=0.0, hi=1.0):
    """Плавная случайная кривая: шум, пропущенный через НЧ rate_hz. Значения lo..hi."""
    r = r or RNG
    k = max(4, int(n / SR * rate_hz * 2) + 4)
    pts = r.uniform(0, 1, k)
    # косинусная интерполяция между опорными точками: гладко и мгновенно
    pos = np.linspace(0, k - 1, n)
    i0 = np.minimum(pos.astype(int), k - 2)
    f = pos - i0
    f = (1 - np.cos(f * np.pi)) * 0.5
    x = pts[i0] * (1 - f) + pts[i0 + 1] * f
    x -= x.min()
    x /= x.max() + 1e-9
    return lo + (hi - lo) * x


def sweep_bp(x, f_curve, q=8.0, block=128):
    """Полосовой фильтр с плывущей частотой (вой ветра, скрип): биквад по блокам с переносом состояния."""
    n = len(x)
    y = np.zeros(n)
    f_curve = np.broadcast_to(np.asarray(f_curve, dtype=np.float64), (n,))
    zi = np.zeros(2)
    for i in range(0, n, block):
        j = min(n, i + block)
        f = float(np.clip(f_curve[i:j].mean(), 20.0, SR * 0.45))
        w0 = 2 * np.pi * f / SR
        alpha = np.sin(w0) / (2 * q)
        a0 = 1 + alpha
        b = np.array([alpha, 0.0, -alpha]) / a0
        a = np.array([1.0, -2 * np.cos(w0) / a0, (1 - alpha) / a0])
        y[i:j], zi = signal.lfilter(b, a, x[i:j], zi=zi)
    return y


def env_exp(n, decay_s, attack_s=0.002):
    t = np.arange(n) / SR
    e = np.exp(-t / max(decay_s, 1e-4))
    a = max(1, int(attack_s * SR))
    e[:a] *= np.linspace(0, 1, a)
    return e


def fade(x, fin=0.005, fout=0.02):
    x = np.array(x, dtype=np.float64)
    a = min(len(x) // 2, max(1, secs(fin)))
    b = min(len(x) // 2, max(1, secs(fout)))
    ramp_in = np.linspace(0, 1, a)
    ramp_out = np.linspace(1, 0, b)
    if x.ndim == 2:
        ramp_in = ramp_in[:, None]
        ramp_out = ramp_out[:, None]
    x[:a] *= ramp_in
    x[-b:] *= ramp_out
    return x


def norm(x, pk=0.9):
    return x / (np.abs(x).max() + 1e-9) * pk


def modal(n, modes, r=None):
    """Удар по предмету: сумма затухающих синусов. modes — [(частота, затухание с, громкость)]."""
    t = np.arange(n) / SR
    y = np.zeros(n)
    r = r or RNG
    for f, d, a in modes:
        y += a * np.sin(2 * np.pi * f * t + r.uniform(0, 6.28)) * np.exp(-t / d)
    return y


def click(n, f_lo=1500, f_hi=6000, decay=0.004, r=None):
    return bp(white(n, r), f_lo, f_hi) * env_exp(n, decay, 0.0005)


def reverb(x, sec, wet, damp=3500, pre=0.0, seed=5):
    r = np.random.default_rng(seed)
    n = secs(sec)
    ir = r.standard_normal(n) * np.exp(-np.arange(n) / SR * (6.9 / sec))
    ir = lp(ir, damp)
    ir /= np.sqrt((ir ** 2).sum()) + 1e-9
    if pre > 0:
        ir = np.concatenate([np.zeros(secs(pre)), ir])
    y = signal.fftconvolve(x, ir)
    out = np.zeros(len(y))
    out[:len(x)] += x * (1 - wet)
    out += y * wet
    return out


def stereo_reverb(x, sec, wet, damp=3500, pre=0.0):
    l = reverb(x, sec, wet, damp, pre, 5)
    r = reverb(x, sec, wet, damp, pre, 9)
    return np.stack([l, r], axis=1)


def loopify(x, xf=1.0):
    """Бесшовная петля: хвост перекрёстно вмешивается в начало."""
    n = secs(xf)
    if x.ndim == 1:
        head, tail = x[:n], x[-n:]
        k = np.linspace(0, 1, n)
        mixed = head * np.sqrt(k) + tail * np.sqrt(1 - k)
        return np.concatenate([mixed, x[n:-n]])
    k = np.linspace(0, 1, n)[:, None]
    mixed = x[:n] * np.sqrt(k) + x[-n:] * np.sqrt(1 - k)
    return np.concatenate([mixed, x[n:-n]])


def place(buf, x, at_s, gain=1.0):
    """Вставить звук x в буфер buf с момента at_s."""
    i = secs(at_s)
    if i >= len(buf):
        return
    m = min(len(x), len(buf) - i)
    buf[i:i + m] += x[:m] * gain


def to_stereo(x, width=0.0, seed=3):
    """Моно → стерео; width > 0 добавляет несвязанную разницу каналов (для шумов)."""
    if x.ndim == 2:
        return x
    if width <= 0:
        return np.stack([x, x], axis=1)
    d = signal.fftconvolve(x, np.random.default_rng(seed).standard_normal(64) * np.hanning(64), mode="same")
    d = d / (np.abs(d).max() + 1e-9) * np.abs(x).max()
    return np.stack([x * (1 - width * 0.5) + d * width * 0.5, x * (1 - width * 0.5) - d * width * 0.5], axis=1)


def soft(x, drive=1.5):
    return np.tanh(x * drive) / np.tanh(drive)


def save(name, x, pk=0.9, q=4):
    """Записать snd/<name>.ogg. x — моно или стерео, любая амплитуда (нормализуется к pk)."""
    os.makedirs(OUT, exist_ok=True)
    x = np.nan_to_num(np.asarray(x, dtype=np.float64))
    if pk > 0:
        x = norm(x, pk)
    x = np.clip(x, -1.0, 1.0)
    tw = os.path.join(TMP, name + ".wav")
    wavfile.write(tw, SR, (x * 32767).astype(np.int16))
    to = os.path.join(TMP, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tw, "-c:a", "libvorbis", "-q:a", str(q), to], check=True)
    dst = os.path.join(OUT, name + ".ogg")
    with open(to, "rb") as f:
        data = f.read()
    with open(dst, "wb") as f:
        f.write(data)
    os.remove(tw)
    os.remove(to)
    dur = len(x) / SR
    rms = float(np.sqrt((x ** 2).mean()))
    print(f"   {name}: {dur:.2f}s rms={rms:.3f}", flush=True)
