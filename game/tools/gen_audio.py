#!/usr/bin/env python3
"""M3.3: Alle Spielgeräusche prozedural erzeugen (numpy/scipy) -> Ogg Vorbis (ffmpeg/libvorbis).
Eigene Synthese, keine Fremdaufnahmen: lizenzfrei (CC0, siehe assets/audio/LICENSES.md).
Aufruf (aus game/):  python3 tools/gen_audio.py [zielordner]   (Standard assets/audio)
Loops sind periodisch konstruiert (Rauschen gekachelt, Filter über 3 Perioden, Mitte genommen),
damit sie nahtlos laufen. Mono, 22050 Hz, niedrige Bitrate (q0..q2)."""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 22050
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(1937)


def t_of(sec):
    return np.arange(int(sec * SR)) / SR


def noise(n):
    return rng.uniform(-1, 1, n)


def bp(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], "bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lp(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, "lowpass", fs=SR, output="sos"), x)


def hp(x, f, order=2):
    return signal.sosfilt(signal.butter(order, f, "highpass", fs=SR, output="sos"), x)


def loop_filter(x, fn):
    """Periodisches Signal x (eine Periode) filtern, ohne Naht: 3x kacheln, Mitte nehmen."""
    n = len(x)
    return fn(np.tile(x, 3))[n:2 * n]


def env_exp(n, tau):
    return np.exp(-np.arange(n) / (tau * SR))


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def fade(x, a=0.005, b=0.02):
    x = x.copy()
    na, nb = int(a * SR), int(b * SR)
    if na:
        x[:na] *= np.linspace(0, 1, na)
    if nb:
        x[-nb:] *= np.linspace(1, 0, nb)
    return x


def write(name, x, q=1):
    os.makedirs(OUT, exist_ok=True)
    x = np.clip(x, -1, 1)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    dst = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(q),
                    "-ac", "1", "-ar", str(SR), dst], check=True)
    os.unlink(tmp)
    return dst


def pulse_engine(f0, pulses, pattern, tau, harm, roar, cut, rough):
    """Kolbenmotor als Zündimpuls-Folge (periodisch): f0 Zündfrequenz, pattern Zylinderstreuung."""
    n = int(round(pulses / f0 * SR))
    x = np.zeros(n)
    nz = noise(n)
    per = n / pulses
    kern = int(per * 2.5)
    k_env = env_exp(kern, tau)
    k = (np.sin(2 * np.pi * f0 * 0.5 * np.arange(kern) / SR) * 0.6 + noise(kern) * rough) * k_env
    for i in range(pulses):
        s = int(i * per)
        amp = pattern[i % len(pattern)]
        idx = (np.arange(kern) + s) % n
        x[idx] += k * amp
    t = np.arange(n) / SR
    for h, a in harm:
        x += a * np.sin(2 * np.pi * f0 * h * t)
    x += roar * nz
    return norm(loop_filter(x, lambda y: lp(hp(y, 30), cut)), 0.85)


