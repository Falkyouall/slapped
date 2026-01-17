extends Resource
class_name VehiclePhysicsConfig
## Parametrische Fahrzeugphysik-Konfiguration
## 14 Parameter für vollständige Kontrolle über das Fahrverhalten

# === ANTRIEB (3 Parameter) ===
@export_group("Drive")
@export var engine_force: float = 150.0          ## Beschleunigungskraft (N)
@export var drag_coefficient: float = 0.02       ## Luftwiderstand (velocity² basiert)
@export var max_speed: float = 45.0              ## Maximale Geschwindigkeit (m/s)

# === LENKUNG (3 Parameter) ===
@export_group("Steering")
@export var steer_gain_low_speed: float = 5.0    ## Lenkstärke bei niedriger Geschwindigkeit
@export var steer_gain_high_speed: float = 2.0   ## Lenkstärke bei hoher Geschwindigkeit
@export var steer_response_time: float = 0.08    ## Sekunden bis 90% Ziel-Yaw

# === GRIP/DRIFT (4 Parameter) ===
@export_group("Grip & Drift")
@export var grip_base: float = 0.95              ## Basis-Grip (1.0 = kein Drift, 0.0 = voller Drift)
@export var grip_breakpoint_slip: float = 15.0   ## Slip-Winkel ab dem Drift startet (Grad)
@export var slide_friction: float = 0.6          ## Reibung während Drift
@export var drift_recovery_strength: float = 3.0 ## Wie schnell Drift endet

# === YAW-KONTROLLE (2 Parameter) ===
@export_group("Yaw Control")
@export var yaw_damping: float = 2.0             ## Dämpfung der Y-Rotation
@export var spin_threshold: float = 180.0        ## Grad/s ab dem Spin-Out erkannt wird

# === KOLLISION (2 Parameter) ===
@export_group("Collision")
@export var collision_restitution: float = 0.4   ## Bounce-Faktor (0 = kein Bounce, 1 = voller Bounce)
@export var collision_energy_loss: float = 0.3   ## Geschwindigkeitsverlust bei Crash (0-1)


## Berechnet die interpolierte Lenkstärke basierend auf Geschwindigkeit
func get_steer_gain(speed_ratio: float) -> float:
	return lerpf(steer_gain_low_speed, steer_gain_high_speed, clampf(speed_ratio, 0.0, 1.0))


## Berechnet den Steering-Response Alpha-Wert für exponentielles Smoothing
func get_steer_alpha(delta: float) -> float:
	if steer_response_time <= 0.0:
		return 1.0
	return 1.0 - exp(-delta / steer_response_time)


## Prüft ob ein Slip-Winkel als Drift gilt
func is_drifting(slip_angle_deg: float) -> bool:
	return absf(slip_angle_deg) > grip_breakpoint_slip


## Gibt den effektiven Grip-Wert zurück (normal oder während Drift)
func get_effective_grip(is_in_drift: bool) -> float:
	return slide_friction if is_in_drift else grip_base
