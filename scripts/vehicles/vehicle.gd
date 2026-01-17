extends RigidBody3D
class_name Vehicle
## Basis-Fahrzeug mit parametrischer Arcade-Steuerung (RigidBody3D)
## Verwendet VehiclePhysicsConfig für alle Physik-Parameter

signal destroyed()
signal hit(damage: float)
signal out_of_bounds(player_id: int)
signal weapon_changed(weapon: Weapon)

# Physik-Konfiguration
@export var physics_config: VehiclePhysicsConfig

# Leben
var lives: int = 3
var is_eliminated: bool = false
var respawn_immunity: bool = false

# Waffen-System
var current_weapon: Weapon = null

# Treffer-Reaktion
var hit_debuff_timer: float = 0.0
var hit_jerk_accumulator: float = 0.0
var is_being_hit: bool = false

# Kollisions-Grip-Debuff
var collision_grip_debuff_timer: float = 0.0
var is_collision_stunned: bool = false

# Spieler-Zuordnung
@export var player_id: int = 0

# Bot-Steuerung
var is_bot: bool = false
var bot_waypoints: Array[Vector3] = []
var bot_current_waypoint: int = 0
var bot_waypoint_threshold: float = 25.0
var bot_initialized: bool = false
var bot_start_delay: float = 1.0

# Input-Actions (werden pro Spieler gesetzt)
var input_accelerate: String = "accelerate"
var input_brake: String = "brake"
var input_left: String = "steer_left"
var input_right: String = "steer_right"
var input_shoot: String = "shoot"

# Interner Zustand
var steering_input: float = 0.0
var throttle_input: float = 0.0
var steering_actual: float = 0.0  # Geglättete Lenkung
var input_disabled: bool = false  # Für Autotune - deaktiviert Player-Input

# Echtzeit-Metriken (read-only für Debug/Autotune)
var metrics: Dictionary = {
	"speed_kmh": 0.0,
	"speed_ms": 0.0,
	"slip_angle": 0.0,
	"yaw_rate": 0.0,
	"is_drifting": false,
	"steering_actual": 0.0,
	"last_collision_impulse": 0.0,
	"effective_grip": 0.0,
	"forward_speed": 0.0,
	"lateral_speed": 0.0
}


func _ready() -> void:
	add_to_group("vehicles")
	lives = GameManager.config.max_lives
	_setup_input_actions()
	_load_physics_config()

	# RigidBody3D Einstellungen
	contact_monitor = true
	max_contacts_reported = 4

	# Kollisions-Signal verbinden
	body_entered.connect(_on_body_entered)


func _load_physics_config() -> void:
	if not physics_config:
		physics_config = load("res://resources/vehicle_physics.tres")
		if not physics_config:
			push_warning("Vehicle: Keine physics_config gefunden, verwende Standardwerte")
			physics_config = VehiclePhysicsConfig.new()


func _setup_input_actions() -> void:
	var suffix = "" if player_id == 0 else "_p" + str(player_id + 1)
	input_accelerate = "accelerate" + suffix
	input_brake = "brake" + suffix
	input_left = "steer_left" + suffix
	input_right = "steer_right" + suffix
	input_shoot = "shoot" + suffix


func _physics_process(delta: float) -> void:
	_handle_input(delta)
	_apply_forces(delta)
	_keep_upright(delta)


func _handle_input(_delta: float) -> void:
	# Bei deaktiviertem Input (Autotune) nicht überschreiben
	if input_disabled:
		return

	if is_bot:
		_handle_bot_input(_delta)
		return

	throttle_input = 0.0
	steering_input = 0.0

	if Input.is_action_pressed(input_accelerate):
		throttle_input = 1.0
	elif Input.is_action_pressed(input_brake):
		throttle_input = -0.5

	if Input.is_action_pressed(input_left):
		steering_input = -1.0
	elif Input.is_action_pressed(input_right):
		steering_input = 1.0


