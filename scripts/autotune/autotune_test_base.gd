extends Node
class_name AutotuneTestBase
## Basis-Klasse für alle Autotune-Tests
## Jeder Test misst spezifische Fahrzeug-Eigenschaften und gibt Ergebnisse zurück

signal test_started(test_name: String)
signal test_progress(test_name: String, progress: float)
signal test_completed(test_name: String, results: Dictionary)

var vehicle: Vehicle
var config: VehiclePhysicsConfig
var test_name: String = "base_test"

# Zielwerte (werden vom AutotuneRunner gesetzt)
var targets: Dictionary = {}


func setup(test_vehicle: Vehicle, physics_config: VehiclePhysicsConfig, target_values: Dictionary) -> void:
	vehicle = test_vehicle
	config = physics_config
	targets = target_values


func run() -> Dictionary:
	## Override in Subklassen - Führt den Test durch und gibt Ergebnisse zurück
	push_error("AutotuneTestBase.run() muss überschrieben werden!")
	return {"passed": false, "error": "Not implemented"}


func _reset_vehicle() -> void:
	## Setzt das Fahrzeug auf Startposition zurück
	vehicle.input_disabled = true  # Player-Input deaktivieren
	vehicle.reset_to_spawn(Vector3.ZERO, 0.0)
	vehicle.linear_velocity = Vector3.ZERO
	vehicle.angular_velocity = Vector3.ZERO
	vehicle.throttle_input = 0.0
	vehicle.steering_input = 0.0
	# Kurz warten damit Physik sich stabilisiert
	await get_tree().physics_frame
	await get_tree().physics_frame


func _cleanup() -> void:
	## Aufräumen nach Test - Input wieder aktivieren
	vehicle.input_disabled = false
	vehicle.throttle_input = 0.0
	vehicle.steering_input = 0.0


func _simulate_frames(count: int) -> void:
	## Simuliert eine bestimmte Anzahl von Physik-Frames
	for i in range(count):
		await get_tree().physics_frame


func _get_physics_delta() -> float:
	## Gibt das Physik-Delta zurück
	return get_physics_process_delta_time()


func get_test_name() -> String:
	return test_name


func get_description() -> String:
	## Override für Test-Beschreibung
	return "Basis-Test"
