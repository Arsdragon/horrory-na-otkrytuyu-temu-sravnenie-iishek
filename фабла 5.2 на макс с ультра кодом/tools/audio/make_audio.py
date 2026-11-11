"""Весь звук игры синтезируется здесь → snd/*.ogg

    python tools/audio/make_audio.py            всё
    python tools/audio/make_audio.py wind steps только группы

Группы: wind steps doors knocks machines radio body stings entity world ui music
Звуки с суффиксом _N — варианты одного звука. Петли зацикливает игра (Snd.loop / Snd.emitter).
"""
import sys
import numpy as np
from synth import *


# ------------------------------------------------------------------ общие заготовки

def creak(r, dur, f0, f1, jitter=0.1, bright=1.0, rough=9.0):
    """Скрип: пила с дрожащим периодом, рваная огибающая «трение-срыв», два резонанса."""
    n = secs(dur)
    f = np.linspace(f0, f1, n) * (1 + smooth_rand(n, 13, r, -jitter, jitter))
    ph = np.cumsum(f) / SR
    saw = 2 * (ph % 1.0) - 1
    gate = lp((smooth_rand(n, rough, r) > 0.38).astype(float), 70)
    y = hp(saw, 300)
    y = peak(y, 950 * bright, 4) * 0.8 + peak(y, 2300 * bright, 6) * 0.6 + y * 0.15
    y *= gate * smooth_rand(n, 4, r, 0.4, 1.0)
    return fade(y, 0.01, 0.05)


def knock(r, heavy=0.0):
    """Удар костяшками (heavy=0) или кулаком (heavy=1) по деревянной двери."""
    n = secs(0.4)
    base = 118 - 40 * heavy + r.uniform(-4, 4)
    y = modal(n, [(base, 0.07 + 0.06 * heavy, 1.0), (base * 2.1, 0.05, 0.6), (base * 3.7, 0.03, 0.35), (base * 5.9, 0.02, 0.15)], r)
    y += click(n, 1200, 4500 - 2200 * heavy, 0.004, r) * (0.75 - 0.45 * heavy)
    return y


def crunch(r, dur=0.3, thud=92.0, squeak=True, weight=1.0):
    """Шаг по морозному снегу: зернистый хруст, глухой удар, морозный писк."""
    n = secs(dur)
    g = np.zeros(n)
    k = int(r.integers(45, 80))
    pos = (r.uniform(0, 1, k) ** 1.6 * 0.62 * n).astype(int)
    g[pos] += r.uniform(0.3, 1.0, k) * r.choice([-1.0, 1.0], k)
    g = bp(g, 700, 6500) * 6.0
    body = bp(white(n, r), 450, 4200) * env_exp(n, 0.07 * weight, 0.004)
    low = np.sin(2 * np.pi * thud * np.arange(n) / SR) * env_exp(n, 0.05 * weight, 0.003) * 0.9 * weight
    y = g * env_exp(n, 0.11 * weight, 0.003) + body * 0.7 + low
    if squeak:
        f = np.linspace(r.uniform(900, 1350), r.uniform(580, 820), n)
        y += sweep_bp(white(n, r), f, 14.0) * env_exp(n, 0.09, 0.02) * 1.5
    return fade(y, 0.002, 0.04)


def diesel(rate_fn, dur, r, amp_fn=None):
    """Одноцилиндровый дизель: каждый такт — низкий «тук» и лязг клапанов. rate_fn(t) — тактов в секунду."""
    n = secs(dur)
    y = np.zeros(n)
    t = 0.0
    i = 0
    while t < dur - 0.02:
        k = max(rate_fn(t), 0.8)
        a = 1.0 if amp_fn is None else amp_fn(t)
        thump = modal(secs(0.1), [(61, 0.032, 1.0), (122, 0.022, 0.6), (197, 0.015, 0.35), (316, 0.01, 0.2)], r) * (0.85 + 0.3 * r.uniform())
        clat = bp(white(secs(0.04), r), 900, 3800) * env_exp(secs(0.04), 0.008) * (0.22 + 0.2 * r.uniform())
        place(y, thump, t, a)
        place(y, clat, t + 0.004, a)
        if i % 2 == 0:
            place(y, clat * 0.7, t + 0.5 / k, a)
        t += 1.0 / k
        i += 1
    return y


# ------------------------------------------------------------------ ветер

def g_wind():
    r = rng(11)
    n = secs(24)
    ch = []
    for _ in range(2):
        x = lp(brown(n, r), 160) + 0.4 * bp(pink(n, r), 60, 320)
        ch.append(x * smooth_rand(n, 0.25, r, 0.55, 1.0))
    save("wind_low", loopify(np.stack(ch, 1), 2.0), 0.85)

    n = secs(32)
    ch = []
    for c in range(2):
        src = pink(n, r)
        y = np.zeros(n)
        for k, (f0, f1, q) in enumerate(((200, 520, 9.0), (320, 780, 12.0), (470, 1150, 14.0))):
            fc = smooth_rand(n, 0.2, r, f0, f1)
            amp = smooth_rand(n, 0.28, r, 0.12, 1.0) ** 2
            y += sweep_bp(src, fc, q) * amp * (1.0 - 0.2 * k)
        ch.append(y)
    save("wind_howl", loopify(np.stack(ch, 1), 2.5), 0.85)

    n = secs(26)
    src = white(n, r)
    y = np.zeros(n)
    for f0, f1 in ((1250, 1900), (2100, 3100), (2900, 3600)):
        fc = smooth_rand(n, 0.35, r, f0, f1)
        gate = np.clip(smooth_rand(n, 0.33, r, -0.9, 1.0), 0, 1) ** 2
        y += sweep_bp(src, fc, 38.0) * gate
    save("wind_whistle", loopify(to_stereo(y, 0.5), 2.0), 0.7)

    # снег сечёт по капюшону: высокое зернистое шипение
    n = secs(11)
    grain = lp(np.abs(white(n, r)), 55.0)
    grain = (grain / grain.max()) ** 2
    y = hp(white(n, r), 3200) * (0.35 + 0.65 * grain) * smooth_rand(n, 0.5, r, 0.6, 1.0)
    y += bp(white(n, r), 900, 2600) * 0.12
    save("snow_hiss", loopify(to_stereo(y, 0.6), 1.2), 0.6)

    # порыв: нарастающий удар ветра
    for i in (1, 2):
        n = secs(4.2)
        t = np.arange(n) / SR
        env = np.clip(t / 1.3, 0, 1) ** 2 * np.clip((4.2 - t) / 2.4, 0, 1)
        fc = 250 + 700 * env + smooth_rand(n, 1.2, r, -60, 60)
        y = sweep_bp(pink(n, r), fc, 5.0) * env + lp(brown(n, r), 220) * env * 0.9
        save(f"gust_{i}", to_stereo(fade(y, 0.05, 0.3), 0.5), 0.9)

    # трос гудит на ветру (эолов тон)
    n = secs(12)
    f = smooth_rand(n, 0.4, r, 96, 128)
    ph = np.cumsum(f) / SR
    y = np.sin(2 * np.pi * ph) + 0.4 * np.sin(4 * np.pi * ph + 0.7) + 0.18 * np.sin(6 * np.pi * ph)
    y *= smooth_rand(n, 0.6, r, 0.2, 1.0)
    y += sweep_bp(white(n, r), f * 8.0, 30.0) * 0.5
    save("rope_hum", loopify(y, 1.5), 0.6)


