extends AutotuneTestBase
class_name TestSteering
## Testet Lenkverhalten: Response-Time, Überschwingen, High-Speed Handling

func _init() -> void:
	test_name = "steering"


func get_description() -> String:
	return "Misst Lenk-Ansprechzeit und Überschwingen"


func run() -> Dictionary:
	test_started.emit(test_name)

	await _reset_vehicle()

	# Phase 1: Auf mittlere Geschwindigkeit beschleunigen
	var target_speed: float = 25.0  # m/s
	var elapsed: float = 0.0

	while vehicle.metrics.speed_ms < target_speed and elapsed < 5.0:
		vehicle.throttle_input = 1.0
		vehicle.steering_input = 0.0
		await get_tree().physics_frame
		elapsed += _get_physics_delta()

	# Initiale Ausrichtung merken
	var initial_yaw = vehicle.rotation.y
	var target_yaw_change = deg_to_rad(45.0)  # 45° Drehung als Ziel

	# Phase 2: Lenkung einleiten und Response messen
	var response_time: float = -1.0
	var max_yaw_rate: float = 0.0
	var yaw_at_90_percent: float = 0.0
	var overshoot: float = 0.0
	var test_elapsed: float = 0.0
	var max_test_time: float = 3.0

	var yaw_history: Array[float] = []

	while test_elapsed < max_test_time:
		vehicle.throttle_input = 0.8  # Geschwindigkeit halten
		vehicle.steering_input = 1.0  # Volle Rechtslenkung

		await get_tree().physics_frame
		test_elapsed += _get_physics_delta()

		var current_yaw = vehicle.rotation.y
		var yaw_change = absf(current_yaw - initial_yaw)
		yaw_history.append(yaw_change)

		# Maximale Yaw-Rate tracken
		if absf(vehicle.metrics.yaw_rate) > max_yaw_rate:
			max_yaw_rate = absf(vehicle.metrics.yaw_rate)

		# 90% Response Time
		if response_time < 0.0 and yaw_change >= target_yaw_change * 0.9:
			response_time = test_elapsed
			yaw_at_90_percent = yaw_change

		test_progress.emit(test_name, test_elapsed / max_test_time)

	# Überschwingen berechnen (max Yaw - Ziel Yaw)
	var max_yaw_change: float = 0.0
	for yaw in yaw_history:
		if yaw > max_yaw_change:
			max_yaw_change = yaw

	if target_yaw_change > 0:
		overshoot = ((max_yaw_change - target_yaw_change) / target_yaw_change) * 100.0
		overshoot = maxf(overshoot, 0.0)

	# Phase 3: High-Speed Steering Test
	await _reset_vehicle()
	elapsed = 0.0

	# Auf Highspeed beschleunigen
	while vehicle.metrics.speed_ms < 40.0 and elapsed < 8.0:
		vehicle.throttle_input = 1.0
		vehicle.steering_input = 0.0
		await get_tree().physics_frame
		elapsed += _get_physics_delta()

	# High-Speed Turn Rate messen
	var high_speed_yaw_rate: float = 0.0
	test_elapsed = 0.0

	while test_elapsed < 1.0:
		vehicle.throttle_input = 0.8
		vehicle.steering_input = 1.0
		await get_tree().physics_frame
		test_elapsed += _get_physics_delta()

		if absf(vehicle.metrics.yaw_rate) > high_speed_yaw_rate:
			high_speed_yaw_rate = absf(vehicle.metrics.yaw_rate)

	# Fahrzeug stoppen und aufräumen
	_cleanup()

	# Auswerten
	var target_response = targets.get("steering_response_time", 0.12)
	var target_overshoot = targets.get("steering_max_overshoot", 10.0)

	var passed_response = response_time > 0.0 and response_time <= target_response * 1.2
	var passed_overshoot = overshoot <= target_overshoot
	var passed_highspeed = high_speed_yaw_rate >= 30.0  # Min 30°/s bei Highspeed

	var all_passed = passed_response and passed_overshoot and passed_highspeed

	var results = {
		"passed": all_passed,
		"response_time": response_time,
		"overshoot_percent": overshoot,
		"max_yaw_rate": max_yaw_rate,
		"high_speed_turn_rate": high_speed_yaw_rate,
		"target_response": target_response,
		"target_overshoot": target_overshoot
	}

	test_completed.emit(test_name, results)
	return results
