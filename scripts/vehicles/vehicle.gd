extends CharacterBody3D
class_name Vehicle
## Basis-Fahrzeug mit Arcade-Steuerung (3D)
## Bewegung auf X/Z-Ebene mit Sprung-Physik

signal destroyed()
signal hit(damage: float)
signal out_of_bounds(player_id: int)
signal weapon_changed(weapon: Weapon)

# Leben
var lives: int = 3
var is_eliminated: bool = false
var respawn_immunity: bool = false

# Bewegungs-Parameter (nicht-konfigurierbar)
var friction: float = 20.0
var turn_speed: float = 3.5
var drift_factor: float = 0.95
var ground_y: float = 0.0

# Runtime
var vertical_velocity: float = 0.0
var is_airborne: bool = false

# Waffen-System
var current_weapon: Weapon = null

# Treffer-Reaktion
var hit_debuff_timer: float = 0.0
var hit_jerk_accumulator: float = 0.0
var is_being_hit: bool = false

# Spieler-Zuordnung
@export var player_id: int = 0

# Input-Actions (werden pro Spieler gesetzt)
var input_accelerate: String = "accelerate"
var input_brake: String = "brake"
var input_left: String = "steer_left"
var input_right: String = "steer_right"
var input_shoot: String = "shoot"

# Interner Zustand
var current_speed: float = 0.0
var steering_input: float = 0.0

# Externe Impulse (von Kollisionen mit anderen Fahrzeugen)
var push_velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("vehicles")
	lives = GameManager.config.max_lives
	_setup_input_actions()

func _setup_input_actions() -> void:
	# Input-Actions basierend auf player_id setzen
	var suffix = "" if player_id == 0 else "_p" + str(player_id + 1)
	input_accelerate = "accelerate" + suffix
	input_brake = "brake" + suffix
	input_left = "steer_left" + suffix
	input_right = "steer_right" + suffix
	input_shoot = "shoot" + suffix

func _physics_process(delta: float) -> void:
	_handle_input(delta)
	_apply_movement(delta)
	move_and_slide()
	_handle_vehicle_collisions()
	# Externe Impulse nach allem anderen anwenden und direkt bewegen
	_apply_external_impulse(delta)

func _apply_external_impulse(delta: float) -> void:
	# Push-Velocity über Zeit abbauen (Reibung)
	if push_velocity.length_squared() > 0.01:
		push_velocity = push_velocity.move_toward(Vector3.ZERO, 25.0 * delta)

func _handle_input(delta: float) -> void:
	var cfg = GameManager.config
	var accel_input = Input.get_action_strength(input_accelerate)
	var brake_input = Input.get_action_strength(input_brake)

	if accel_input > 0:
		current_speed += cfg.vehicle_acceleration * accel_input * delta
	elif brake_input > 0:
		if current_speed > 0:
			current_speed -= cfg.vehicle_brake_power * brake_input * delta
		else:
			current_speed -= cfg.vehicle_acceleration * 0.5 * brake_input * delta
	else:
		current_speed = move_toward(current_speed, 0, friction * delta)

	current_speed = clamp(current_speed, -cfg.vehicle_max_speed * 0.4, cfg.vehicle_max_speed)

	# Lenkung (nur wenn in Bewegung)
	steering_input = 0.0
	if abs(current_speed) > 1:
		if Input.is_action_pressed(input_left):
			steering_input = -1.0
		elif Input.is_action_pressed(input_right):
			steering_input = 1.0


