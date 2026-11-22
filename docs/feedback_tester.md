# Tester-Feedback

## M1.1 (01.11.2026, Maus/Tastatur + Xbox-Controller)
- Hochziehen fühlt sich deutlich besser an als M1. Controller funktioniert.
- Warnton: ok.
- HUD-Schrift: zu mittig und unschön. Wunsch: Fluganzeigen kompakt in eine Ecke (z. B. links unten/links oben), schönere Schrift/Gestaltung. → wird mit dem Kampf-HUD (M2, Paket 9) neu gestaltet.
- Abriss-Warnung (Rütteln/Ton/HUD) kommt zu früh. Aktuell ab 3° vor dem Abriss. → auf ca. 1,5° vor dem Abriss verkürzen und Stärke progressiv steigern (erst leicht, dann stark). Umsetzung in Paket 14 (gemeinsame Dateien), danach erneut testen.

## Wünsche vom 01.11.2026 (zu HUD-Vorschau M2)
- Anzeigen sollen zur Epoche des Flugzeugs passen: je moderner das Flugzeug, desto moderner das HUD/die Anzeigen (z. B. Tier I: analoge Rundinstrumente/Reflexvisier-Stil; Jets: Head-up-Display mit Leitlinien). → Konzept: HUD-Themes je Tier/Flugzeugklasse, eingeplant nach M2.
- Echte Cockpit-Innenansicht beim Kamerawechsel: modelliertes Cockpit, alle Instrumente zeigen live die echten Werte (Fahrtmesser, Höhenmesser, Variometer, Drehzahl, Kompass, Ladedruck, Kraftstoff, Fahrwerksanzeige…), Steuerknüppel, Pedale und Gashebel bewegen sich mit. → eigener Arbeitsschritt (Blender-Cockpitmodell + Instrumenten-Animation), eingeplant nach M2.

## M3.1 (06.11.2026)
- UI und Hilfe überarbeiten: zu unübersichtlich, Tasten schwer zu merken, sieht nicht schön aus.
- Hilfe für Neulinge: geführtes Tutorial (Starten, Kämpfen, Landen, Abfertigen).

## M3.3 (22.11.2026) → umgesetzt in M3.4
- Einstellungsmenü: Schieberegler ragen in die Beschriftungen. → Beschriftung links in fester Spalte, Regler mit Prozentwert rechts, Liste scrollt bei wenig Höhe (geprüft 720p bis 1440p, 16:9 und 21:9).
- Anzeige-Einstellungen fehlen. → „Anzeigemodus“ Vollbild / Rahmenloses Fenster / Fenster, „Fenstergröße“, „V-Sync“ (gespeichert, beim Start angewendet).
- Tutorial: erst am Boden vorbereiten (aussteigen, tanken, MG laden, einsteigen, Vorflug-Check mit Klappen), dann Start, Fliegen, Zielen, Landung mit Klappen und Fahrwerk, Abstellplatz. → umgebaut (11 Schritte), Klappen werden beim Start und bei der Landung als Aktion geprüft.
- Strömungsabriss-Warnung: Bild soll nicht wackeln. → Kamera-Rütteln standardmäßig aus (Einstellung aus/leicht), stattdessen Summer (schneller/lauter je näher am Abriss), HUD-Hinweis, Controller-Vibration (Standard leicht).
- Flugplatz/Startbahn aufwerten. → Piste 1.300 × 60 m (vorher 900 × 40 m), gemähte Lanen, abgefahrener Mittelstreifen, Randsteine, Schwellen mit Eckflaggen, Lande-T, zwei animierte Windsäcke, sichtbare Rollwege und Abstellfläche, Hecke/Holzzaun, Flugleitung mit Funkmast, Schuppen, Fässer (beide Plätze).

## M3.4 (22.11.2026)
- Menü und Einstellungen: besser.
- Befehlsrad überarbeiten: Fahrzeuge rufen und wegschicken; einzeln befehlen (tanken / aufmunitionieren); danach räumen sie selbst auf und fahren weg – oder man macht es selbst.
- Tutorial: Markierungen, wo und wie man tankt/aufmunitioniert.
- Modell: Munitionsschächte am Flugzeug gut sichtbar; Tankstutzen nicht oben drauf, sondern an sinnvoller Stelle.
- Bug: Nach Ein-/Aussteigen beim Tanken standen noch die Flugsteuerungs-Infos.
- Motor anlassen/abstellen, Strom (Batterie/Zündung) und was man „in echt“ braucht.
- Warnungen (Achtung, Abriss) als rote Lampen unten beim Flug-Panel statt Bildschirmmitte.
- Abgeschossene Flugzeuge sollen nicht verschwinden, sondern abstürzen, je nach Schaden Teile verlieren (Flügel abreißen usw.) – auch das eigene Flugzeug.
