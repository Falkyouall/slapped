extends Node3D
class_name AutotuneSceneController
## Controller für die Autotune-Test-Szene
## Verwaltet UI-Updates und Benutzer-Interaktion

@onready var vehicle: Vehicle = $TestVehicle
@onready var runner: AutotuneRunner = $AutotuneRunner
@onready var debug_panel: PanelContainer = $UI/DebugPanel
@onready var vbox: VBoxContainer = $UI/DebugPanel/VBox

# UI-Labels
var label_status: Label
var label_iteration: Label
var label_speed: Label
var label_slip: Label
var label_yaw: Label
var label_drift: Label
var label_grip: Label
var label_steering: Label
var label_test: Label
var progress_bar: ProgressBar


func _ready() -> void:
	_setup_ui_references()
	_connect_signals()

	# Runner konfigurieren
	runner.vehicle = vehicle
	runner.config = vehicle.physics_config.duplicate()

	_update_status("Bereit - [ENTER] zum Starten")


func _setup_ui_references() -> void:
	label_status = vbox.get_node("Status")
	label_iteration = vbox.get_node("Iteration")
	label_speed = vbox.get_node("Speed")
	label_slip = vbox.get_node("SlipAngle")
	label_yaw = vbox.get_node("YawRate")
	label_drift = vbox.get_node("Drift")
	label_grip = vbox.get_node("Grip")
	label_steering = vbox.get_node("Steering")
	label_test = vbox.get_node("CurrentTest")
	progress_bar = vbox.get_node("TestProgress")


func _connect_signals() -> void:
	runner.test_completed.connect(_on_test_completed)
	runner.iteration_completed.connect(_on_iteration_completed)
	runner.tuning_completed.connect(_on_tuning_completed)
	runner.tuning_failed.connect(_on_tuning_failed)


func _process(_delta: float) -> void:
	_update_vehicle_metrics()
	_handle_input()


func _update_vehicle_metrics() -> void:
	if not vehicle:
		return

	var m = vehicle.metrics
	label_speed.text = "Speed: %.1f km/h" % m.speed_kmh
	label_slip.text = "Slip: %.1f°" % m.slip_angle
	label_yaw.text = "Yaw: %.1f°/s" % m.yaw_rate
	label_drift.text = "Drift: %s" % ("YES" if m.is_drifting else "NO")
	label_grip.text = "Grip: %.2f" % m.effective_grip
	label_steering.text = "Steer: %.2f -> %.2f" % [vehicle.steering_input, m.steering_actual]


func _handle_input() -> void:
	if Input.is_action_just_pressed("ui_accept"):  # Enter
		if not runner.is_running:
			_start_autotune()
		else:
			runner.stop_autotune()

	if Input.is_action_just_pressed("ui_cancel"):  # Escape
		runner.stop_autotune()

	if Input.is_key_pressed(KEY_R):
		vehicle.reset_to_spawn(Vector3(0, 1, 0), 0.0)


func _start_autotune() -> void:
	_update_status("Tuning läuft...")
	runner.config = vehicle.physics_config.duplicate()
	runner.run_autotune()


func _update_status(text: String) -> void:
	label_status.text = "Status: %s" % text


func _on_test_completed(test_name: String, results: Dictionary) -> void:
	var passed = results.get("passed", false)
	var status = "PASS" if passed else "FAIL"
	label_test.text = "Test: %s [%s]" % [test_name, status]
	progress_bar.value = 100.0


func _on_iteration_completed(iteration: int, all_passed: bool) -> void:
	label_iteration.text = "Iteration: %d / %d" % [iteration + 1, runner.max_iterations]
	progress_bar.value = 0.0

	if all_passed:
		_update_status("Alle Tests bestanden!")


func _on_tuning_completed(final_config: VehiclePhysicsConfig) -> void:
	_update_status("Tuning abgeschlossen!")

	# Konfiguration anwenden
	vehicle.physics_config = final_config

	# Optional: Konfiguration speichern
	_save_config(final_config)

	print("\n=== FINALE KONFIGURATION ===")
	print("engine_force: %.2f" % final_config.engine_force)
	print("drag_coefficient: %.4f" % final_config.drag_coefficient)
	print("max_speed: %.2f" % final_config.max_speed)
	print("steer_gain_low_speed: %.2f" % final_config.steer_gain_low_speed)
	print("steer_gain_high_speed: %.2f" % final_config.steer_gain_high_speed)
	print("steer_response_time: %.4f" % final_config.steer_response_time)
	print("grip_base: %.2f" % final_config.grip_base)
	print("grip_breakpoint_slip: %.2f" % final_config.grip_breakpoint_slip)
	print("slide_friction: %.2f" % final_config.slide_friction)
	print("drift_recovery_strength: %.2f" % final_config.drift_recovery_strength)
	print("yaw_damping: %.2f" % final_config.yaw_damping)
	print("spin_threshold: %.2f" % final_config.spin_threshold)
	print("collision_restitution: %.2f" % final_config.collision_restitution)
	print("collision_energy_loss: %.2f" % final_config.collision_energy_loss)


func _on_tuning_failed(reason: String) -> void:
	_update_status("FEHLER: %s" % reason)


func _save_config(config: VehiclePhysicsConfig) -> void:
	var save_path = "user://tuned_vehicle_physics.tres"
	var error = ResourceSaver.save(config, save_path)
	if error == OK:
		print("Konfiguration gespeichert: %s" % save_path)
	else:
		push_error("Fehler beim Speichern: %d" % error)
