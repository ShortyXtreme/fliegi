#!/usr/bin/env python3
"""M3.14: Echte Aufnahmen (CC0/CC BY, docs/asset_lizenzen.md) auswählen, schneiden, säubern und als
Ogg Vorbis nach game/assets/audio/real/ schreiben. Wiederholbar (fester Zufallsstartwert).

  python3 -I tools/build_real_audio.py [--src <ordner>] [--out <ordner>] [--proben <ordner>]

Quelle: asset_quellen/sounds/ (nicht im Repo, Ordner 1_wwii_fighter … 9_feuer, einzeln/).
Kette je Klang: dekodieren (ffmpeg, mono/stereo float) -> Ansage/Slate am Dateianfang meiden
(Schnittzeiten unten) -> Netzbrumm-Kerben 60/120/180/240 Hz (Filmüberspielung) -> Hochpass 35 Hz
-> leichte Rauschminderung (Spektralabzug, Rauschprofil aus den leisesten Rahmen derselben Datei)
-> Lautheit auf den prozeduralen Vorgänger gleichen Namens (gleiche Mischung im Spiel)
-> Spitzenbegrenzung -1 dBFS -> Loop mit Überblendung (Schnittstelle an bester Korrelation) bzw.
Ein-/Ausblendung -> Vorbis. Am Ende: Messbericht real/manifest.json (Lautheit, Spitze, Loop-Sprung
nach erneutem Dekodieren) und auf Wunsch Hörproben (docs/hoerproben_m3_14/).
"""
import argparse
import json
import os
import subprocess
import sys

import numpy as np
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)
SR = 32000
RNG = np.random.default_rng(1314)

# Motor V12 (fighter_t1): fünf Drehzahl-Layer aus Abschnitten konstanter Drehzahl. Gemessener
# Harmonischen-Abstand (Hz) des Abschnitts und Ziel nach leichter Tonhöhen-Angleichung (gleichmäßige
# Stufen, Faktor 0,94…1,08). Bezugs-"Klangdrehzahl" = 2750 * Ziel / 70,5 (GameAudio.REAL_ENGINE_RPM).
ENGINE_V12 = [
    # name, datei, von, bis, f_gemessen, f_ziel
    ("idle", "1_wwii_fighter/437775__craigsmith__g04-11-wwii-fighters-engine-idle.wav", 2.6, 10.0, 44.6, 44.6),
    ("low", "1_wwii_fighter/437790__craigsmith__g04-23-wwii-fighter-starts-taxis-stops.wav", 34.5, 46.0, 53.2, 50.1),
    ("mid", "1_wwii_fighter/437772__craigsmith__g04-08-fighter-engine-drone.wav", 2.6, 18.0, 56.2, 56.2),
    ("high", "1_wwii_fighter/437771__craigsmith__g04-07-wwii-stuka-engine-drone.wav", 3.0, 36.0, 58.2, 62.9),
    ("full", "1_wwii_fighter/437792__craigsmith__g04-25-wwii-fighter-revs-engine.wav", 26.0, 50.0, 70.5, 70.5),
]
ENGINE_LOOP_S = {"idle": 4.0, "low": 6.0, "mid": 6.0, "high": 6.0, "full": 6.0}