# ------------------------------------------------------------------ шаги

def g_steps():
    r = rng(21)
    for i in range(1, 7):
        save(f"step_snow_{i}", crunch(r), 0.85)
    for i in range(1, 6):
        n = secs(0.34)
        y = modal(n, [(r.uniform(84, 112), 0.05, 1.0), (r.uniform(170, 235), 0.035, 0.5), (r.uniform(380, 520), 0.02, 0.25)], r)
        y += click(n, 800, 3500, 0.006, r) * 0.5
        if i % 2 == 0:
            place(y, creak(r, 0.16, r.uniform(240, 320), r.uniform(200, 380), 0.08) * 0.25, 0.05)
        save(f"step_wood_{i}", fade(reverb(y, 0.25, 0.16, 3000), 0.001, 0.05), 0.8)
    for i in range(1, 5):
        n = secs(0.22)
        y = modal(n, [(r.uniform(130, 160), 0.02, 1.0), (r.uniform(300, 380), 0.012, 0.4)], r) + click(n, 1500, 5500, 0.005, r) * 0.9
        y += bp(white(n, r), 2000, 6000) * env_exp(n, 0.03, 0.01) * 0.2
        save(f"step_conc_{i}", fade(reverb(y, 0.4, 0.2, 4000), 0.001, 0.05), 0.75)
    for i in range(1, 5):
        n = secs(0.25)
        y = click(n, 2000, 7000, 0.006, r) + modal(n, [(r.uniform(95, 120), 0.03, 0.7)], r)
        f = np.linspace(r.uniform(1700, 2400), r.uniform(1300, 1800), n)
        y += sweep_bp(white(n, r), f, 22.0) * env_exp(n, 0.05, 0.01) * 1.2
        save(f"step_ice_{i}", fade(reverb(y, 1.1, 0.3, 5000), 0.001, 0.2), 0.75)
    # существо по снегу: тяжелее, медленнее, вторым хрустом тянет ногу
    for i in range(1, 5):
        n = secs(0.75)
        y = np.zeros(n)
        place(y, crunch(r, 0.5, 56.0, False, 1.5), 0.0)
        place(y, crunch(r, 0.3, 80.0, False, 0.9), r.uniform(0.2, 0.3), 0.45)
        save(f"ent_step_{i}", fade(lp(y, 3400), 0.002, 0.05), 0.9)
    # существо по доскам: глухой удар и половица
    for i in range(1, 4):
        n = secs(0.9)
        y = modal(n, [(r.uniform(52, 64), 0.12, 1.0), (r.uniform(108, 126), 0.08, 0.6), (r.uniform(190, 230), 0.04, 0.3)], r)
        y += click(n, 500, 2200, 0.008, r) * 0.35
        place(y, creak(r, 0.42, r.uniform(150, 190), r.uniform(190, 260), 0.14, 0.8) * 0.4, 0.09)
        save(f"ent_wood_{i}", fade(reverb(y, 0.35, 0.22, 2500), 0.001, 0.1), 0.9)


# ------------------------------------------------------------------ двери

def g_doors():
    r = rng(31)
    lat = lambda: modal(secs(0.08), [(1850, 0.012, 1.0), (3200, 0.008, 0.6), (5100, 0.005, 0.3)], r) + click(secs(0.08), 2000, 7000, 0.003, r) * 0.5
    thud = lambda k=1.0: modal(secs(0.35), [(72, 0.09, 1.0), (141, 0.06, 0.6), (305, 0.03, 0.3)], r) * k

    n = secs(1.0)
    y = np.zeros(n)
    place(y, lat(), 0.0, 0.6)
    place(y, creak(r, 0.55, 230, 340, 0.12), 0.08, 0.7)
    place(y, lp(white(secs(0.5), r), 500) * env_exp(secs(0.5), 0.2, 0.1), 0.1, 0.15)
    save("door_open", fade(reverb(y, 0.3, 0.15), 0.002, 0.1), 0.8)

    n = secs(0.9)
    y = np.zeros(n)
    place(y, creak(r, 0.3, 320, 220, 0.12), 0.0, 0.5)
    place(y, thud(), 0.3)
    place(y, lat(), 0.32, 0.5)
    save("door_close", fade(reverb(y, 0.3, 0.15), 0.002, 0.1), 0.85)

    n = secs(0.7)
    y = np.zeros(n)
    for t0 in (0.0, 0.13, 0.24):
        place(y, lat(), t0, 0.7)
        place(y, thud(0.5), t0 + 0.01)
    save("door_locked", fade(reverb(y, 0.25, 0.12), 0.002, 0.1), 0.8)

    n = secs(0.8)
    y = np.zeros(n)
    sc = bp(white(secs(0.3), r), 400, 2200) * smooth_rand(secs(0.3), 30, r, 0.2, 1.0) * np.hanning(secs(0.3))
    place(y, sc, 0.0, 0.6)
    place(y, thud(0.9), 0.3)
    place(y, lat(), 0.31, 0.8)
    save("latch", fade(reverb(y, 0.25, 0.12), 0.002, 0.1), 0.85)

    n = secs(1.1)
    y = np.zeros(n)
    place(y, thud(1.3), 0.0)
    place(y, lat(), 0.02, 0.5)
    y += lp(white(n, r), 300) * env_exp(n, 0.12, 0.002) * 0.5
    save("door_slam", fade(reverb(y, 0.6, 0.25), 0.001, 0.2), 0.95)

    # тяжёлые удары в дверь снаружи
    for i in (1, 2, 3):
        n = secs(1.3)
        y = np.zeros(n)
        place(y, knock(r, 1.0) * 1.3, 0.0)
        place(y, modal(secs(0.5), [(44, 0.14, 1.0), (88, 0.08, 0.5)], r), 0.0)
        for _ in range(4):
            place(y, lat() * r.uniform(0.2, 0.5), r.uniform(0.02, 0.22))
        save(f"door_bang_{i}", fade(reverb(y, 0.55, 0.28, 2600), 0.001, 0.25), 0.95)

    # дверь выбита
    n = secs(2.0)
    y = np.zeros(n)
    place(y, knock(r, 1.0) * 1.4, 0.0)
    place(y, modal(secs(0.6), [(40, 0.18, 1.0), (79, 0.1, 0.6)], r), 0.0)
    for _ in range(14):
        f0 = r.uniform(380, 1500)
        place(y, modal(secs(0.12), [(f0, 0.018, 1.0), (f0 * 2.3, 0.01, 0.5)], r) + click(secs(0.12), 1500, 7000, 0.004, r), r.uniform(0.0, 0.5), r.uniform(0.2, 0.7))
    place(y, bp(white(secs(0.9), r), 300, 4000) * env_exp(secs(0.9), 0.25, 0.01), 0.05, 0.5)
    save("door_break", fade(reverb(y, 0.7, 0.3, 3000), 0.001, 0.3), 0.97)

    # люк ледника: мёрзлое дерево, тяжёлый скрип, удар
    n = secs(2.4)
    y = np.zeros(n)
    place(y, click(secs(0.2), 1500, 6000, 0.02, r), 0.0, 0.8)
    place(y, creak(r, 1.5, 120, 190, 0.2, 0.7, 6.0), 0.1, 0.9)
    place(y, thud(0.8), 1.7)
    save("hatch_open", fade(reverb(y, 0.9, 0.3, 2500), 0.002, 0.3), 0.9)
    n = secs(2.2)
    y = np.zeros(n)
    place(y, modal(secs(0.9), [(38, 0.22, 1.0), (61, 0.16, 0.8), (118, 0.09, 0.5), (240, 0.05, 0.25)], r), 0.0)
    place(y, lp(white(secs(0.4), r), 600) * env_exp(secs(0.4), 0.08, 0.001), 0.0, 0.8)
    save("hatch_slam", fade(reverb(y, 1.8, 0.45, 1800), 0.001, 0.5), 0.97)

    for i in (1, 2, 3):
        n = secs(0.5)
        y = modal(n, [(r.uniform(150, 190), 0.05, 1.0), (r.uniform(330, 420), 0.03, 0.5)], r) + click(n, 900, 3000, 0.006, r) * 0.4
        place(y, creak(r, 0.25, 260, 330, 0.1) * 0.3, 0.04)
        save(f"ladder_{i}", fade(reverb(y, 0.8, 0.3, 3000), 0.001, 0.2), 0.8)

    # печная дверца, щелчок выключателя, шкаф
    n = secs(0.7)
    y = np.zeros(n)
    place(y, creak(r, 0.3, 520, 700, 0.15, 1.5), 0.0, 0.5)
    place(y, modal(secs(0.3), [(310, 0.05, 1.0), (790, 0.04, 0.7), (1650, 0.025, 0.5), (2900, 0.015, 0.3)], r), 0.3)
    save("stove_door", fade(y, 0.002, 0.1), 0.8)
    n = secs(0.12)
    save("switch", fade(click(n, 1800, 6000, 0.004, r) + modal(n, [(900, 0.01, 0.5)], r), 0.0005, 0.03), 0.6)


