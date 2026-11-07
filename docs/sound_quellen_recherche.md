# Sound-Quellen-Recherche (echte Aufnahmen, kommerziell nutzbar)

Stand: 07.11.2026. Ziel: echte Aufnahmen für ein kommerzielles Steam-Spiel aus der Zeit Ende der 1930er/1940er Jahre, die wir auch als **Rohmaterial** verwenden: schneiden, schichten, filtern, Loops bauen, Pitch und Tempo ändern, mit Synthese mischen.
Heruntergeladen wurde nichts, und im Repo ist nichts committet.

**Erreichbarkeit:** (a) = über GitHub/git aus der Arbeitsumgebung ladbar. (b) = muss der Product Owner (PO) manuell herunterladen.
**Ergebnis:** Kein brauchbarer Kandidat ist über GitHub erreichbar, **alle Funde sind (b).**
**Bearbeitung:** Gibt an, ob abgeleitete Werke (Schnitt, Schichtung usw.) erlaubt sind.
**Schicht-Tipp ★:** Eignet sich besonders als Ausgangsmaterial, etwa lange Loops bei konstanter Drehzahl, Einzelschüsse oder trockene Aufnahmen.

## Lizenzen im Überblick

| Lizenz | Kommerziell | Namensnennung | Bearbeitung | Einschränkung |
|---|---|---|---|---|
| CC0 1.0 (Freesound, archive.org) | ja | nein | ja | keine |
| CC BY 4.0 / CC BY 3.0 | ja | **ja, im Abspann** (Titel, Urheber, Lizenz, Link) | ja | keine |
| Sonniss GDC Bundle License | ja | nein („without attribution to the original creator“) | ja, im eigenen Projekt. Verboten ist nur „modify … with intent to claim authorship“ | Kein Weiterverkauf und keine Weitergabe als Einzel-SFX oder Soundpack. Eingebettet im Spiel ist das erlaubt. |
| Pixabay Content License | ja | nein | ja | Keine „Standalone“-Weitergabe. Herkunft der Uploads ist oft unklar, daher nur Notlösung. |
| CC BY-NC, Sampling+ | **nein** | | | ausgeschlossen |

**Wichtiger Risiko-Hinweis zur USC/Craig-Smith-Sammlung** (Freesound-Nutzer `craigsmith` und archive.org-Sammlung `usc-sound-effect-archive`):
- Die Sammlung ist als CC0 1.0 markiert. Es handelt sich um digitalisierte Hollywood-Studioeffekte von 1930 bis 1960 (Red/Gold Library, Sunset Editorial), überspielt von USC Cinema.
- Die CC0-Erklärung beruht auf der Einschätzung des Uploaders. Er schreibt wörtlich: *„I consider Hollywood sound effects recorded between 1927 and 2000 as Public Domain“* und *„not a lawyer“*.
- Eine ausdrückliche Freigabe der Studios gibt es nicht. Das Restrisiko ist gering bis mittel: Die Effekte werden seit Jahrzehnten frei herumgereicht, ein Rechteinhaber ist praktisch nicht feststellbar, und archive.org hostet sie ebenfalls als CC0.
- Für das Spielgefühl der Epoche ist die Sammlung ideal. Für die **Kernklänge (Motor, MG)** sollten wir aber zusätzlich modernes Material mit sauberer Lizenz schichten (Sonniss), damit keiner unserer Klänge allein auf USC-Material beruht.

---

## 1. Propellermotor (Stern-/V12-Motor)

