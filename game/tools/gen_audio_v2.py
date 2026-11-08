#!/usr/bin/env python3
"""M3.3 v2 (Tester-Feedback): realistischere Synthese für Motor und Alarm. Eigene Synthese, CC0.
Motor: Zündimpulse nach Zündfolge (Sternmotor 9 Zyl. 1-3-5-7-9-2-4-6-8, V12 60°), Takt- und
Lautstärke-Streuung je Zündung, Auspuff-Resonanz (Kammfilter = Rohrlänge, Formant-Bandpässe),
Ventil-/Mechanikrauschen im Nockenwellentakt, Propellerschlag (Blattfrequenz über Untersetzung),
weiche Sättigung, Raumanteil (frühe Reflexionen). Drehzahl-Layer (Leerlauf/Mitte/Voll), je 4 s Loop
mit Kreuzblende (keine Naht). Sirene: mechanische Rotor-Sirene (Doppelrotor, Anlauf/Auslauf,
Tonhöhen-Schwankung, Obertöne, Luftrauschen, Hall) und Alarmglocke (Glockenpartiale, Klöppel).
Aufruf (aus game/): python3 tools/gen_audio_v2.py [assets/audio] [hoerproben-ordner]
Alle v2-Loops sind exakt periodisch (ganze Zahl Zündungen/Umdrehungen, Filter über 3 Perioden)."""
import os
import sys

import numpy as np
from scipy import signal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_audio as ga  # noqa: E402  (write, Filter, SR)

SR = ga.SR
rng = np.random.default_rng(1938)

# --- Bausteine ---------------------------------------------------------------------------------


def comb(x, delay_s, fb):
    """Rückgekoppelter Kammfilter (Auspuffrohr: Grundresonanz c/2L)."""
    d = max(1, int(delay_s * SR))
    a = np.zeros(d + 1)
    a[0] = 1.0
    a[d] = -fb
    return signal.lfilter([1.0], a, x)


def peak(x, f, q, gain):
    b, a = signal.iirpeak(f, q, fs=SR)
    return x + gain * signal.lfilter(b, a, x)


def room(x, amount=0.18):
    """Frühe Reflexionen (Boden, Hallenwände) + kurze diffuse Fahne."""
    y = x.copy()
    for d, g in [(0.011, 0.5), (0.023, 0.35), (0.037, 0.25), (0.061, 0.18), (0.089, 0.12)]:
        n = int(d * SR)
        y[n:] += x[:-n] * g * amount * 2
    tail = ga.lp(np.convolve(x, ga.noise(int(0.25 * SR)) * ga.env_exp(int(0.25 * SR), 0.06), "same"), 2500)
    return y + tail * amount * 0.02


def sat(x, drive):
    return np.tanh(x * drive) / np.tanh(drive)


def crossfade_loop(x, loop_s, xf_s=0.5):
    """x ist loop_s + xf_s lang: Ende weich in den Anfang blenden -> nahtloser Loop."""
    n, k = int(loop_s * SR), int(xf_s * SR)
    out = x[:n].copy()
    w = np.sin(np.linspace(0, np.pi / 2, k)) ** 2
    out[:k] = x[:k] * w + x[n:n + k] * (1 - w)
    return out


# --- Motor -------------------------------------------------------------------------------------

RADIAL = dict(cyl=9, order=[0, 2, 4, 6, 8, 1, 3, 5, 7], gear=0.5625, blades=3, pipe=0.0042,
              formants=[(95, 2.0, 2.5), (310, 3.0, 1.6), (820, 4.0, 0.8)], click=0.035, bark=1.0)
V12 = dict(cyl=12, order=list(range(12)), gear=0.477, blades=3, pipe=0.0028,
           formants=[(140, 2.5, 2.0), (520, 3.5, 1.4), (1350, 4.0, 0.7)], click=0.03, bark=0.75)


def _tile3(x):
    return np.tile(x, 3)


def _mid(y, n):
    return y[n:2 * n]


def room_loop(x, amount):
    """room() für periodische Signale (3x kacheln, Mitte) -> keine Naht."""
    n = len(x)
    return _mid(room(_tile3(x), amount), n)