# ------------------------------------------------------------------ стуки

def g_knocks():
    r = rng(41)

    def seq(times, heavy, dur, wet=0.25, gains=None):
        y = np.zeros(secs(dur))
        for k, t0 in enumerate(times):
            place(y, knock(r, heavy), t0, 1.0 if gains is None else gains[k])
        return fade(reverb(y, 0.45, wet, 2800), 0.001, 0.2)

    save("knock_1", seq((0.1, 0.62, 1.14), 0.1, 2.2), 0.85)
    save("knock_2", seq((0.1, 0.9, 1.7), 0.7, 3.0), 0.9)
    save("knock_3", seq((0.1, 1.5, 1.95), 0.3, 3.0), 0.85)
    save("knock_single", seq((0.05,), 0.4, 1.2), 0.85)
    t = [0.1]
    gap = 0.5
    for _ in range(8):
        t.append(t[-1] + gap)
        gap *= 0.82
    save("knock_hard", seq(t, 1.0, 4.2, 0.3), 0.95)
    # в стекло ногтем
    y = np.zeros(secs(1.8))
    for t0 in (0.1, 0.5, 0.9):
        place(y, modal(secs(0.12), [(1180, 0.02, 1.0), (2700, 0.012, 0.6), (4150, 0.008, 0.35)], r) + click(secs(0.12), 3000, 9000, 0.002, r) * 0.6, t0)
    save("knock_window", fade(reverb(y, 0.3, 0.2, 5000), 0.001, 0.2), 0.8)
    # скребёт по стене
    for i, dur in ((1, 2.4), (2, 4.2)):
        n = secs(dur)
        fc = np.linspace(r.uniform(1100, 1500), r.uniform(1700, 2300), n) + smooth_rand(n, 3, r, -200, 200)
        gate = lp((smooth_rand(n, 16, r) > 0.42).astype(float), 60) * smooth_rand(n, 1.5, r, 0.3, 1.0)
        y = sweep_bp(white(n, r), fc, 3.0) * gate + bp(white(n, r), 300, 900) * gate * 0.4
        save(f"scratch_{i}", fade(reverb(y, 0.35, 0.2, 3000), 0.05, 0.3), 0.75)


# ------------------------------------------------------------------ механизмы