func _handle_bot_input(delta: float) -> void:
	# Start-Verzögerung
	if bot_start_delay > 0:
		bot_start_delay -= delta
		return

	if bot_waypoints.is_empty():
		return

	if not bot_initialized:
		_bot_find_best_waypoint()
		bot_initialized = true

	# Aktueller Wegpunkt
	var target = bot_waypoints[bot_current_waypoint]
	var to_target = target - global_position
	to_target.y = 0
	var dist = to_target.length()

	# Zum nächsten Wegpunkt wechseln wenn nah genug
	if dist < bot_waypoint_threshold:
		bot_current_waypoint = (bot_current_waypoint + 1) % bot_waypoints.size()
		target = bot_waypoints[bot_current_waypoint]
		to_target = target - global_position
		to_target.y = 0

	# Richtung zum Ziel
	var target_dir = to_target.normalized()

	# Eigene Vorwärtsrichtung
	var forward = -transform.basis.z
	forward.y = 0
	forward = forward.normalized()

	# Winkel zum Ziel
	var cross = forward.cross(target_dir)

	# Lenkung
	steering_input = clamp(-cross.y * 3.0, -1.0, 1.0)

	# Gas
	throttle_input = 1.0

	# Langsamer in scharfen Kurven
	if abs(cross.y) > 0.5:
		throttle_input = 0.6


func _bot_find_best_waypoint() -> void:
	var closest_idx = 0
	var closest_dist = 999999.0

	for i in range(bot_waypoints.size()):
		var to_point = bot_waypoints[i] - global_position
		to_point.y = 0
		var dist = to_point.length()

		if dist < closest_dist:
			closest_dist = dist
			closest_idx = i

	bot_current_waypoint = (closest_idx + 1) % bot_waypoints.size()


func _apply_forces(delta: float) -> void:
	var cfg = physics_config

	# Richtungsvektoren
	var forward = -transform.basis.z
	forward.y = 0
	forward = forward.normalized()

	var right = transform.basis.x
	right.y = 0
	right = right.normalized()

	# Geschwindigkeiten berechnen
	var speed = linear_velocity.length()
	var forward_vel = linear_velocity.dot(forward)
	var lateral_vel = linear_velocity.dot(right)

	# Metriken aktualisieren
	metrics.speed_ms = speed
	metrics.speed_kmh = speed * 3.6
	metrics.forward_speed = forward_vel
	metrics.lateral_speed = lateral_vel

	# === ANTRIEB ===
	if throttle_input > 0:
		if forward_vel < cfg.max_speed:
			var force = forward * cfg.engine_force * throttle_input
			apply_central_force(force)
	elif throttle_input < 0:
		if forward_vel > -cfg.max_speed * 0.4:
			var force = forward * cfg.engine_force * throttle_input * 0.6
			apply_central_force(force)

	# === DRAG (quadratisch) ===
	var drag = -linear_velocity * speed * cfg.drag_coefficient
	apply_central_force(drag * mass)

	# === LENKUNG (interpoliert mit Response-Time) ===
	var speed_ratio = clampf(speed / cfg.max_speed, 0.0, 1.0)
	var steer_gain = cfg.get_steer_gain(speed_ratio)

	# Response-Time via exponential smoothing
	var steer_alpha = cfg.get_steer_alpha(delta)
	var target_steer = steering_input * steer_gain
	steering_actual = lerpf(steering_actual, target_steer, steer_alpha)
	metrics.steering_actual = steering_actual

	# Lenkung nur anwenden wenn Geschwindigkeit > Minimum
	if speed > 2.0 and absf(steering_actual) > 0.1:
		var turn_amount = steering_actual * delta

		# Bei Rückwärtsfahrt Lenkung umkehren
		if forward_vel < -1.0:
			turn_amount *= -1

		# Debuff bei Treffer
		turn_amount *= get_steering_multiplier()

		# Direkte Rotation anwenden
		rotate_y(-turn_amount)

		# Angular velocity auf Y begrenzen (für Kollisionen)
		angular_velocity.y = clampf(angular_velocity.y, -3.0, 3.0)
	else:
		# Dämpfe Y-Rotation wenn nicht aktiv gelenkt wird
		angular_velocity.y *= 0.9

	# === SLIP ANGLE ===
	var slip_angle_rad = atan2(lateral_vel, maxf(absf(forward_vel), 0.1))
	metrics.slip_angle = rad_to_deg(slip_angle_rad)

	# === DRIFT DETECTION ===
	metrics.is_drifting = cfg.is_drifting(metrics.slip_angle)

	# === GRIP FORCE ===
	var effective_grip = cfg.get_effective_grip(metrics.is_drifting)

	# Kollisions-Debuff auf Grip anwenden
	if is_collision_stunned:
		effective_grip *= GameManager.config.collision_grip_debuff

	metrics.effective_grip = effective_grip

	var grip_force = -lateral_vel * effective_grip * cfg.drift_recovery_strength
	apply_central_force(right * grip_force * mass)

	# === YAW DAMPING ===
	angular_velocity.y -= angular_velocity.y * cfg.yaw_damping * delta
	metrics.yaw_rate = rad_to_deg(angular_velocity.y)

	# === REIBUNG (wenn kein Gas) ===
	if absf(throttle_input) < 0.1:
		var friction = -linear_velocity * 1.5
		friction.y = 0
		apply_central_force(friction * mass)