def engine_layer(e, rpm, sec=4.0, load=1.0):
    """Ein Drehzahl-Layer als exakt periodischer Loop (ganze Zahl Zündungen/Blattschläge je Loop,
    Rauschen und alle Filter über 3 Perioden gekachelt) -> nahtlos ohne Kreuzblende."""
    n = int(sec * SR)
    f_fire = rpm / 60.0 * e["cyl"] / 2.0          # Zündungen je s (4-Takt)
    nf = max(1, int(round(f_fire * sec)))
    per = n / nf                                   # Samples je Zündung (exakt periodisch)
    x = np.zeros(n)
    kl = int(min(per / SR * 2.2, 0.06) * SR)
    kt = np.arange(kl) / SR
    cyl_gain = 1.0 + rng.normal(0, 0.08, e["cyl"])
    cyl_tone = rng.uniform(0.85, 1.15, e["cyl"])
    ring_f = e.get("ring", 70)
    nc = len(e["order"])
    for k in range(nf):
        c = e["order"][k % nc]
        amp = cyl_gain[c % len(cyl_gain)] * (1.0 + rng.normal(0, 0.12)) * (0.55 + 0.45 * load)
        s = int(k * per + rng.normal(0, 0.035) * per)
        ring = np.sin(2 * np.pi * ring_f * cyl_tone[c % len(cyl_tone)] * kt) * ga.env_exp(kl, 0.006)
        burst = ga.lp(ga.noise(kl), 1500) * ga.env_exp(kl, 0.0025) * 0.8
        edge = np.exp(-kt / 0.0008)
        x[(np.arange(kl) + s) % n] += amp * (edge * 1.2 + ring * 0.6 + burst) * e["bark"]
    tt = np.arange(n) / SR
    # Mechanik im Zündtakt (Ventiltrieb)
    tick = (0.5 + 0.5 * np.cos(2 * np.pi * nf / sec * tt)) ** 8
    mech_n = ga.noise(n)
    if e["blades"] > 0:
        nb = max(1, int(round(rpm / 60.0 * e["gear"] * e["blades"] * sec)))
        blade = np.clip(np.cos(2 * np.pi * nb / sec * tt), 0, 1) ** 6
    else:
        blade = np.zeros(n)
    air_n = ga.noise(n)

    def chain(xx, tk, bl, mn, an):
        y = comb(xx, e["pipe"], 0.55)
        for f, q, g in e["formants"]:
            y = peak(y, f, q, g)
        y = ga.lp(ga.hp(y, 35), e.get("cut", 2600))
        mech = ga.bp(mn, 1800, 6000) * (0.3 + tk) * e["click"]
        air = ga.bp(an, 200, 1400) * (0.25 + 0.75 * bl) * (0.05 + 0.15 * (rpm / 2600) ** 2) * e.get("air", 1.0)
        thump = ga.lp(bl - bl.mean(), 120) * 0.6
        return y, mech + air + thump

    y, rest = chain(*[_tile3(a) for a in (x, tick, blade, mech_n, air_n)])
    y, rest = _mid(y, n), _mid(rest, n)
    z = ga.norm(y) + rest
    z = sat(ga.norm(z, 1.0), 1.8 + 1.2 * load)
    z = room_loop(z, 0.16)
    return ga.norm(z, 0.85)


# Drehzahlen je Layer müssen zu GameAudio.ENGINE_RPM passen (game/audio/game_audio.gd).
RADIAL_LAYERS = [("idle", 700, 0.25), ("mid", 1550, 0.6), ("full", 2450, 1.0)]
V12_LAYERS = [("idle", 850, 0.25), ("mid", 1800, 0.6), ("full", 2750, 1.0)]
# Tankwagen: Vierzylinder-Diesel/Benziner, kein Propeller, langes Rohr, dumpfe Formanten
TRUCK = dict(cyl=4, order=[0, 2, 3, 1], gear=0, blades=0, pipe=0.0065, ring=45, cut=1400, air=0,
             formants=[(70, 2.0, 2.5), (180, 3.0, 1.5), (420, 4.0, 0.6)], click=0.06, bark=1.0)


def engines():
    out = {}
    for tag, e, layers in [("radial", RADIAL, RADIAL_LAYERS), ("v12", V12, V12_LAYERS)]:
        for name, rpm, load in layers:
            out["engine_%s_%s" % (tag, name)] = (engine_layer(e, rpm, 4.0, load), rpm)
    return out