# Einzelklänge: name -> (datei, von, bis, loop, ziel-lautheit-von, extras)
# „ziel“ = Name des prozeduralen Vorgängers, dessen Lautheit übernommen wird.
SHOTS = {
    # Motor-Ereignisse
    "engine_catch": ("1_wwii_fighter/437790__craigsmith__g04-23-wwii-fighter-starts-taxis-stops.wav", 16.6, 21.2, False, "engine_catch", {"fade_out": 1.2}),
    "engine_stop": ("1_wwii_fighter/437790__craigsmith__g04-23-wwii-fighter-starts-taxis-stops.wav", 106.2, 114.2, False, "engine_stop", {"fade_out": 1.5}),
    "engine_misfire": ("1_wwii_fighter/437776__craigsmith__g04-12-fighter-engine-pop-and-dive.wav", 20.0, 22.4, False, "engine_stop", {"dropouts": 4}),
    "engine_starve": ("2_props/479525__craigsmith__r02-40-prop-sputtering-engine.wav", 56.0, 68.4, False, "engine_stop", {"dropouts": 6, "fade_out": 1.0}),
    # Treffer
    "hit_metal_1": ("4_treffer/675944__craigsmith__s20-47-50-cal-browning-machine-gun-bullet-impacts.wav", 2.45, 2.85, False, "hit_enemy", {}),
    "hit_metal_2": ("4_treffer/675944__craigsmith__s20-47-50-cal-browning-machine-gun-bullet-impacts.wav", 3.18, 3.58, False, "hit_enemy", {}),
    "hit_metal_3": ("4_treffer/675944__craigsmith__s20-47-50-cal-browning-machine-gun-bullet-impacts.wav", 5.50, 5.82, False, "hit_enemy", {}),
    "hit_metal_4": ("4_treffer/675951__craigsmith__s31-15-shooting-gallery-hitting-metal-targets.wav", 1.60, 2.10, False, "hit_enemy", {}),
    "hit_metal_5": ("4_treffer/675951__craigsmith__s31-15-shooting-gallery-hitting-metal-targets.wav", 5.33, 5.85, False, "hit_enemy", {}),
    "hit_wood_1": ("4_treffer/675945__craigsmith__s31-21-artillery-bullets-hitting-nearby-overhead.wav", 1.33, 1.70, False, "hit_own", {}),
    "hit_wood_2": ("4_treffer/675945__craigsmith__s31-21-artillery-bullets-hitting-nearby-overhead.wav", 1.73, 2.10, False, "hit_own", {}),
    "hit_wood_3": ("4_treffer/675945__craigsmith__s31-21-artillery-bullets-hitting-nearby-overhead.wav", 4.27, 4.62, False, "hit_own", {}),
    "ricochet_1": ("4_treffer/675953__craigsmith__s25-16-machine-gun-ricochets.wav", 1.63, 2.12, False, "hit_enemy", {}),
    "ricochet_2": ("4_treffer/675953__craigsmith__s25-16-machine-gun-ricochets.wav", 6.20, 6.72, False, "hit_enemy", {}),
    "ricochet_3": ("4_treffer/675955__craigsmith__s20-02-rifle-ricochets.wav", 3.60, 4.45, False, "hit_enemy", {}),
    "ricochet_4": ("4_treffer/675955__craigsmith__s20-02-rifle-ricochets.wav", 5.17, 5.75, False, "hit_enemy", {}),
    "whiz_1": ("4_treffer/675946__craigsmith__s20-40-bullets-flying-overhead-and-hitting-objects.wav", 6.30, 6.95, False, "hit_own", {}),
    "whiz_2": ("4_treffer/675946__craigsmith__s20-40-bullets-flying-overhead-and-hitting-objects.wav", 8.55, 9.10, False, "hit_own", {}),
    "whiz_3": ("4_treffer/675946__craigsmith__s20-40-bullets-flying-overhead-and-hitting-objects.wav", 9.32, 9.90, False, "hit_own", {}),
    # Explosion / Absturz / Bauchlandung
    "explosion_1": ("5_explosionen/483294__craigsmith__r30-06-big-crisp-explosions.wav", 3.12, 7.6, False, "explosion", {"fade_out": 1.5}),
    "explosion_2": ("5_explosionen/483294__craigsmith__r30-06-big-crisp-explosions.wav", 9.72, 14.4, False, "explosion", {"fade_out": 1.5}),
    "explosion_3": ("5_explosionen/483281__craigsmith__r09-53-huge-explosion.wav", 0.12, 5.2, False, "explosion", {"fade_out": 1.5}),
    "crash_impact": ("5_explosionen/483276__craigsmith__r09-48-huge-explosion-with-wood-and-sand-debris.wav", 1.10, 7.8, False, "explosion", {"fade_out": 2.0}),
    "crash": ("8_metall/486276__craigsmith__r04-50-metal-scraping.wav", 0.8, 5.0, False, "crash", {"fade_out": 1.2}),
    # Feuer (Wrack, Brand)
    "fire": ("9_feuer/BURNING/FIREBurn_Fire burning with rumble; without crackle_CS_USC.wav", 3.0, 13.0, True, "fire",
             {"mix": ("9_feuer/BURNING/FIREBurn_Heavy fire crackle_CS_USC.wav", 0.5, -6.0)}),
    # Lkw / Tankwagen
    "truck_start": ("6_lkw/487161__craigsmith__r19-48-old-large-truck-start-idle-out.wav", 0.25, 6.0, False, "truck_idle", {"fade_out": 1.5}),
    "truck_idle": ("6_lkw/487161__craigsmith__r19-48-old-large-truck-start-idle-out.wav", 20.0, 32.0, True, "truck_idle", {}),
    "truck_drive": ("6_lkw/487151__craigsmith__r03-29-large-truck-constant-engine.wav", 1.0, 10.5, True, "truck_idle", {}),
    # Alarm (Einstellung „Alarmton“: Sirene/Glocke)
    "alarm_siren": ("7_alarm/675691__craigsmith__s24-14-single-air-raid-siren.wav", 4.0, 34.0, True, "alarm_siren", {}),
    "alarm_bell": ("7_alarm/675682__craigsmith__s28-15-old-style-fire-alarm-bell-hand-cranked.wav", 0.0, 4.6, True, "alarm_bell", {"tail_fade": 0.6}),
    # Bodenbetrieb: Metall, Kisten, Werkzeug, Klappen
    "crate_down_1": ("8_metall/486287__craigsmith__r16-35-metal-thump.wav", 0.66, 1.15, False, "crate_down", {}),
    "crate_down_2": ("8_metall/486287__craigsmith__r16-35-metal-thump.wav", 1.78, 2.40, False, "crate_down", {}),
    "crate_down_3": ("8_metall/486287__craigsmith__r16-35-metal-thump.wav", 4.16, 4.80, False, "crate_down", {}),
    "crate_up_1": ("8_metall/486277__craigsmith__r08-55-metal-clanks.wav", 4.86, 5.30, False, "crate_up", {}),
    "crate_up_2": ("8_metall/486277__craigsmith__r08-55-metal-clanks.wav", 7.09, 7.50, False, "crate_up", {}),
    "tool": ("8_metall/486288__craigsmith__r16-36-screwdriver-on-metal.wav", 2.0, 10.0, True, "tool", {}),
    "belt": ("8_metall/486292__craigsmith__r17-14-jingling-metal.wav", 1.0, 2.6, False, "belt", {"fade_out": 0.4}),
    "enter": ("8_metall/486284__craigsmith__r16-31-metal-clank-and-ring.wav", 0.60, 1.10, False, "enter", {}),
    "hatch": ("einzeln/488221__irolan__opening-and-closing-a-small-metal-hatch.wav", 10.10, 10.95, False, "hatch", {}),
    "hatch_open": ("einzeln/488221__irolan__opening-and-closing-a-small-metal-hatch.wav", 0.70, 1.60, False, "hatch", {}),
    # Umgebung
    "ambient": ("einzeln/240108__klankbeeld__meadow-land-summer-ambience-nl-140603_0262.wav", 2.0, 62.0, True, "ambient", {"stereo": True}),
    "wind": ("einzeln/136287__juskiddink__storm-wind.wav", 30.0, 52.0, True, "wind", {}),
}