def g_machines():
    r = rng(51)
    # дизель: петля ровно на 96 тактов
    dur = 4.0
    y = diesel(lambda t: 24.0, dur, r)
    n = len(y)
    y += lp(brown(n, r), 130) * 0.35
    tt_ = np.arange(n) / SR
    y += 0.03 * np.sin(2 * np.pi * 720 * tt_) + 0.015 * np.sin(2 * np.pi * 1440 * tt_)
    save("gen_loop", loopify(reverb(y, 0.3, 0.2, 3000)[:n], 0.25), 0.85)

    # рывок шнура: трещотка и два тяжёлых оборота — не схватил
    def pull():
        m = secs(0.7)
        p = np.zeros(m)
        t0 = 0.0
        gap = 0.012
        while t0 < 0.42:
            place(p, click(secs(0.02), 1500, 6000, 0.003, r), t0, r.uniform(0.3, 0.6))
            t0 += gap
            gap *= 1.035
        place(p, lp(white(secs(0.4), r), 900) * np.hanning(secs(0.4)), 0.0, 0.25)
        return p
    n = secs(1.6)
    y = np.zeros(n)
    place(y, pull(), 0.0)
    place(y, diesel(lambda t: 6.0 - t * 3.5, 0.9, r, lambda t: 1.0 - t * 0.9), 0.3, 0.8)
    save("gen_pull", fade(reverb(y, 0.3, 0.2, 3000), 0.002, 0.2), 0.85)
    # схватил: обороты растут до рабочих
    n = secs(3.4)
    y = np.zeros(n)
    place(y, pull(), 0.0)
    place(y, diesel(lambda t: 6.0 + min(t / 2.2, 1.0) ** 0.7 * 18.0, 3.1, r, lambda t: 0.6 + 0.4 * min(t / 1.5, 1.0)), 0.3)
    y += np.concatenate([np.zeros(secs(0.3)), lp(brown(n - secs(0.3), r), 130) * np.linspace(0, 0.35, n - secs(0.3))])
    save("gen_start", fade(reverb(y, 0.3, 0.2, 3000)[:n], 0.002, 0.05), 0.9)
    # заглох: обороты падают, чихает
    n = secs(3.3)
    y = diesel(lambda t: 24.0 * max(1.0 - t / 2.9, 0.06) ** 0.8, 3.0, r, lambda t: max(1.0 - t / 3.2, 0.0) * (0.6 + 0.4 * float(np.sin(t * 9.0) > -0.5)))
    y = np.concatenate([y, np.zeros(n - len(y))])
    place(y, modal(secs(0.3), [(92, 0.06, 1.0), (410, 0.03, 0.4)], r), 2.95, 0.6)
    save("gen_stop", fade(reverb(y, 0.4, 0.2, 3000)[:n], 0.002, 0.3), 0.9)

    # солярка льётся: бульканье
    n = secs(3.6)
    y = np.zeros(n)
    t0 = 0.0
    while t0 < 3.5:
        m = secs(r.uniform(0.09, 0.16))
        f = np.linspace(r.uniform(170, 240), r.uniform(260, 380), m)
        g = sweep_bp(white(m, r), f, 7.0) * np.hanning(m)
        place(y, g, t0, r.uniform(0.5, 1.0))
        t0 += r.uniform(0.1, 0.19)
    y += bp(white(n, r), 700, 3000) * smooth_rand(n, 6, r, 0.05, 0.14)
    save("fuel_pour", loopify(y, 0.4), 0.75)
    # ручной насос: скрип и всхлип
    for i in (1, 2, 3):
        n = secs(0.95)
        y = np.zeros(n)
        place(y, creak(r, 0.4, r.uniform(380, 460), r.uniform(520, 640), 0.12, 1.3), 0.0, 0.6)
        m = secs(0.45)
        place(y, sweep_bp(white(m, r), np.linspace(300, 900, m), 4.0) * np.hanning(m), 0.42, 0.8)
        place(y, modal(secs(0.15), [(520, 0.03, 1.0), (1300, 0.02, 0.5)], r), 0.4, 0.5)
        save(f"pump_{i}", fade(y, 0.002, 0.1), 0.8)
    for i in (1, 2):
        n = secs(0.6)
        y = modal(n, [(r.uniform(170, 200), 0.12, 1.0), (r.uniform(400, 450), 0.09, 0.7), (r.uniform(700, 780), 0.06, 0.5), (1210, 0.04, 0.35), (2100, 0.02, 0.2)], r)
        y += click(n, 1500, 6000, 0.004, r) * 0.6
        save(f"can_clank_{i}", fade(y, 0.001, 0.15), 0.8)

    # печь: треск и ровный гул тяги
    n = secs(13)
    y = lp(brown(n, r), 260) * smooth_rand(n, 0.8, r, 0.25, 0.45)
    for _ in range(150):
        m = secs(r.uniform(0.004, 0.03))
        place(y, bp(white(m, r), 900, 7000) * env_exp(m, r.uniform(0.001, 0.008), 0.0003), r.uniform(0, 12.9), r.uniform(0.15, 1.0) ** 2)
    save("fire_loop", loopify(to_stereo(y, 0.3), 1.0), 0.7)
    n = secs(0.5)
    y = np.zeros(n)
    place(y, knock(r, 0.3) * 0.8, 0.0)
    place(y, knock(r, 0.1) * 0.6, r.uniform(0.13, 0.2))
    save("wood_put", fade(y, 0.001, 0.1), 0.8)
    n = secs(1.1)
    y = np.zeros(n)
    m = secs(0.16)
    place(y, hp(white(m, r), 2500) * np.hanning(m) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 85 * np.arange(m) / SR))), 0.0)
    m = secs(0.8)
    place(y, bp(white(m, r), 400, 5000) * env_exp(m, 0.18, 0.04), 0.14, 0.9)
    save("match", fade(y, 0.002, 0.2), 0.7)
    # бочка занялась: «вумп»
    n = secs(1.6)
    y = lp(white(n, r), 500) * env_exp(n, 0.35, 0.08) + bp(white(n, r), 800, 5000) * env_exp(n, 0.5, 0.15) * 0.4
    y += modal(n, [(52, 0.25, 1.0)], r) * 0.8
    save("ignite", fade(y, 0.002, 0.4), 0.9)

    # вертолёт Ми-8: лопасти 16 Гц, турбина, гул
    dur = 4.0
    n = secs(dur)
    tt_ = np.arange(n) / SR
    blade = np.clip(np.sin(2 * np.pi * 16.0 * tt_), 0, 1) ** 3
    y = lp(white(n, r), 380) * (0.25 + 0.75 * blade) * 1.4 + lp(brown(n, r), 110) * 0.6
    y += (np.sin(2 * np.pi * 1840 * tt_) * 0.03 + np.sin(2 * np.pi * 3110 * tt_) * 0.02) * (1 + 0.3 * np.sin(2 * np.pi * 0.7 * tt_))
    y += bp(white(n, r), 2500, 7000) * 0.05 * (0.5 + 0.5 * blade)
    save("heli_loop", loopify(to_stereo(y, 0.3), 0.25), 0.9)

    # часы
    n = secs(2.0)
    y = np.zeros(n)
    for k, t0 in enumerate((0.0, 0.5, 1.0, 1.5)):
        f = 2600 if k % 2 == 0 else 2150
        place(y, modal(secs(0.06), [(f, 0.006, 1.0), (f * 1.9, 0.004, 0.5)], r) + click(secs(0.06), 3000, 9000, 0.0015, r) * 0.6, t0)
    save("clock_loop", y, 0.35)


# ------------------------------------------------------------------ радио

MORSE = {"А": ".-", "Б": "-...", "В": ".--", "Г": "--.", "Д": "-..", "Е": ".", "Ж": "...-", "З": "--..", "И": "..", "К": "-.-",
         "Л": ".-..", "М": "--", "Н": "-.", "О": "---", "П": ".--.", "Р": ".-.", "С": "...", "Т": "-", "У": "..-", "Ф": "..-.",
         "Х": "....", "Ц": "-.-.", "Ч": "---.", "Ш": "----", "Щ": "--.-", "Ы": "-.--", "Ь": "-..-", "Э": "..-..", "Ю": "..--",
         "Я": ".-.-", "1": ".----", "2": "..---", "3": "...--", "4": "....-", "5": ".....", "6": "-....", "7": "--...",
         "8": "---..", "9": "----.", "0": "-----"}


def morse(text, wpm=19, freq=700.0, r=None):
    dit = 1.2 / wpm
    seq = []
    for w in text.upper().split(" "):
        for ch in w:
            for s in MORSE.get(ch, ""):
                seq.append((dit if s == "." else 3 * dit, True))
                seq.append((dit, False))
            seq.append((2 * dit, False))
        seq.append((4 * dit, False))
    n = sum(secs(d) for d, _ in seq)
    key = np.zeros(n)
    i = 0
    for d, on in seq:
        m = secs(d)
        if on:
            key[i:i + m] = 1.0
        i += m
    key = lp(key, 220.0)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * freq * t) * key