def pump_loop(sec=2.0):
    """Tankpumpe: Kolben-/Flügelzellenpumpe (12 Hübe/s, Druckstöße mit Gehäuse-Resonanz),
    Elektromotor-Brummen mit leicht schwankender Last, Treibstoffrauschen im Schlauch."""
    n = int(sec * SR)
    tt = np.arange(n) / SR
    x = np.zeros(n)
    strokes = int(12 * sec)
    kl = int(0.05 * SR)
    kt = np.arange(kl) / SR
    for k in range(strokes):
        s = int(k * n / strokes + rng.normal(0, 0.02) * n / strokes)
        a = 1.0 + rng.normal(0, 0.1)
        hit = (np.sin(2 * np.pi * 240 * kt) * 0.6 + ga.noise(kl) * 0.5) * ga.env_exp(kl, 0.008) * a
        x[(np.arange(kl) + s) % n] += hit
    hum = sum(a * np.sin(2 * np.pi * f * tt) for f, a in [(48, 0.12), (96, 0.08), (144, 0.03)])
    load = 1.0 + 0.15 * np.cos(2 * np.pi * 12 * tt)  # Last im Hubtakt
    flow_n = ga.noise(n)

    def chain(xx, hm, ld, fn):
        y = peak(ga.bp(xx, 80, 3000), 620, 4.0, 1.5)       # Pumpengehäuse
        y = peak(y, 1450, 6.0, 0.8)
        flow = ga.bp(fn, 700, 3200) * (0.5 + 0.5 * ld) * 0.25
        return sat(y * 0.6 + hm * ld * 1.6 + flow, 1.5)
    z = _mid(chain(*[_tile3(a) for a in (x, hum, load, flow_n)]), n)
    return ga.norm(room_loop(z, 0.12), 0.8)


def siren_loop(cycle=8.0, ports=(10, 12), rpm_max=3300.0):
    """Mechanische Rotorsirene als Loop: auf- und abschwellender Heulton (Antrieb zyklisch ein/aus,
    Rotor läuft träge hoch und aus). Rotorumdrehungen je Zyklus ganzzahlig -> exakt periodisch."""
    n = int(cycle * SR)
    tt = np.arange(n) / SR
    on = cycle * 0.55
    # Drehzahl-Kurve: Anlauf (exp.), Auslauf; periodisch zusammengesetzt (Start = Ende)
    w_lo = 0.38
    w = np.where(tt < on, 1 - (1 - w_lo) * np.exp(-tt / 1.4), 0.0)
    w_on = 1 - (1 - w_lo) * np.exp(-on / 1.4)
    tau_off = -(cycle - on) / np.log(w_lo / w_on)
    w = np.where(tt >= on, w_on * np.exp(-(tt - on) / tau_off), w)
    wob = 1 + 0.012 * np.sin(2 * np.pi * (6 / cycle) * tt)
    rps = w * wob * rpm_max / 60.0
    rev = np.cumsum(rps) / SR
    rev *= round(rev[-1]) / rev[-1]
    y = np.zeros(n)
    for p, g in zip(ports, (1.0, 0.8)):
        ph = 2 * np.pi * rev * p
        y += g * (np.clip(np.sin(ph), 0, 1) ** 1.5 - 0.32)
    air_n = ga.noise(n)

    def chain(yy, ww, an):
        y2 = peak(ga.lp(yy, 4500), 900, 2.0, 1.2)
        air = ga.bp(an, 400, 2500) * (0.03 + 0.08 * ww)
        z = sat(ga.norm(y2, 1.0) * np.clip(ww * 1.4, 0, 1) + air, 1.6)
        out = z.copy()
        for d, g in [(0.12, 0.35), (0.27, 0.22), (0.45, 0.14), (0.7, 0.08)]:
            k = int(d * SR)
            out[k:] += ga.lp(z[:-k], 2500) * g
        return out
    return ga.norm(_mid(chain(*[_tile3(a) for a in (y, w, air_n)]), n), 0.85)