# MG: Einzelschuss-Grains aus der Browning-Salve, neu gesetzt auf 1150/min je MG (zwei Flügel-MGs).
MG_SRC = ("3_maschinengewehre/486042__craigsmith__r12-04-browning-machine-gun.wav", 2.0, 4.0)
MG_TAIL = ("3_maschinengewehre/486040__craigsmith__r11-49-machine-gun-with-reverb.wav", 1.66, 3.2)
MG_RPM = 1150.0
MG_SHOTS = 24   # je MG und Loop -> Loop = 24 * 60/1150 s

HUM = (60.0, 120.0, 180.0, 240.0)
NO_HUM = ("einzeln/",)          # moderne Digitalaufnahmen: keine Brummkerben


# --- Grundbausteine -----------------------------------------------------------------------

def load(path, sr=SR, stereo=False):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "2" if stereo else "1", "-ar", str(sr),
                          "-f", "f32le", "-"], capture_output=True, check=True).stdout
    x = np.frombuffer(raw, np.float32).astype(np.float64)
    return x.reshape(-1, 2).T if stereo else x


def encode(x, path, q=4):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    ch = 2 if x.ndim == 2 else 1
    data = (x.T if ch == 2 else x).astype(np.float32).tobytes()
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", str(ch), "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(q), path], input=data, check=True)


def per_channel(fn, x, *a, **k):
    return np.stack([fn(c, *a, **k) for c in x]) if x.ndim == 2 else fn(x, *a, **k)


def dehum(x):
    for h in HUM:
        b, a = signal.iirnotch(h, 35.0, SR)
        x = signal.filtfilt(b, a, x)
    return x


def highpass(x, fc=35.0):
    sos = signal.butter(2, fc, "highpass", fs=SR, output="sos")
    return signal.sosfiltfilt(sos, x)


def denoise(x, noise_src, amount=0.6, floor=0.35):
    """Spektralabzug: Rauschprofil = Median der leisesten 10 % Rahmen von noise_src."""
    n = 1024
    _, _, Zn = signal.stft(noise_src, SR, nperseg=n)
    e = np.mean(np.abs(Zn) ** 2, axis=0)
    quiet = Zn[:, e <= np.percentile(e, 10)]
    prof = np.median(np.abs(quiet), axis=1, keepdims=True)
    _, _, Z = signal.stft(x, SR, nperseg=n)
    mag = np.abs(Z)
    g = np.maximum(1.0 - amount * prof / (mag + 1e-12), floor)
    g = signal.medfilt2d(g, (1, 5))      # gegen „Musical Noise“
    _, y = signal.istft(Z * g, SR, nperseg=n)
    return y[:len(x)]


