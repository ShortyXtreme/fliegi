# Audio – Herkunft und Lizenz (M3.3)

Alle Klänge in diesem Ordner sind **selbst prozedural erzeugt** mit `game/tools/gen_audio.py`
(Python, numpy/scipy-Synthese: Zündimpulse, gefiltertes Rauschen, Sinus-Partiale, Hüllkurven;
Kodierung Ogg Vorbis über ffmpeg/libvorbis). Es wurden **keine Fremdaufnahmen oder
Sample-Bibliotheken** verwendet.

Lizenz: **CC0 1.0** (gemeinfrei) – frei nutzbar ohne Namensnennung.

Neu erzeugen (aus `game/`): `python3 tools/gen_audio.py` (v1-Klänge) und `python3 tools/gen_audio_v2.py` (Motoren, Alarm,
Tankwagen, Pumpe: Zündfolge, Auspuffresonanz, Propellerschlag, exakt periodische Loops); fester Zufallsstartwert.

**Echte Aufnahmen** (z. B. Warbird-Pakete) ersetzen einen Motortyp, indem `engines/<typ>/idle|mid|full.ogg`
ausgetauscht werden (nahtlose Loops); die Bezugsdrehzahl je Layer steht in `GameAudio.ENGINE_RPM`. Neuer Typ:
Ordner + Eintrag in `ENGINE_RPM`, im Flugzeug `AircraftData.engine_sound = "<typ>"`.

| Datei | Inhalt | Loop |
|---|---|---|
| engines/v12/idle, mid, full | Reihenmotor V12 (fighter_t1), Drehzahl-Layer 850/1800/2750 U/min (v2) | ja |
| engines/radial/idle, mid, full | Sternmotor 9 Zyl., Drehzahl-Layer 700/1550/2450 U/min (v2, für spätere Typen) | ja |
| wind | Fahrtwind/Propellerrauschen | ja |
| gear, flaps, touchdown, crash | Fahrwerk, Klappen, Aufsetzen, Bauchlandung | nein |
| mg_loop | MG-Feuer (2 MG, ≈ 20 Schuss/s) | ja |
| hit_own, hit_enemy, explosion, eject | Treffer, Absturz, Notausstieg | nein |
| fire | Brand/Knistern | ja |
| step_grass, crate_up, crate_down, hatch, belt, enter | Boden-Aktionen | nein |
| truck_idle, pump | Tankwagen-Vierzylinder, Tankpumpe (v2) | ja |
| tool | Ratsche | ja |
| alarm_siren | Alarm: mechanische Rotorsirene, auf- und abschwellend (v2, Standard) | ja |
| alarm_bell | Alarm: Alarmglocke (v2, Einstellung „Alarmton: Glocke“) | ja |
| ambient | Wind + Vögel am Boden | ja |
| ui_click, ui_confirm, ui_step | Menü, Bestätigung, Tutorial-Schritt | nein |

Mono, 22 050 Hz, Vorbis q0–q2; zusammen ≈ 380 KB.