| # | Titel / Datei | URL | Lizenz (wörtlich) | Urheber | Dauer / Qualität | Eignung | Bearb. | Erreichb. | Risiko |
|---|---|---|---|---|---|---|---|---|---|
| 1 ★ | **Sonniss GDC 2018 Game Audio Bundle** – Ordner `Pole Position - Messerschmitt Bf109 G4`: `Me_109_t2_ext_stationary_startup_idle_steady_rpms_shutdown_pointing_exhaust_K6.L.wav` / `.R.wav` (je 47 MB) + `Me_109_t7_foley_power_lever_DPA4017.wav` | https://sonniss.com/gameaudiogdc18/ (Torrent: https://sonniss.com/GameAudioGDCPart4.torrent) | Sonniss GDC Bundle License („royalty-free … personal and commercial projects without attribution“) | Pole Position Production | 24 bit / 48 kHz, Mehrspur-Profiaufnahme | Echter DB 605 V12: Anlassen, Leerlauf, **konstante Drehzahlstufen**, Abstellen. Bestes Loop-Material. | ja (im Spiel) | b | sehr gering. Inhalt aus Datei-Index (Torrent-Liste) bestätigt, nicht von offizieller Seite. |
| 2 ★ | dto., `Pole Position - Supermarine Spitfire Mk XIV`: `Spitfire_Mk_XIV_t1_onbrd_stationary_startup_steady_rpms_cockpit_DPA4061.L/.R.wav` (je 129 MB) + `..._t10_ext_landing_passby_mid_runway_following_plane_CSS5.wav` | wie oben | wie oben | Pole Position | 24/96 (laut Datenblatt) | **Cockpit-Innengeräusch** Griffon V12, konstante Drehzahl, plus Vorbeiflug | ja | b | wie oben |
| 3 ★ | dto., `Pole Position - North American P-51D Mustang` (`P-51D_t2_ext_startup_ramps_shutdown_distant_behind_RSM191.L/.R.wav`, `P-51D_t7_foley_buttons_switches_canopy_dashboard.wav`), `Pole Position - Curtiss C-46 Commando` (`C-46_t2_onbrd_startup_idle_steady_rpms_ramps_throttle_movements_shutdown_..._PZM.wav`, **Sternmotor** P&W R-2800), `Pole Position - Fokker Dr. 1 1917` (`fokker_dr1_t2_ext_fast_fly_bys_XY_RSM191.wav`) | wie oben | wie oben | Pole Position | Profi | Merlin-Hochlaufen, Sternmotor innen, Flybys | ja | b | wie oben |
| 4 | G04-23-WWII Fighter Starts, Taxis, Stops.wav (+ Pack „Vintage WWII Fighter Aircraft“: Takes Off, Revs Engine, P-51 Passes, P-47 Overhead, Many Overhead) | https://freesound.org/s/437790 · Pack: https://freesound.org/people/craigsmith/packs/24883/ | Creative Commons 0 | craigsmith (USC/Hollywood) | 1:54, mono 24/48, teils verrauscht | Echter Epochen-Klang, Anlassen und Leerlauf | ja | b (Freesound-Konto nötig) | USC-Hinweis oben |
| 5 | G06-13_2 Engine Prop Steady Engine.wav | https://freesound.org/s/437831 | Creative Commons 0 | craigsmith | 1:38 | Zweimot. konstante Drehzahl, ★ Loop | ja | b | USC |
| 6 | Pack „Vintage Aircraft - Props (Red Lib)“ (u. a. R17-03 Prop Plane Idles and Revs, R02-36 Prop Plane Fly By) | https://freesound.org/people/craigsmith/packs/27154/ | Creative Commons 0 | craigsmith | 9 Dateien | Leerlauf, Hochlaufen, Stottern (Schaden!) | ja | b | USC |
| 7 | Spitfire and B-17 Taxi | https://freesound.org/s/142897 | Attribution 3.0 | Fight2FlyPhoto | 0:47 | Merlin + Wright Cyclone beim Rollen | ja | b | Namensnennung |
| 8 | P-47 Flyby / B-25s Taking Off | https://freesound.org/s/143560 · https://freesound.org/s/143559 | Attribution 3.0 | Fight2FlyPhoto | 0:12 / 0:44 | Sternmotor R-2800 Flyby, Start | ja | b | Namensnennung |
| 9 | Hurricane and Spitfire dog fighting | https://freesound.org/s/434671 | Attribution 4.0 | jimsim | 8:17, Airshow | Merlin/Griffon im Kurvenkampf, Doppler | ja | b | Namensnennung, Publikum hörbar |
| 10 | spitfire fly past.mp3 | https://freesound.org/s/42968 | Attribution 4.0 | mattew | 0:36, MP3, war übersteuert | Spitfire-Flyby | ja | b | geringe Qualität |
| 11 | WW2AirplaneFlyover.wav (T-6 Texan) | https://freesound.org/s/43807 | Attribution 4.0 | daveincamas | 2:24, Wind | **Harvard/T-6** Sternmotor, 2 Überflüge | ja | b | Namensnennung, Wind |
| 12 | Viima 1939-Schuldoppeldecker, Kreisen / Sturzflug | https://freesound.org/s/322058 · https://freesound.org/s/254511 | Attribution 4.0 | YleArkisto | 2:35 / 0:41, Analogband 1981 | Sternmotor (Siemens-Halske) aus der Epoche | ja | b | Namensnennung |
| 13 | Small plane (Cessna) engine start, idle, and takeoff | https://freesound.org/s/322321 | Creative Commons 0 | JLWSound | 21:54, Kabine | Kein Warbird, aber CC0. Lange Leerlauf-/Kabinenpassagen ★ als Unterschicht. | ja | b | gering |

