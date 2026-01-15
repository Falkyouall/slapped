extends Node2D
## Hauptspielszene - Lädt Track und spawnt Spieler

const VehicleScene = preload("res://scenes/vehicles/vehicle.tscn")
const CameraScene = preload("res://scenes/vehicles/dynamic_camera.tscn")

@export var player_count: int = 2
@export var out_of_bounds_margin: float = 100.0  # Extra Rand bevor Out-of-Bounds

var camera: DynamicCamera
var race_tracker: RaceTracker
var vehicles: Array[Vehicle] = []
var spawn_points: Array[Node2D] = []
var alive_count: int = 0
var _is_restarting: bool = false  # Verhindert mehrfaches Triggern

# Spieler-Farben
var player_colors: Array[Color] = [
	Color(0.2, 0.5, 1.0),   # Blau
	Color(1.0, 0.3, 0.3),   # Rot
	Color(0.3, 0.9, 0.3),   # Grün
	Color(1.0, 0.8, 0.2),   # Gelb
]

@onready var hud: HUD = $HUD

func _ready() -> void:
	spawn_points.assign($Track/SpawnPoints.get_children())
	_setup_race_tracker()
	_setup_camera()
	_spawn_players()
	_init_systems()
	_give_start_immunity()
	GameManager.start_game()

func _setup_race_tracker() -> void:
	# RaceTracker erstellen
	race_tracker = RaceTracker.new()
	race_tracker.name = "RaceTracker"
	add_child(race_tracker)

func _setup_camera() -> void:
	camera = CameraScene.instantiate()
	add_child(camera)

func _spawn_players() -> void:
	for i in range(min(player_count, spawn_points.size())):
		_create_vehicle(i)
	alive_count = vehicles.size()

func _init_systems() -> void:
	# Racing-Line vom Track holen
	var racing_line = $Track/RacingLine as Path2D

	if not racing_line:
		push_error("Game: RacingLine nicht gefunden unter $Track/RacingLine!")
		# Versuche alternative Pfade
		racing_line = $Track.get_node_or_null("RacingLine") as Path2D
		if racing_line:
			print("Game: RacingLine gefunden via get_node_or_null")

	# RaceTracker initialisieren
	race_tracker.setup(vehicles, racing_line)

	# Kamera mit RaceTracker verbinden
	camera.setup(race_tracker)

	# HUD mit RaceTracker verbinden
	hud.setup(vehicles, player_colors, race_tracker)

	# Kamera initial positionieren
	_init_camera_position()

func _init_camera_position() -> void:
	# Kamera direkt an Startposition setzen
	if vehicles.size() > 0:
		var first_vehicle = vehicles[0]
		var forward_dir = Vector2.UP.rotated(first_vehicle.rotation)
		camera.position_smoothing_enabled = false
		camera.global_position = first_vehicle.global_position + forward_dir * camera.look_ahead
		camera.zoom = Vector2(camera.default_zoom, camera.default_zoom)
		await get_tree().process_frame
		camera.position_smoothing_enabled = true

func _give_start_immunity() -> void:
	# Alle Spieler bekommen kurze Start-Immunität
	for vehicle in vehicles:
		vehicle.respawn_immunity = true
	# Nach kurzer Zeit aufheben
	await get_tree().create_timer(1.0).timeout
	for vehicle in vehicles:
		if is_instance_valid(vehicle):
			vehicle.respawn_immunity = false

func _create_vehicle(idx: int) -> Vehicle:
	var vehicle = VehicleScene.instantiate()
	vehicle.player_id = idx
	vehicle.position = spawn_points[idx].position
	vehicle.rotation = spawn_points[idx].rotation
	vehicle.get_node("Sprite").modulate = player_colors[idx]
	vehicle._setup_input_actions()
	vehicle.destroyed.connect(_on_vehicle_destroyed.bind(idx))

	$Track.add_child(vehicle)
	vehicles.append(vehicle)
	GameManager.register_player(vehicle)
	return vehicle

func _physics_process(_delta: float) -> void:
	_check_out_of_bounds()

func _check_out_of_bounds() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	var viewport_size = get_viewport_rect().size
	# Verwende Ziel-Position und Ziel-Zoom für konsistente Berechnung
	# (die Kamera berechnet den Zoom basierend auf der Ziel-Position)
	var cam_pos = camera.get_bounds_center()
	var zoom_factor = camera.get_target_zoom()

	# Sichtbare Grenzen berechnen (basierend auf Ziel-Zoom)
	var half_width = (viewport_size.x / 2.0) / zoom_factor + out_of_bounds_margin
	var half_height = (viewport_size.y / 2.0) / zoom_factor + out_of_bounds_margin

	for vehicle in vehicles:
		if vehicle.is_eliminated or vehicle.respawn_immunity:
			continue

		# Distanz zur Ziel-Kameraposition prüfen
		var rel_pos = vehicle.global_position - cam_pos

		if abs(rel_pos.x) > half_width or abs(rel_pos.y) > half_height:
			_handle_out_of_bounds(vehicle)