def k_weight(x):
    b1, a1 = signal.butter(2, 60.0, "highpass", fs=SR)
    # Höhenanhebung +4 dB ab ~1,5 kHz (BS.1770-Vorfilter, angenähert)
    b2, a2 = signal.iirfilter(1, 1500.0, btype="highpass", fs=SR)
    y = signal.lfilter(b1, a1, x)
    return y + (10 ** (4 / 20) - 1) * signal.lfilter(b2, a2, y)


def loudness(x):
    """Gegatete K-gewichtete Lautheit (LUFS-ähnlich), Blöcke 400 ms / 75 % Überlappung."""
    m = x.mean(axis=0) if x.ndim == 2 else x
    y = k_weight(m)
    n, h = int(0.4 * SR), int(0.1 * SR)
    if len(y) < n:
        y = np.pad(y, (0, n - len(y)))
    z = np.array([np.mean(y[i:i + n] ** 2) for i in range(0, len(y) - n + 1, h)])
    lk = -0.691 + 10 * np.log10(z + 1e-12)
    z = z[lk > -70]
    if len(z) == 0:
        return -70.0
    rel = -0.691 + 10 * np.log10(np.mean(z)) - 10
    z2 = z[-0.691 + 10 * np.log10(z) > rel]
    return float(-0.691 + 10 * np.log10(np.mean(z2 if len(z2) else z)))


def limit(x, ceil_db=-1.0):
    c = 10 ** (ceil_db / 20)
    t = 0.75 * c
    a = np.abs(x)
    over = a > t
    y = x.copy()
    y[over] = np.sign(x[over]) * (t + (c - t) * np.tanh((a[over] - t) / (c - t)))
    return y


def fades(x, fin=0.004, fout=0.02):
    n = x.shape[-1]
    i, o = max(int(fin * SR), 1), max(int(fout * SR), 1)
    w = np.ones(n)
    w[:i] = np.linspace(0, 1, i)
    w[n - o:] *= np.cos(np.linspace(0, np.pi / 2, o)) ** 2
    return x * w


def resample(x, factor):
    """Tonhöhe * factor (Dauer / factor), polyphas."""
    if abs(factor - 1.0) < 1e-4:
        return x
    from fractions import Fraction
    fr = Fraction(1.0 / factor).limit_denominator(400)
    return per_channel(signal.resample_poly, x, fr.numerator, fr.denominator)


def make_loop(x, length_s, xfade_s=0.25):
    """Nahtloser Loop: Länge L um ±8 % so gewählt, dass x[L:L+F] am besten zu x[0:F] passt, dann
    x[0:F] mit x[L:L+F] überblendet (gleiche Amplitude bei hoher Korrelation, sonst gleiche Leistung).
    Am Loop-Punkt folgt y[0] = x[L] direkt auf y[L-1] = x[L-1] -> kein Sprung."""
    mono = x.mean(axis=0) if x.ndim == 2 else x
    F = int(xfade_s * SR)
    L0 = int(length_s * SR)
    maxL = mono.shape[-1] - F - 1
    best, bl = -2.0, min(L0, maxL)
    a = mono[:F]
    for L in range(max(int(L0 * 0.92), F * 2), min(int(L0 * 1.08), maxL), 16):
        b = mono[L:L + F]
        r = np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-12)
        if r > best:
            best, bl = r, L
    for L in range(bl - 16, bl + 17):
        if F * 2 <= L <= maxL:
            b = mono[L:L + F]
            r = np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-12)
            if r > best:
                best, bl = r, L
    t = np.linspace(0, 1, F)
    if best > 0.5:
        fi, fo = t, 1 - t
    else:
        fi, fo = np.sin(t * np.pi / 2), np.cos(t * np.pi / 2)
    y = x[..., :bl].copy()
    y[..., :F] = x[..., bl:bl + F] * fo + x[..., :F] * fi
    return y, best


def seam_jump(y):
    """Sprung an der Loop-Grenze relativ zu den Sprüngen im Inneren (1.0 = wie der größte innere
    Schritt im 99,9-%-Perzentil) und Pegelsprung (dB) 30 ms vor/nach der Grenze."""
    m = y.mean(axis=0) if y.ndim == 2 else y
    d = np.abs(np.diff(m))
    jump = abs(m[0] - m[-1]) / (np.percentile(d, 99.9) + 1e-12)
    n = int(0.03 * SR)
    lv = 20 * np.log10((np.sqrt(np.mean(m[:n] ** 2)) + 1e-9) / (np.sqrt(np.mean(m[-n:] ** 2)) + 1e-9))
    return float(jump), float(lv)