Ausgeschlossen, weil NC lizenziert: freesound 33370 (ermine, Spitfire), 161103 (Hurricane), 161114 (B-25), 156015, 275138, 233582. Ebenfalls ausgeschlossen: 12815 (Sampling+, synthetisch), 347795 (synthetisch).

## 2. Sirene / Alarm

| # | Titel | URL | Lizenz | Urheber | Dauer | Eignung | Bearb. | Erreichb. | Risiko |
|---|---|---|---|---|---|---|---|---|---|
| 1 ★ | G44-02-Air Raid Siren.wav | https://freesound.org/people/craigsmith/sounds/438696/ | Creative Commons 0 | craigsmith | 0:28 | Mechanische Luftschutzsirene mit Hoch- und Auslaufen, Epochenklang | ja | b | USC |
| 2 ★ | Air Raid Siren (Sofia) | https://freesound.org/s/157463 | Creative Commons 0 | cocaine | 2:48, iPhone | Echte mechanische Sirene, lang, gut für Loops | ja | b | gering, Handy-Qualität |
| 3 | Pack „SSE Vintage Alarms“ (S24-14 Single air raid siren, S24-15 Hand Cranked siren, S03-05 Glass bell) bzw. archive.org „SSE Library: ALARMS“ (`Bell_Old style fire alarm bell; hand cranked`, `Siren_Air raid siren`) | https://freesound.org/people/craigsmith/packs/37713/ · https://archive.org/details/SSE_Library_ALARMS | CC0 1.0 Universal | craigsmith / USC | – | Handsirene + **Alarmglocke** (Flugplatzalarm) | ja | b (archive.org ohne Konto) | USC |
| 4 | HLS273 Sirene Signal: Warnung (Hörmann, mechanisch) | https://freesound.org/s/324576 | Attribution 4.0 | dcf77 | 2:32 | Deutsche Hörmann-Sirene, passt für den deutschen Flugplatz | ja | b | Namensnennung, komprimiert |
| 5 | Broadmoor Hospital Siren Test | https://freesound.org/s/80460 | Creative Commons 0 | hyderpotter | 4:22, MP3 | Wechselton und Entwarnung | ja | b | MP3 |

## 3. MG-Feuer, Einschläge, Explosion, Feuer

