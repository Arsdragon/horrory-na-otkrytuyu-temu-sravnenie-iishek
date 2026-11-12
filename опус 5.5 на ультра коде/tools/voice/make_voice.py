"""Голос Хозяйки: фразы Windows TTS (Irina) → хриплый шёпот (LPC с шумовым возбуждением), замедление,
низкий «скрежещущий» слой, мокрые щелчки, эхо кафельной мыльной. Результат — snd/hoz_whisper_N.ogg,
snd/phone_call.ogg.

    python tools/voice/make_voice.py
"""
import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "snd")
SR = 22050
rng = np.random.default_rng(13)

PHRASES = [
    "Иди мыться.", "Чистенький.", "Пар готов.", "С лёгким паром.", "Мой хороший.",
    "Третий пар мой.", "Где ты.", "Не прячься.",
]


def tts(text, path, rate=-3):
    ps = f"""
Add-Type -AssemblyName System.Speech
$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
$s.SelectVoice('Microsoft Irina Desktop')
$s.Rate = {rate}
$f = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo({SR}, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
$s.SetOutputToWaveFile('{path}', $f)
$s.Speak('{text}')
$s.Dispose()
"""
    subprocess.run(["powershell", "-NoProfile", "-Command", ps], check=True, capture_output=True)


def read_wav(path):
    with wave.open(path) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32768.0
    return x


def lpc(frame, order):
    r = np.correlate(frame, frame, "full")[len(frame) - 1:len(frame) + order]
    if r[0] <= 1e-9:
        return np.r_[1.0, np.zeros(order)], 0.0
    a = np.zeros(order + 1)
    a[0] = 1.0
    e = r[0]
    for i in range(1, order + 1):
        k = -(r[i] + np.dot(a[1:i], r[i - 1:0:-1])) / e
        a[1:i] = a[1:i] + k * a[i - 1:0:-1]
        a[i] = k
        e *= (1 - k * k)
    return a, e


def whisperize(x, order=18):
    n = int(0.03 * SR)
    hop = n // 2
    win = np.hanning(n)
    out = np.zeros(len(x) + n)
    pre = signal.lfilter([1, -0.95], [1], x)
    for i in range(0, len(x) - n, hop):
        fr = pre[i:i + n] * win
        a, e = lpc(fr, order)
        g = np.sqrt(max(e, 0) / n)
        exc = rng.normal(0, 1, n) * g
        y = signal.lfilter([1], a, exc)
        out[i:i + n] += y * win
    out = signal.lfilter([1], [1, -0.95], out)
    return out[:len(x)]


def reverb(x, secs=1.4, wet=0.35):
    n = int(secs * SR)
    t = np.arange(n) / SR
    ir = rng.normal(0, 1, n) * np.exp(-t * 4.5)
    ir = signal.lfilter(*signal.butter(2, 3500 / (SR / 2)), ir)
    ir /= np.abs(ir).sum() ** 0.5 * 10
    y = signal.fftconvolve(x, ir)[:len(x) + n]
    out = np.zeros(len(y))
    out[:len(x)] += x
    return out * (1 - wet) + y * wet * 3


def norm(x, peak=0.9):
    m = np.abs(x).max()
    return x * (peak / m) if m > 0 else x


def save_ogg(x, name, sr=SR):
    x = np.clip(x, -1, 1)
    tmp = os.path.join(tempfile.gettempdir(), name + ".wav")
    with wave.open(tmp, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(tmp)


def creepy(x):
    w = whisperize(x)
    # замедлить на 18% (ниже, старше)
    w = signal.resample(w, int(len(w) * 1.18))
    # скрежещущий слой: тот же шёпот на кварту ниже, рваный
    low = signal.resample(w, int(len(w) * 1.35))[:len(w)]
    gate = (rng.random(len(low) // 200 + 1) > 0.3).repeat(200)[:len(low)]
    low = low * gate * 0.35
    y = w + np.pad(low, (0, max(0, len(w) - len(low))))[:len(w)]
    # мокрые щелчки рта
    for _ in range(rng.integers(2, 5)):
        p = rng.integers(0, len(y) - 300)
        click = rng.normal(0, 1, 120) * np.exp(-np.arange(120) / 15)
        y[p:p + 120] += signal.lfilter(*signal.butter(2, [1500 / (SR / 2), 5000 / (SR / 2)], "band"), click) * 0.6
    y = signal.lfilter(*signal.butter(2, 120 / (SR / 2), "high"), y)
    pad = np.zeros(int(0.25 * SR))
    y = np.concatenate([pad, y, pad])
    return norm(reverb(y), 0.85)


def phone_band(x):
    b, a = signal.butter(4, [350 / (SR / 2), 3200 / (SR / 2)], "band")
    y = signal.lfilter(b, a, x)
    return np.tanh(y * 2.5) * 0.6


def main():
    os.makedirs(OUT, exist_ok=True)
    tmpd = tempfile.mkdtemp()
    whispers = []
    for i, ph in enumerate(PHRASES):
        p = os.path.join(tmpd, f"v{i}.wav")
        tts(ph, p, -4)
        x = read_wav(p)
        y = creepy(x)
        whispers.append(y)
        save_ogg(y, f"hoz_whisper_{i + 1}")
        print("шёпот", i + 1, ph)
    # звонок: капли, дыхание, «пар… готов»
    dur = 9.0
    n = int(dur * SR)
    call = np.zeros(n)
    t = np.arange(n) / SR
    call += rng.normal(0, 1, n) * 0.012
    for k in range(18):
        p = int(rng.uniform(0, dur - 0.2) * SR)
        f0 = rng.uniform(900, 2200)
        m = int(0.08 * SR)
        tt = np.arange(m) / SR
        call[p:p + m] += np.sin(2 * np.pi * f0 * tt * (1 + tt * 6)) * np.exp(-tt * 60) * 0.25
    for k in range(3):
        p = int((0.6 + k * 1.6) * SR)
        m = int(1.1 * SR)
        env = np.sin(np.linspace(0, np.pi, m)) ** 2
        br = signal.lfilter(*signal.butter(2, [300 / (SR / 2), 1800 / (SR / 2)], "band"), rng.normal(0, 1, m)) * env * 0.5
        call[p:p + m] += br
    w = whispers[2]
    p0 = int(5.2 * SR)
    seg = w[:min(len(w), n - p0)]
    call[p0:p0 + len(seg)] += seg * 1.1
    save_ogg(norm(phone_band(call), 0.8), "phone_call")
    print("звонок")


if __name__ == "__main__":
    main()