def dropouts(x, n, rng):
    """Stottern: n kurze Aussetzer (40–140 ms, 5 ms Flanken) an zufälligen Stellen."""
    y = x.copy()
    for _ in range(n):
        d = int(rng.uniform(0.04, 0.14) * SR)
        s = int(rng.uniform(0.1, 0.85) * (len(y) - d))
        e = int(0.005 * SR)
        w = np.ones(d)
        w[e:d - e] = rng.uniform(0.0, 0.15)
        w[:e] = np.linspace(1, w[e], e)
        w[d - e:] = np.linspace(w[d - e - 1], 1, e)
        y[s:s + d] *= w
    return y


def speech_score(x):
    """Hinweis auf Stimmen: Anteil der Hüllkurven-Modulation 3–7 Hz im Sprachband (0..1)."""
    m = x.mean(axis=0) if x.ndim == 2 else x
    sos = signal.butter(3, [300, 3000], "bandpass", fs=SR, output="sos")
    e = np.abs(signal.sosfilt(sos, m))
    e = signal.resample_poly(e, 1, 320)        # 100 Hz
    e = e - e.mean()
    f, P = signal.welch(e, 100, nperseg=min(256, len(e)))
    return float(P[(f >= 3) & (f <= 7)].sum() / (P[(f >= 0.5) & (f <= 40)].sum() + 1e-12))


# --- Verarbeitung -------------------------------------------------------------------------

