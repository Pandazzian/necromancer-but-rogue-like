"""Procedural audio for Necromancer's Toll: SFX + loopable music, pure stdlib.
Writes 16-bit mono WAVs into assets/audio/."""
import math, os, random, struct, wave

SR = 22050
OUT = r"C:\Users\gemzl\Documents\Claude\Projects\necromancer-but-rougue-like\assets\audio"
random.seed(11)

def write_wav(name, samples, peak=0.8):
    m = max(1e-9, max(abs(s) for s in samples))
    k = peak / m
    data = b"".join(struct.pack("<h", int(max(-1, min(1, s * k)) * 32767)) for s in samples)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data)
    print(name, len(samples) / SR, "s")

def silence(dur): return [0.0] * int(dur * SR)

def add(dst, src, at=0.0, gain=1.0):
    i0 = int(at * SR)
    for i, s in enumerate(src):
        j = i0 + i
        if 0 <= j < len(dst): dst[j] += s * gain
    return dst

def sine(freq, dur, gain=1.0, detune=0.0):
    out = []
    ph = 0.0
    for i in range(int(dur * SR)):
        f = freq + detune * math.sin(2 * math.pi * 0.7 * i / SR)
        ph += 2 * math.pi * f / SR
        out.append(gain * math.sin(ph))
    return out

def noise(dur, gain=1.0): return [gain * (random.random() * 2 - 1) for _ in range(int(dur * SR))]

def lowpass(x, cutoff):
    k = 1.0 - math.exp(-2 * math.pi * cutoff / SR)
    y, out = 0.0, []
    for s in x:
        y += k * (s - y); out.append(y)
    return out

def env_ad(x, a, d):
    n = len(x); na = int(a * SR)
    out = []
    for i, s in enumerate(x):
        if i < na: e = i / max(1, na)
        else: e = math.exp(-(i - na) / max(1, d * SR))
        out.append(s * e)
    return out

def env_slot(x, a, r):
    n = len(x); na, nr = int(a * SR), int(r * SR)
    out = []
    for i, s in enumerate(x):
        e = min(1.0, i / max(1, na)) * min(1.0, (n - i) / max(1, nr))
        out.append(s * e)
    return out

def loopify(x, fade=0.05):
    nf = int(fade * SR)
    out = x[:len(x) - nf]
    for i in range(nf):
        w = i / nf
        out[i] = x[len(x) - nf + i] * (1 - w) + out[i] * w
    return out

# ---------------- SFX ----------------
def sfx_hit():
    x = env_ad(lowpass(noise(0.12, 0.9), 1800), 0.002, 0.03)
    add(x, env_ad(sine(150, 0.12), 0.001, 0.045), 0, 0.9)
    write_wav("hit", x)

def sfx_shoot():
    n = lowpass(noise(0.2, 0.8), 2600)
    x = env_ad(n, 0.004, 0.05)
    sw = []
    ph = 0.0
    for i in range(int(0.18 * SR)):
        f = 800 * math.exp(-3.0 * i / SR / 0.18) + 240
        ph += 2 * math.pi * f / SR
        sw.append(0.5 * math.sin(ph))
    add(x, env_ad(sw, 0.003, 0.06))
    write_wav("shoot", x)

def sfx_blast():
    br, y = [], 0.0
    for s in noise(0.55, 1.0):
        y = 0.995 * y + 0.05 * s; br.append(y)
    x = env_ad([s * 6 for s in br], 0.004, 0.16)
    add(x, env_ad(sine(60, 0.5), 0.002, 0.2), 0, 1.1)
    write_wav("blast", x)

def sfx_bones():
    x = silence(0.4)
    for t in [0.0, 0.05, 0.09, 0.16, 0.22, 0.3]:
        click = env_ad(lowpass(noise(0.05, 0.9), 3200 - 3000 * t), 0.001, 0.012)
        add(x, click, t, 1.0 - t)
    write_wav("bones", x)

def sfx_rise():
    x = env_slot(lowpass(noise(0.55, 0.9), 300), 0.1, 0.25)
    sw = []
    ph = 0.0
    for i in range(int(0.5 * SR)):
        f = 100 + 220 * (i / SR / 0.5)
        ph += 2 * math.pi * f / SR
        trem = 0.7 + 0.3 * math.sin(2 * math.pi * 13 * i / SR)
        sw.append(0.5 * trem * math.sin(ph))
    add(x, env_slot(sw, 0.15, 0.2), 0.05)
    write_wav("rise", x)

def sfx_soul_burst():
    x = silence(0.8)
    for f, t, g in [(659.3, 0.0, 0.9), (880.0, 0.05, 0.7), (1318.5, 0.1, 0.5)]:
        add(x, env_ad(sine(f, 0.7, 1.0, 1.5), 0.004, 0.22), t, g)
    add(x, env_ad(lowpass(noise(0.4, 0.5), 5000), 0.02, 0.12), 0.0, 0.5)
    write_wav("soul_burst", x)

