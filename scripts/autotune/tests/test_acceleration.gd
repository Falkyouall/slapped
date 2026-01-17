extends AutotuneTestBase
class_name TestAcceleration
## Testet Beschleunigung: Zeit bis 60 km/h, 100 km/h und max Speed

func _init() -> void:
	test_name = "acceleration"


func get_description() -> String:
	return "Misst Zeit bis 60 km/h, 100 km/h und maximale Geschwindigkeit"


func run() -> Dictionary:
	test_started.emit(test_name)

	await _reset_vehicle()

	var time_0_60: float = -1.0
	var time_0_100: float = -1.0
	var max_speed_reached: float = 0.0
	var elapsed: float = 0.0
	var max_test_time: float = 10.0  # Maximal 10 Sekunden testen

	# Vollgas simulieren
	while elapsed < max_test_time:
		vehicle.throttle_input = 1.0
		vehicle.steering_input = 0.0

		await get_tree().physics_frame
		elapsed += _get_physics_delta()

		var speed_kmh = vehicle.metrics.speed_kmh

		# Geschwindigkeits-Meilensteine tracken
		if time_0_60 < 0.0 and speed_kmh >= 60.0:
			time_0_60 = elapsed

		if time_0_100 < 0.0 and speed_kmh >= 100.0:
			time_0_100 = elapsed

		if speed_kmh > max_speed_reached:
			max_speed_reached = speed_kmh

		# Progress melden
		test_progress.emit(test_name, elapsed / max_test_time)

		# Abbrechen wenn Maxspeed erreicht und stabil
		if elapsed > 5.0 and absf(vehicle.metrics.speed_kmh - max_speed_reached) < 0.1:
			break

	# Fahrzeug stoppen und aufräumen
	_cleanup()

	# Ergebnisse auswerten
	var target_0_60 = targets.get("time_0_to_60", 1.5)
	var target_0_100 = targets.get("time_0_to_100", 3.2)
	var target_max = targets.get("max_speed_kmh", 162.0)

	var passed_0_60 = time_0_60 > 0.0 and time_0_60 <= target_0_60 * 1.1
	var passed_0_100 = time_0_100 > 0.0 and time_0_100 <= target_0_100 * 1.1
	var passed_max = max_speed_reached >= target_max * 0.95

	var all_passed = passed_0_60 and passed_max  # 0-100 ist optional

	var results = {
		"passed": all_passed,
		"time_0_60": time_0_60,
		"time_0_100": time_0_100,
		"max_speed_reached": max_speed_reached,
		"target_0_60": target_0_60,
		"target_0_100": target_0_100,
		"target_max_speed": target_max,
		"elapsed_time": elapsed
	}

	test_completed.emit(test_name, results)
	return results