def bell_loop(sec=4.0, rate=7.0):
    """Alarmglocke als Loop (Klöppelschläge mit Streuung, Ausklang über die Naht gewickelt)."""
    n = int(sec * SR)
    y = np.zeros(n)
    f0 = 1180.0
    partials = [(0.5, 0.35, 0.9), (1.0, 1.0, 0.7), (1.19, 0.5, 0.5), (1.5, 0.4, 0.45), (2.0, 0.45, 0.35),
                (2.51, 0.25, 0.25), (2.98, 0.2, 0.2), (4.1, 0.1, 0.12)]
    kl = int(1.2 * SR)
    kt = np.arange(kl) / SR
    strikes = int(rate * sec)
    for k in range(strikes):
        s = int((k + rng.normal(0, 0.06)) * n / strikes)
        strike = np.zeros(kl)
        for r, g, tau in partials:
            strike += g * np.sin(2 * np.pi * f0 * r * (1 + rng.normal(0, 0.0005)) * kt + rng.uniform(0, 6.28)) \
                * ga.env_exp(kl, tau * 0.4)
        strike += ga.hp(ga.noise(kl), 3000) * ga.env_exp(kl, 0.002) * 0.6
        y[(np.arange(kl) + s) % n] += strike * (0.8 + rng.uniform(-0.15, 0.15))
    y = sat(ga.norm(y, 1.0), 1.4)
    return ga.norm(room_loop(y, 0.25), 0.85)


def game_files(audio_dir):
    """Spiel-Klänge v2 nach assets/audio: engines/<typ>/{idle,mid,full}.ogg, alarm_siren, alarm_bell,
    truck_idle, pump. Gibt {name: pfad} zurück."""
    old = ga.OUT
    files = {}
    eng = engines()
    for key, (x, _rpm) in eng.items():
        _, typ, layer = key.split("_")
        ga.OUT = os.path.join(audio_dir, "engines", typ)
        files[key] = ga.write(layer, x, 2)
    ga.OUT = audio_dir
    files["alarm_siren"] = ga.write("alarm_siren", siren_loop(), 1)
    files["alarm_bell"] = ga.write("alarm_bell", bell_loop(), 1)
    files["truck_idle"] = ga.write("truck_idle", engine_layer(TRUCK, 750, 2.0, 0.3), 1)
    files["pump"] = ga.write("pump", pump_loop(), 1)
    ga.OUT = old
    return files, eng


# --- Alarm -------------------------------------------------------------------------------------


def rotor_siren(sec=16.0, ports=(10, 12), rpm_max=3300.0, up=5.5, hold=4.0):
    """Mechanische Doppelrotor-Sirene: Drehzahl folgt Antrieb (Anlauf), danach Auslauf."""
    n = int(sec * SR)
    tt = np.arange(n) / SR
    w = np.where(tt < up, 1 - np.exp(-tt / (up / 3.2)), 0.0)
    w_top = 1 - np.exp(-3.2)
    t_off = up + hold
    w = np.where((tt >= up) & (tt < t_off), w_top + (1 - w_top) * (1 - np.exp(-(tt - up) / 1.5)) * 0.4, w)
    w_off = w_top + (1 - w_top) * (1 - np.exp(-hold / 1.5)) * 0.4
    w = np.where(tt >= t_off, w_off * np.exp(-(tt - t_off) / 3.2), w)
    wob = 1 + 0.012 * np.sin(2 * np.pi * 0.7 * tt) + ga.lp(rng.normal(0, 1, n), 3) * 0.02
    rps = w * wob * rpm_max / 60.0
    y = np.zeros(n)
    for p, g in zip(ports, (1.0, 0.8)):
        ph = 2 * np.pi * np.cumsum(rps * p) / SR
        # Lochscheibe: Luftstoß je Port -> gleichgerichteter, abgerundeter Puls (reich an Obertönen)
        y += g * (np.clip(np.sin(ph), 0, 1) ** 1.5 - 0.32)
    y = ga.lp(y, 4500)
    y = peak(y, 900, 2.0, 1.2)  # Trichter-Resonanz
    air = ga.bp(ga.noise(n), 400, 2500) * (0.03 + 0.08 * w)
    z = sat(ga.norm(y, 1.0) * np.clip(w * 1.6, 0, 1) + air, 1.6)
    # Freifeld-Hall: Echo von Hallen/Waldrand
    out = z.copy()
    for d, g in [(0.12, 0.35), (0.27, 0.22), (0.45, 0.14), (0.7, 0.08)]:
        k = int(d * SR)
        out[k:] += ga.lp(z[:-k], 2500) * g
    return ga.fade(ga.norm(out, 0.85), 0.01, 0.4)


