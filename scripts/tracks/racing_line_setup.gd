extends Path3D
class_name RacingLineSetup
## Definiert die Racing-Line für Position-Tracking (3D)
## Dieses Script wird an den Path3D Node im Track angehängt

## Die Punkte der Racing-Line (Strecken-Mittellinie)
## Gegen den Uhrzeigersinn, erster Punkt = Start/Ziel
@export var racing_points: Array[Vector3] = []

func _ready() -> void:
	_setup_curve()

func _setup_curve() -> void:
	if racing_points.is_empty():
		push_warning("RacingLineSetup: Keine racing_points definiert!")
		return

	if not curve:
		curve = Curve3D.new()

	curve.clear_points()

	for point in racing_points:
		curve.add_point(point)

	print("RacingLine: %d Punkte, Länge: %.1f" % [curve.point_count, curve.get_baked_length()])
