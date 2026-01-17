extends Node
class_name AutotuneRunner
## Haupt-Controller für das Autotune-System
## Führt Tests durch und passt Parameter regelbasiert an

signal test_completed(test_name: String, results: Dictionary)
signal iteration_completed(iteration: int, all_passed: bool)
signal tuning_completed(final_config: VehiclePhysicsConfig)
signal tuning_failed(reason: String)

@export var vehicle: Vehicle
@export var config: VehiclePhysicsConfig
@export var max_iterations: int = 10
@export var log_results: bool = true

var iteration: int = 0
var is_running: bool = false
var test_instances: Array[AutotuneTestBase] = []

# Zielmetriken - können vor dem Start angepasst werden
var targets: Dictionary = {
	# Beschleunigung
	"time_0_to_60": 1.5,       # Sekunden bis 60 km/h
	"time_0_to_100": 3.2,      # Sekunden bis 100 km/h
	"max_speed_kmh": 162.0,    # Maximale Geschwindigkeit (45 m/s * 3.6)

	# Lenkung
	"steering_response_time": 0.12,  # Sekunden bis 90% Ziel-Yaw
	"steering_max_overshoot": 10.0,  # Maximales Überschwingen in %

	# Drift
	"drift_breakpoint_slip": 15.0,   # Grad Slip-Winkel für Drift-Start
	"drift_recovery_time": 1.0,      # Sekunden bis Drift endet

	# Kollision
	"collision_rest_speed_percent": 0.4,  # 40% Restgeschwindigkeit nach Crash

	# Bremsen
	"brake_distance": 20.0     # Meter Bremsweg bei 100 km/h
}


func _ready() -> void:
	_load_tests()


func _load_tests() -> void:
	# Tests werden bei Bedarf instanziiert
	pass


func run_autotune() -> void:
	if is_running:
		push_warning("AutotuneRunner: Tuning läuft bereits!")
		return

	if not vehicle:
		tuning_failed.emit("Kein Fahrzeug zugewiesen!")
		return

	if not config:
		config = vehicle.physics_config.duplicate()
		if not config:
			tuning_failed.emit("Keine Physik-Konfiguration!")
			return

	is_running = true
	iteration = 0

	_log("=== AUTOTUNE GESTARTET ===")
	_log("Max Iterationen: %d" % max_iterations)

	await _run_tuning_loop()


func _run_tuning_loop() -> void:
	while iteration < max_iterations and is_running:
		_log("\n--- Iteration %d ---" % (iteration + 1))

		var all_passed = true
		var test_results: Dictionary = {}

		# Alle Tests durchführen
		var tests_to_run = _get_test_list()

		for test_info in tests_to_run:
			var test = _create_test(test_info.type)
			if not test:
				continue

			add_child(test)
			test.setup(vehicle, config, targets)

			var result = await test.run()
			test_results[test_info.name] = result

			test_completed.emit(test_info.name, result)

			if not result.get("passed", false):
				all_passed = false
				# Regel anwenden
				AutotuneRules.apply_rule(test_info.name, result, config, targets)
				_log("  [FAIL] %s - Anpassung angewendet" % test_info.name)
			else:
				_log("  [PASS] %s" % test_info.name)

			test.queue_free()
			await get_tree().process_frame

		iteration_completed.emit(iteration, all_passed)

		if all_passed:
			_log("\n=== ALLE TESTS BESTANDEN nach %d Iterationen ===" % (iteration + 1))
			is_running = false
			tuning_completed.emit(config)
			return

		iteration += 1

	# Max Iterationen erreicht
	_log("\n=== MAX ITERATIONEN ERREICHT ===")
	is_running = false
	tuning_completed.emit(config)


func _get_test_list() -> Array:
	return [
		{"name": "acceleration", "type": "TestAcceleration"},
		{"name": "steering", "type": "TestSteering"},
		{"name": "drift", "type": "TestDrift"},
		{"name": "collision", "type": "TestCollision"}
	]


func _create_test(type: String) -> AutotuneTestBase:
	var script_path = "res://scripts/autotune/tests/%s.gd" % type.to_snake_case()

	if not ResourceLoader.exists(script_path):
		push_warning("AutotuneRunner: Test-Script nicht gefunden: %s" % script_path)
		return null

	var script = load(script_path)
	if not script:
		return null

	var test = script.new() as AutotuneTestBase
	return test


func stop_autotune() -> void:
	is_running = false
	_log("=== AUTOTUNE GESTOPPT ===")


func set_target(key: String, value: float) -> void:
	targets[key] = value


func get_current_config() -> VehiclePhysicsConfig:
	return config


func get_iteration_count() -> int:
	return iteration


func _log(message: String) -> void:
	if log_results:
		print("[Autotune] %s" % message)