def sfx_bind_hum():
    dur = 1.2
    x = silence(dur)
    for f, g in [(110.0, 0.5), (165.0, 0.3), (221.5, 0.35), (330.8, 0.18)]:
        add(x, sine(f, dur, g))
    write_wav("bind_hum", loopify(x), 0.5)

def sfx_pickup():
    x = silence(0.3)
    add(x, env_ad(sine(880, 0.12), 0.003, 0.05))
    add(x, env_ad(sine(1318.5, 0.18), 0.003, 0.07), 0.07, 0.8)
    write_wav("pickup", x)

def sfx_door():
    grind = env_slot(lowpass(noise(0.7, 1.0), 220), 0.08, 0.3)
    x = silence(0.95)
    add(x, grind)
    add(x, env_ad(sine(55, 0.6), 0.01, 0.25), 0.0, 1.2)
    add(x, env_ad(sine(659.3, 0.5, 1.0, 1.2), 0.004, 0.2), 0.45, 0.4)
    write_wav("door", x)

def sfx_heartbeat():
    x = silence(0.9)
    for t, g in [(0.0, 1.0), (0.30, 0.75)]:
        th = env_ad(sine(55, 0.16), 0.004, 0.05)
        add(th, env_ad(sine(90, 0.1), 0.002, 0.03), 0, 0.5)
        add(x, th, t, g)
    write_wav("heartbeat", loopify(x, 0.02), 0.85)

def sfx_transfusion():
    sw = []
    ph = 0.0
    for i in range(int(0.3 * SR)):
        f = 160 * math.exp(-2.2 * i / SR / 0.3) + 40
        ph += 2 * math.pi * f / SR
        sw.append(math.sin(ph))
    x = env_ad(sw, 0.004, 0.1)
    add(x, env_ad(lowpass(noise(0.2, 0.7), 900), 0.01, 0.06), 0.02, 0.7)
    write_wav("transfusion", x)

# ---------------- Music ----------------
NOTE = {"A2":110.0,"E3":164.81,"F3":174.61,"G3":196.0,"GS3":207.65,"A3":220.0,"B3":246.94,
        "C4":261.63,"D4":293.66,"E4":329.63,"F4":349.23,"A4":440.0,"B4":493.88,
        "C5":523.25,"E5":659.26,"G5":783.99}

def pad(freqs, dur, gain):
    x = silence(dur)
    for f in freqs:
        add(x, sine(f, dur, 0.5, 0.4))
        add(x, sine(f * 2.003, dur, 0.12))
        add(x, sine(f * 0.5, dur, 0.25))
    return env_slot([s * gain for s in x], 1.4, 1.6)

def bell(f, dur, gain):
    x = env_ad(sine(f, dur, 1.0, 0.8), 0.005, dur * 0.35)
    add(x, env_ad(sine(f * 2.76, dur * 0.5), 0.003, dur * 0.12), 0, 0.25)
    return [s * gain for s in x]

def music_run():
    total = 24.0
    x = silence(total + 2.0)
    add(x, sine(55.0, total + 2.0, 0.16, 0.15))
    add(x, sine(110.2, total + 2.0, 0.08, 0.2))
    prog = [["A3","C4","E4"], ["F3","A3","C4"], ["E3","GS3","B3"], ["A3","C4","E4"]]
    for i, chord in enumerate(prog):
        add(x, pad([NOTE[n] for n in chord], 6.4, 0.30), i * 6.0)
    for t, n in [(2.0,"E5"),(5.2,"C5"),(8.4,"B4"),(11.0,"A4"),(14.0,"E5"),(17.2,"G5"),(20.0,"B4"),(22.0,"A4")]:
        add(x, bell(NOTE[n], 2.8, 0.10), t)
    # crossfade tail into head for a clean loop
    nf = int(2.0 * SR); body = x[:int(total * SR)]
    for i in range(nf):
        w = i / nf
        body[i] = body[i] * w + x[int(total * SR) + i] * (1 - w)
    write_wav("music_run", body, 0.55)

def music_hub():
    total = 20.0
    x = silence(total + 2.0)
    add(x, sine(110.0, total + 2.0, 0.12, 0.12))
    add(x, pad([NOTE[n] for n in ["A3","C4","E4"]], 10.6, 0.22), 0.0)
    add(x, pad([NOTE[n] for n in ["F3","A3","C4"]], 10.6, 0.22), 10.0)
    seq = ["A4","C5","E5","C5"]
    for k in range(8):
        add(x, bell(NOTE[seq[k % 4]], 1.6, 0.07), k * 2.5 + 0.5)
    nf = int(2.0 * SR); body = x[:int(total * SR)]
    for i in range(nf):
        w = i / nf
        body[i] = body[i] * w + x[int(total * SR) + i] * (1 - w)
    write_wav("music_hub", body, 0.5)

os.makedirs(OUT, exist_ok=True)
for f in [sfx_hit, sfx_shoot, sfx_blast, sfx_bones, sfx_rise, sfx_soul_burst,
          sfx_bind_hum, sfx_pickup, sfx_door, sfx_heartbeat, sfx_transfusion,
          music_run, music_hub]:
    f()
print("DONE")