func _apply_movement(delta: float) -> void:
	# Rotation um Y-Achse (horizontales Drehen)
	var turn_amount = steering_input * turn_speed * delta
	var speed_factor = 1.0 - (abs(current_speed) / GameManager.config.vehicle_max_speed) * 0.3
	# Lenkungs-Debuff bei Treffern anwenden
	turn_amount *= get_steering_multiplier()
	# Bei Rückwärtsfahrt: Lenkung umkehren damit links auch nach links fährt
	if current_speed < 0:
		turn_amount *= -1
	rotation.y -= turn_amount * speed_factor

	# Fahrtrichtung berechnen (vorwärts ist -Z in Godot 3D)
	var forward = -transform.basis.z

	# Horizontale Bewegung
	var target_velocity = forward * current_speed
	velocity.x = lerpf(velocity.x, target_velocity.x, 1.0 - drift_factor + 0.05)
	velocity.z = lerpf(velocity.z, target_velocity.z, 1.0 - drift_factor + 0.05)

	# Push-Velocity von Kollisionen hinzufügen
	velocity.x += push_velocity.x
	velocity.z += push_velocity.z

	# Vertikale Bewegung (Sprung-Physik)
	if is_on_floor():
		is_airborne = false
		vertical_velocity = 0.0
		# Rampen-Erkennung: Wenn wir auf einer Schräge sind, bekommen wir Auftrieb
		var floor_normal = get_floor_normal()
		if floor_normal.y < 0.95 and current_speed > 5.0:  # Schräge + Geschwindigkeit
			var ramp_boost = current_speed * (1.0 - floor_normal.y) * 0.8
			vertical_velocity = ramp_boost
	else:
		# Nur Gravitation anwenden wenn wir über dem Boden sind
		if global_position.y > ground_y + 0.5:
			is_airborne = true
			vertical_velocity -= GameManager.config.vehicle_gravity * delta
		else:
			global_position.y = ground_y
			vertical_velocity = 0.0
			is_airborne = false

	velocity.y = vertical_velocity

func _handle_vehicle_collisions() -> void:
	# Prüfe alle anderen Fahrzeuge auf Kollision
	for other in get_tree().get_nodes_in_group("vehicles"):
		if other == self or not other is Vehicle:
			continue

		var other_vehicle: Vehicle = other
		var to_other = other_vehicle.global_position - global_position
		to_other.y = 0
		var dist = to_other.length()

		# Kollisionsradius - Fahrzeug ist ca. 11x5 Einheiten (2.5x skaliert)
		# Wir nutzen einen Durchschnittswert
		var collision_dist = 14.0

		if dist < collision_dist and dist > 0.1:
			var overlap = collision_dist - dist
			var dir = to_other.normalized()

			# Meine Geschwindigkeit in Richtung des anderen
			var my_speed_toward = velocity.dot(dir)

			# Wenn ich mich auf den anderen zubewege (auch langsam)
			if my_speed_toward > 0.5:
				# Minimaler Schubser
				var push_force = my_speed_toward * 0.005
				other_vehicle.apply_collision_impulse(dir * push_force)

				# Minimale Abbremsung
				velocity -= dir * my_speed_toward * 0.02

			# Separation um Überlappung zu verhindern
			if overlap > 0:
				global_position -= dir * overlap * 0.3

func apply_collision_impulse(impulse: Vector3) -> void:
	push_velocity += impulse

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
	rotation.y = spawn_rot
	velocity = Vector3.ZERO
	current_speed = 0
	push_velocity = Vector3.ZERO
	# Waffe behalten, aber Treffer-Status zurücksetzen
	hit_debuff_timer = 0.0
	hit_jerk_accumulator = 0.0
	is_being_hit = false

func _process(delta: float) -> void:
	_handle_weapon_input()
	_update_hit_debuff(delta)

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

	# Erst Feuern stoppen, dann entfernen
	current_weapon.stop_firing()
	current_weapon.weapon_empty.disconnect(_on_weapon_empty)
	current_weapon.unequip()
	current_weapon.queue_free()
	current_weapon = null
	weapon_changed.emit(null)

func _on_weapon_empty() -> void:
	# Waffe ist leer - entfernen
	unequip_weapon()

# === TREFFER-REAKTION ===

func on_projectile_hit(attacker: Vehicle) -> void:
	if respawn_immunity or is_eliminated:
		return

	var cfg = GameManager.weapon_config

	# Debuff-Timer zurücksetzen
	hit_debuff_timer = cfg.hit_steering_debuff_duration
	is_being_hit = true

	# Zuck-Effekt akkumulieren (mit Maximum begrenzen)
	hit_jerk_accumulator += cfg.hit_jerk_strength
	hit_jerk_accumulator = minf(hit_jerk_accumulator, cfg.hit_jerk_max_angle)

	# Zufällige Richtung für Zucken (innerhalb des erlaubten Winkels)
	var jerk_amount = cfg.hit_jerk_strength * (1.0 + randf() * cfg.hit_jerk_randomness)
	var jerk_dir = 1.0 if randf() > 0.5 else -1.0

	# Rotation zucken lassen
	rotation.y += jerk_amount * jerk_dir

	hit.emit(1.0)

func get_steering_multiplier() -> float:
	if is_being_hit:
		return GameManager.weapon_config.hit_steering_multiplier
	return 1.0
