#!/usr/bin/env python3
"""M3.5: prozedurale Anlass-/Abstellklänge (wie die übrigen Motor-Klänge synthetisch).

starter_whine  Schwungkraft-Anlasser: Schwungrad läuft hoch (Heulen steigt), ca. 4 s
engine_catch   Einkuppeln, Husten, Zünden, Übergang in Leerlauf (ca. 2,5 s)
engine_stop    Abstellen: Zündung/Gemisch aus, Auslaufen mit Stottern (ca. 2 s)
switch         Kippschalter (kurzer Klick)

Aufruf: python3 tools/gen_audio_m3_5.py game/assets/audio   (benötigt numpy, ffmpeg)
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 22050
rng = np.random.default_rng(35)


def lp(x, a):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def env(n, att, rel):
    e = np.ones(n)
    a = int(att * SR)
    r = int(rel * SR)
    if a:
        e[:a] = np.linspace(0, 1, a)
    if r:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def firing(t, rate_hz, jitter=0.0, miss=0.0):
    """Zündfolge eines Kolbenmotors: kurze gedämpfte Pulse je Zündung."""
    out = np.zeros_like(t)
    phase = 0.0
    i = 0
    dt = 1.0 / SR
    nxt = 0.0
    while i < len(t):
        r = rate_hz[i] if hasattr(rate_hz, "__len__") else rate_hz
        if t[i] >= nxt:
            if rng.random() >= miss:
                L = int(0.03 * SR)
                k = np.arange(min(L, len(t) - i))
                pulse = np.exp(-k / (0.006 * SR)) * np.sin(2 * np.pi * 70 * k / SR)
                out[i:i + len(k)] += pulse * (0.8 + 0.4 * rng.random())
            nxt = t[i] + (1.0 / max(r, 1.0)) * (1.0 + jitter * (rng.random() - 0.5))
        i += 1
    return out


def starter_whine():
    d = 4.0
    t = np.arange(int(d * SR)) / SR
    f = 180 + 900 * (1 - np.exp(-t / 1.6))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = 0.5 * np.sin(ph) + 0.25 * np.sin(2 * ph + 0.4) + 0.1 * np.sin(3 * ph)
    x += 0.12 * lp(rng.standard_normal(len(t)), 0.05)
    return x * env(len(t), 0.15, 0.2) * np.clip(t / 2.0, 0.3, 1.0)


def engine_catch():
    d = 2.6
    t = np.arange(int(d * SR)) / SR
    rate = np.interp(t, [0, 0.5, 1.0, 1.6, 2.6], [5, 7, 20, 32, 30])
    miss = 0.0
    x = firing(t, rate, jitter=0.35, miss=miss)
    # Einkuppeln (Klack) und Husten
    k = int(0.05 * SR)
    x[:k] += np.exp(-np.arange(k) / (0.008 * SR)) * rng.standard_normal(k) * 0.8
    x = lp(x, 0.25) + 0.08 * lp(rng.standard_normal(len(t)), 0.02) * np.clip(t, 0, 1)
    return x * env(len(t), 0.0, 0.3)


def engine_stop():
    d = 2.2
    t = np.arange(int(d * SR)) / SR
    rate = np.interp(t, [0, 0.4, 1.4, 2.2], [30, 18, 6, 2])
    x = firing(t, rate, jitter=0.5, miss=0.3)
    x = lp(x, 0.2)
    return x * env(len(t), 0.0, 0.8) * np.exp(-t / 1.4)


def switch():
    n = int(0.06 * SR)
    k = np.arange(n)
    x = np.exp(-k / (0.004 * SR)) * (rng.standard_normal(n) * 0.6 + np.sin(2 * np.pi * 2400 * k / SR) * 0.5)
    return x


def write(path, x):
    x = x / max(np.max(np.abs(x)), 1e-6) * 0.85
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", path], check=True)
    os.unlink(tmp)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "game/assets/audio"
    for name, fn in [("starter_whine", starter_whine), ("engine_catch", engine_catch),
                     ("engine_stop", engine_stop), ("switch", switch)]:
        write(os.path.join(out, name + ".ogg"), fn())
        print("geschrieben", name)


if __name__ == "__main__":
    main()