func _handle_out_of_bounds(vehicle: Vehicle) -> void:
	# Verhindere mehrfaches Triggern während Neustart
	if _is_restarting:
		return

	print("OUT OF BOUNDS: %s - Leben vorher: %d" % [vehicle.name, vehicle.lives])
	vehicle.lose_life()
	print("OUT OF BOUNDS: %s - Leben nachher: %d" % [vehicle.name, vehicle.lives])

	if vehicle.is_eliminated:
		# Spieler ist komplett raus
		vehicle.visible = false
		vehicle.set_physics_process(false)
		alive_count -= 1

		if alive_count <= 1:
			# Runde beendet - Gewinner ermitteln
			_end_current_round()
		else:
			# Rennen neu starten (ohne den eliminierten Spieler)
			_restart_race_from_start()
	else:
		# Spieler hat noch Leben - Rennen neu starten
		_restart_race_from_start()

## Startet das Rennen neu von der Startlinie (alle Spieler zurück zum Start)
func _restart_race_from_start() -> void:
	_is_restarting = true

	# Alle aktiven Spieler zurück zum Start
	for i in range(vehicles.size()):
		var vehicle = vehicles[i]
		if vehicle.is_eliminated:
			continue

		vehicle.respawn_immunity = true
		vehicle.reset_to_spawn(spawn_points[i].position, spawn_points[i].rotation)

	# RaceTracker zurücksetzen
	if race_tracker:
		race_tracker.reset_laps()

	# Kamera sofort an Startposition
	_reset_camera_to_start()

	# Kurze Pause, dann weiter
	await get_tree().create_timer(0.5).timeout

	# Immunität aufheben und Rennen fortsetzen
	for vehicle in vehicles:
		if not vehicle.is_eliminated:
			vehicle.respawn_immunity = false

	_is_restarting = false
	print("Rennen neu gestartet!")

## Beendet die aktuelle Runde (Gewinner gefunden)
func _end_current_round() -> void:
	_is_restarting = true

	# Gewinner finden
	var winner_id = -1
	for vehicle in vehicles:
		if not vehicle.is_eliminated:
			winner_id = vehicle.player_id
			GameManager.add_score(winner_id)
			break

	GameManager.current_state = GameManager.GameState.ROUND_END
	GameManager.round_ended.emit(winner_id)

	# Nächste Runde nach kurzer Pause starten
	await get_tree().create_timer(2.0).timeout
	_is_restarting = false
	_start_new_round()

func _reset_camera_to_start() -> void:
	if vehicles.size() > 0:
		var first_active: Vehicle = null
		for v in vehicles:
			if not v.is_eliminated:
				first_active = v
				break

		if first_active:
			var forward_dir = Vector2.UP.rotated(first_active.rotation)
			camera.position_smoothing_enabled = false
			camera.global_position = first_active.global_position + forward_dir * camera.look_ahead
			camera.position_smoothing_enabled = true

func _on_vehicle_destroyed(player_id: int) -> void:
	GameManager.eliminate_player(player_id)

func _start_new_round() -> void:
	GameManager.current_round += 1

	if GameManager.current_round > GameManager.max_rounds:
		# Spiel beendet - zeige Endergebnis
		print("Spiel beendet! Endergebnis:")
		for i in range(vehicles.size()):
			print("Spieler %d: %d Punkte" % [i + 1, GameManager.get_score(i)])
		return

	# Alle Fahrzeuge zurücksetzen
	for i in range(vehicles.size()):
		var vehicle = vehicles[i]
		vehicle.lives = vehicle.max_lives
		vehicle.is_eliminated = false
		vehicle.respawn_immunity = true  # Start-Immunität
		vehicle.visible = true
		vehicle.set_physics_process(true)
		vehicle.reset_to_spawn(spawn_points[i].position, spawn_points[i].rotation)

	# RaceTracker Runden zurücksetzen
	race_tracker.reset_laps()

	# Kamera sofort an Startposition setzen
	if vehicles.size() > 0:
		var first_vehicle = vehicles[0]
		var forward_dir = Vector2.UP.rotated(first_vehicle.rotation)
		camera.position_smoothing_enabled = false
		camera.global_position = first_vehicle.global_position + forward_dir * camera.look_ahead
		camera.position_smoothing_enabled = true

	alive_count = vehicles.size()
	GameManager.current_state = GameManager.GameState.PLAYING
	GameManager.round_started.emit()

	# Start-Immunität nach kurzer Zeit aufheben
	await get_tree().create_timer(1.0).timeout
	for vehicle in vehicles:
		if is_instance_valid(vehicle):
			vehicle.respawn_immunity = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if GameManager.current_state == GameManager.GameState.PLAYING:
			GameManager.pause_game()
		elif GameManager.current_state == GameManager.GameState.PAUSED:
			GameManager.resume_game()