def g_radio():
    r = rng(61)
    n = secs(9)
    y = bp(white(n, r), 300, 3600) * smooth_rand(n, 0.7, r, 0.6, 1.0)
    for _ in range(60):
        place(y, click(secs(0.01), 800, 6000, 0.002, r), r.uniform(0, 8.9), r.uniform(0.5, 2.5))
    y += 0.03 * np.sin(2 * np.pi * 50 * np.arange(n) / SR)
    save("radio_static", loopify(y, 0.8), 0.6)

    n = secs(4)
    t = np.arange(n) / SR
    f = 1000 + 14 * np.sin(2 * np.pi * 0.5 * t) + 5 * np.sin(2 * np.pi * 5.1 * t)
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * (0.8 + 0.2 * np.sin(2 * np.pi * 50 * t))
    save("radio_whine", y, 0.5)

    n = secs(1.1)
    y = np.zeros(n)
    place(y, click(secs(0.05), 800, 5000, 0.004, r), 0.0)
    y += 0.25 * np.sin(2 * np.pi * 50 * np.arange(n) / SR) * np.clip(np.arange(n) / SR / 0.6, 0, 1)
    y += bp(white(n, r), 300, 3600) * np.clip((np.arange(n) / SR - 0.3) / 0.6, 0, 1) * 0.5
    save("radio_on", fade(y, 0.001, 0.05), 0.7)
    save("radio_off", fade(click(secs(0.12), 600, 4000, 0.006, r) + modal(secs(0.12), [(180, 0.03, 0.8)], r), 0.0005, 0.03), 0.6)
    save("tune_tick", fade(click(secs(0.03), 2000, 8000, 0.002, r), 0.0003, 0.01), 0.35)

    # своя передача ключом — чистый самоконтроль
    for i, txt in ((1, "ТХЯ ТХЯ ДКС 16 21 М31 В18 СН74"), (2, "ТХЯ ДКС 17 21 М33 В22 СН76 К"), (3, "ТХЯ ДКС ПРИЕМ ПРИЕМ К"),
                   (4, "СОС СОС ТХЯ ТХЯ ПРИЕМ")):
        save(f"morse_tx_{i}", fade(morse(txt, 21, 800.0), 0.002, 0.02), 0.5)
    # приём с Диксона — сквозь эфир, с замираниями
    for i, txt in ((1, "ТХЯ ДКС ПОЧЕМУ МОЛЧАЛИ С 14"), (2, "ГОЛОСОМ НЕ РАБОТАЕМ ДВЕ НЕДЕЛИ"), (3, "БОРТ 20 ЕСЛИ СТИХНЕТ ОБОЗНАЧЬТЕ ПЛОЩАДКУ"),
                   (4, "БОРТ ВЫЛЕТАЕТ 0600 ДЕРЖИТЕСЬ"), (5, "ДКС ТХЯ ПРИНЯТО К")):
        m = morse(txt, 19, 640.0)
        n = len(m)
        y = m * smooth_rand(n, 0.5, r, 0.35, 1.0) + bp(white(n, r), 300, 3200) * 0.22
        y = bp(y, 350, 2800)
        save(f"morse_rx_{i}", fade(y, 0.02, 0.05), 0.55)

    # рация на груди: помехи тем сильнее, чем оно ближе
    n = secs(7)
    crack = lp(np.abs(white(n, r)), 30.0)
    crack = (crack / crack.max()) ** 3
    y = bp(white(n, r), 500, 4500) * (0.25 + 0.75 * crack)
    for _ in range(45):
        place(y, click(secs(0.012), 1000, 5000, 0.002, r), r.uniform(0, 6.9), r.uniform(0.6, 2.0))
    save("walkie_static", loopify(soft(y * 2.0, 2.0), 0.6), 0.6)
    for i in (1, 2, 3):
        n = secs(0.6)
        y = np.zeros(n)
        k = 2 if i < 3 else 3
        for j in range(k):
            m = secs(0.09)
            place(y, bp(white(m, r), 500, 4000) * env_exp(m, 0.03, 0.001), 0.02 + j * 0.2)
            place(y, click(secs(0.02), 900, 3500, 0.003, r), 0.02 + j * 0.2, 2.0)
        save(f"walkie_click_{i}", fade(y, 0.001, 0.05), 0.6)
    n = secs(0.32)
    save("squelch", fade(soft(bp(white(n, r), 500, 4500) * env_exp(n, 0.1, 0.002) * 3.0, 2.0), 0.001, 0.05), 0.6)

    # «жужжалка»: неживая станция на соседней частоте
    n = secs(4.0)
    t = np.arange(n) / SR
    saw = 2 * ((t * 104.0) % 1.0) - 1
    buzz = bp(saw + 0.5 * (2 * ((t * 208.3) % 1.0) - 1), 250, 2600)
    gate = lp(((t % 2.0) < 1.25).astype(float), 40.0)
    y = buzz * gate + bp(white(n, r), 300, 3200) * 0.18
    save("buzzer", loopify(y, 0.2), 0.5)


# ------------------------------------------------------------------ тело и вещи

def g_body():
    r = rng(71)
    # сердце: петля ровно в один удар
    n = secs(1.0)
    y = np.zeros(n)
    place(y, modal(secs(0.25), [(58, 0.055, 1.0), (96, 0.03, 0.4)], r), 0.0)
    place(y, modal(secs(0.25), [(49, 0.05, 0.8), (84, 0.03, 0.3)], r), 0.28, 0.75)
    save("heartbeat", lp(y, 400), 0.9)

    def breath_cycle(tin, tout, tremolo=0.0):
        m1, m2 = secs(tin), secs(tout)
        a = bp(white(m1, r), 900, 3600) * np.hanning(m1) ** 0.7 * 0.8
        b = bp(white(m2, r), 350, 2200) * np.hanning(m2) ** 0.6
        b = peak(b, 620, 2.0) * 0.5 + b * 0.6
        y = np.concatenate([a, np.zeros(secs(0.08)), b, np.zeros(secs(0.12))])
        if tremolo > 0:
            t = np.arange(len(y)) / SR
            y *= 1.0 - tremolo * (0.5 + 0.5 * np.sin(2 * np.pi * 9.5 * t))
        return y
    save("breath_run", np.concatenate([breath_cycle(0.55, 0.6), breath_cycle(0.5, 0.62)]), 0.5)
    save("breath_cold", np.concatenate([breath_cycle(0.9, 1.3, 0.7), breath_cycle(1.0, 1.2, 0.75)]), 0.4)
    m = secs(0.9)
    save("breath_in", fade(bp(white(m, r), 1000, 4200) * np.linspace(0.2, 1.0, m) ** 2 * np.hanning(m) ** 0.3, 0.02, 0.05), 0.45)
    m = secs(1.2)
    save("breath_out", fade(bp(white(m, r), 350, 2400) * env_exp(m, 0.4, 0.05), 0.02, 0.2), 0.45)
    m = secs(0.5)
    save("gasp", fade(bp(white(m, r), 1100, 5000) * env_exp(m, 0.14, 0.03) + peak(white(m, r), 950, 5) * env_exp(m, 0.1, 0.03) * 0.3, 0.005, 0.1), 0.6)

    for i in (1, 2):
        n = secs(0.5)
        y = bp(white(n, r), 800, 5000) * smooth_rand(n, 14, r, 0.0, 1.0) ** 2 * np.hanning(n)
        save(f"cloth_{i}", y, 0.35)
    n = secs(0.3)
    save("pickup", fade(bp(white(n, r), 700, 4500) * env_exp(n, 0.06, 0.01) + modal(n, [(420, 0.03, 0.6)], r), 0.002, 0.05), 0.5)
    for i in (1, 2):
        n = secs(0.6)
        y = hp(white(n, r), 1800) * smooth_rand(n, 22, r, 0.0, 1.0) ** 2 * np.hanning(n)
        save(f"paper_{i}", y, 0.4)
    n = secs(1.5)
    y = np.zeros(n)
    t0 = 0.05
    while t0 < 1.35:
        m = secs(r.uniform(0.07, 0.2))
        place(y, bp(white(m, r), 2200, 6500) * np.hanning(m) * smooth_rand(m, 40, r, 0.4, 1.0), t0, r.uniform(0.5, 1.0))
        t0 += m / SR + r.uniform(0.02, 0.09)
    save("pencil", y, 0.35)
    # рука в рукавице на тросе
    n = secs(0.35)
    y = lp(white(n, r), 1500) * env_exp(n, 0.07, 0.01)
    place(y, creak(r, 0.3, 170, 230, 0.1, 0.5), 0.0, 0.5)
    save("rope_grab", fade(y, 0.003, 0.08), 0.5)
    n = secs(0.25)
    save("rope_release", fade(lp(white(n, r), 1200) * env_exp(n, 0.05, 0.02), 0.003, 0.08), 0.35)

    save("lamp_on", fade(click(secs(0.06), 1500, 6000, 0.003, r) + modal(secs(0.06), [(1250, 0.008, 0.6)], r), 0.0005, 0.02), 0.5)
    save("lamp_off", fade(click(secs(0.06), 1000, 4500, 0.004, r) + modal(secs(0.06), [(880, 0.01, 0.6)], r), 0.0005, 0.02), 0.45)
    n = secs(1.3)
    t = np.arange(n) / SR
    gate = (smooth_rand(n, 18, r) > 0.5).astype(float)
    y = bp(np.sign(np.sin(2 * np.pi * 100 * t)), 300, 3000) * lp(gate, 200) * 0.6
    for _ in range(9):
        place(y, click(secs(0.02), 2000, 8000, 0.002, r), r.uniform(0, 1.2), 1.4)
    save("lamp_flicker", fade(y, 0.002, 0.1), 0.5)

    # фальшфейер
    n = secs(1.0)
    y = hp(white(n, r), 1200) * env_exp(n, 0.5, 0.004) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 70 * np.arange(n) / SR)))
    place(y, modal(secs(0.2), [(140, 0.04, 1.0)], r) + click(secs(0.2), 1000, 8000, 0.01, r) * 2.0, 0.0)
    save("flare_ignite", fade(y, 0.001, 0.1), 0.9)
    n = secs(4.5)
    flut = lp(np.abs(white(n, r)), 75.0)
    flut = flut / flut.max()
    y = hp(white(n, r), 1000) * (0.45 + 0.55 * flut) + lp(brown(n, r), 300) * 0.5
    save("flare_burn", loopify(to_stereo(y, 0.3), 0.5), 0.7)
    # ракетница: выстрел, свист, далёкий хлопок
    n = secs(3.4)
    y = np.zeros(n)
    place(y, white(secs(0.5), r) * env_exp(secs(0.5), 0.07, 0.0005) + modal(secs(0.5), [(58, 0.12, 1.2), (130, 0.06, 0.6)], r), 0.0, 1.5)
    m = secs(1.5)
    place(y, sweep_bp(white(m, r), np.linspace(900, 3400, m), 16.0) * np.linspace(1.0, 0.1, m), 0.08, 0.5)
    place(y, lp(white(secs(0.7), r), 1500) * env_exp(secs(0.7), 0.14, 0.002), 1.85, 0.5)
    place(y, hp(white(secs(1.2), r), 2000) * env_exp(secs(1.2), 0.5, 0.05), 1.9, 0.12)
    save("flaregun", stereo_reverb(fade(y, 0.0005, 0.3), 1.6, 0.25, 3000), 0.97)

    n = secs(0.9)
    y = np.zeros(n)
    place(y, creak(r, 0.5, 300, 420, 0.15, 1.2), 0.05, 0.6)
    place(y, bp(white(secs(0.4), r), 500, 3000) * np.hanning(secs(0.4)), 0.0, 0.3)
    save("bed_creak", fade(y, 0.005, 0.1), 0.55)