| # | Titel | URL | Lizenz | Urheber | Dauer | Eignung | Bearb. | Erreichb. | Risiko |
|---|---|---|---|---|---|---|---|---|---|
| 1 ★ | Pack „Vintage Guns - Machine (Red Lib)“: **R12-04-Browning Machine Gun**, **R12-06-Machine Gun Single Shots** ★ (Einzelschüsse), **R30-31-Old Machine Gun Without Ambience** ★ (trocken), R30-43 Rapid-Fire | https://freesound.org/people/craigsmith/packs/27453/ | Creative Commons 0 | craigsmith | – | Browning .30 ist das passende Kaliber. Einzelschüsse und trockene Salven eignen sich zum Schichten. | ja | b | USC |
| 2 | Pack „SSE Vintage Bullets“: 675951 *Shooting gallery; hitting metal targets* ★ (Einschlag Metall), 675953 *Machine gun ricochets*, 675946 *Bullets flying overhead and hitting objects* | https://freesound.org/people/craigsmith/packs/37732/ | Creative Commons 0 | craigsmith | – | **Treffer auf Metall**, Querschläger, Vorbeifliegen | ja | b | USC |
| 3 | Sonniss GDC 2018: `Pole Position - The Outdoor Gun Acoustics Library` (z. B. `AK5_valley_field_forest_50m_behind_gun_..._M10.wav`, `MP5_forest_road_10m_...wav`) | https://sonniss.com/gameaudiogdc18/ | Sonniss GDC Bundle License | Pole Position | Profi | Moderne Gewehre mit Außen-Hall. Nicht epochentypisch, aber als **saubere Transienten-/Hallschicht** unter das Browning-Material. | ja | b | gering |
| 4 ★ | Pack „Vintage Explosions (Red Lib)“ (R29-33 *Large Explosion with Metal and Glass Debris*, R30-06 *Big Crisp Explosions*), identisch zu archive.org „Red Library: Explosions“ (22 Dateien, FLAC/WAV) | https://freesound.org/people/craigsmith/packs/27307/ · https://archive.org/details/Red_Library_Explosions | CC0 1.0 Universal | craigsmith / USC | – | Absturz/Explosion mit Metalltrümmern | ja | b | USC |
| 5 ★ | archive.org „SSE Library: FIRE“ (`Burn_Heavy fire crackle`, `Burn_Fire burning with rumble; without crackle` ★ Loop) | https://archive.org/details/SSE_Library_FIRE | CC0 1.0 Universal | USC / Sunset Editorial | 11 Dateien, WAV/FLAC | Brennendes Wrack, Knistern | ja | b | USC |
| 6 | S37-27 Various side swipes and metallic crashes; fire or steam | https://freesound.org/s/675850 | Creative Commons 0 | craigsmith | 0:45 | Aufschlag/Absturz-Metall | ja | b | USC |
| 7 | air-raid.wav (Sirene + Bomber + Wind, Gestaltung) | https://freesound.org/s/160888 | Creative Commons 0 | blaukreuz | 0:54 | Fertige Luftangriffs-Atmosphäre (Intro/Menü) | ja | b | gering |

## 4. Boden / Flugplatz