class Builder:
    def __init__(self, src, out):
        self.src, self.out = src, out
        self.cache = {}
        self.ref_lufs = {}
        self.manifest = {}

    def source(self, rel, stereo=False):
        key = (rel, stereo)
        if key not in self.cache:
            x = load(os.path.join(self.src, rel), stereo=stereo)
            if not rel.startswith(NO_HUM):
                x = per_channel(dehum, x)
            self.cache[key] = per_channel(highpass, x)
        return self.cache[key]

    def cut(self, rel, a, b, stereo=False, clean=True):
        x = self.source(rel, stereo)
        y = x[..., int(a * SR):int(b * SR)]
        if clean:
            full = x.mean(axis=0) if x.ndim == 2 else x
            y = per_channel(denoise, y, full)
        return y

    def target(self, proc_name):
        if proc_name not in self.ref_lufs:
            p = os.path.join(GAME, "assets/audio/%s.ogg" % proc_name)
            if "/" in proc_name:
                p = os.path.join(GAME, "assets/audio/%s.ogg" % proc_name)
            self.ref_lufs[proc_name] = loudness(load(p)) if os.path.exists(p) else -20.0
        return self.ref_lufs[proc_name]

    def finish(self, name, y, loop, ref_name, info):
        g = self.target(ref_name) - loudness(y)
        y = limit(y * 10 ** (g / 20))
        path = os.path.join(self.out, name + ".ogg")
        encode(y, path, q=info.pop("q", 4))
        z = load(path, stereo=y.ndim == 2)        # Messung am dekodierten Ergebnis
        ent = {"loop": loop, "lufs": round(loudness(z), 1), "ref": ref_name, "ref_lufs": round(self.target(ref_name), 1),
               "peak_db": round(float(20 * np.log10(np.max(np.abs(z)) + 1e-9)), 1),
               "len_s": round(z.shape[-1] / SR, 3), "speech": round(speech_score(z), 3), "bytes": os.path.getsize(path)}
        if loop:
            j, lv = seam_jump(z)
            ent.update({"seam_jump": round(j, 2), "seam_db": round(lv, 2)})
        ent.update(info)
        self.manifest[name] = ent
        print("%-22s %6.2fs %6.1f LUFS (Ziel %6.1f) Spitze %5.1f%s" % (name, ent["len_s"], ent["lufs"], ent["ref_lufs"],
              ent["peak_db"], "  Loop-Sprung %.2f / %.2f dB" % (ent["seam_jump"], ent["seam_db"]) if loop else ""))
        return z

    def engines(self):
        for name, rel, a, b, f0, ft in ENGINE_V12:
            x = self.cut(rel, a, b)
            x = resample(x, ft / f0)
            y, r = make_loop(x, ENGINE_LOOP_S[name], 0.35)
            self.finish("engines/v12/" + name, y, True, "engines/v12/mid",
                        {"src": rel, "cut": [a, b], "f0": f0, "f_target": ft, "ref_rpm": round(2750.0 * ft / 70.5),
                         "xfade_corr": round(r, 2)})

    def shots(self):
        for name, (rel, a, b, loop, ref, ex) in SHOTS.items():
            ex = dict(ex)
            stereo = ex.pop("stereo", False)
            y = self.cut(rel, a, b + (0.6 if loop else 0.0), stereo=stereo)
            if "mix" in ex:
                mrel, ma, mdb = ex.pop("mix")
                m = self.cut(mrel, ma, ma + y.shape[-1] / SR + 0.1)[:y.shape[-1]]
                y = y + m * 10 ** (mdb / 20) * np.sqrt(np.mean(y ** 2) / (np.mean(m ** 2) + 1e-12))
            if "dropouts" in ex:
                y = dropouts(y, ex.pop("dropouts"), RNG)
            if loop:
                if "tail_fade" in ex:      # Glocke: Ausklingen vor der Loop-Grenze, dann stille Grenze
                    y = fades(y[..., :int((b - a) * SR)], 0.002, ex.pop("tail_fade"))
                    r = 1.0
                else:
                    y, r = make_loop(y, b - a, 0.5 if (b - a) > 6 else 0.25)
                ex["xfade_corr"] = round(r, 2)
            else:
                y = fades(y, 0.003, ex.pop("fade_out", 0.03))
            ex.update({"src": rel, "cut": [a, b]})
            self.finish(name, y, loop, ref, ex)

    def mg(self):
        x = self.cut(*MG_SRC)
        hp = signal.sosfilt(signal.butter(2, 1000, "highpass", fs=SR, output="sos"), x)
        w = int(0.002 * SR)
        e = np.convolve(hp ** 2, np.ones(w) / w, "same")
        pk, _ = signal.find_peaks(e, distance=int(0.035 * SR))
        pk = pk[(pk > int(0.01 * SR)) & (pk < len(x) - int(0.09 * SR))]
        pk = pk[np.argsort(-e[pk])][:10]           # zehn deutlichste Einzelschüsse
        pre, post = int(0.006 * SR), int(0.075 * SR)
        env = np.concatenate([np.linspace(0, 1, pre), np.exp(-np.linspace(0, 4.0, post))])
        grains = [x[p - pre:p + post] * env for p in pk]
        grains = [g / np.sqrt(np.mean(g ** 2)) for g in grains]
        period = 60.0 / MG_RPM
        L = int(round(MG_SHOTS * period * SR))
        for name, inner in (("mg_loop", False), ("mg_int", True)):
            y = np.zeros(L + len(grains[0]))
            for gun, off in ((0, 0.0), (1, 0.43)):
                for k in range(MG_SHOTS):
                    g = grains[RNG.integers(len(grains))] * RNG.uniform(0.8, 1.0)
                    s = int(round((k + off) * period * SR + RNG.uniform(-0.002, 0.002) * SR)) % L
                    seg = y[s:s + len(g)]
                    seg += g[:len(seg)]
            # zyklisch falten (Ausschwingen über die Loop-Grenze nach vorn) -> exakt periodisch
            y[:len(y) - L] += y[L:]
            y = y[:L]
            if inner:   # Innen: dumpfer (Rumpf/Haube), Mechanik-Rattern betont, mehr Tiefe
                y = signal.sosfiltfilt(signal.butter(2, 2200, "lowpass", fs=SR, output="sos"), y)
                y = y + 0.5 * signal.sosfiltfilt(signal.butter(2, [90, 400], "bandpass", fs=SR, output="sos"), y)
            self.finish(name, y, True, "mg_loop", {"src": MG_SRC[0], "cut": [MG_SRC[1], MG_SRC[2]], "rpm": MG_RPM,
                                                  "guns": 2, "grains": len(grains), "perspective": "innen" if inner else "aussen"})
        t = self.cut(*MG_TAIL)
        self.finish("mg_tail", fades(t, 0.01, 0.4), False, "mg_loop", {"src": MG_TAIL[0], "cut": [MG_TAIL[1], MG_TAIL[2]]})

    def run(self):
        self.engines()
        self.mg()
        self.shots()
        total = 0
        for root, _, files in os.walk(self.out):
            total += sum(os.path.getsize(os.path.join(root, f)) for f in files if f.endswith(".ogg"))
        with open(os.path.join(self.out, "manifest.json"), "w") as f:
            json.dump({"sr": SR, "bytes": total, "sounds": self.manifest}, f, indent=1, ensure_ascii=False, sort_keys=True)
        print("zusammen %d Dateien, %.2f MB" % (len(self.manifest), total / 1e6))