def gen():
    files = {}
    # --- Flug ------------------------------------------------------------------------------
    # Sternmotor (9 Zylinder): Zündfrequenz 72 Hz bei Pitch 1 (Spiel: Pitch 0,55 Leerlauf .. 1,6 Vollgas)
    rad = pulse_engine(72.0, 144, [1.0, 0.82, 0.93, 0.76, 1.0, 0.88, 0.8, 0.95, 0.85], 0.010,
                       [(0.5, 0.25), (1, 0.35), (2, 0.12), (1 / 3, 0.18)], 0.25, 1800, 0.6)
    t = np.arange(len(rad)) / SR
    rad *= 0.85 + 0.15 * np.sin(2 * np.pi * 24.0 * t)   # Propellerschlag (3 Blätter)
    files["engine_radial"] = write("engine_radial", norm(rad, 0.85), 1)
    # Reihenmotor (V12): glatter, höher, mehr Summen
    inl = pulse_engine(96.0, 192, [1.0, 0.9, 0.97, 0.88, 0.95, 0.92], 0.006,
                       [(1, 0.4), (2, 0.22), (3, 0.08), (0.5, 0.15)], 0.18, 2600, 0.4)
    files["engine_inline"] = write("engine_inline", inl, 1)
    # Fahrtwind / Propellerrauschen (3 s Loop)
    n = 3 * SR
    w = loop_filter(noise(n), lambda y: bp(y, 250, 2400))
    tt = np.arange(n) / SR
    w *= 0.8 + 0.2 * np.sin(2 * np.pi * tt / 1.5)
    files["wind"] = write("wind", norm(w, 0.8), 0)
    # Fahrwerk: Elektromotor-/Hydraulik-Surren 1,4 s, Einrasten am Ende
    tt = t_of(1.5)
    whine = np.sin(2 * np.pi * (180 + 40 * tt) * tt) * 0.3 + bp(noise(len(tt)), 300, 900) * 0.6
    g = whine * np.clip(tt / 0.1, 0, 1) * np.clip((1.3 - tt) / 0.1, 0, 1)
    clunk = np.zeros_like(tt)
    s = int(1.3 * SR)
    ln = len(tt) - s
    clunk[s:] = (lp(noise(ln), 600) * 3 + np.sin(2 * np.pi * 70 * np.arange(ln) / SR)) * env_exp(ln, 0.04)
    files["gear"] = write("gear", fade(norm(g * 0.6 + clunk)), 1)
    # Klappen: mechanisches Rattern 0,9 s
    tt = t_of(0.9)
    rat = (np.sin(2 * np.pi * 22 * tt) > 0.6).astype(float)
    fl = bp(noise(len(tt)), 600, 2500) * (0.4 + rat) * np.clip((0.85 - tt) / 0.1, 0, 1)
    files["flaps"] = write("flaps", fade(norm(fl, 0.7)), 1)
    # Reifen-Aufsetzen: Quietschen + Rumms
    tt = t_of(0.6)
    sq = bp(noise(len(tt)), 1300, 2800, 3) * env_exp(len(tt), 0.12)
    th = lp(noise(len(tt)), 300) * env_exp(len(tt), 0.05) * 4
    files["touchdown"] = write("touchdown", fade(norm(sq + th)), 1)
    # Bauchlandung / Aufprall: Schleifen und metallische Schläge 1,8 s
    tt = t_of(1.8)
    sc = bp(noise(len(tt)), 200, 3000) * np.clip((1.8 - tt) / 1.2, 0, 1)
    for k in range(7):
        s = int(rng.uniform(0, 1.4) * SR)
        ln = int(0.25 * SR)
        pt = np.arange(ln) / SR
        sc[s:s + ln] += (np.sin(2 * np.pi * rng.uniform(300, 900) * pt) + lp(noise(ln), 800)) * env_exp(ln, 0.05) * 1.5
    sc += lp(noise(len(tt)), 120) * env_exp(len(tt), 0.3) * 4
    files["crash"] = write("crash", fade(norm(sc)), 1)
    # --- Kampf ------------------------------------------------------------------------------
    # MG-Feuer: Loop 1 s mit 20 Schuss (2 MG), Schuss = Knall + Mündungsdruck
    n = SR
    x = np.zeros(n)
    ln = int(0.05 * SR)
    for i in range(20):
        s = int(i * n / 20 + rng.uniform(-60, 60)) % n
        shot = (noise(ln) * 0.9 + np.sin(2 * np.pi * 110 * np.arange(ln) / SR)) * env_exp(ln, 0.012)
        idx = (np.arange(ln) + s) % n
        x[idx] += shot * rng.uniform(0.85, 1.0)
    files["mg_loop"] = write("mg_loop", norm(loop_filter(x, lambda y: lp(hp(y, 60), 5000)), 0.9), 2)
    # Treffer am eigenen Flugzeug: metallischer Einschlag
    tt = t_of(0.35)
    m = sum(np.sin(2 * np.pi * f * tt) * a for f, a in [(420, 1), (1130, 0.6), (2290, 0.4), (3170, 0.3)])
    hit = m * env_exp(len(tt), 0.06) + lp(noise(len(tt)), 900) * env_exp(len(tt), 0.02) * 2.5
    files["hit_own"] = write("hit_own", fade(norm(hit), 0.001), 1)
    # Treffer am Gegner (fern): kurzes trockenes „Plock“
    tt = t_of(0.18)
    he = bp(noise(len(tt)), 700, 2600) * env_exp(len(tt), 0.02) + np.sin(2 * np.pi * 260 * tt) * env_exp(len(tt), 0.03)
    files["hit_enemy"] = write("hit_enemy", fade(norm(he), 0.001), 1)
    # Explosion / Absturz 2,8 s
    tt = t_of(2.8)
    boom = lp(noise(len(tt)), 180, 3) * env_exp(len(tt), 0.6) * 3 + lp(noise(len(tt)), 1500) * env_exp(len(tt), 0.08) * 2
    boom += np.sin(2 * np.pi * (55 - 15 * tt) * tt) * env_exp(len(tt), 0.35)
    files["explosion"] = write("explosion", fade(norm(boom), 0.002, 0.3), 1)
    # Brand / Knistern: Loop 3 s
    n = 3 * SR
    cr = lp(noise(n), 400) * 0.6
    for k in range(90):
        s = int(rng.uniform(0, n))
        ln = int(rng.uniform(0.004, 0.02) * SR)
        idx = (np.arange(ln) + s) % n
        cr[idx] += hp(noise(ln), 1500) * env_exp(ln, 0.004) * rng.uniform(1, 3)
    files["fire"] = write("fire", norm(loop_filter(cr, lambda y: lp(y, 6000)), 0.8), 0)
    # Notausstieg: Haube ab (Knall) + Luftstrom
    tt = t_of(1.6)
    ej = hp(noise(len(tt)), 300) * env_exp(len(tt), 0.03) * 3 + bp(noise(len(tt)), 300, 2500) * np.clip(tt / 0.2, 0, 1) * np.clip((1.6 - tt) / 0.8, 0, 1)
    files["eject"] = write("eject", fade(norm(ej)), 1)
    # --- Boden ------------------------------------------------------------------------------
    # Schritt auf Gras
    tt = t_of(0.2)
    st = bp(noise(len(tt)), 400, 4000) * env_exp(len(tt), 0.04) + lp(noise(len(tt)), 200) * env_exp(len(tt), 0.02) * 2
    files["step_grass"] = write("step_grass", fade(norm(st, 0.7), 0.002), 1)
    # Lkw-Motor Leerlauf (4 Zylinder, 25 Hz Zündfolge)
    tr = pulse_engine(25.0, 50, [1.0, 0.8, 0.95, 0.85], 0.02, [(1, 0.3), (2, 0.15), (0.5, 0.2)], 0.15, 900, 0.7)
    files["truck_idle"] = write("truck_idle", tr, 1)
    # Tankpumpe + Treibstoffrauschen (2 s Loop)
    n = 2 * SR
    tt = np.arange(n) / SR
    pu = sum(np.sin(2 * np.pi * f * tt) * a for f, a in [(50, 0.3), (100, 0.25), (150, 0.1), (300, 0.05)])
    gur = bp(noise(n), 500, 2500) * (0.6 + 0.4 * np.sin(2 * np.pi * 3 * tt)) * 0.5
    files["pump"] = write("pump", norm(loop_filter(pu + gur, lambda y: lp(y, 4000)), 0.8), 0)
    # Kiste abstellen (dumpf, Holz) / aufnehmen (heller, kurz)
    tt = t_of(0.3)
    cd = (lp(noise(len(tt)), 500) * 2 + np.sin(2 * np.pi * 140 * tt)) * env_exp(len(tt), 0.04)
    files["crate_down"] = write("crate_down", fade(norm(cd), 0.001), 1)
    tt = t_of(0.25)
    cu = (bp(noise(len(tt)), 400, 1800) + np.sin(2 * np.pi * 220 * tt) * 0.5) * env_exp(len(tt), 0.03)
    files["crate_up"] = write("crate_up", fade(norm(cu, 0.7), 0.001), 1)
    # MG-Klappe: Riegel-Klick + Blech
    tt = t_of(0.35)
    hc = hp(noise(len(tt)), 2000) * env_exp(len(tt), 0.003) * 2
    s = int(0.08 * SR)
    pt = np.arange(len(tt) - s) / SR
    hc[s:] += sum(np.sin(2 * np.pi * f * pt) * a for f, a in [(820, 1), (1960, 0.5)]) * env_exp(len(pt), 0.05)
    files["hatch"] = write("hatch", fade(norm(hc, 0.8), 0.001), 1)
    # Gurt einlegen: Patronen-Klirren
    tt = t_of(0.6)
    be = np.zeros_like(tt)
    for k in range(14):
        s = int(rng.uniform(0, 0.5) * SR)
        ln = int(0.03 * SR)
        pt = np.arange(ln) / SR
        be[s:s + ln] += np.sin(2 * np.pi * rng.uniform(2500, 4200) * pt) * env_exp(ln, 0.006)
    be += hp(noise(len(tt)), 3000) * 0.05
    files["belt"] = write("belt", fade(norm(be, 0.7)), 1)
    # Werkzeug: Ratsche (Loop 1 s, 12 Klicks)
    n = SR
    to = np.zeros(n)
    ln = int(0.02 * SR)
    for i in range(12):
        s = int(i * n / 12)
        to[s:s + ln] += hp(noise(ln), 2500) * env_exp(ln, 0.003)
    s = int(0.6 * SR)
    ln = int(0.2 * SR)
    pt = np.arange(ln) / SR
    to[s:s + ln] += np.sin(2 * np.pi * 1450 * pt) * env_exp(ln, 0.03) * 0.5
    files["tool"] = write("tool", norm(to, 0.7), 1)
    # Ein-/Aussteigen: Knarzen + Sitz-Rumms
    tt = t_of(0.5)
    en = np.sin(2 * np.pi * (300 + 200 * np.sin(2 * np.pi * 7 * tt)) * tt) * 0.2 * np.clip((0.25 - tt) / 0.25, 0, 1)
    s = int(0.25 * SR)
    ln = len(tt) - s
    en[s:] += lp(noise(ln), 400) * env_exp(ln, 0.04) * 2
    files["enter"] = write("enter", fade(norm(en, 0.7)), 1)
    # Alarm-Sirene: Handkurbel-Sirene, Loop 4 s (auf und ab)
    n = 4 * SR
    tt = np.arange(n) / SR
    f = 330 + 290 * (1 - np.cos(2 * np.pi * tt / 4.0)) / 2
    ph = 2 * np.pi * np.cumsum(f) / SR
    ph *= (2 * np.pi * round(ph[-1] / (2 * np.pi))) / ph[-1]   # ganze Perioden -> nahtlos
    si = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)
    files["siren"] = write("siren", norm(si, 0.8), 1)
    # --- Umgebung: leiser Wind + Vögel, Loop 8 s
    n = 8 * SR
    amb = loop_filter(noise(n), lambda y: bp(y, 150, 900)) * 0.25
    tt = np.arange(n) / SR
    for k in range(10):
        s = int(rng.uniform(0, 7.6) * SR)
        ln = int(rng.uniform(0.06, 0.14) * SR)
        pt = np.arange(ln) / SR
        f0 = rng.uniform(2800, 4200)
        ch = np.sin(2 * np.pi * (f0 + rng.uniform(-900, 900) * pt / pt[-1]) * pt) * np.sin(np.pi * pt / pt[-1])
        for r in range(int(rng.integers(1, 4))):
            o = s + r * int(0.18 * SR)
            if o + ln < n:
                amb[o:o + ln] += ch * rng.uniform(0.08, 0.18)
    files["ambient"] = write("ambient", norm(amb, 0.6), 0)
    # --- UI
    tt = t_of(0.05)
    files["ui_click"] = write("ui_click", fade(np.sin(2 * np.pi * 1800 * tt) * env_exp(len(tt), 0.008) * 0.5, 0.0005, 0.005), 1)
    tt = t_of(0.22)
    co = np.where(tt < 0.09, np.sin(2 * np.pi * 880 * tt), np.sin(2 * np.pi * 1320 * tt)) * env_exp(len(tt), 0.08)
    files["ui_confirm"] = write("ui_confirm", fade(co * 0.5, 0.002), 1)
    tt = t_of(0.75)
    ch = np.zeros_like(tt)
    for i, fr in enumerate([660, 880, 1320]):
        s = int(i * 0.11 * SR)
        pt = np.arange(len(tt) - s) / SR
        ch[s:] += (np.sin(2 * np.pi * fr * pt) + 0.3 * np.sin(4 * np.pi * fr * pt)) * env_exp(len(pt), 0.18)
    files["ui_step"] = write("ui_step", fade(norm(ch, 0.6), 0.002), 1)
    return files


if __name__ == "__main__":
    fs = gen()
    tot = sum(os.path.getsize(p) for p in fs.values())
    print("%d Dateien, %.0f KB" % (len(fs), tot / 1024))
