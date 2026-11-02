# Lizenzen der Grafik-Assets (M3)

Stand: 02.11.2026

Alle Modelle, Texturen und Animationen aus M3 sind **Eigenproduktion** und werden vollständig per
Blender-Python-Skript erzeugt (keine fremden Dateien, keine Downloads, kein Mixamo):

| Asset | Erzeugt von | Quelle/Lizenz |
|---|---|---|
| Platz-Modelle (`art/models/ground/*.glb`: Tankwagen, Munitionswagen, Kiste, Fass, Hangar, Tanklager, Munitionsbunker, Werkzeugkiste, Feuerlöscher, Bremsklötze, Bodenmarke) | `art/scripts/build_airfield_props.py` | eigen, Projektlizenz |
| Texturen (`art/textures/ground/*`, `art/textures/crew/*`) | prozedural gebacken (Cycles) | eigen, Projektlizenz |
| Figur „Mechaniker“ + Skelett + 8 Animationen (`art/models/crew/crew_mechanic.glb`) | `art/scripts/build_crew.py` (prozedurale Keyframes) | eigen, Projektlizenz |
| `svc_*`-Marker im Jäger | `art/scripts/build_game_aircraft.py --add-svc` | eigen |

Designs sind generisch (keine echten Marken, Typenbezeichnungen oder Hoheitszeichen).
Fremd-Animationen (z. B. Quaternius, CC0) wurden **nicht** verwendet. Kommen später welche dazu,
gehören Quelle, Lizenztext und Download-Datum als eigene Datei in diesen Ordner.