# --- Hörproben (Simulation wie im Spiel: Layer-Überblendung, Pitch, Doppler) -------------------

def layer_weight(refs, i, r):
    r0 = refs[i]
    x = 1.0
    if r <= r0 and i > 0:
        x = np.clip((r - refs[i - 1]) / (r0 - refs[i - 1]), 0, 1)
    elif r > r0 and i + 1 < len(refs):
        x = np.clip((refs[i + 1] - r) / (refs[i + 1] - r0), 0, 1)
    return np.sin(x * np.pi / 2)


def render_engine(layers, refs, snd_rpm, gain_db, dist=None):
    """layers: Loops; snd_rpm/gain_db: je Ausgabesample. Pitch = snd_rpm/ref (variable Lesegeschwindigkeit)."""
    n = len(snd_rpm)
    out = np.zeros(n)
    for i, lp in enumerate(layers):
        w = np.array([layer_weight(refs, i, r) for r in snd_rpm[::64]])
        w = np.repeat(w, 64)[:n]
        rate = np.clip(snd_rpm / refs[i], 0.5, 2.0)
        if dist is not None:
            rate = rate * dist["doppler"]
        pos = np.cumsum(rate) + RNG.uniform(0, len(lp))
        out += w * np.interp(pos % len(lp), np.arange(len(lp)), lp)
    return out * 10 ** (gain_db / 20)


def sound_rpm(rpm, refs, idle=850.0, top=2800.0):
    g = np.log(refs[-1] / refs[0]) / np.log(top / idle)
    return refs[0] * (np.maximum(rpm, 1.0) / idle) ** g