| # | Titel | URL | Lizenz | Urheber | Dauer | Eignung | Bearb. | Erreichb. | Risiko |
|---|---|---|---|---|---|---|---|---|---|
| 1 ★ | Pack „Vintage Trucks (Red Lib)“: 487161 *Old Large Truck Start Idle Out*, 487151 *Large Truck Constant Engine* ★ (Loop), 487152 *Old Truck Engine Working Hard*, 487162 *Truck Drives in Low Gear* | https://freesound.org/people/craigsmith/packs/27529/ (Einzeln: https://freesound.org/people/craigsmith/sounds/487161/ usw.) | Creative Commons 0 | craigsmith | – | Oldtimer-Lkw: Anlassen, Leerlauf, Fahren | ja | b | USC |
| 2 | Pack „Vintage Metal (Red Lib)“ / „SSE Vintage Metal“ (Klappern, Metall-Thump, Kurbel) | https://freesound.org/people/craigsmith/packs/27466/ · https://freesound.org/people/craigsmith/packs/37703/ | Creative Commons 0 | craigsmith | – | Munitionskiste, Werkzeug, Metallgeräusche | ja | b | USC |
| 3 ★ | Opening and closing a small metal hatch | https://freesound.org/people/Irolan/sounds/488221 | Creative Commons 0 | Irolan | 0:15 | **Metallklappe** mit Riegeln (Tankdeckel/Wartungsklappe) | ja | b | gering |
| 4 ★ | Fantozzi's Footsteps (Grass/Sand & Stone) | https://lpc.opengameart.org/node/21492 | CC0 | Fantozzi | 12 Einzelschritte, FLAC/OGG | **Schritte auf Gras** als Einzelsamples | ja | b | gering |
| 5 | meadow-land summer ambience NL / spring field NL 05 | https://freesound.org/s/240108 · https://freesound.org/people/klankbeeld/sounds/547361 | Attribution 4.0 | klankbeeld | 12:35 / 8:43 | Wiese, Vögel, Insekten: Flugplatz-Grundatmosphäre ★ Loop | ja | b | Namensnennung |
| 6 | Pumpe/Treibstoff | – | – | – | – | **Kein geeigneter CC0/CC-BY-Fund.** Vorschlag: aus der Lkw-/Metall-Sammlung von craigsmith (Pumpe, Kurbel: S23-02 *Metallic crank noise*, 675483) plus Wasser-/Gluckergeräusch schichten. | | | |

## 5. Cockpit-Mechanik / Wind

| # | Titel | URL | Lizenz | Urheber | Dauer | Eignung | Bearb. | Erreichb. | Risiko |
|---|---|---|---|---|---|---|---|---|---|
| 1 ★ | Sonniss GDC 2018: `P-51D_t7_foley_buttons_switches_canopy_dashboard.wav` (15 MB), `Me_109_t7_foley_power_lever_DPA4017.wav` | https://sonniss.com/gameaudiogdc18/ | Sonniss GDC Bundle License | Pole Position | Profi | **Echte Warbird-Cockpitmechanik**: Schalter, Haube, Gashebel | ja | b | gering |
| 2 | 140802_SXF_PlaneLandingInt.wav (Fahrwerk/Klappen-Hydraulik, Airliner) | https://freesound.org/s/249439 | Creative Commons 0 | blaukreuz | 6:53 | Hydraulik und Fahrwerk-Rumpeln zum Herausschneiden, mit dem Metall-Foley schichten | ja | b | modern, Stimmen hörbar, nur Ausschnitte nutzen |
| 3 | R02-48-Jet Fighter Canopy Closing (Pack „Vintage Aircraft - Jets“) | https://freesound.org/people/craigsmith/packs/27152/ | Creative Commons 0 | craigsmith | – | Kabinenhaube | ja | b | USC |
| 4 ★ | Storm wind.wav (loopbar) | https://freesound.org/s/136287 | Attribution 4.0 | juskiddink | 2:09 | Fahrtwind/Sturz-Wind als Rauschschicht | ja | b | Namensnennung |
| 5 | Old wind machine // Vanha tuulikone | https://freesound.org/s/455592 | Attribution 4.0 | YleArkisto | 0:51 | Historische Wind-Maschine, sehr „sauberer“ Wind ★ | ja | b | Namensnennung |

Für Fahrwerk und Klappen eines Warbirds gibt es keine freie Aufnahme. Gute Lösung: Metall-Foley (craigsmith) + Hydraulik aus #2 + Elektromotor schichten.

---

## Empfohlenes Paket (minimale Downloads, deckt alle 5 Kategorien)

