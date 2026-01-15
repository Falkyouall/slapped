# Progress

## Phase 1: Core Foundation ✅
- Projektstruktur, Vehicle mit Arcade-Steuerung, DynamicCamera, Teststrecke, Kollisionen

## Phase 2: Multiplayer Local ✅
- Input für 2 Spieler (WASD + Pfeiltasten), Controller-Support vorbereitet
- Dynamische Kamera folgt dem **Race Leader** (basierend auf Streckenfortschritt)
- **Dynamischer Catch-Up Zoom:**
  - Kamera zoomt raus wenn Spieler zurückfallen (ab 600px Distanz)
  - Gibt ihnen Chance aufzuholen bevor Out-of-Bounds
  - Zoomt smooth wieder rein wenn sie näher kommen
  - Parameter: `catchup_distance`, `max_distance`, `min_zoom` einstellbar
- **"Wrecked" Style Out-of-Bounds System:**
  - Wer vom Bildschirm fällt verliert 1 Leben
  - Das GESAMTE Rennen startet neu von der Startlinie
  - Alle Spieler gehen zurück zum Start
  - Der Spieler der rausfiel hat 1 Leben weniger
- Rundensystem: 5 Runden, Gewinner bekommt Punkt
- HUD zeigt: Spielername (farbig), Platz + Fortschritt %, Leben, Punkte
- ESC pausiert das Spiel

## Race Position Tracking System ✅
**State-of-the-Art Path2D-basiertes Tracking** (wie in Mario Kart, F-Zero etc.)

### Architektur:
```
RaceTracker.gd (scripts/race/)
  └── Verwendet Path2D/Curve2D für Fortschrittsberechnung
  └── API: get_leader(), get_position(), get_progress(), get_progress_percent()

RacingLineSetup.gd (scripts/tracks/)
  └── Script für Path2D Nodes in Track-Szenen
  └── Export: racing_points Array definiert die Strecken-Mittellinie
```

### Für neue Strecken:
1. Path2D Node "RacingLine" erstellen
2. `racing_line_setup.gd` Script anhängen
3. `racing_points` Array im Inspector mit Mittellinie-Punkten füllen

## Wichtige Dateien:

| Datei | Beschreibung |
|-------|--------------|
| `scripts/game.gd` | Hauptspiellogik, Out-of-Bounds, Runden-Management |
| `scripts/race/race_tracker.gd` | Zentrales Position-Tracking Modul |
| `scripts/tracks/racing_line_setup.gd` | Track-spezifische Racing-Line Definition |
| `scripts/vehicles/vehicle.gd` | Fahrzeug mit Arcade-Steuerung, Leben |
| `scripts/vehicles/dynamic_camera.gd` | Kamera folgt Leader mit Look-ahead |
| `scripts/ui/hud.gd` | HUD mit Platz, Leben, Punkte Anzeige |
| `scenes/tracks/test_track.tscn` | Ovale Test-Strecke mit RacingLine |

## Nächste Phase: 3 - Combat System
- Power-up Spawner auf der Strecke
- Waffen-System (Raketen, Boost, Schild, Mine)
- Treffer-Feedback und Effekte

---
*Siehe auch: `/planning/race_tracking_system.md` für technische Details*