def proben(out_audio, dst):
    os.makedirs(dst, exist_ok=True)
    man = json.load(open(os.path.join(out_audio, "manifest.json")))["sounds"]
    L = lambda n: load(os.path.join(out_audio, n + ".ogg"))
    P = lambda n: load(os.path.join(GAME, "assets/audio", n + ".ogg"))
    names = [e[0] for e in ENGINE_V12]
    layers = [L("engines/v12/" + n) for n in names]
    refs = [man["engines/v12/" + n]["ref_rpm"] for n in names]

    def save(name, y):
        y = limit(y / (np.max(np.abs(y)) + 1e-9) * 0.8)
        encode(y, os.path.join(dst, name + ".ogg"), q=5)

    # 1 Anlassen -> Leerlauf -> Vollgas -> zurück
    whine, catch = P("starter_whine"), L("engine_catch")
    T = 22.0
    t = np.arange(int(T * SR)) / SR
    gas = np.interp(t, [0, 9, 12, 16, 18, 22], [0, 0, 1, 1, 0.1, 0.1])
    rpm = 850 + (2800 - 850) * (0.6 * gas + 0.0) / 0.75
    on = t > 3.6
    eng = render_engine(layers, refs, sound_rpm(rpm, refs), 0) * np.clip((t - 3.4) / 0.6, 0, 1) * on
    eng *= 10 ** ((np.interp(gas, [0, 1], [-6, 0])) / 20)
    y = eng.copy()
    y[:len(whine)] += whine * 0.6
    s = int(2.6 * SR)
    y[s:s + len(catch)] += catch[:len(y) - s] * 0.9
    save("01_motor_anlassen_leerlauf_vollgas", y)
    # 2 Überflug (Gegner, 120 m/s, 60 m Passierabstand, Doppler + Entfernung + Luftdämpfung)
    T = 10.0
    t = np.arange(int(T * SR)) / SR
    v, d0 = 120.0, 60.0
    xpos = v * (t - T / 2)
    r = np.sqrt(xpos ** 2 + d0 ** 2)
    radial = v * xpos / r
    doppler = 343.0 / (343.0 + radial)
    rpm = np.full(len(t), 2500.0)
    eng = render_engine(layers, refs, sound_rpm(rpm, refs), 0, {"doppler": doppler})
    eng += 0.5 * render_engine([L("wind")], [1.0], np.ones(len(t)), -4, {"doppler": doppler})
    att = np.minimum(1.0, 30.0 / r)
    # Luftdämpfung: zeitvariabler Tiefpass (blockweise)
    outp = np.zeros_like(eng)
    blk = 1024
    zi = None
    for i in range(0, len(eng), blk):
        fc = float(np.clip(9000.0 * (60.0 / r[i]) ** 0.8, 1200.0, 9000.0))
        b, a = signal.butter(1, fc, fs=SR)
        if zi is None:
            zi = signal.lfilter_zi(b, a) * 0
        outp[i:i + blk], zi = signal.lfilter(b, a, eng[i:i + blk], zi=zi)
    save("02_ueberflug_gegner", outp * att)
    # 3 MG-Salve außen (1,2 s) + Schwanz, dann innen
    mg, mgi, tail = L("mg_loop"), L("mg_int"), L("mg_tail")
    def burst(lp, secs):
        n = int(secs * SR)
        b = np.tile(lp, n // len(lp) + 1)[:n]
        b[-int(0.01 * SR):] *= np.linspace(1, 0, int(0.01 * SR))
        return np.concatenate([b, tail])
    y = np.concatenate([burst(mg, 1.2), np.zeros(int(0.4 * SR)), burst(mgi, 1.0) * 0.8])
    save("03_mg_salve_aussen_innen", y)
    # 4 Treffer: Metall, Holz/Stoff, Querschläger, Vorbeizischen
    parts = []
    for n in ["hit_metal_1", "hit_metal_4", "hit_wood_1", "hit_wood_3", "ricochet_1", "ricochet_3", "whiz_1", "whiz_2"]:
        parts += [L(n), np.zeros(int(0.35 * SR))]
    save("04_treffer", np.concatenate(parts))
    # 5 Explosion, Absturz, Feuer
    fire = L("fire")
    y = np.concatenate([L("explosion_1"), np.zeros(int(0.3 * SR)), L("crash_impact")])
    f = np.tile(fire, 3)[:int(5 * SR)] * 0.5
    f[:int(1.0 * SR)] *= np.linspace(0, 1, int(1.0 * SR))
    f[-int(1.0 * SR):] *= np.linspace(1, 0, int(1.0 * SR))
    save("05_explosion_absturz_feuer", np.concatenate([y, f]))
    # 6 Lkw: Anlassen, Leerlauf, Fahren
    st, idle, drive = L("truck_start"), L("truck_idle"), L("truck_drive")
    n = int(5 * SR)
    a = np.tile(idle, 2)[:n]
    b = np.tile(drive, 2)[:n]
    xf = np.linspace(0, 1, int(1.5 * SR))
    mix = np.concatenate([a[:n - len(xf)], a[n - len(xf):] * (1 - xf) + b[:len(xf)] * xf, b[len(xf):]])
    y = np.concatenate([st[:int(len(st) - 1.0 * SR)], mix])
    save("06_lkw", y)
    # 7 Alarm: Sirene, Glocke
    sir, bell = L("alarm_siren"), L("alarm_bell")
    y = np.concatenate([sir[:int(8 * SR)] * np.minimum(1, np.linspace(0, 8, int(8 * SR))) * np.minimum(1, np.linspace(8, 0, int(8 * SR)) / 1.5),
                        np.zeros(int(0.5 * SR)), np.tile(bell, 2)])
    save("07_alarm_sirene_glocke", y)
    # 8 Flugplatz-Atmo (stereo) + Bodenbetrieb
    amb = load(os.path.join(out_audio, "ambient.ogg"), stereo=True)[:, :int(14 * SR)]
    for nm, at in (("hatch_open", 2.0), ("crate_down_1", 4.5), ("crate_up_1", 6.0), ("hatch", 8.0), ("tool", 10.0)):
        s = L(nm)[:int(2.5 * SR)]
        i = int(at * SR)
        amb[:, i:i + len(s)] += 0.35 * s
    amb = limit(amb / (np.max(np.abs(amb)) + 1e-9) * 0.7)
    encode(amb, os.path.join(dst, "08_flugplatz_atmo.ogg"), q=5)
    # 9 Schaden: Stottern, Spucken bei leerem Tank
    y = render_engine(layers, refs, sound_rpm(np.full(int(4 * SR), 2300.0), refs), 0)
    y[int(1.5 * SR):int(1.5 * SR) + len(L("engine_misfire"))] *= 0.25
    y[int(1.5 * SR):int(1.5 * SR) + len(L("engine_misfire"))] += L("engine_misfire")[:int(2.5 * SR)]
    save("09_motor_stottern_tank_leer", np.concatenate([y, L("engine_starve")]))
    print("Hörproben:", sorted(os.listdir(dst)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="/home/claude/flugzeug/asset_quellen/sounds")
    ap.add_argument("--out", default=os.path.join(GAME, "assets/audio/real"))
    ap.add_argument("--proben", default="")
    ap.add_argument("--nur-proben", action="store_true")
    a = ap.parse_args()
    if not a.nur_proben:
        if not os.path.isdir(a.src):
            sys.exit("Quellordner fehlt: " + a.src)
        Builder(a.src, a.out).run()
    if a.proben:
        proben(a.out, a.proben)


if __name__ == "__main__":
    main()