func _keep_upright(_delta: float) -> void:
	# Halte das Fahrzeug flach auf dem Boden
	rotation.x = lerpf(rotation.x, 0, 0.3)
	rotation.z = lerpf(rotation.z, 0, 0.3)

	# Dämpfe ungewollte Rotation
	angular_velocity.x *= 0.5
	angular_velocity.z *= 0.5


func take_damage(amount: float) -> void:
	hit.emit(amount)


func destroy() -> void:
	destroyed.emit()


func lose_life() -> void:
	lives -= 1
	if lives <= 0:
		is_eliminated = true
		destroyed.emit()


func reset_to_spawn(spawn_pos: Vector3, spawn_rot: float = 0.0) -> void:
	global_position = spawn_pos
	rotation = Vector3(0, spawn_rot, 0)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	steering_actual = 0.0
	bot_initialized = false
	bot_start_delay = 1.0
	hit_debuff_timer = 0.0
	hit_jerk_accumulator = 0.0
	is_being_hit = false
	collision_grip_debuff_timer = 0.0
	is_collision_stunned = false
	# Metriken zurücksetzen
	for key in metrics.keys():
		if metrics[key] is float:
			metrics[key] = 0.0
		elif metrics[key] is bool:
			metrics[key] = false


func _process(delta: float) -> void:
	_handle_weapon_input()
	_update_hit_debuff(delta)
	_update_collision_debuff(delta)


func _handle_weapon_input() -> void:
	if not current_weapon:
		return

	if Input.is_action_pressed(input_shoot):
		if not current_weapon.is_firing:
			current_weapon.start_firing()
	else:
		if current_weapon.is_firing:
			current_weapon.stop_firing()


func _update_hit_debuff(delta: float) -> void:
	if hit_debuff_timer > 0:
		hit_debuff_timer -= delta
		if hit_debuff_timer <= 0:
			is_being_hit = false
			hit_jerk_accumulator = 0.0


# === WAFFEN-SYSTEM ===

func equip_weapon(weapon: Weapon) -> void:
	if current_weapon:
		unequip_weapon()

	current_weapon = weapon
	add_child(weapon)
	weapon.equip(self)
	weapon.weapon_empty.connect(_on_weapon_empty)
	weapon_changed.emit(weapon)


