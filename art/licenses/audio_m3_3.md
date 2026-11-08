# Audio – Herkunft und Lizenz (M3.3)

Alle Klänge in diesem Ordner sind **selbst prozedural erzeugt** mit `game/tools/gen_audio.py`
(Python, numpy/scipy-Synthese: Zündimpulse, gefiltertes Rauschen, Sinus-Partiale, Hüllkurven;
Kodierung Ogg Vorbis über ffmpeg/libvorbis). Es wurden **keine Fremdaufnahmen oder
Sample-Bibliotheken** verwendet.

Lizenz: **CC0 1.0** (gemeinfrei) – frei nutzbar ohne Namensnennung.

Neu erzeugen (aus `game/`): `python3 tools/gen_audio.py` (fester Zufallsstartwert → reproduzierbar).

| Datei | Inhalt | Loop |
|---|---|---|
| engine_radial | Sternmotor (9 Zyl.), Pitch im Spiel 0,55–1,6 | ja |
| engine_inline | Reihenmotor V12 (Gegner) | ja |
| wind | Fahrtwind/Propellerrauschen | ja |
| gear, flaps, touchdown, crash | Fahrwerk, Klappen, Aufsetzen, Bauchlandung | nein |
| mg_loop | MG-Feuer (2 MG, ≈ 20 Schuss/s) | ja |
| hit_own, hit_enemy, explosion, eject | Treffer, Absturz, Notausstieg | nein |
| fire | Brand/Knistern | ja |
| step_grass, crate_up, crate_down, hatch, belt, enter | Boden-Aktionen | nein |
| truck_idle, pump, tool | Wagen-Leerlauf, Tankpumpe, Ratsche | ja |
| siren | Alarm (Handkurbelsirene) | ja |
| ambient | Wind + Vögel am Boden | ja |
| ui_click, ui_confirm, ui_step | Menü, Bestätigung, Tutorial-Schritt | nein |

Mono, 22 050 Hz, Vorbis q0–q2; zusammen ≈ 230 KB.
