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
- MachineGun: 30 Schuss, 10/Sek
- Power-Up System mit Respawn
- Treffer-Reaktion: Lenkungs-Debuff + Zuck-Effekt

## Kollisions-System ✅
- Ramming mit Geschwindigkeits-basiertem Impuls
- Grip-Debuff nach Kollision (30% für 0.4s)

## Parametrische Fahrphysik ✅

### VehiclePhysicsConfig (14 Parameter)
```
Antrieb:       engine_force, drag_coefficient, max_speed
Lenkung:       steer_gain_low_speed, steer_gain_high_speed, steer_response_time
Grip/Drift:    grip_base, grip_breakpoint_slip, slide_friction, drift_recovery_strength
Yaw-Kontrolle: yaw_damping, spin_threshold
Kollision:     collision_restitution, collision_energy_loss
```

### Echtzeit-Metriken
- speed_kmh, speed_ms, slip_angle, yaw_rate
- is_drifting, effective_grip, steering_actual
- forward_speed, lateral_speed, last_collision_impulse

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
- Bis zu 50 Iterationen
- Speichert finale Config als .tres

### Autotune-Szene
- `scenes/autotune/autotune_scene.tscn`
- [ENTER] Start, [ESC] Stop, [R] Reset

## Wichtige Dateien

| Datei | Beschreibung |
|-------|--------------|
| `scripts/autoload/vehicle_physics_config.gd` | 14-Parameter Resource |
| `resources/vehicle_physics.tres` | Standard-Konfiguration |
| `scripts/vehicles/vehicle.gd` | Parametrische Physik + Metriken |
| `scripts/autotune/autotune_runner.gd` | Autotune Controller |
| `scripts/autotune/autotune_rules.gd` | Regelbasierte Anpassung |
| `scripts/autotune/tests/*.gd` | 4 Test-Klassen |
| `scripts/ui/hud.gd` | HUD + Debug-Overlay |

## Nächste Schritte
- Autotune testen und Zielwerte feinjustieren
- Visuelles Feedback (Mündungsfeuer, Treffer-Funken)
- Sound-Effekte
- Weitere Waffen (Rakete, Boost, Schild, Mine)
