extends Path3D
class_name RacingLineSetup
## Definiert die Racing-Line für Position-Tracking (3D)
## Dieses Script wird an den Path3D Node im Track angehängt

## Die Punkte der Racing-Line (Strecken-Mittellinie)
## Gegen den Uhrzeigersinn, erster Punkt = Start/Ziel
@export var racing_points: Array[Vector3] = []

## Farbe der Ideallinie
@export var line_color: Color = Color(0.0, 1.0, 0.5, 0.8)

## Breite der Linie
@export var line_width: float = 1.0

## Linie anzeigen?
@export var show_line: bool = true

var line_mesh_instance: MeshInstance3D

func _ready() -> void:
	_setup_curve()
	if show_line:
		_draw_racing_line()

func _setup_curve() -> void:
	if racing_points.is_empty():
		push_warning("RacingLineSetup: Keine racing_points definiert!")
		return

	if not curve:
		curve = Curve3D.new()

	curve.clear_points()

	for point in racing_points:
		curve.add_point(point)

func _draw_racing_line() -> void:
	if racing_points.size() < 2:
		return

	# MeshInstance für die Linie erstellen
	line_mesh_instance = MeshInstance3D.new()
	line_mesh_instance.name = "RacingLineVisual"
	add_child(line_mesh_instance)

	# ImmediateMesh für die Linie
	var immediate_mesh = ImmediateMesh.new()
	line_mesh_instance.mesh = immediate_mesh

	# Material erstellen
	var material = StandardMaterial3D.new()
	material.albedo_color = line_color
	material.emission_enabled = true
	material.emission = line_color
	material.emission_energy_multiplier = 0.5
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mesh_instance.material_override = material

	# Linie zeichnen als Quad-Strip (breite Linie)
	immediate_mesh.clear_surfaces()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	for i in range(racing_points.size()):
		var current = racing_points[i]
		var next = racing_points[(i + 1) % racing_points.size()]

		# Richtung zum nächsten Punkt
		var direction = (next - current).normalized()
		# Seitlicher Vektor (senkrecht zur Richtung)
		var side = Vector3(-direction.z, 0, direction.x) * (line_width * 0.5)

		# Zwei Vertices für diesen Punkt (links und rechts)
		var left = current + side + Vector3(0, 0.15, 0)  # Leicht über dem Boden
		var right = current - side + Vector3(0, 0.15, 0)

		immediate_mesh.surface_add_vertex(left)
		immediate_mesh.surface_add_vertex(right)

	# Schließe die Schleife
	var first = racing_points[0]
	var second = racing_points[1]
	var direction = (second - first).normalized()
	var side = Vector3(-direction.z, 0, direction.x) * (line_width * 0.5)
	immediate_mesh.surface_add_vertex(first + side + Vector3(0, 0.15, 0))
	immediate_mesh.surface_add_vertex(first - side + Vector3(0, 0.15, 0))

	immediate_mesh.surface_end()

	# Wegpunkt-Marker hinzufügen
	_add_waypoint_markers()

func _add_waypoint_markers() -> void:
	for i in range(racing_points.size()):
		var marker = CSGSphere3D.new()
		marker.radius = 1.5
		marker.transform.origin = racing_points[i] + Vector3(0, 1, 0)

		var mat = StandardMaterial3D.new()
		mat.albedo_color = line_color
		mat.emission_enabled = true
		mat.emission = line_color
		marker.material = mat

		add_child(marker)
