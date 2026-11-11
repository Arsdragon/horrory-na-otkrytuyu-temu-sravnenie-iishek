"""Синтез всех звуков и текстур «Поверки». Запуск: python tools/make_assets.py"""
import os, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.signal import lfilter, butter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 22050
rng = np.random.default_rng(7)
os.makedirs(os.path.join(ROOT, "snd"), exist_ok=True)
os.makedirs(os.path.join(ROOT, "tex"), exist_ok=True)

def save(name, x, norm=0.9):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1
    x = x / m * norm
    d = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(ROOT, "snd", name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(d.tobytes())

def t(sec): return np.arange(int(round(SR * sec))) / SR
def noise(sec): return rng.standard_normal(int(round(SR * sec)))
def lp(x, f, o=2): b, a = butter(o, f / (SR / 2)); return lfilter(b, a, x)
def hp(x, f, o=2): b, a = butter(o, f / (SR / 2), "high"); return lfilter(b, a, x)
def bp(x, f1, f2, o=2): b, a = butter(o, [f1 / (SR / 2), f2 / (SR / 2)], "band"); return lfilter(b, a, x)
def env(n, a, d):
    e = np.ones(n); ai = int(a * SR); di = int(d * SR)
    if ai: e[:ai] = np.linspace(0, 1, ai)
    if di: e[-di:] *= np.linspace(1, 0, di)
    return e
def exp_dec(sec, k): return np.exp(-t(sec) * k)

# --- ambient drone (loop 12 s; ends match because all periods divide 12)
T = t(12)
drone = (np.sin(2*np.pi*41*T) * 0.5 + np.sin(2*np.pi*55.25*T + np.sin(2*np.pi*0.25*T)) * 0.35
         + np.sin(2*np.pi*82.5*T) * 0.12 * (0.5 + 0.5*np.sin(2*np.pi*T/6)))
air = lp(noise(12), 300) * 0.6 * (0.6 + 0.4*np.sin(2*np.pi*T/4))
save("drone", drone + air, 0.5)

# heartbeat (one beat ~0.9s)
hb = np.zeros(int(SR*0.9))
for off, amp in ((0, 1.0), (0.22, 0.7)):
    s = int(off*SR); n = len(t(0.15))
    hb[s:s+n] += np.sin(2*np.pi*48*t(0.15)) * exp_dec(0.15, 30) * amp
save("heart", lp(hb, 150), 0.95)

def step(heavy=False, drag=False):
    sec = 0.35 if not drag else 0.9
    x = lp(noise(sec), 900 if heavy else 2500) * exp_dec(sec, 25 if not drag else 5)
    if heavy: x += np.sin(2*np.pi*60*t(sec)) * exp_dec(sec, 18) * 2
    if drag: x += bp(noise(sec), 200, 1200) * env(int(sec*SR), 0.2, 0.4) * 0.8
    return x
for i in range(4): save(f"step{i}", step(), 0.5)
for i in range(3): save(f"estep{i}", step(heavy=True, drag=(i == 2)), 0.9)

# glass crunch
g = np.zeros(int(SR*0.5))
for _ in range(40):
    p = rng.integers(0, len(g) - 2000); n = rng.integers(200, 1500)
    g[p:p+n] += hp(noise(n/SR), 3000) * exp_dec(n/SR, 60) * rng.uniform(0.3, 1)
save("glass", g, 0.8)

# breath (in-out)
br = bp(noise(2.4), 400, 2500) * (np.sin(np.pi*t(2.4)/1.2)**2)
save("breath", br, 0.4)
# gasp after hold
save("gasp", bp(noise(0.8), 500, 3000) * env(int(0.8*SR), 0.05, 0.6), 0.6)

# whisper: shaped noise with formant wobble
W = t(3.0)
wh = bp(noise(3.0), 1500, 5000) * (0.5 + 0.5*np.sin(2*np.pi*3.7*W)**8) * env(len(W), 0.3, 0.8)
save("whisper", wh, 0.5)

# entity groan: low, unstable, distorted
G = t(2.6)
f = 70 + 15*np.sin(2*np.pi*1.3*G) + 8*rng.standard_normal(len(G)).cumsum()/200
ph = 2*np.pi*np.cumsum(f)/SR
gr = np.tanh(3*(np.sin(ph) + 0.5*np.sin(2.01*ph) + 0.3*lp(noise(2.6), 600))) * env(len(G), 0.3, 1.0)
save("groan", lp(gr, 1500), 0.8)

# jumpscare scream: detuned saw stack + noise
S = t(1.6)
sc = np.zeros(len(S))
for fr in (311, 330, 466, 622, 700):
    ff = fr * (1 + 0.04*np.sin(2*np.pi*7*S))
    sc += 2*((np.cumsum(ff)/SR) % 1) - 1
sc = np.tanh(2*(sc/3 + hp(noise(1.6), 1500)*0.8)) * env(len(S), 0.005, 0.7)
save("scream", sc, 1.0)

# knock (3 knocks)
kn = np.zeros(int(SR*1.4))
for i in range(3):
    s = int(i*0.33*SR); n = len(t(0.12))
    kn[s:s+n] += (np.sin(2*np.pi*120*t(0.12)) + lp(noise(0.12), 1500)) * exp_dec(0.12, 40)
save("knock", kn, 0.8)

# slam
sl = (lp(noise(1.5), 400) + np.sin(2*np.pi*45*t(1.5))*2) * exp_dec(1.5, 4)
save("slam", sl, 1.0)

# wardrobe creak
C = t(1.2)
cf = 300 + 200*np.sin(2*np.pi*0.8*C)
cr = np.sign(np.sin(2*np.pi*np.cumsum(cf)/SR)) * (0.5 + 0.5*np.sin(2*np.pi*23*C)) * env(len(C), 0.1, 0.4)
save("creak", bp(cr, 400, 3000), 0.5)

# old phone ring (2 rings)
P = t(3.0)
ring = (np.sin(2*np.pi*425*P) * np.sign(np.sin(2*np.pi*25*P))) * ((P % 1.5) < 0.9)
save("phone", ring, 0.5)

# meter click & read-done, flashlight click, paper, battery
save("click", hp(noise(0.05), 2000) * exp_dec(0.05, 120), 0.6)
save("done", np.sin(2*np.pi*880*t(0.25)) * exp_dec(0.25, 12), 0.4)
save("page", bp(noise(0.6), 1000, 6000) * env(int(0.6*SR), 0.05, 0.3) * (0.5+0.5*np.sin(2*np.pi*17*t(0.6))), 0.5)
save("buzz", (np.sign(np.sin(2*np.pi*100*t(2))) * 0.3 + lp(noise(2), 3000) * 0.1), 0.25)

# stinger: rising dissonant swell
R = t(4)
st = np.zeros(len(R))
for fr in (110, 116.5, 155.6, 233):
    st += np.sin(2*np.pi*fr*R*(1+R/8))
st = st * (R/4)**2 + hp(noise(4), 2000) * (R/4)**3 * 0.6
save("stinger", st, 0.7)

# radio: static and a garbled "voice"
Rd = t(5)
static = bp(noise(5), 300, 4000) * 0.5
voice = np.sin(2*np.pi*(180 + 40*np.sin(2*np.pi*4*Rd))*Rd) * (np.sin(2*np.pi*2.3*Rd) > 0.2) * 0.6
save("radio", static + bp(voice, 300, 3000), 0.6)

# ---------------- textures -----------------
def tex_noise(sz, scale):
    a = rng.standard_normal((sz // scale + 2, sz // scale + 2))
    im = Image.fromarray(((a - a.min()) / (np.ptp(a)) * 255).astype(np.uint8)).resize((sz, sz), Image.BICUBIC)
    return np.asarray(im).astype(np.float32) / 255

def save_tex(name, arr):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(os.path.join(ROOT, "tex", name + ".png"))

S = 512
# wallpaper: faded vertical pattern with stains and peeling
base = np.zeros((S, S, 3), np.float32) + np.array([120, 112, 84])
xs = np.arange(S)
stripe = (np.sin(xs / S * 2 * np.pi * 8) > 0.6)[None, :, None] * np.array([-18, -14, -6])
base += stripe
im = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)); d = ImageDraw.Draw(im)
for i in range(8):
    for j in range(8):
        cx, cy = i * 64 + 32, j * 64 + (32 if i % 2 else 0)
        d.ellipse([cx - 9, cy - 14, cx + 9, cy + 14], outline=(90, 82, 60), width=2)
        d.line([cx, cy - 14, cx, cy + 14], fill=(95, 86, 62), width=1)
base = np.asarray(im).astype(np.float32)
stain = tex_noise(S, 32)
water = np.clip((tex_noise(S, 64) - 0.55) * 4, 0, 1)
dirt = (0.75 + 0.35 * stain)[..., None]
base = base * dirt * (1 - water[..., None] * 0.45) + water[..., None] * np.array([40, 35, 20])
yy = np.linspace(0, 1, S)[:, None, None]
base *= 1 - 0.35 * yy ** 3  # dirtier near floor
save_tex("wall", base)

# concrete
c = 95 + 50 * tex_noise(S, 8) + 25 * tex_noise(S, 64) + rng.standard_normal((S, S)) * 6
save_tex("concrete", np.stack([c, c * 0.98, c * 0.95], -1))

# linoleum floor: brown with worn pattern squares
l = np.zeros((S, S, 3), np.float32) + np.array([96, 58, 40])
chk = ((xs[None, :] // 64 + xs[:, None] // 64) % 2)[..., None] * np.array([12, 8, 4])
wear = tex_noise(S, 16)[..., None]
save_tex("floor", (l + chk) * (0.7 + 0.45 * wear) + rng.standard_normal((S, S, 1)) * 4)

# wood (doors, wardrobes)
yv = np.arange(S)[:, None]
grain = np.sin((xs[None, :] + 30 * tex_noise(S, 128)) / 5.0) * 0.5 + 0.5
w = np.stack([grain * 40 + 70, grain * 25 + 42, grain * 12 + 22], -1) * (0.8 + 0.3 * tex_noise(S, 32)[..., None])
save_tex("wood", w)

# ceiling: whitewash with cracks + soot
ce = 150 + 30 * tex_noise(S, 16) - 70 * np.clip((tex_noise(S, 48) - 0.6) * 3, 0, 1)
im = Image.fromarray(np.clip(ce, 0, 255).astype(np.uint8)).convert("RGB"); d = ImageDraw.Draw(im)
for _ in range(14):
    x, y = rng.integers(0, S, 2)
    for _ in range(25):
        nx, ny = x + rng.integers(-18, 19), y + rng.integers(-18, 19)
        d.line([x, y, nx, ny], fill=(60, 58, 55), width=1); x, y = nx, ny
save_tex("ceiling", np.asarray(im))

# entity skin: grey, wet, veined
sk = 70 + 40 * tex_noise(256, 8) + 30 * tex_noise(256, 32)
im = Image.fromarray(np.clip(np.stack([sk, sk * 0.92, sk * 0.88], -1), 0, 255).astype(np.uint8)); d = ImageDraw.Draw(im)
for _ in range(30):
    x, y = rng.integers(0, 256, 2)
    for _ in range(12):
        nx, ny = x + rng.integers(-10, 11), y + rng.integers(0, 14)
        d.line([x, y, nx, ny], fill=(50, 25, 30), width=1); x, y = nx, ny
save_tex("skin", np.asarray(im.filter(ImageFilter.GaussianBlur(0.6))))

# robe fabric: faded checked flannel
rb = np.zeros((256, 256, 3), np.float32) + np.array([70, 52, 50])
x2 = np.arange(256)
rb += ((x2[None, :] // 16) % 2)[..., None] * np.array([18, 8, 6]) + ((x2[:, None] // 16) % 2)[..., None] * np.array([10, 5, 3])
save_tex("robe", rb * (0.6 + 0.5 * tex_noise(256, 8)[..., None]))

# paper note
pa = 200 + 25 * tex_noise(256, 16)
save_tex("paper", np.stack([pa, pa * 0.95, pa * 0.82], -1))
print("assets ok")