# ------------------------------------------------------------------ удары и гул страха

def g_stings():
    r = rng(81)
    # низкий провал
    n = secs(3.2)
    t = np.arange(n) / SR
    f = 58 * np.exp(-t * 0.35) + 26
    y = soft(np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 1.1, 0.01) * 1.6, 2.0)
    y += lp(brown(n, r), 180) * env_exp(n, 0.8, 0.3) * 0.5
    save("sting_low", stereo_reverb(fade(y, 0.002, 0.5), 2.2, 0.3, 1200), 0.95)

    # удар: гроздь расстроенных пил, шумовая атака, долгий хвост
    n = secs(1.2)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for f0 in (55, 58.3, 110, 116.5, 123.5, 220, 233, 247, 466, 494):
        y += (2 * ((t * f0 * (1 + r.uniform(-0.004, 0.004))) % 1.0) - 1) * r.uniform(0.5, 1.0)
    y = lp(y, 2600) * env_exp(n, 0.35, 0.002)
    y += white(n, r) * env_exp(n, 0.03, 0.0005) * 4.0
    y += modal(n, [(41, 0.5, 6.0)], r)
    save("sting_hit", stereo_reverb(y, 3.2, 0.42, 2800), 0.98)

    # визг: высокая диссонирующая гроздь, нарастает и обрывается
    n = secs(1.5)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for f0 in (1870, 1984, 2110, 2794, 2960, 3136, 3951, 4186):
        vib = 1 + 0.012 * np.sin(2 * np.pi * r.uniform(5, 8) * t + r.uniform(0, 6))
        ph = np.cumsum(f0 * vib) / SR
        y += (2 * (ph % 1.0) - 1) * r.uniform(0.5, 1.0)
    y = bp(y, 1200, 9000) * np.clip(t / 0.9, 0, 1) ** 2.5 * (t < 1.02)
    y += hp(white(n, r), 4000) * np.clip(t / 0.9, 0, 1) ** 3 * (t < 1.02) * 0.4
    save("sting_screech", stereo_reverb(fade(y, 0.01, 0.01), 2.0, 0.35, 6000), 0.95)

    # нарастание перед погоней
    n = secs(4.5)
    t = np.arange(n) / SR
    k = (t / 4.5) ** 2
    y = sweep_bp(pink(n, r), 180 + 2600 * k, 5.0) * k * (0.6 + 0.4 * np.sin(2 * np.pi * (2 + 14 * k) * t))
    y += np.sin(2 * np.pi * np.cumsum(50 + 60 * k) / SR) * k * 0.6
    save("riser", stereo_reverb(fade(y, 0.05, 0.02), 1.2, 0.2), 0.95)

    # обратный всасывающий звук
    n = secs(1.8)
    y = (bp(white(n, r), 300, 5000) * env_exp(n, 0.5, 0.001))[::-1]
    save("reverse", fade(to_stereo(y, 0.4), 0.2, 0.004), 0.8)

    # смерть: тишина на вдох, потом всё сразу
    n = secs(3.0)
    t = np.arange(n) / SR
    y = white(n, r) * env_exp(n, 0.09, 0.0005) * 3.0
    y += modal(n, [(36, 0.9, 5.0), (72, 0.4, 2.0)], r)
    for f0 in (233, 247, 466, 494, 932, 988, 1976, 2093):
        y += (2 * ((t * f0) % 1.0) - 1) * env_exp(n, 0.5, 0.001) * 0.5
    y = soft(y * 0.5, 3.0)
    save("death_hit", stereo_reverb(y, 3.0, 0.4, 3500), 0.99)

    # замерзание: высокий тающий тон
    n = secs(8)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for f0, a in ((523.3, 1.0), (784.0, 0.6), (1046.5, 0.4), (1568.0, 0.2)):
        y += np.sin(2 * np.pi * f0 * t * (1 + 0.001 * np.sin(2 * np.pi * 0.3 * t))) * a * smooth_rand(n, 0.3, r, 0.4, 1.0)
    y *= np.clip(t / 3.0, 0, 1) * np.clip((8 - t) / 3.0, 0, 1)
    save("freeze_tone", stereo_reverb(y, 3.0, 0.5, 5000), 0.6)


