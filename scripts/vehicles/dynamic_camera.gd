extends Camera3D
class_name DynamicCamera
## Kamera hält ALLE Fahrzeuge im Bild und folgt dem Streckenverlauf (Wrecked-Style)
## Smooth Rotation um Kurven

@export var default_height: float = 45.0
@export var min_height: float = 35.0
@export var max_height: float = 100.0
@export var position_smooth_speed: float = 4.0
@export var rotation_smooth_speed: float = 2.5  # Langsamer für smoothere Kurven
@export var height_smooth_speed: float = 3.0
@export var look_ahead: float = 10.0
@export var camera_angle: float = 55.0
@export var screen_margin: float = 30.0

var race_tracker: RaceTracker
var _target_height: float = 80.0
var _current_height: float = 80.0
var _target_position: Vector3
var _current_position: Vector3
var _target_direction: Vector3 = Vector3(-1, 0, 0)  # Ziel-Blickrichtung
var _current_direction: Vector3 = Vector3(-1, 0, 0)  # Aktuelle Blickrichtung (smooth)
var _initialized: bool = false

func _ready() -> void:
	_target_height = default_height
	_current_height = default_height

func setup(tracker: RaceTracker) -> void:
	race_tracker = tracker
	_initialize_from_vehicles()

func _initialize_from_vehicles() -> void:
	if not race_tracker:
		print("DynamicCamera: No race_tracker!")
		return

	var vehicles = race_tracker.get_vehicles()
	if vehicles.is_empty():
		print("DynamicCamera: No vehicles!")
		return

	# Berechne Mittelpunkt und Bounding Box aller Fahrzeuge
	var bounds = _calculate_vehicle_bounds(vehicles)
	var center = bounds["center"]
	var size = bounds["size"]

	print("DynamicCamera: Center=", center, " Size=", size)

	# Initiale Richtung: nach -X (links), da die Autos so starten
	_target_direction = Vector3(-1, 0, 0)
	_current_direction = Vector3(-1, 0, 0)

	# Berechne nötige Höhe um alle Autos zu sehen
	var fov_rad = deg_to_rad(fov)
	var needed_height = max(size.x, size.z) / tan(fov_rad / 2.0) * 0.6
	needed_height = clamp(needed_height, min_height, max_height)

	_target_position = center
	_current_position = center
	_target_height = needed_height
	_current_height = needed_height

	print("DynamicCamera: Height=", needed_height, " Position=", center)

	# Positioniere Kamera sofort
	_update_camera_transform_immediate()

	print("DynamicCamera: Final camera pos=", global_position)
	_initialized = true

func _calculate_vehicle_bounds(vehicles: Array[Vehicle]) -> Dictionary:
	var min_pos = Vector3(INF, 0, INF)
	var max_pos = Vector3(-INF, 0, -INF)
	var count = 0

	for vehicle in vehicles:
		if not is_instance_valid(vehicle) or vehicle.is_eliminated:
			continue
		var pos = vehicle.global_position
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.z = min(min_pos.z, pos.z)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.z = max(max_pos.z, pos.z)
		count += 1

	if count == 0:
		return {"center": Vector3.ZERO, "size": Vector3.ZERO}

	var center = Vector3(
		(min_pos.x + max_pos.x) / 2.0,
		0,
		(min_pos.z + max_pos.z) / 2.0
	)
	var size = Vector3(
		max_pos.x - min_pos.x + screen_margin * 2,
		0,
		max_pos.z - min_pos.z + screen_margin * 2
	)

	return {"center": center, "size": size}

