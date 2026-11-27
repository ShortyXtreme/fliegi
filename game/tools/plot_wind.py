#!/usr/bin/env python3
"""M3.9: Diagramm aus tools/wind_dump.gd -> docs/screens_m3/m3_9_wind_profil.png
python3 tools/plot_wind.py <csv-Präfix> <out.png>"""
import csv
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

S1, S2, S3, S4 = "#257de0", "#f47230", "#00b894", "#f2a600"
TXT, TXT2, GRID = "#191919", "#666666", "#e6e6e6"


def load(path):
    with open(path) as f:
        r = csv.DictReader(f)
        rows = list(r)
    return {k: [float(row[k]) for row in rows] for k in rows[0]}


def style(ax, title, xl, yl):
    ax.set_title(title, loc="left", fontsize=11, color=TXT, fontweight="bold")
    ax.set_xlabel(xl, color=TXT2, fontsize=9)
    ax.set_ylabel(yl, color=TXT2, fontsize=9)
    ax.tick_params(colors=TXT2, labelsize=8)
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    for s in ("left", "bottom"):
        ax.spines[s].set_color("#bbbbbb")
    ax.grid(True, color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)


def main():
    pre, out = sys.argv[1], sys.argv[2]
    p = load(pre + "_profil.csv")
    z = load(pre + "_zeit.csv")
    w = load(pre + "_wetter.csv")
    fl = load(pre + "_flug.csv")
    fig, axs = plt.subplots(2, 3, figsize=(15, 8.5), dpi=110)
    fig.patch.set_facecolor("white")

    ax = axs[0][0]
    for key, col, lab in (("wasser", S1, "Wasser"), ("gras", S2, "Wiese"), ("feld", S3, "Feld"), ("wald", S4, "Wald")):
        ax.plot(p[key], p["h"], color=col, lw=2, label=lab)
    ax.set_yscale("log")
    style(ax, "Höhenprofil (Normal, 5 m/s in 10 m über Gras)", "mittlerer Wind (m/s)", "Höhe über Grund (m, log)")
    ax.legend(frameon=False, fontsize=8, labelcolor=TXT)

    ax = axs[0][1]
    ax.plot(p["drehung"], p["h"], color=S1, lw=2)
    ax.set_yscale("log")
    style(ax, "Rechtsdrehung mit der Höhe (Ekman)", "Richtung „woher“ relativ zu 10 m (Grad)", "Höhe über Grund (m, log)")

    ax = axs[0][2]
    n = int(600 / 0.2)
    ax.plot([t / 60 for t in z["t"][:n]], z["boden7m"][:n], color=S1, lw=1, label="Windsack 7 m (mit Böen)")
    ax.plot([t / 60 for t in z["t"][:n]], [v * 0.93 for v in z["mittel10m"][:n]], color=TXT2, lw=2, ls="--",
            label="Mittel in 7 m")
    style(ax, "Böen am Windsack (10 min)", "Zeit (min)", "Wind (m/s)")
    ax.legend(frameon=False, fontsize=8, labelcolor=TXT)

    ax = axs[1][0]
    ax.plot([t / 60 for t in w["t"]], w["mittel10m"], color=S1, lw=2)
    style(ax, "Großwetter über 3 h: Stärke (10 m)", "Zeit (min)", "mittlerer Wind (m/s)")
    ax.set_ylim(bottom=0)

    ax = axs[1][1]
    ax.plot([t / 60 for t in w["t"]], w["richtung"], color=S2, lw=2)
    fr = [t / 60 for t, f in zip(w["t"], w["front"]) if 0.05 < f < 0.95]
    if fr:
        ax.axvspan(fr[0], fr[-1], color="#efefef", zorder=0)
        ax.text(fr[-1] + 2, min(w["richtung"]), "Kaltfront", color=TXT2, fontsize=8)
    style(ax, "Großwetter über 3 h: Richtung „woher“", "Zeit (min)", "Grad (0 = Nord, 90 = Ost)")

    ax = axs[1][2]
    ax.plot(fl["t"], fl["w30"], color=S1, lw=1.2, label="vertikal, 30 m")
    ax.plot(fl["t"], fl["w300"], color=S2, lw=1.2, label="vertikal, 300 m")
    ax.plot(fl["t"], fl["thermik300"], color=S3, lw=2, label="Thermik, 300 m")
    style(ax, "Böen entlang einer Flugbahn (100 m/s)", "Zeit (s)", "Vertikalwind (m/s)")
    ax.legend(frameon=False, fontsize=8, labelcolor=TXT)

    fig.suptitle("Flugkern M3.9 – Windmodell (Testlauf tools/wind_dump.gd)", x=0.01, ha="left",
                 fontsize=13, color=TXT, fontweight="bold")
    fig.tight_layout(rect=(0, 0, 1, 0.96))
    fig.savefig(out, facecolor="white")


if __name__ == "__main__":
    main()
