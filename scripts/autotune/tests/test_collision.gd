extends AutotuneTestBase
class_name TestCollision
## Testet Kollisions-Verhalten: Restgeschwindigkeit, Spin-Out-Erkennung
## Hinweis: Benötigt eine Wand oder zweites Fahrzeug in der Test-Szene

func _init() -> void:
	test_name = "collision"


func get_description() -> String:
	return "Misst Kollisions-Verhalten und Restgeschwindigkeit"


func run() -> Dictionary:
	test_started.emit(test_name)

	await _reset_vehicle()

	# Phase 1: Beschleunigen Richtung Kollisions-Ziel
	var target_speed: float = 30.0  # m/s
	var pre_collision_speed: float = 0.0
	var elapsed: float = 0.0

	while vehicle.metrics.speed_ms < target_speed and elapsed < 5.0:
		vehicle.throttle_input = 1.0
		vehicle.steering_input = 0.0
		await get_tree().physics_frame
		elapsed += _get_physics_delta()

		pre_collision_speed = vehicle.metrics.speed_ms
		test_progress.emit(test_name, 0.3 * (elapsed / 5.0))

	# Geschwindigkeit merken
	var speed_before_collision = vehicle.metrics.speed_ms

	# Phase 2: Weiter Richtung Wand fahren bis Kollision
	var collision_detected: bool = false
	var collision_impulse: float = 0.0
	var test_elapsed: float = 0.0
	var prev_speed: float = speed_before_collision

	# Auf Kollision warten (max 5 Sekunden) - Wand ist bei z=-50
	while test_elapsed < 5.0 and not collision_detected:
		vehicle.throttle_input = 1.0
		vehicle.steering_input = 0.0

		await get_tree().physics_frame
		test_elapsed += _get_physics_delta()

		var current_speed = vehicle.metrics.speed_ms

		# Kollision erkennen: Plötzlicher Geschwindigkeitsabfall (> 30%)
		if prev_speed > 5.0 and current_speed < prev_speed * 0.7:
			collision_detected = true
			collision_impulse = prev_speed - current_speed
			speed_before_collision = prev_speed

		prev_speed = current_speed
		test_progress.emit(test_name, 0.3 + 0.3 * (test_elapsed / 5.0))

	# Phase 3: Post-Kollision messen
	await get_tree().physics_frame
	await get_tree().physics_frame

	var post_collision_speed = vehicle.metrics.speed_ms
	var rest_speed_percent = post_collision_speed / maxf(speed_before_collision, 0.1)

	# Spin-Out erkennen
	var spin_out_detected: bool = false
	var max_yaw_rate: float = 0.0
	test_elapsed = 0.0

	while test_elapsed < 1.0:
		vehicle.throttle_input = 0.0
		vehicle.steering_input = 0.0

		await get_tree().physics_frame
		test_elapsed += _get_physics_delta()

		var yaw_rate = absf(vehicle.metrics.yaw_rate)
		if yaw_rate > max_yaw_rate:
			max_yaw_rate = yaw_rate

		# Spin-Out wenn > 180°/s
		if yaw_rate > config.spin_threshold:
			spin_out_detected = true

		test_progress.emit(test_name, 0.6 + 0.4 * (test_elapsed / 1.0))

	# Fahrzeug stoppen und aufräumen
	_cleanup()

	# Auswerten
	var target_rest_speed = targets.get("collision_rest_speed_percent", 0.4)

	var passed_rest_speed = rest_speed_percent >= target_rest_speed - 0.15 and rest_speed_percent <= target_rest_speed + 0.15
	var passed_no_spinout = not spin_out_detected

	var all_passed = passed_rest_speed and passed_no_spinout

	var results = {
		"passed": all_passed,
		"collision_detected": collision_detected,
		"speed_before": speed_before_collision,
		"speed_after": post_collision_speed,
		"rest_speed_percent": rest_speed_percent,
		"collision_impulse": collision_impulse,
		"max_yaw_rate_after": max_yaw_rate,
		"spin_out_detected": spin_out_detected,
		"target_rest_speed": target_rest_speed
	}

	test_completed.emit(test_name, results)
	return results
