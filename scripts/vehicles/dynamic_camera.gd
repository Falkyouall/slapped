extends Camera2D
class_name DynamicCamera
## Kamera fokussiert auf den Führenden im Rennen
## Verwendet RaceTracker für die Leader-Ermittlung
## Zoomt dynamisch raus um alle Spieler im Bild zu halten

@export var default_zoom: float = 0.55  # Standard Zoom-Level (wenn alle nah beieinander)
@export var min_zoom: float = 0.35      # Maximales Rauszoomen (kleinerer Wert = weiter weg)
@export var smooth_speed: float = 8.0   # Kamera-Reaktion
@export var zoom_smooth_speed: float = 3.0  # Wie schnell der Zoom sich anpasst
@export var look_ahead: float = 250.0   # Wie weit vor dem Führenden die Kamera schaut
@export var screen_margin: float = 150.0  # Rand um Spieler herum (damit sie nicht am Bildschirmrand kleben)

var race_tracker: RaceTracker
var _target_zoom: float = 0.55
var _target_position: Vector2  # Ziel-Position für konsistente Out-of-Bounds Prüfung
var _viewport_size: Vector2

func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = smooth_speed
	_target_zoom = default_zoom
	zoom = Vector2(default_zoom, default_zoom)
	_viewport_size = get_viewport_rect().size

func setup(tracker: RaceTracker) -> void:
	race_tracker = tracker

func _process(delta: float) -> void:
	if not race_tracker:
		return

	var leader = race_tracker.get_leader()
	if leader:
		_update_position(leader)
		_update_zoom(delta, leader)

func _update_position(leader: Node2D) -> void:
	# Kamera folgt dem Führenden mit Vorausschau in Fahrtrichtung
	var forward_dir = Vector2.UP.rotated(leader.rotation)
	_target_position = leader.global_position + forward_dir * look_ahead
	global_position = _target_position

func _update_zoom(delta: float, leader: Node2D) -> void:
	# Berechne Ziel-Position der Kamera (wo sie hinwill)
	var forward_dir = Vector2.UP.rotated(leader.rotation)
	var target_cam_pos = leader.global_position + forward_dir * look_ahead

	# Finde den kleinsten Zoom der nötig ist um alle Spieler im Bild zu halten
	var needed_zoom: float = default_zoom
	var vehicles = race_tracker.get_vehicles()

	var half_width = _viewport_size.x / 2.0
	var half_height = _viewport_size.y / 2.0

	for vehicle in vehicles:
		if not is_instance_valid(vehicle):
			continue
		if vehicle.is_eliminated or vehicle.respawn_immunity:
			continue

		# Position des Spielers relativ zur Ziel-Kameraposition
		var rel_pos = vehicle.global_position - target_cam_pos

		# Welchen Zoom bräuchten wir um diesen Spieler im Bild zu halten?
		# Formel: sichtbare_hälfte = viewport_hälfte / zoom
		# Also: zoom = viewport_hälfte / benötigte_sichtbare_hälfte
		var needed_half_width = abs(rel_pos.x) + screen_margin
		var needed_half_height = abs(rel_pos.y) + screen_margin

		if needed_half_width > 0:
			var zoom_for_x = half_width / needed_half_width
			needed_zoom = min(needed_zoom, zoom_for_x)

		if needed_half_height > 0:
			var zoom_for_y = half_height / needed_half_height
			needed_zoom = min(needed_zoom, zoom_for_y)

	# Zoom begrenzen zwischen min_zoom und default_zoom
	_target_zoom = clamp(needed_zoom, min_zoom, default_zoom)

	# Smooth Zoom anwenden
	var current_zoom = zoom.x
	var new_zoom = lerpf(current_zoom, _target_zoom, zoom_smooth_speed * delta)
	zoom = Vector2(new_zoom, new_zoom)

## Gibt den Ziel-Zoom zurück (für Out-of-Bounds Berechnung)
## Verwende diesen Wert statt zoom.x, damit Grenzen sofort erweitert werden
func get_target_zoom() -> float:
	return _target_zoom

## Gibt die Ziel-Position zurück (für konsistente Out-of-Bounds Berechnung)
func get_bounds_center() -> Vector2:
	return _target_position