func _process(delta: float) -> void:
	if not race_tracker or not _initialized:
		return

	var vehicles = race_tracker.get_vehicles()
	if vehicles.is_empty():
		return

	# Berechne Bounds aller aktiven Fahrzeuge
	var bounds = _calculate_vehicle_bounds(vehicles)
	var center = bounds["center"]
	var size = bounds["size"]

	# Hole Streckenrichtung vom Leader
	var leader = race_tracker.get_leader()
	if leader:
		_target_direction = _get_track_direction_at(leader)

	# Fokuspunkt: Mitte aller Fahrzeuge + leichte Vorausschau in Fahrtrichtung
	_target_position = center + _current_direction * look_ahead

	# Berechne nötige Höhe
	var fov_rad = deg_to_rad(fov)
	var needed_height = max(size.x, size.z) / tan(fov_rad / 2.0) * 1.2
	needed_height = clamp(needed_height, min_height, max_height)
	_target_height = needed_height

	# SMOOTH UPDATES
	_current_position = _current_position.lerp(_target_position, position_smooth_speed * delta)
	_current_height = lerpf(_current_height, _target_height, height_smooth_speed * delta)

	# Smooth Richtungs-Interpolation (Slerp für Vektoren)
	_current_direction = _smooth_direction(_current_direction, _target_direction, rotation_smooth_speed * delta)

	# Update Kamera-Transform mit smoothed Werten
	_update_camera_transform_smooth()

func _smooth_direction(current: Vector3, target: Vector3, factor: float) -> Vector3:
	# Verwende Slerp-ähnliche Interpolation für smoothe Richtungsänderung
	if current.dot(target) > 0.9999:
		return target

	# Lineare Interpolation und Normalisierung
	var result = current.lerp(target, factor)
	result.y = 0
	return result.normalized() if result.length() > 0.001 else current

func _get_track_direction_at(vehicle: Node3D) -> Vector3:
	if not race_tracker or not race_tracker.racing_line or not race_tracker.racing_line.curve:
		var forward = -vehicle.transform.basis.z
		forward.y = 0
		return forward.normalized() if forward.length() > 0.1 else Vector3(-1, 0, 0)

	var curve = race_tracker.racing_line.curve
	var racing_line = race_tracker.racing_line
	var local_pos = racing_line.to_local(vehicle.global_position)
	var offset = curve.get_closest_offset(local_pos)

	# Sample etwas VORAUS auf der Kurve für vorausschauende Kamera
	var look_ahead_offset = 15.0
	var pos1 = curve.sample_baked(offset)
	var pos2_offset = fmod(offset + look_ahead_offset, curve.get_baked_length())
	var pos2 = curve.sample_baked(pos2_offset)

	var direction = (pos2 - pos1).normalized()
	direction = racing_line.global_transform.basis * direction
	direction.y = 0

	return direction.normalized() if direction.length() > 0.1 else Vector3(-1, 0, 0)

func _update_camera_transform_immediate() -> void:
	# Sofortige Positionierung ohne Smoothing (für Init)
	# Autos fahren nach -X, also muss Kamera bei +X sein (hinter ihnen)
	var back_distance = _current_height * 0.6

	# Kamera ist HINTER den Autos (in +X Richtung, da Autos nach -X fahren)
	var cam_pos = Vector3(
		_current_position.x + back_distance,  # Hinter den Autos
		_current_height,                       # Oben
		_current_position.z                    # Gleiche Z-Position
	)

	global_position = cam_pos

	# Schau auf den Fokuspunkt
	look_at(_current_position + Vector3(0, 1, 0), Vector3.UP)

func _update_camera_transform_smooth() -> void:
	# Kamera-Position: hinter dem Fokuspunkt basierend auf aktueller (smoothed) Richtung
	var back_dir = -_current_direction
	var back_distance = _current_height * 0.6

	var cam_pos = _current_position + back_dir * back_distance
	cam_pos.y = _current_height

	global_position = cam_pos

	# Smooth Rotation: Schau auf den Fokuspunkt
	look_at(_current_position + Vector3(0, 1, 0), Vector3.UP)

func _apply_rotation_to_direction(dir: Vector3) -> void:
	# Berechne Y-Rotation aus Richtung
	var target_rot_y = atan2(dir.x, dir.z)

	# Setze Rotation: X für Neigung nach unten, Y für Blickrichtung
	rotation.x = deg_to_rad(-camera_angle)
	rotation.y = target_rot_y
	rotation.z = 0

## Für Out-of-Bounds Berechnung
func get_target_height() -> float:
	return _target_height

func get_bounds_center() -> Vector3:
	return _target_position

func get_visible_bounds() -> Dictionary:
	var fov_rad = deg_to_rad(fov)
	var half_width = _current_height * tan(fov_rad / 2.0)
	var half_depth = half_width / cos(deg_to_rad(camera_angle))

	return {
		"half_width": half_width,
		"half_depth": half_depth,
		"center": _current_position
	}
