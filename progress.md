# Progress

## Phase 1: Core Foundation ✅
- Projektstruktur, Vehicle mit Arcade-Steuerung, Teststrecke, Kollisionen

## Phase 2: Multiplayer Local ✅
- Input für 2 Spieler (WASD + Pfeiltasten), Controller-Support vorbereitet
- Out-of-Bounds System, Rundensystem, HUD
- Score-System: Punkte bei Out-of-Bounds

## 3D-Umbau ✅
- Doge-Car GLB-Modell mit 4 Rädern
- Sprung-Physik mit Rampen-Erkennung
- Zentrale Konfiguration: GameConfig + WeaponConfig

## Phase 3: Combat System ✅
- MachineGun: 40 Schuss, 20/Sek, Speed 100
- Power-Up System mit Respawn
- RayGun: Strahl-Waffe mit Launch-Effekt

### RayGun Waffe
- Burst-Strahl: 0.3 Sek, 1 Schuss
- 87.5m Reichweite, 0.5m Radius (Multi-Hit möglich)
- ShapeCast3D trifft alle Fahrzeuge im Strahl-Pfad
- Treffer-Effekt: Kickflip mit 360° Rotation basierend auf Trefferrichtung
- Launch: Force 12, ~1.2 Sek Luftzeit
- Launch-Immunity nach Landung (2.5 Sek)

### Wrecked-Style Wobble-System
- Treffer baut Wobble-Intensität auf (+15% pro Treffer, max 100%)
- Auto wackelt hin und her (~10 Hz)
- Klingt nach 0.5s ohne Treffer ab
- Lenkungs-Debuff erst ab 5+ Treffern (90% → 50%)

## Kollisions-System ✅
- Ramming mit Geschwindigkeits-basiertem Impuls
- Grip-Debuff nach Kollision (30% für 0.4s)

## Parametrische Fahrphysik ✅

### VehiclePhysicsConfig (19 Parameter)
```
Antrieb:       engine_force, drag_coefficient, max_speed
Lenkung:       steer_gain_low_speed, steer_gain_high_speed, steer_response_time
Grip/Drift:    grip_base, grip_breakpoint_slip, slide_friction, drift_recovery_strength
Yaw-Kontrolle: yaw_damping, spin_threshold
Kollision:     collision_restitution, collision_energy_loss
Slipstream:    slipstream_range, slipstream_angle, slipstream_max_drag_reduction, slipstream_falloff, slipstream_min_speed
```

### Slipstream-System ✅
- Hinter Fahrzeug fahren gibt Geschwindigkeitsboost
- Reichweite: 50 Einheiten, ±30° Winkel
- Exponentieller Falloff: näher = stärker
- Bis zu 80% Drag-Reduktion + 30% extra Antriebskraft
- Nur aktiv ab 5 m/s, beide müssen gleiche Richtung fahren
- Debug-Metriken: is_in_slipstream, slipstream_intensity (F3)

### Echtzeit-Metriken
- speed_kmh, speed_ms, slip_angle, yaw_rate
- is_drifting, effective_grip, steering_actual
- hit_count, wobble_intensity
- is_in_slipstream, slipstream_intensity

### Debug-Overlay
- Toggle mit F3
- Zeigt alle Metriken in Echtzeit

## Autotune-Framework ✅

### Tests
- **TestAcceleration**: 0-60, 0-100, max_speed
- **TestSteering**: Response-Time, Überschwingen, High-Speed Handling
- **TestDrift**: Drift-Breakpoint, Slip-Winkel, Recovery-Zeit
- **TestCollision**: Restgeschwindigkeit, Spin-Out-Erkennung

### Regelsystem
- Max ±5% Anpassung pro Iteration
- Bis zu 10 Iterationen
- Speichert finale Config als .tres

### Autotune-Szene
- `scenes/autotune/autotune_scene.tscn`
- [ENTER] Start, [ESC] Stop, [R] Reset

## Wichtige Dateien

| Datei | Beschreibung |
|-------|--------------|
| `scripts/autoload/vehicle_physics_config.gd` | 14-Parameter Resource |
| `resources/vehicle_physics.tres` | Standard-Konfiguration |
| `scripts/vehicles/vehicle.gd` | Parametrische Physik + Metriken + Launch-System |
| `scripts/weapons/ray_gun.gd` | RayGun Strahl-Waffe |
| `scripts/autotune/autotune_runner.gd` | Autotune Controller |
| `scripts/autotune/autotune_rules.gd` | Regelbasierte Anpassung |
| `scripts/autotune/tests/*.gd` | 4 Test-Klassen |
| `scripts/ui/hud.gd` | HUD + Debug-Overlay |

## Nächste Schritte
- Visuelles Feedback (Mündungsfeuer, Treffer-Funken, Slipstream-Effekt)
- Sound-Effekte
- Weitere Waffen (Rakete, Boost, Schild, Mine)

## DevOps / Infrastructure
- Linux & Web Build Automation mit `just` (justfile)
- Docker-basierte Builds für Linux und HTML5
- Lokaler Web-Server via Docker (`just serve-web`)
- CI/CD: GitHub Action für Auto-Deployment zu GitHub Pages (`.github/workflows/deploy-web.yml`)
