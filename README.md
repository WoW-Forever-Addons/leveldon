# Leveldon 0.2.0 Beta (WoW Forever)

Leveldon ist ein Levelguide für WoW Forever: die schnellste Route mit Quests, Flugpunkten, Ruhestein, Lehrern und Händlern, Schritt für Schritt, mit Questdons Kompass. Die Routen sind pro Volk und Klasse geplant.

**Beta:** Diese Version enthält die Routen für **Stufe 1 bis 30**. Die Stufen 30 bis 60 folgen später. Texte gibt es auf Englisch und Deutsch.

## Installation
- **Questdon 1.3.6 oder neuer** ist Pflicht. Leveldon nutzt Questdons Kompass, Questdaten und Fenster.
- Den Ordner `Leveldon` und die Routenordner `Leveldon_<Volk>` in `Interface\AddOns` kopieren. Geladen wird nur die Route deines Volks.
- Nach dem Einspielen das Spiel neu starten (ein /reload reicht bei neuen Dateien nicht).

## Was Leveldon zeigt
- **Kapitel-Kopf:** Gebiet, Stufenbereich, Schritt x von y und der Fortschritt des Kapitels.
- **Speedrun-Zeile** (`/lvd run` oder die Stoppuhr in der Kopfzeile, standardmäßig aus): deine Zeit auf der Route gegen den Plan, die letzten Stufenaufstiege und wie lange es bis zur nächsten Stufe dauert. Die Uhr hält an, wenn du 2 Minuten nichts tust.
- **Aktuelle Station:** was zu tun ist, die Questziele als kleine Blöcke und Questdons Kompass. Er zeigt auf das Ziel, den Weg um Berge herum zeigen die Punkte auf der Minimap.
- **Die nächsten Schritte** und kommende Stufen-Meilensteine.
- **Lehrer und Händler:** Kommst du an einem Ort mit Händler oder deinem Klassenlehrer an, werden sie ein Schritt dieses Besuchs, wenn es sich lohnt. Beim Händler zählen graue Beute, volle Taschen, kaputte Ausrüstung und (Jäger) Munition, beim Lehrer neue Fähigkeiten.
- **Nadeln über den NPCs:** Der NPC des aktuellen Schritts bekommt eine Nadel über der Namensplakette (gold: annehmen, grün: abgeben, türkis: Lehrer, orange: Händler, violett: Flugmeister und Gasthaus, rot: benannte Gegner). Dafür müssen die Namensplaketten freundlicher NPCs an sein. `/lvd raidmarks` schaltet sie ab.
- **Berufe:** Am Anfang wählst du bis zu zwei Hauptberufe und die Nebenberufe, oder keine. Leveldon baut Lernen, Werkzeugkauf und das Hochleveln in die Route ein.
- **Dungeons** (`/lvd dungeons on`): die Route mit den passenden Dungeons und ihren Quests.
- **Ganze Quest lesen:** Shift-Klick auf einen Schritt oder das Buch in der Kopfzeile.

## Fenster
- Griff unten rechts: Breite und wie viele kommende Schritte das Fenster zeigt.
- Strg + Mausrad: Schriftgröße. Shift + Mausrad: Deckkraft, bis ganz ohne Hintergrund.
- Ist Questdons Questliste offen, hängt sie direkt unter Leveldon.

## Rückmeldungen
- **Melden** (Knopf in der Kopfzeile oder `/lvd report`): „Questgeber nicht da“, „Route ergibt keinen Sinn“ oder eine Notiz mit deinem Text.
- **Aufzeichnung** (`/lvd rec on|off`, an): Leveldon schreibt bei dir mit, wie die Route läuft (Wege, Zeiten, Quests). Die Daten bleiben in deinen SavedVariables.
- **Teilen** (`/lvd share on|off`, an): Leveldon schickt anderen Leveldon-Spielern über Questdons Kanal QuestdonNet, Gilde und Gruppe, wie lange Schritte dauern, welche übersprungen werden und Meldegründe. Nur Zahlen und Routennamen, keine Namen und keine Texte.
- **`/lvd export`**: ein Text mit deinen Meldungen samt Notizen und allem, was andere geteilt haben. Bitte in einen Kommentar auf CurseForge einfügen, damit die Routen besser werden.

## Befehle
`/lvd` (oder `/leveldon`) mit: `next`, `back`, `route`, `reset`, `report`, `profs`, `solo`, `dungeons on|off`, `dungeon`, `dungeon no`, `run`, `run reset`, `text 1.3`, `raidmarks`, `marks`, `camp on|off`, `bag on|off`, `bags`, `rec on|off`, `share on|off`, `export`.

Trainer-Daten nach WhatsTraining (siehe `LICENSE-WhatsTraining.txt`).
