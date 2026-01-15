extends Node
class_name RaceTracker
## Zentrales Modul für Rennposition-Tracking
## Verwendet Path2D/Curve2D für präzises, streckenunabhängiges Tracking

signal lap_completed(vehicle: Vehicle, lap: int)
signal position_changed(vehicle: Vehicle, old_pos: int, new_pos: int)

## Die Racing-Line (Path2D) die die Strecken-Mittellinie definiert
@export var racing_line: Path2D

## Schwellwert für Runden-Erkennung (wie viel % der Strecke als "Sprung" gilt)
@export var lap_threshold: float = 0.4

var vehicles: Array[Vehicle] = []
var lap_counts: Dictionary = {}  # Vehicle -> int
var last_offsets: Dictionary = {}  # Vehicle -> float
var last_positions: Dictionary = {}  # Vehicle -> int (Platzierung)

var track_length: float = 0.0
var _curve: Curve2D

func _ready() -> void:
	if racing_line and racing_line.curve:
		_curve = racing_line.curve
		track_length = _curve.get_baked_length()

## Initialisiert den Tracker mit Fahrzeugen und Racing-Line
func setup(race_vehicles: Array[Vehicle], path: Path2D) -> void:
	vehicles = race_vehicles
	racing_line = path

	if not racing_line:
		push_error("RaceTracker: racing_line ist NULL! Track braucht einen RacingLine Path2D Node.")
		return

	if not racing_line.curve or racing_line.curve.point_count == 0:
		push_error("RaceTracker: racing_line.curve ist leer! RacingLine braucht racing_points.")
		return

	_curve = racing_line.curve
	track_length = _curve.get_baked_length()

	print("RaceTracker Setup: %d Fahrzeuge, Streckenlänge: %.1f, Punkte: %d" % [
		vehicles.size(), track_length, _curve.point_count
	])

	# Alle Fahrzeuge initialisieren
	lap_counts.clear()
	last_offsets.clear()
	last_positions.clear()

	for vehicle in vehicles:
		lap_counts[vehicle] = 0
		last_offsets[vehicle] = _get_raw_offset(vehicle)
		last_positions[vehicle] = 0
		print("  - %s: Start-Offset %.1f" % [vehicle.name, last_offsets[vehicle]])

## Setzt alle Fahrzeuge auf Runde 0 zurück (für neue Runde)
func reset_laps() -> void:
	for vehicle in vehicles:
		lap_counts[vehicle] = 0
		last_offsets[vehicle] = _get_raw_offset(vehicle)

## Holt den rohen Offset auf der Kurve (0 bis track_length)
func _get_raw_offset(vehicle: Vehicle) -> float:
	if not _curve or not is_instance_valid(vehicle):
		return 0.0

	# Konvertiere zu lokalen Koordinaten der Path2D
	var local_pos = racing_line.to_local(vehicle.global_position)
	return _curve.get_closest_offset(local_pos)

## Berechnet den Gesamt-Fortschritt (inklusive Runden)
func get_progress(vehicle: Vehicle) -> float:
	if not is_instance_valid(vehicle) or vehicle.is_eliminated:
		return -1000.0

	var current_offset = _get_raw_offset(vehicle)
	var laps = lap_counts.get(vehicle, 0)

	return (laps * track_length) + current_offset

## Berechnet den Fortschritt als Prozent der aktuellen Runde (0.0 - 1.0)
func get_progress_percent(vehicle: Vehicle) -> float:
	if not is_instance_valid(vehicle) or track_length <= 0:
		return 0.0

	var current_offset = _get_raw_offset(vehicle)
	return current_offset / track_length

## Gibt die aktuelle Platzierung zurück (1 = Erster, 2 = Zweiter, etc.)
func get_position(vehicle: Vehicle) -> int:
	var positions = get_all_positions()
	return positions.get(vehicle, vehicles.size())

## Berechnet alle Platzierungen und gibt ein Dictionary zurück
func get_all_positions() -> Dictionary:
	var progress_list: Array[Dictionary] = []

	for vehicle in vehicles:
		var progress = get_progress(vehicle)
		progress_list.append({"vehicle": vehicle, "progress": progress})

	# Nach Fortschritt sortieren (höchster zuerst)
	progress_list.sort_custom(func(a, b): return a["progress"] > b["progress"])

	# Platzierungen zuweisen
	var positions: Dictionary = {}
	for i in range(progress_list.size()):
		positions[progress_list[i]["vehicle"]] = i + 1

	return positions

## Gibt den Führenden zurück
func get_leader() -> Vehicle:
	var best_vehicle: Vehicle = null
	var best_progress: float = -INF

	for vehicle in vehicles:
		if not is_instance_valid(vehicle) or vehicle.is_eliminated:
			continue

		var progress = get_progress(vehicle)
		if progress > best_progress:
			best_progress = progress
			best_vehicle = vehicle

	return best_vehicle

## Gibt die aktuelle Runde eines Fahrzeugs zurück
func get_lap(vehicle: Vehicle) -> int:
	return lap_counts.get(vehicle, 0)

## Gibt alle registrierten Fahrzeuge zurück
func get_vehicles() -> Array[Vehicle]:
	return vehicles

## Muss jeden Frame aufgerufen werden um Runden zu tracken
func _process(_delta: float) -> void:
	_update_tracking()

func _update_tracking() -> void:
	if not _curve:
		return

	for vehicle in vehicles:
		if not is_instance_valid(vehicle) or vehicle.is_eliminated:
			continue

		var current_offset = _get_raw_offset(vehicle)
		var last_offset = last_offsets.get(vehicle, current_offset)

		# Runden-Erkennung
		_detect_lap_crossing(vehicle, last_offset, current_offset)

		last_offsets[vehicle] = current_offset

	# Positions-Änderungen erkennen
	_detect_position_changes()

func _detect_lap_crossing(vehicle: Vehicle, old_offset: float, new_offset: float) -> void:
	if track_length <= 0:
		return

	var threshold = track_length * lap_threshold

	# Vorwärts über Start/Ziel (von Ende zum Anfang)
	if old_offset > track_length - threshold and new_offset < threshold:
		lap_counts[vehicle] = lap_counts.get(vehicle, 0) + 1
		lap_completed.emit(vehicle, lap_counts[vehicle])

	# Rückwärts über Start/Ziel (von Anfang zum Ende)
	elif old_offset < threshold and new_offset > track_length - threshold:
		lap_counts[vehicle] = max(0, lap_counts.get(vehicle, 0) - 1)

func _detect_position_changes() -> void:
	var current_positions = get_all_positions()

	for vehicle in vehicles:
		var old_pos = last_positions.get(vehicle, 0)
		var new_pos = current_positions.get(vehicle, 0)

		if old_pos != new_pos and old_pos > 0:
			position_changed.emit(vehicle, old_pos, new_pos)

		last_positions[vehicle] = new_pos

## Debug: Gibt Tracking-Info für ein Fahrzeug zurück
func get_debug_info(vehicle: Vehicle) -> String:
	if not is_instance_valid(vehicle):
		return "Invalid"

	var offset = _get_raw_offset(vehicle)
	var progress = get_progress(vehicle)
	var position = get_position(vehicle)
	var lap = get_lap(vehicle)

	return "P%d | Lap %d | %.0f/%.0f (%.1f%%)" % [
		position,
		lap,
		offset,
		track_length,
		(offset / track_length) * 100 if track_length > 0 else 0
	]
