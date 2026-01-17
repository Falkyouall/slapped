extends AutotuneTestBase
class_name TestDrift
## Testet Drift-Verhalten: Breakpoint, Slip-Winkel, Recovery-Zeit

func _init() -> void:
	test_name = "drift"


func get_description() -> String:
	return "Misst Drift-Auslösung und Recovery-Zeit"


func run() -> Dictionary:
	test_started.emit(test_name)

	await _reset_vehicle()

	# Phase 1: Auf Driftspeed beschleunigen
	var target_speed: float = 30.0  # m/s - gute Driftgeschwindigkeit
	var elapsed: float = 0.0

	while vehicle.metrics.speed_ms < target_speed and elapsed < 5.0:
		vehicle.throttle_input = 1.0
		vehicle.steering_input = 0.0
		await get_tree().physics_frame
		elapsed += _get_physics_delta()

	# Phase 2: Drift einleiten mit hartem Lenkeinschlag
	var drift_triggered: bool = false
	var slip_angle_at_drift: float = 0.0
	var time_to_drift: float = 0.0
	var max_slip_angle: float = 0.0
	var test_elapsed: float = 0.0
	var max_test_time: float = 3.0

	while test_elapsed < max_test_time:
		vehicle.throttle_input = 0.9
		vehicle.steering_input = 1.0  # Volle Lenkung

		await get_tree().physics_frame
		test_elapsed += _get_physics_delta()

		var slip = absf(vehicle.metrics.slip_angle)

		if slip > max_slip_angle:
			max_slip_angle = slip

		# Drift-Erkennung
		if not drift_triggered and vehicle.metrics.is_drifting:
			drift_triggered = true
			slip_angle_at_drift = slip
			time_to_drift = test_elapsed

		test_progress.emit(test_name, 0.5 * (test_elapsed / max_test_time))

	# Phase 3: Drift Recovery messen
	var recovery_start_slip = vehicle.metrics.slip_angle
	var recovery_time: float = 0.0
	var recovery_threshold: float = 5.0  # Slip unter 5° = recovered
	test_elapsed = 0.0

	# Lenkung loslassen
	while test_elapsed < 3.0:
		vehicle.throttle_input = 0.5
		vehicle.steering_input = 0.0  # Keine Lenkung

		await get_tree().physics_frame
		test_elapsed += _get_physics_delta()

		if absf(vehicle.metrics.slip_angle) < recovery_threshold:
			recovery_time = test_elapsed
			break

		test_progress.emit(test_name, 0.5 + 0.5 * (test_elapsed / 3.0))

	# Fahrzeug stoppen und aufräumen
	_cleanup()

	# Auswerten
	var target_slip = targets.get("drift_breakpoint_slip", 15.0)
	var target_recovery = targets.get("drift_recovery_time", 1.0)

	var passed_drift = drift_triggered
	var passed_slip = slip_angle_at_drift >= target_slip - 5.0 and slip_angle_at_drift <= target_slip + 5.0
	var passed_recovery = recovery_time > 0.0 and recovery_time <= target_recovery * 1.5

	# Drift muss ausgelöst werden, Rest ist nice-to-have
	var all_passed = passed_drift and (passed_slip or passed_recovery)

	var results = {
		"passed": all_passed,
		"drift_triggered": drift_triggered,
		"slip_angle_at_drift": slip_angle_at_drift,
		"max_slip_angle": max_slip_angle,
		"time_to_drift": time_to_drift,
		"recovery_time": recovery_time,
		"target_slip": target_slip,
		"target_recovery": target_recovery
	}

	test_completed.emit(test_name, results)
	return results
