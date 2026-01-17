extends Node3D
## Hauptspielszene - Lädt Track und spawnt Spieler (3D)

var VehicleScene = load("res://scenes/vehicles/vehicle.tscn")
const CameraScene = preload("res://scenes/vehicles/dynamic_camera.tscn")

var camera: DynamicCamera
var race_tracker: RaceTracker
var vehicles: Array[Vehicle] = []
var spawn_points: Array[Node3D] = []
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
	var count = min(GameManager.config.player_count, spawn_points.size())
	for i in range(count):
		_create_vehicle(i)
	alive_count = vehicles.size()

func _init_systems() -> void:
	# Racing-Line vom Track holen
	var racing_line = $Track/RacingLine as Path3D

	if not racing_line:
		push_error("Game: RacingLine nicht gefunden unter $Track/RacingLine!")
		racing_line = $Track.get_node_or_null("RacingLine") as Path3D

	# RaceTracker initialisieren
	race_tracker.setup(vehicles, racing_line)

	# Kamera mit RaceTracker verbinden
	camera.setup(race_tracker)

	# HUD mit RaceTracker verbinden
	hud.setup(vehicles, player_colors, race_tracker)

	# Kamera initial positionieren
	_init_camera_position()

func _init_camera_position() -> void:
	# Kamera initialisiert sich jetzt selbst im setup()
	# Warte einen Frame um sicherzustellen dass alles geladen ist
	await get_tree().process_frame

func _give_start_immunity() -> void:
	# Alle Spieler bekommen kurze Start-Immunität
	for vehicle in vehicles:
		vehicle.respawn_immunity = true
	# Nach kurzer Zeit aufheben
	await get_tree().create_timer(1.0).timeout
	for vehicle in vehicles:
		if is_instance_valid(vehicle):
			vehicle.respawn_immunity = false

func _apply_color_to_meshes(node: Node, color: Color) -> void:
	# Rekursiv alle MeshInstance3D finden und einfärben
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		var material = StandardMaterial3D.new()
		material.albedo_color = color
		mesh_instance.material_override = material
	for child in node.get_children():
		_apply_color_to_meshes(child, color)

func _create_vehicle(idx: int) -> Vehicle:
	var vehicle = VehicleScene.instantiate()
	vehicle.player_id = idx

	# ERST zum Baum hinzufügen, DANN Position setzen
	$Track.add_child(vehicle)

	# Position und Rotation vom Spawn-Point übernehmen
	var spawn = spawn_points[idx]
	vehicle.global_position = spawn.global_position
	vehicle.rotation.y = spawn.rotation.y

	# Spieler 2+ als Bot aktivieren (zum Testen)
	if idx >= 1:
		vehicle.is_bot = true
		var racing_line = $Track/RacingLine
		if racing_line and racing_line.has_method("get_racing_points"):
			vehicle.bot_waypoints = racing_line.get_racing_points()
		elif racing_line and "racing_points" in racing_line:
			vehicle.bot_waypoints = racing_line.racing_points

	# Farbe temporär deaktiviert zum Testen
	#var body_node = vehicle.get_node_or_null("Body")
	#if body_node:
	#	_apply_color_to_meshes(body_node, player_colors[idx])

	vehicle._setup_input_actions()
	vehicle.destroyed.connect(_on_vehicle_destroyed.bind(idx))

	vehicles.append(vehicle)
	GameManager.register_player(vehicle)
	return vehicle

func _physics_process(_delta: float) -> void:
	_check_out_of_bounds()

func _check_out_of_bounds() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# Verwende die berechneten sichtbaren Grenzen der Kamera
	var bounds = camera.get_visible_bounds()
	var cam_center = bounds["center"]
	var margin = GameManager.config.out_of_bounds_margin
	var half_width = bounds["half_width"] + margin
	var half_depth = bounds["half_depth"] + margin

	for vehicle in vehicles:
		if vehicle.is_eliminated or vehicle.respawn_immunity:
			continue

		# Distanz zur Ziel-Kameraposition prüfen (nur X/Z)
		var rel_pos = vehicle.global_position - cam_center
		rel_pos.y = 0

		if abs(rel_pos.x) > half_width or abs(rel_pos.z) > half_depth:
			_handle_out_of_bounds(vehicle)

func _handle_out_of_bounds(vehicle: Vehicle) -> void:
	# Verhindere mehrfaches Triggern während Neustart
	if _is_restarting:
		return

	vehicle.lose_life()

	# Punkte an alle Spieler vergeben, die NICHT out of bounds gegangen sind
	for other_vehicle in vehicles:
		if other_vehicle != vehicle and not other_vehicle.is_eliminated:
			GameManager.add_score(other_vehicle.player_id)

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
		var spawn = spawn_points[i]
		vehicle.reset_to_spawn(spawn.global_position, spawn.rotation.y)

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

## Beendet die aktuelle Runde (Gewinner gefunden)
func _end_current_round() -> void:
	_is_restarting = true

	# Gewinner finden (Punkte wurden bereits in _handle_out_of_bounds vergeben)
	var winner_id = -1
	for vehicle in vehicles:
		if not vehicle.is_eliminated:
			winner_id = vehicle.player_id
			break

	GameManager.current_state = GameManager.GameState.ROUND_END
	GameManager.round_ended.emit(winner_id)

	# Nächste Runde nach kurzer Pause starten
	await get_tree().create_timer(2.0).timeout
	_is_restarting = false
	_start_new_round()

func _reset_camera_to_start() -> void:
	# Kamera positioniert sich automatisch basierend auf allen Fahrzeugen
	# Erzwinge sofortige Neupositionierung
	if camera:
		camera._initialize_from_vehicles()

func _on_vehicle_destroyed(player_id: int) -> void:
	GameManager.eliminate_player(player_id)

func _start_new_round() -> void:
	GameManager.current_round += 1

	if GameManager.current_round > GameManager.config.max_rounds:
		# Spiel beendet
		return

	# Alle Fahrzeuge zurücksetzen
	for i in range(vehicles.size()):
		var vehicle = vehicles[i]
		vehicle.lives = GameManager.config.max_lives
		vehicle.is_eliminated = false
		vehicle.respawn_immunity = true  # Start-Immunität
		vehicle.visible = true
		vehicle.set_physics_process(true)

		var spawn = spawn_points[i]
		vehicle.reset_to_spawn(spawn.global_position, spawn.rotation.y)

	# RaceTracker Runden zurücksetzen
	race_tracker.reset_laps()

	# Kamera sofort an Startposition setzen
	_reset_camera_to_start()

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