def alarm_bell(sec=8.0, rate=7.0):
    """Elektrische/handgeschlagene Alarmglocke: Glockenpartiale, Klöppel mit Streuung."""
    n = int(sec * SR)
    y = np.zeros(n)
    f0 = 1180.0
    partials = [(0.5, 0.35, 0.9), (1.0, 1.0, 0.7), (1.19, 0.5, 0.5), (1.5, 0.4, 0.45), (2.0, 0.45, 0.35),
                (2.51, 0.25, 0.25), (2.98, 0.2, 0.2), (4.1, 0.1, 0.12)]
    kl = int(1.2 * SR)
    kt = np.arange(kl) / SR
    t = 0.05
    while t < sec - 0.05:
        s = int(t * SR)
        a = 0.8 + rng.uniform(-0.15, 0.15)
        strike = np.zeros(kl)
        for r, g, tau in partials:
            strike += g * np.sin(2 * np.pi * f0 * r * (1 + rng.normal(0, 0.0005)) * kt + rng.uniform(0, 6.28)) \
                * ga.env_exp(kl, tau * 0.4)
        strike += ga.hp(ga.noise(kl), 3000) * ga.env_exp(kl, 0.002) * 0.6
        e = min(kl, n - s)
        y[s:s + e] += strike[:e] * a
        t += 1.0 / rate * (1 + rng.normal(0, 0.06))
    y = room(sat(ga.norm(y, 1.0), 1.4), 0.25)
    return ga.fade(ga.norm(y, 0.85), 0.005, 0.3)


# --- Hörproben ---------------------------------------------------------------------------------


def layered_sweep(layers, rpm_curve):
    """Wie im Spiel: Layer nach Drehzahl überblenden (gleiche Leistung), je Layer Pitch = rpm/rpm_layer."""
    n = len(rpm_curve)
    out = np.zeros(n)
    rpms = [r for _, r in layers]
    for i, (x, r0) in enumerate(layers):
        lo = rpms[i - 1] if i > 0 else -1e9
        hi = rpms[i + 1] if i + 1 < len(rpms) else 1e9
        wgt = np.where(rpm_curve <= r0, np.clip((rpm_curve - lo) / (r0 - lo), 0, 1),
                       np.clip((hi - rpm_curve) / (hi - r0), 0, 1))
        wgt = np.sin(wgt * np.pi / 2)
        pos = np.cumsum(rpm_curve / r0)
        out += np.interp(pos % len(x), np.arange(len(x)), x) * wgt
    return out


def previews(dst, eng):
    os.makedirs(dst, exist_ok=True)
    old_out = ga.OUT
    ga.OUT = dst
    sec = 9.0
    n = int(sec * SR)
    tt = np.arange(n) / SR
    rp = 700 + 1750 * np.clip((tt - 2.0) / 3.5, 0, 1) ** 1.3
    rad = [eng["engine_radial_%s" % k] for k in ("idle", "mid", "full")]
    x = layered_sweep(rad, rp) * (0.55 + 0.45 * np.clip((tt - 2.0) / 3.5, 0, 1))
    ga.write("motor_v2_sternmotor_leerlauf_bis_vollgas", ga.fade(ga.norm(x, 0.9), 0.05, 0.3), 3)
    # Vorbeiflug Reihenmotor (Doppler, Entfernung, Luftdämpfung)
    v, d0 = 110.0, 40.0
    xpos = (tt - 4.5) * v
    dist = np.sqrt(xpos ** 2 + d0 ** 2)
    radial_v = xpos / dist * v
    dop = 343.0 / (343.0 + radial_v)
    inl = [eng["engine_v12_%s" % k] for k in ("idle", "mid", "full")]
    y = layered_sweep(inl, 2600 * dop)
    y *= 40.0 / dist
    lp_y = ga.lp(y, 900)
    mix = np.clip((dist - 40) / 300, 0, 1)
    y = y * (1 - mix) + lp_y * mix
    ga.write("motor_v2_reihenmotor_vorbeiflug", ga.fade(ga.norm(y, 0.9), 0.05, 0.3), 3)
    ga.write("alarm_v2_rotorsirene", rotor_siren(10.0, up=4.0, hold=2.5), 3)
    ga.write("alarm_v2_glocke", alarm_bell(8.0), 3)
    ga.OUT = old_out


if __name__ == "__main__":
    # Aufruf (aus game/): python3 tools/gen_audio_v2.py assets/audio [hoerproben-ordner]
    dst = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
    fs, eng = game_files(dst)
    if len(sys.argv) > 2:
        previews(sys.argv[2], eng)
    tot = sum(os.path.getsize(p) for p in fs.values())
    print("%d Dateien, %.0f KB" % (len(fs), tot / 1024))