Zielordner: `C:\Users\Daniel\Desktop\fliegi\sounds_roh\`

**A. Sonniss GDC 2018 Game Audio Bundle**, deckt Kategorie 1 (Kern), 3 (Schicht) und 5 ab, ohne Namensnennung.
- Seite: https://sonniss.com/gameaudiogdc18/ (oder Übersicht https://sonniss.com/gameaudiogdc/)
- Am sparsamsten ist der **Torrent** https://sonniss.com/GameAudioGDCPart4.torrent. Im Torrent-Programm (z. B. qBittorrent) nur diese Ordner anhaken:
  - `Pole Position - Messerschmitt Bf109 G4`
  - `Pole Position - Supermarine Spitfire Mk XIV`
  - `Pole Position - North American P-51D Mustang`
  - `Pole Position - Curtiss C-46 Commando`
  - `Pole Position - Fokker Dr. 1 1917`
  - `Pole Position - The Outdoor Gun Acoustics Library`
  
  Das sind zusammen ca. 1 GB statt 31 GB.
- Ablage: `sounds_roh\sonniss_gdc2018\`, dazu die beiliegende `License.pdf` aufbewahren.

**B. Freesound-Packs von `craigsmith`** (CC0), decken die Kategorien 1 bis 5 im Epochenklang ab. Kostenloses Freesound-Konto nötig, auf der Pack-Seite „Download pack“ (ZIP) wählen:
1. https://freesound.org/people/craigsmith/packs/24883/ (WWII Fighter)
2. https://freesound.org/people/craigsmith/packs/27154/ (Props)
3. https://freesound.org/people/craigsmith/packs/27453/ (Machine Guns)
4. https://freesound.org/people/craigsmith/packs/37732/ (Bullets)
5. https://freesound.org/people/craigsmith/packs/27307/ (Explosions)
6. https://freesound.org/people/craigsmith/packs/27529/ (Trucks)
7. https://freesound.org/people/craigsmith/packs/37713/ (Alarms)
8. https://freesound.org/people/craigsmith/packs/27466/ (Metal)
9. Einzeldatei https://freesound.org/people/craigsmith/sounds/438696/ (Air Raid Siren)

Ablage: `sounds_roh\usc_craigsmith\`. Feuer: https://archive.org/details/SSE_Library_FIRE, rechts unter „WAVE“ als ZIP, in denselben Ordner.

**C. Einzeldateien** (Ablage `sounds_roh\einzeln\`):
- https://freesound.org/s/157463 (Sirene, CC0)
- https://freesound.org/people/Irolan/sounds/488221 (Metallklappe, CC0)
- https://lpc.opengameart.org/node/21492 (Schritte, CC0)
- https://freesound.org/s/240108 (Wiese, CC BY 4.0)
- https://freesound.org/s/136287 (Wind, CC BY 4.0)

**Abspann-Pflicht (nur bei C):** „meadow-land summer ambience NL 140603_0262.wav“ von klankbeeld (freesound.org/s/240108) und „Storm wind.wav“ von juskiddink (freesound.org/s/136287), beide CC BY 4.0. Alles Übrige im Paket ist CC0 bzw. Sonniss und braucht keine Namensnennung.

## Quellen (Recherche)
- Sonniss Spitfire XIV Datenblatt: https://sonniss.com/wp-content/uploads/2017/05/Supermarine-Spitfire-Mk-XIV-sound-effects-library.pdf
- Datei-Index GDC 2018 (nur zur Inhaltsprüfung, **nicht** als Download nutzen): https://www.torrentdownloads.pro/torrent/1664709968/Sonniss++-+GDC+2018+-+Game+Audio+Bundle
- Lizenz GDC-Bundle (Kopie): https://scrubby.duckdns.org/Sonniss.com%20-%20GDC%202023%20-%20Game%20Audio%20Bundle/License.pdf und Übersicht https://licenseorg.com/guide/music-audio/sonniss
- GDC 2018 Downloadhinweise: https://community.gamedev.tv/t/30gb-of-high-quality-royalty-free-sound-effects-the-sonniss-gameaudiogdc-bundle-2018/63406
- USC-Sammlung: https://blog.archive.org/2023/05/20/crash-bark-boom-the-usc-sound-effects-library/ · https://openculture.com/2024/09/download-1000-digitized-tapes-of-sounds-from-classic-hollywood-films-tv.html
- Pixabay-Lizenz: https://pixabay.com/da/service/license
