# Progress

## Phase 1: Core Foundation ✅
- Projektstruktur, Vehicle mit Arcade-Steuerung, Teststrecke, Kollisionen

## Phase 2: Multiplayer Local ✅
- Input für 2 Spieler (WASD + Pfeiltasten), Controller-Support vorbereitet
- Out-of-Bounds System, Rundensystem, HUD

## 3D-Umbau ✅
**Kompletter Umbau von 2D auf 3D für "Wrecked"-Style geneigte Kamera-Perspektive**

### Koordinaten-Mapping:
- 2D x → 3D x (links/rechts)
- 2D y → 3D z (vorne/hinten)
- 3D y = Höhe (0 für Boden)

### Kamera-System (Wrecked-Style) ✅
- **Perspektivische Vogelperspektive**: Camera3D mit ~55° Neigung
- **Dynamische Positionierung**: Hält ALLE Fahrzeuge im Bild mit Puffer
- **Smooth Kurvenfahrt**: Kamera folgt dem Streckenverlauf mit Interpolation
- **Automatische Höhenanpassung**: Zoomt raus wenn Spieler sich entfernen
- Verwendet `look_at()` für robuste Blickrichtung
- Richtungs-Interpolation für flüssige Kurven

### Kamera-Parameter:
```
default_height: 45
min_height: 35
max_height: 100
back_distance: height * 0.6
screen_margin: 30 (Puffer um Autos)
```

## Wichtige Dateien:

| Datei | Beschreibung |
|-------|--------------|
| `scripts/game.gd` | Hauptspiellogik (Node3D), Out-of-Bounds auf X/Z |
| `scripts/race/race_tracker.gd` | Position-Tracking mit Path3D/Curve3D |
| `scripts/tracks/racing_line_setup.gd` | Track Racing-Line (Vector3) |
| `scripts/vehicles/vehicle.gd` | CharacterBody3D, Bewegung auf X/Z |
| `scripts/vehicles/dynamic_camera.gd` | Wrecked-Style Kamera, hält alle Autos im Bild |
| `scripts/ui/hud.gd` | HUD (CanvasLayer - 2D über 3D) |
| `scenes/tracks/test_track.tscn` | 3D-Strecke mit Wänden, Lighting |

## Nächste Phase: 3 - Combat System
- Power-up Spawner auf der Strecke
- Waffen-System (Raketen, Boost, Schild, Mine)
- Treffer-Feedback und Effekte
