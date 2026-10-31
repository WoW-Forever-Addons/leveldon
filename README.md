# Leveldon 0.2.9 Beta (WoW Forever)

Leveldon ist ein Levelguide für WoW Forever: die schnellste Route mit Quests, Flugpunkten, Ruhestein, Lehrern und Händlern, Schritt für Schritt, mit Questdons Kompass. Die Routen sind pro Volk geplant, die Quests und Lehrer deiner Klasse liegen dort, wo sie am wenigsten Weg kosten.

**Beta:** Diese Version enthält die Routen für **Stufe 1 bis 30**. Die Stufen 30 bis 60 sind als ungetestete Vorschau dabei. Texte gibt es auf Englisch, Deutsch, Französisch, Spanisch, Portugiesisch (Brasilien), Russisch, Koreanisch und traditionellem Chinesisch.

## Installation
- **DonData** (Questdaten) und **DonMap** (Pfeil, Kompass, Karte) sind Pflicht, die CurseForge-App installiert sie mit. Von Hand: die Ordner `DonData` und `DonMap` neben `Leveldon` kopieren.
- **Questdon** ist seit 0.2.9 optional. Mit Questdon gibt es dessen Questliste, Kartenpins und Leveldons Optionsfenster (Questdon 1.3.9 oder neuer); ohne Questdon zeigt DonMaps Pfeil den Weg, eingestellt wird über die `/lvd`-Befehle.
- Den Ordner `Leveldon`, die Routenordner `Leveldon_<Volk>` und `Leveldon_<Volk>Lines` in `Interface\AddOns` kopieren. Geladen wird nur die Route deines Volks, die Lines-Ordner erst, wenn du eine andere Route wählst.
- Nach dem Einspielen das Spiel neu starten (ein /reload reicht bei neuen Dateien nicht).

## Was Leveldon zeigt
- **Kapitel-Kopf:** Gebiet, Stufenbereich, Schritt x von y und der Fortschritt des Kapitels.
- **Speedrun-Zeile** (`/lvd run` oder die Stoppuhr in der Kopfzeile, standardmäßig aus): deine Zeit auf der Route gegen den Plan, die letzten Stufenaufstiege und wie lange es bis zur nächsten Stufe dauert. Die Uhr hält an, wenn du 2 Minuten nichts tust.
- **Aktuelle Station:** was zu tun ist, die Questziele als kleine Blöcke und Questdons Kompass. Er zeigt auf das Ziel, den Weg um Berge herum zeigen die Punkte auf der Minimap.
- **Die nächsten Schritte:** oben der aktuelle Schritt und was du gleich hier miterledigen kannst, darunter die kommenden Schritte, mit Mausrad und Regler zu blättern.
- **Routenwahl** (Optionen > Route oder `/lvd line`): nach deinem Startgebiet über jedes andere Startgebiet deiner Seite leveln, mit Stunden, Quests und Ruf je Route. Wechseln geht auch mitten in der Route.
- **Lehrer und Händler:** An jedem Hub mit Abgabe gibt es einen festen Verkaufsschritt, bevorzugt bei einem Händler, der repariert. Er entfällt, wenn nichts zu verkaufen ist (graue Beute, volle Taschen, kaputte Ausrüstung, Jäger: Munition). Beim Lehrer zählen neue Hauptzauber. Im Gasthaus kommt der Ruhestein zuerst.
- **Taschen:** Gegenstände, die eine spätere Quest braucht, bekommen in den Taschen einen Rahmen, damit du sie nicht verkaufst.
- **Sparmodus beim Lehrer:** Leveldon empfiehlt nur die Hauptzauber, passend zu deiner Talentung, mit ihrem Preis, im Schritt und im Chat am Lehrer. Alles andere entscheidest du selbst, damit das Gold für das Reiten mit 40 reicht.
- **Geld:** Berufe kommen dort in die Route, wo das Geld fürs nächste Klassentraining übrig bleibt. Fehlt es dir wirklich, sagt der Lernschritt, wie viel du aufheben solltest.
- **Reiten mit 40:** ein Schritt beim Reitlehrer (120 Gold, Paladin und Hexenmeister 100 Gold). Fehlt das Gold, geht die Route zu Fuß weiter und Leveldon meldet sich, sobald du es hast.
- **Nadeln über den NPCs:** Der NPC des aktuellen Schritts bekommt eine Nadel über der Namensplakette (gold: annehmen, grün: abgeben, türkis: Lehrer, orange: Händler, violett: Flugmeister und Gasthaus, rot: benannte Gegner). Dafür müssen die Namensplaketten freundlicher NPCs an sein. `/lvd raidmarks` schaltet sie ab.
- **Berufe:** Am Anfang wählst du bis zu zwei Hauptberufe und die Nebenberufe, oder keine. Leveldon baut Lernen, Werkzeugkauf und das Hochleveln in die Route ein.
- **Dungeons** (`/lvd dungeons on`): die Route mit den passenden Dungeons und ihren Quests.
- **Absichtlich sterben:** Wo ein Tod schneller ist als der Rückweg (unter Stufe 10), führt Leveldon erst an die Stelle, von der aus du beim richtigen Geistheiler landest.
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
`/lvd` (oder `/leveldon`) mit: `next`, `back`, `route`, `line`, `options`, `reset`, `report`, `profs`, `solo`, `dungeons on|off`, `dungeon`, `dungeon no`, `run`, `run reset`, `text 1.3`, `raidmarks`, `marks`, `camp on|off`, `bag on|off`, `bags`, `rec on|off`, `share on|off`, `export`, `mem`.

Trainer-Daten nach WhatsTraining (MIT, siehe `LICENSE-WhatsTraining.txt`), ForeverDB (auch foreverdb.net für Zaubernamen) und CMaNGOS classic-db (beide GPL v3); `Training.lua` steht deshalb unter der GPL v3 (siehe `LICENSE-GPLv3.txt`). Gruppenquests und Händler nach CMaNGOS classic-db und ForeverDB. Einige Klassenlehrer (Untote Paladine, Skyborne auf Zephras Isle) nach ForeverDB (Starts.lua, in Forever gesehen).

Data from ForeverDB.net (https://foreverdb.net) (GPL v3 mit Namensnennung, siehe NOTICE.txt der ForeverDB).
