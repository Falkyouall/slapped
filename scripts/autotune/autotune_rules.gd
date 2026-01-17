extends RefCounted
class_name AutotuneRules
## Regelbasierte Parameter-Anpassungen basierend auf Testergebnissen
## Jede Regel passt Parameter um max ±5% pro Iteration an

const ADJUSTMENT_FACTOR: float = 0.05  # 5% Anpassung pro Iteration
const MIN_ADJUSTMENT: float = 0.001    # Minimale absolute Anpassung


static func apply_rule(test_name: String, result: Dictionary, config: VehiclePhysicsConfig, targets: Dictionary) -> void:
	match test_name:
		"acceleration":
			_apply_acceleration_rules(result, config, targets)
		"top_speed":
			_apply_top_speed_rules(result, config, targets)
		"steering":
			_apply_steering_rules(result, config, targets)
		"drift":
			_apply_drift_rules(result, config, targets)
		"collision":
			_apply_collision_rules(result, config, targets)
		"braking":
			_apply_braking_rules(result, config, targets)


static func _apply_acceleration_rules(result: Dictionary, config: VehiclePhysicsConfig, targets: Dictionary) -> void:
	var target_0_60 = targets.get("time_0_to_60", 1.5)
	var target_0_100 = targets.get("time_0_to_100", 3.2)

	var time_0_60 = result.get("time_0_60", -1.0)
	var time_0_100 = result.get("time_0_100", -1.0)

	# Zu langsam auf 60 km/h
	if time_0_60 > 0 and time_0_60 > target_0_60 * 1.1:  # 10% Toleranz
		config.engine_force = _adjust_up(config.engine_force)
		config.drag_coefficient = _adjust_down(config.drag_coefficient)

	# Zu schnell auf 60 km/h (unwahrscheinlich, aber möglich)
	elif time_0_60 > 0 and time_0_60 < target_0_60 * 0.8:
		config.engine_force = _adjust_down(config.engine_force)

	# Zu langsam auf 100 km/h
	if time_0_100 > 0 and time_0_100 > target_0_100 * 1.1:
		config.engine_force = _adjust_up(config.engine_force)


static func _apply_top_speed_rules(result: Dictionary, config: VehiclePhysicsConfig, targets: Dictionary) -> void:
	var target_max_speed = targets.get("max_speed_kmh", 162.0)  # 45 m/s * 3.6
	var actual_max = result.get("max_speed_reached", 0.0)

	# Max Speed zu niedrig
	if actual_max < target_max_speed * 0.95:
		config.drag_coefficient = _adjust_down(config.drag_coefficient)

	# Max Speed zu hoch
	elif actual_max > target_max_speed * 1.05:
		config.drag_coefficient = _adjust_up(config.drag_coefficient)


static func _apply_steering_rules(result: Dictionary, config: VehiclePhysicsConfig, targets: Dictionary) -> void:
	var target_response = targets.get("steering_response_time", 0.12)
	var target_overshoot = targets.get("steering_max_overshoot", 10.0)

	var actual_response = result.get("response_time", 0.0)
	var actual_overshoot = result.get("overshoot_percent", 0.0)

	# Zu träge
	if actual_response > target_response * 1.1:
		config.steer_response_time = _adjust_down(config.steer_response_time)

	# Zu zappelig
	elif actual_response < target_response * 0.8:
		config.steer_response_time = _adjust_up(config.steer_response_time)

	# Zu viel Überschwingen
	if actual_overshoot > target_overshoot:
		config.yaw_damping = _adjust_up(config.yaw_damping)

	# Zu wenig Reaktion bei hoher Geschwindigkeit
	var high_speed_turn = result.get("high_speed_turn_rate", 0.0)
	if high_speed_turn < 30.0:  # Minimal 30°/s bei Highspeed
		config.steer_gain_high_speed = _adjust_up(config.steer_gain_high_speed)


static func _apply_drift_rules(result: Dictionary, config: VehiclePhysicsConfig, targets: Dictionary) -> void:
	var target_slip = targets.get("drift_breakpoint_slip", 15.0)
	var target_recovery = targets.get("drift_recovery_time", 1.0)

	var drift_triggered = result.get("drift_triggered", false)
	var actual_slip = result.get("slip_angle_at_drift", 0.0)
	var recovery_time = result.get("recovery_time", 0.0)

	# Drift startet nicht
	if not drift_triggered:
		config.grip_breakpoint_slip = _adjust_down(config.grip_breakpoint_slip)
		config.grip_base = _adjust_down(config.grip_base)

	# Drift startet zu früh
	elif actual_slip < target_slip - 3.0:
		config.grip_breakpoint_slip = _adjust_up(config.grip_breakpoint_slip)
		config.grip_base = _adjust_up(config.grip_base)

	# Drift startet zu spät
	elif actual_slip > target_slip + 3.0:
		config.grip_breakpoint_slip = _adjust_down(config.grip_breakpoint_slip)

	# Recovery zu langsam
	if recovery_time > target_recovery * 1.2:
		config.drift_recovery_strength = _adjust_up(config.drift_recovery_strength)

	# Recovery zu schnell (kein echtes Driften)
	elif recovery_time < target_recovery * 0.5:
		config.drift_recovery_strength = _adjust_down(config.drift_recovery_strength)


static func _apply_collision_rules(result: Dictionary, config: VehiclePhysicsConfig, targets: Dictionary) -> void:
	var target_rest_speed = targets.get("collision_rest_speed_percent", 0.4)

	var actual_rest_speed = result.get("rest_speed_percent", 0.0)
	var spin_out = result.get("spin_out_detected", false)

	# Zu viel Geschwindigkeitsverlust
	if actual_rest_speed < target_rest_speed - 0.1:
		config.collision_energy_loss = _adjust_down(config.collision_energy_loss)
		config.collision_restitution = _adjust_up(config.collision_restitution)

	# Zu wenig Geschwindigkeitsverlust
	elif actual_rest_speed > target_rest_speed + 0.1:
		config.collision_energy_loss = _adjust_up(config.collision_energy_loss)

	# Spin-Out nach Kollision
	if spin_out:
		config.yaw_damping = _adjust_up(config.yaw_damping)


static func _apply_braking_rules(result: Dictionary, config: VehiclePhysicsConfig, targets: Dictionary) -> void:
	var target_brake_dist = targets.get("brake_distance", 20.0)  # Meter bei 100 km/h

	var actual_dist = result.get("brake_distance", 0.0)

	# Zu langer Bremsweg
	if actual_dist > target_brake_dist * 1.2:
		config.drag_coefficient = _adjust_up(config.drag_coefficient)

	# Zu kurzer Bremsweg
	elif actual_dist < target_brake_dist * 0.8:
		config.drag_coefficient = _adjust_down(config.drag_coefficient)


# === HELPER FUNKTIONEN ===

static func _adjust_up(value: float) -> float:
	var adjustment = maxf(value * ADJUSTMENT_FACTOR, MIN_ADJUSTMENT)
	return value + adjustment


static func _adjust_down(value: float) -> float:
	var adjustment = maxf(value * ADJUSTMENT_FACTOR, MIN_ADJUSTMENT)
	return maxf(value - adjustment, MIN_ADJUSTMENT)