def g_drones():
    r = rng(91)
    # гул страха: низкое до, медленный фильтр, биения
    n = secs(40)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for f0, a in ((32.7, 1.0), (32.95, 0.8), (65.4, 0.6), (65.9, 0.5), (98.0, 0.3), (49.0, 0.4)):
        y += (2 * ((t * f0) % 1.0) - 1) * a
    y = sweep_bp(y, smooth_rand(n, 0.07, r, 90, 320), 1.4) + lp(y, 90) * 0.8
    y *= smooth_rand(n, 0.1, r, 0.5, 1.0)
    y += bp(pink(n, r), 2000, 6000) * smooth_rand(n, 0.15, r, 0.0, 0.03)
    save("drone_dread", loopify(to_stereo(y, 0.4), 3.0), 0.8)

    # напряжение: гроздь малых секунд, «смычки»
    n = secs(32)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for f0 in (220.0, 233.1, 246.9, 311.1, 329.6, 440.0, 466.2):
        vib = 1 + 0.006 * np.sin(2 * np.pi * r.uniform(4.5, 6.5) * t + r.uniform(0, 6))
        saw = 2 * ((np.cumsum(f0 * vib) / SR) % 1.0) - 1
        y += lp(saw, 2200) * smooth_rand(n, 0.12, r, 0.0, 1.0) ** 2
    y *= 0.8 + 0.2 * np.sin(2 * np.pi * 7.3 * t)
    save("drone_tension", loopify(stereo_reverb(y, 2.5, 0.4, 4000)[:n], 3.0), 0.7)

    # холод: стеклянные тоны, редкие
    n = secs(48)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for f0 in (146.8, 220.0, 293.7, 440.0, 587.3, 659.3, 880.0):
        y += np.sin(2 * np.pi * f0 * t + 2 * np.sin(2 * np.pi * 0.11 * t + r.uniform(0, 6))) * np.clip(smooth_rand(n, 0.06, r, -0.6, 1.0), 0, 1) ** 2
    y += lp(brown(n, r), 120) * 0.4
    save("drone_cold", loopify(stereo_reverb(y, 3.5, 0.5, 5000)[:n], 4.0), 0.6)

    # ледник: очень низкий гул, воздух, редкий звон льда
    n = secs(30)
    y = lp(brown(n, r), 70) * 1.2 + bp(pink(n, r), 400, 1400) * 0.05
    for _ in range(9):
        f0 = r.uniform(1800, 4200)
        place(y, modal(secs(1.2), [(f0, 0.3, 1.0), (f0 * 1.52, 0.2, 0.5), (f0 * 2.31, 0.12, 0.25)], r), r.uniform(0, 28), r.uniform(0.03, 0.1))
    save("cellar_loop", loopify(stereo_reverb(y, 3.0, 0.45, 5000)[:n], 3.0), 0.7)


# ------------------------------------------------------------------ существо

def g_entity():
    r = rng(101)
    # горловой треск: редкие импульсы через «глотку»
    def croak(dur, rate0, rate1, pitch=1.0):
        n = secs(dur)
        y = np.zeros(n)
        t0 = 0.02
        while t0 < dur - 0.05:
            k = t0 / dur
            rate = rate0 + (rate1 - rate0) * k
            place(y, click(secs(0.01), 300, 5000, 0.002, r), t0, r.uniform(0.6, 1.0))
            t0 += 1.0 / rate * r.uniform(0.85, 1.2)
        out = peak(y, 640 * pitch, 6) + peak(y, 1150 * pitch, 8) * 0.8 + peak(y, 2550 * pitch, 9) * 0.5 + y * 0.1
        out += bp(white(n, r), 300, 1500) * np.hanning(n) * 0.05
        return out * np.hanning(n) ** 0.4
    save("ent_croak_1", stereo_reverb(croak(2.2, 26, 9), 0.6, 0.2, 4000), 0.8)
    save("ent_croak_2", stereo_reverb(croak(3.0, 8, 30, 0.85), 0.6, 0.2, 4000), 0.8)
    save("ent_croak_3", stereo_reverb(croak(1.3, 34, 22, 1.15), 0.6, 0.2, 4000), 0.8)
    for i in (1, 2, 3):
        n = secs(0.5)
        y = np.zeros(n)
        for j in range(i):
            c = click(secs(0.03), 800, 6000, 0.003, r)
            place(y, peak(np.concatenate([c, np.zeros(secs(0.1))]), 1800, 10) + peak(np.concatenate([c, np.zeros(secs(0.1))]), 3200, 12) * 0.6, 0.02 + j * 0.13)
        save(f"ent_click_{i}", fade(y, 0.0005, 0.05), 0.7)
    # оно рядом: низкое горло и дыхание-помеха (петля, 3D)
    n = secs(9)
    y = croak(9.0, 11, 11, 0.7) * 0.7
    br = bp(white(n, r), 250, 1300) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.22 * np.arange(n) / SR)) ** 2
    y = y + br * 0.5 + lp(brown(n, r), 90) * 0.6
    save("ent_near", loopify(y, 1.0), 0.75)
    # крик: радиовизг + горло + шум
    n = secs(1.7)
    t = np.arange(n) / SR
    f = 620 + 900 * np.clip(t / 0.25, 0, 1) + 240 * np.sin(2 * np.pi * 31 * t) + smooth_rand(n, 40, r, -160, 160)
    car = np.sin(2 * np.pi * np.cumsum(f) / SR + 2.5 * np.sin(2 * np.pi * np.cumsum(f * 0.5) / SR))
    y = soft(car * 2.0, 3.0) * env_exp(n, 0.9, 0.004)
    y += soft(bp(white(n, r), 500, 6000) * env_exp(n, 0.6, 0.002) * 2.0, 2.0) * 0.7
    y += croak(1.7, 46, 20, 1.3) * 1.5
    y += np.sin(2 * np.pi * np.cumsum(np.linspace(2600, 900, n)) / SR) * env_exp(n, 0.5, 0.01) * 0.4
    save("ent_scream", stereo_reverb(soft(y, 2.0), 1.4, 0.25, 5000), 0.99)
    # шипение помех, когда оно «говорит»
    n = secs(1.6)
    y = soft(bp(white(n, r), 600, 5000) * smooth_rand(n, 8, r, 0.1, 1.0) ** 2 * 3.0, 2.0)
    save("ent_hiss", fade(y, 0.02, 0.2), 0.6)


# ------------------------------------------------------------------ мир