func unequip_weapon() -> void:
	if not current_weapon:
		return

	current_weapon.stop_firing()
	current_weapon.weapon_empty.disconnect(_on_weapon_empty)
	current_weapon.unequip()
	current_weapon.queue_free()
	current_weapon = null
	weapon_changed.emit(null)


func _on_weapon_empty() -> void:
	unequip_weapon()


# === TREFFER-REAKTION ===

func on_projectile_hit(attacker: Vehicle) -> void:
	if respawn_immunity or is_eliminated:
		return

	var cfg = GameManager.weapon_config

	hit_debuff_timer = cfg.hit_steering_debuff_duration
	is_being_hit = true

	hit_jerk_accumulator += cfg.hit_jerk_strength
	hit_jerk_accumulator = minf(hit_jerk_accumulator, cfg.hit_jerk_max_angle)

	var jerk_amount = cfg.hit_jerk_strength * (1.0 + randf() * cfg.hit_jerk_randomness)
	var jerk_dir = 1.0 if randf() > 0.5 else -1.0

	# Impuls statt direkter Rotation
	apply_torque_impulse(Vector3(0, jerk_amount * jerk_dir * 50.0, 0))

	hit.emit(1.0)


func get_steering_multiplier() -> float:
	if is_being_hit:
		return GameManager.weapon_config.hit_steering_multiplier
	return 1.0


# === KOLLISIONS-SYSTEM ===

func _update_collision_debuff(delta: float) -> void:
	if collision_grip_debuff_timer > 0:
		collision_grip_debuff_timer -= delta
		if collision_grip_debuff_timer <= 0:
			is_collision_stunned = false


func _on_body_entered(body: Node) -> void:
	if not body is Vehicle:
		return

	var other: Vehicle = body
	if other == self:
		return

	_handle_vehicle_collision(other)


func _handle_vehicle_collision(other: Vehicle) -> void:
	var cfg = GameManager.config
	var phys = physics_config

	# Geschwindigkeiten berechnen
	var my_speed = linear_velocity.length()
	var other_speed = other.linear_velocity.length()
	var speed_diff = my_speed - other_speed

	# Kollisions-Impuls für Metriken speichern
	metrics.last_collision_impulse = absf(speed_diff)

	# Richtung vom anderen Auto zu mir
	var collision_dir = (global_position - other.global_position).normalized()
	collision_dir.y = 0

	# Meine Vorwärtsrichtung
	var my_forward = -transform.basis.z
	my_forward.y = 0
	my_forward = my_forward.normalized()

	# Vorwärtsrichtung des anderen Autos
	var other_forward = -other.transform.basis.z
	other_forward.y = 0
	other_forward = other_forward.normalized()

	# === RAMMING BONUS ===
	if speed_diff > cfg.collision_min_speed_diff:
		var ram_direction = (other.global_position - global_position).normalized()
		ram_direction.y = 0

		# Basis-Impuls
		var bonus_impulse = ram_direction * speed_diff * cfg.collision_ramming_multiplier

		# Winkel-Bonus: Treffer von hinten/seitlich sind effektiver
		var hit_angle = other_forward.dot(-ram_direction)

		# Bonus wenn nicht frontal getroffen
		if hit_angle < 0.5:
			bonus_impulse *= cfg.collision_side_bonus

		# Impuls auf das andere Fahrzeug anwenden
		other.apply_central_impulse(bonus_impulse)

		# Grip-Debuff für das getroffene Fahrzeug
		other.apply_collision_stun()


func apply_collision_stun() -> void:
	var cfg = GameManager.config
	collision_grip_debuff_timer = cfg.collision_debuff_duration
	is_collision_stunned = true


# === DEBUG HELPERS ===

func get_debug_info() -> String:
	return "Speed: %.1f km/h | Slip: %.1f° | Drift: %s | Grip: %.2f" % [
		metrics.speed_kmh,
		metrics.slip_angle,
		"YES" if metrics.is_drifting else "NO",
		metrics.effective_grip
	]