def g_world():
    r = rng(111)
    for i in (1, 2):
        n = secs(1.0)
        f0 = r.uniform(160, 230)
        y = modal(n, [(f0, 0.5, 1.0), (f0 * 2.76, 0.35, 0.6), (f0 * 5.4, 0.2, 0.4), (f0 * 8.9, 0.1, 0.25)], r) + click(n, 800, 4000, 0.01, r)
        y = lp(reverb(y, 2.6, 0.7, 900), 1100)
        save(f"metal_bang_far_{i}", to_stereo(fade(y, 0.002, 0.5), 0.3), 0.7)
    for i in range(1, 5):
        n = secs(r.uniform(0.6, 1.4))
        y = np.zeros(n + secs(0.3))
        place(y, creak(r, n / SR, r.uniform(90, 150), r.uniform(110, 210), 0.2, 0.6, r.uniform(4, 9)), 0.0)
        if i % 2 == 0:
            place(y, modal(secs(0.2), [(r.uniform(200, 330), 0.04, 1.0), (r.uniform(600, 900), 0.02, 0.4)], r), r.uniform(0.0, 0.3), 1.4)
        save(f"house_creak_{i}", fade(reverb(y, 0.4, 0.3, 2200), 0.01, 0.2), 0.6)
    n = secs(2.2)
    y = lp(brown(n, r), 300) * np.hanning(n) ** 0.5 + bp(white(n, r), 300, 2000) * np.hanning(n) * 0.2
    place(y, modal(secs(0.5), [(55, 0.15, 1.0)], r), 1.5, 0.8)
    save("roof_slide", fade(y, 0.05, 0.3), 0.7)
    # кто-то дёрнул леер: скрип троса и стук столба
    n = secs(1.6)
    y = np.zeros(n)
    place(y, creak(r, 0.5, 140, 260, 0.2, 0.6), 0.0, 0.8)
    place(y, knock(r, 0.5) * 0.6, 0.42)
    place(y, creak(r, 0.4, 230, 150, 0.2, 0.6), 0.6, 0.5)
    place(y, knock(r, 0.5) * 0.4, 0.95)
    save("rope_tug", fade(y, 0.005, 0.2), 0.75)
    for i in (1, 2, 3):
        n = secs(1.3)
        t = np.arange(n) / SR
        f = 3200 * np.exp(-t * 26.0) + r.uniform(240, 380)
        y = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(n, 0.12, 0.0005) + click(n, 2000, 9000, 0.003, r) * 1.5
        save(f"ice_crack_{i}", stereo_reverb(fade(y, 0.0005, 0.3), 2.4, 0.5, 6000), 0.85)
    # прибор: дверца будки, вертушка
    n = secs(0.6)
    y = np.zeros(n)
    place(y, creak(r, 0.3, 420, 560, 0.12, 1.3), 0.0, 0.5)
    place(y, knock(r, 0.0) * 0.5, 0.3)
    save("booth_door", fade(y, 0.003, 0.1), 0.6)
    n = secs(3.0)
    t = np.arange(n) / SR
    y = bp(white(n, r), 1500, 5000) * (0.5 + 0.5 * np.sin(2 * np.pi * 23 * t)) * 0.5 + np.sin(2 * np.pi * 380 * t) * 0.05
    save("anemo_loop", loopify(y, 0.3), 0.3)
    # стекло разбито
    n = secs(1.6)
    y = white(n, r) * env_exp(n, 0.02, 0.0005) * 2.0
    for _ in range(40):
        f0 = r.uniform(1800, 7000)
        place(y, modal(secs(0.25), [(f0, r.uniform(0.02, 0.09), 1.0), (f0 * 1.6, 0.03, 0.4)], r), r.uniform(0.0, 0.9) ** 2, r.uniform(0.1, 0.5))
    save("glass_break", fade(reverb(y, 0.5, 0.2, 7000), 0.0005, 0.3), 0.9)


# ------------------------------------------------------------------ интерфейс и музыка

def g_ui():
    r = rng(121)
    save("ui_move", fade(modal(secs(0.07), [(1320, 0.012, 1.0), (2640, 0.006, 0.3)], r), 0.0005, 0.02), 0.25)
    save("ui_ok", fade(modal(secs(0.16), [(880, 0.03, 1.0), (1320, 0.03, 0.6)], r), 0.0005, 0.04), 0.3)
    save("ui_back", fade(modal(secs(0.14), [(660, 0.03, 1.0), (440, 0.03, 0.6)], r), 0.0005, 0.04), 0.3)
    for i in (1, 2, 3):
        n = secs(0.07)
        save(f"type_{i}", fade(click(n, 1500, 6500, 0.004, r) + modal(n, [(r.uniform(300, 420), 0.012, 0.8)], r), 0.0003, 0.02), 0.35)
    n = secs(0.5)
    save("page", hp(white(n, r), 1500) * smooth_rand(n, 18, r, 0.0, 1.0) ** 2 * np.hanning(n), 0.35)
    # задача выполнена: тихая галочка карандашом
    n = secs(0.35)
    y = bp(white(n, r), 2200, 6500) * np.hanning(n) * smooth_rand(n, 40, r, 0.4, 1.0)
    save("tick", y, 0.3)


def g_music():
    r = rng(131)
    # меню: холодный аккорд, далёкий ключ, ветер
    n = secs(56)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for f0, a in ((73.4, 1.0), (110.0, 0.7), (146.8, 0.6), (174.6, 0.5), (220.0, 0.4), (293.7, 0.25), (349.2, 0.2)):
        vib = 1 + 0.003 * np.sin(2 * np.pi * r.uniform(0.1, 0.3) * t + r.uniform(0, 6))
        y += np.sin(2 * np.pi * np.cumsum(f0 * vib) / SR) * a * smooth_rand(n, 0.05, r, 0.3, 1.0)
    y = y * 0.5 + lp(brown(n, r), 140) * 0.5
    m = morse("НЕ ОТВЕЧАЙ", 11, 880.0)
    for at in (9.0, 34.0):
        place(y, m, at, 0.05)
    save("music_menu", loopify(stereo_reverb(y, 4.0, 0.55, 3500)[:n], 4.0), 0.6)

    # финал: медленные аккорды ля минор — фа — до — соль
    chords = [(110.0, 130.8, 164.8, 220.0), (87.3, 130.8, 174.6, 220.0), (65.4, 130.8, 164.8, 196.0), (98.0, 123.5, 146.8, 196.0)]
    seg = 9.0
    n = secs(seg * len(chords) * 2)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for rep in range(2):
        for ci, ch in enumerate(chords):
            t0 = (rep * len(chords) + ci) * seg
            m = secs(seg + 2.0)
            tm = np.arange(m) / SR
            env = np.clip(tm / 2.5, 0, 1) * np.clip((seg + 2.0 - tm) / 3.0, 0, 1)
            c = np.zeros(m)
            for f0 in ch:
                c += np.sin(2 * np.pi * f0 * tm) + 0.4 * np.sin(2 * np.pi * f0 * 2 * tm) + 0.15 * np.sin(2 * np.pi * f0 * 3 * tm)
            if rep == 1:
                c += np.sin(2 * np.pi * ch[-1] * 2 * tm) * 0.6 + np.sin(2 * np.pi * ch[1] * 4 * tm) * 0.25
            place(y, c * env, t0)
    y += bp(pink(n, r), 300, 2000) * 0.03
    save("music_end", stereo_reverb(fade(y, 1.0, 5.0), 4.0, 0.5, 4500), 0.6)


ALL = {"wind": g_wind, "steps": g_steps, "doors": g_doors, "knocks": g_knocks, "machines": g_machines, "radio": g_radio,
       "body": g_body, "stings": g_stings, "drones": g_drones, "entity": g_entity, "world": g_world, "ui": g_ui, "music": g_music}

if __name__ == "__main__":
    want = sys.argv[1:] or list(ALL)
    for k in want:
        print(k, flush=True)
        ALL[k]()
    print("Готово")
