extends CanvasLayer
class_name HUD
## HUD - Zeigt Punktestand, Leben, Platzierung und Rundeninformationen
## Verwendet RaceTracker für Positions-Daten
## Debug-Overlay für Fahrzeug-Metriken (Toggle mit F3)

@onready var player_panels: Array[Control] = []
@onready var round_label: Label = $RoundLabel
@onready var message_label: Label = $MessageLabel

var player_count: int = 0
var player_colors: Array[Color] = []
var vehicles_ref: Array[Vehicle] = []
var race_tracker: RaceTracker

# Debug-Overlay
var debug_enabled: bool = false
var debug_panel: PanelContainer = null
var debug_labels: Dictionary = {}
var debug_target_vehicle: Vehicle = null

func _ready() -> void:
	GameManager.round_started.connect(_on_round_started)
	GameManager.round_ended.connect(_on_round_ended)
	GameManager.player_eliminated.connect(_on_player_eliminated)
	message_label.visible = false
	_create_debug_panel()

func setup(vehicles: Array[Vehicle], colors: Array[Color], tracker: RaceTracker) -> void:
	player_count = vehicles.size()
	vehicles_ref = vehicles
	race_tracker = tracker

	# Panels für jeden Spieler erstellen
	for i in range(player_count):
		var color = colors[i].lightened(0.2)
		player_colors.append(color)
		var panel = _create_player_panel(i, color, vehicles[i])
		player_panels.append(panel)
		add_child(panel)

	_update_round_label()

func _create_player_panel(idx: int, player_color: Color, vehicle: Vehicle) -> Control:
	var panel = Control.new()
	panel.name = "Player%d" % (idx + 1)

	# Position basierend auf Spieler-Index
	var margin = 20
	var panel_width = 180
	panel.position = Vector2(margin + idx * (panel_width + margin), margin)

	# Farbiger Rand links
	var color_bar = ColorRect.new()
	color_bar.size = Vector2(6, 103)
	color_bar.color = player_color
	panel.add_child(color_bar)

	# Hintergrund
	var bg = ColorRect.new()
	bg.position = Vector2(6, 0)
	bg.size = Vector2(174, 103)
	bg.color = Color(0, 0, 0, 0.7)
	panel.add_child(bg)

	# Spieler-Name mit Farbe
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = "SPIELER %d" % (idx + 1)
	name_label.position = Vector2(14, 5)
	name_label.add_theme_color_override("font_color", player_color)
	name_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(name_label)

	# Platz-Anzeige (Debug)
	var position_label = Label.new()
	position_label.name = "PositionLabel"
	position_label.text = "Platz: 1"
	position_label.position = Vector2(14, 25)
	position_label.add_theme_color_override("font_color", Color.YELLOW)
	panel.add_child(position_label)

	# Leben-Anzeige
	var lives_label = Label.new()
	lives_label.name = "LivesLabel"
	lives_label.text = "Leben: %d" % vehicle.lives
	lives_label.position = Vector2(14, 43)
	lives_label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(lives_label)

	# Punkte-Anzeige
	var score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "Punkte: 0"
	score_label.position = Vector2(14, 61)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(score_label)

	# Waffen-Anzeige
	var weapon_label = Label.new()
	weapon_label.name = "WeaponLabel"
	weapon_label.text = "Waffe: -"
	weapon_label.position = Vector2(14, 79)
	weapon_label.add_theme_color_override("font_color", Color.ORANGE)
	panel.add_child(weapon_label)

	# Weapon-Changed Signal verbinden
	vehicle.weapon_changed.connect(_on_weapon_changed.bind(idx))

	return panel

func _process(_delta: float) -> void:
	_update_displays()
	_handle_debug_input()
	_update_debug_panel()

func _update_displays() -> void:
	# Positions-Daten vom RaceTracker (falls verfügbar)
	var positions: Dictionary = {}
	if race_tracker:
		positions = race_tracker.get_all_positions()

	for i in range(player_panels.size()):
		var panel = player_panels[i]
		var position_label = panel.get_node("PositionLabel") as Label
		var lives_label = panel.get_node("LivesLabel") as Label
		var score_label = panel.get_node("ScoreLabel") as Label

		var vehicle = vehicles_ref[i] if i < vehicles_ref.size() else null
		if vehicle:
			# Leben-Anzeige (unabhängig vom RaceTracker!)
			lives_label.text = "Leben: %d" % vehicle.lives
			if vehicle.is_eliminated:
				lives_label.add_theme_color_override("font_color", Color.RED)
			else:
				lives_label.add_theme_color_override("font_color", Color.WHITE)

			# Platzierung (nur wenn RaceTracker verfügbar)
			if race_tracker and not vehicle.is_eliminated:
				var place = positions.get(vehicle, i + 1)
				var progress_percent = race_tracker.get_progress_percent(vehicle) * 100.0
				position_label.text = "Platz: %d (%.1f%%)" % [place, progress_percent]
				if place == 1:
					position_label.add_theme_color_override("font_color", Color.GOLD)
				else:
					position_label.add_theme_color_override("font_color", Color.WHITE)
			elif vehicle.is_eliminated:
				position_label.text = "Platz: - (OUT)"
				position_label.add_theme_color_override("font_color", Color.RED)
			else:
				position_label.text = "Platz: ?"

			# Score mit vehicle.player_id abfragen
			score_label.text = "Punkte: %d" % GameManager.get_score(vehicle.player_id)

func _update_round_label() -> void:
	round_label.text = "Runde %d / %d" % [GameManager.current_round, GameManager.config.max_rounds]

func _on_round_started() -> void:
	_update_round_label()
	message_label.visible = false
	# Namen zurücksetzen (ohne [OUT])
	for i in range(player_panels.size()):
		var panel = player_panels[i]
		var name_label = panel.get_node("NameLabel") as Label
		name_label.text = "SPIELER %d" % (i + 1)

func _on_round_ended(winner_id: int) -> void:
	message_label.visible = true
	if winner_id >= 0:
		message_label.text = "Spieler %d gewinnt die Runde!" % (winner_id + 1)
	else:
		message_label.text = "Unentschieden!"

func _on_player_eliminated(player_id: int) -> void:
	if player_id < player_panels.size():
		var panel = player_panels[player_id]
		var name_label = panel.get_node("NameLabel") as Label
		name_label.text += " [OUT]"

func _on_weapon_changed(weapon: Weapon, player_idx: int) -> void:
	if player_idx >= player_panels.size():
		return

	var panel = player_panels[player_idx]
	var weapon_label = panel.get_node("WeaponLabel") as Label

	if weapon:
		weapon_label.text = "Waffe: %s (%d)" % [weapon.get_weapon_name(), weapon.ammo]
		weapon_label.add_theme_color_override("font_color", Color.ORANGE)
		# Ammo-Update Signal verbinden
		weapon.ammo_changed.connect(_on_ammo_changed.bind(player_idx))
	else:
		weapon_label.text = "Waffe: -"
		weapon_label.add_theme_color_override("font_color", Color.GRAY)

func _on_ammo_changed(current: int, max_ammo: int, player_idx: int) -> void:
	if player_idx >= player_panels.size():
		return

	var panel = player_panels[player_idx]
	var weapon_label = panel.get_node("WeaponLabel") as Label
	var vehicle = vehicles_ref[player_idx] if player_idx < vehicles_ref.size() else null

	if vehicle and vehicle.current_weapon:
		weapon_label.text = "Waffe: %s (%d)" % [vehicle.current_weapon.get_weapon_name(), current]
		# Farbe ändern wenn Munition niedrig
		if current <= 5:
			weapon_label.add_theme_color_override("font_color", Color.RED)
		elif current <= 10:
			weapon_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			weapon_label.add_theme_color_override("font_color", Color.ORANGE)


# === DEBUG OVERLAY ===

func _create_debug_panel() -> void:
	debug_panel = PanelContainer.new()
	debug_panel.name = "DebugPanel"
	debug_panel.visible = false

	# Position: Unten links
	debug_panel.anchors_preset = Control.PRESET_BOTTOM_LEFT
	debug_panel.offset_left = 10
	debug_panel.offset_top = -200
	debug_panel.offset_right = 260
	debug_panel.offset_bottom = -10

	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	debug_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	debug_panel.add_child(vbox)

	# Labels erstellen
	var labels = [
		"Title",
		"Speed",
		"SlipAngle",
		"YawRate",
		"Drift",
		"Grip",
		"Steering",
		"HitCount",
		"Wobble"
	]

	for label_name in labels:
		var label = Label.new()
		label.name = label_name
		label.add_theme_font_size_override("font_size", 14)

		if label_name == "Title":
			label.text = "=== DEBUG (F3 toggle) ==="
			label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			label.text = "%s: -" % label_name
			label.add_theme_color_override("font_color", Color.WHITE)

		vbox.add_child(label)
		debug_labels[label_name] = label

	add_child(debug_panel)


func _handle_debug_input() -> void:
	if Input.is_action_just_pressed("ui_page_down") or Input.is_key_pressed(KEY_F3):
		debug_enabled = not debug_enabled
		debug_panel.visible = debug_enabled

		# Ersten Spieler als Standard-Target
		if debug_enabled and vehicles_ref.size() > 0:
			debug_target_vehicle = vehicles_ref[0]


func _update_debug_panel() -> void:
	if not debug_enabled or not debug_target_vehicle:
		return

	var v = debug_target_vehicle
	var m = v.metrics

	debug_labels["Speed"].text = "Speed: %.1f km/h (%.1f m/s)" % [m.speed_kmh, m.speed_ms]
	debug_labels["SlipAngle"].text = "Slip Angle: %.1f°" % m.slip_angle
	debug_labels["YawRate"].text = "Yaw Rate: %.1f°/s" % m.yaw_rate

	var drift_color = Color.GREEN if m.is_drifting else Color.RED
	debug_labels["Drift"].text = "Drifting: %s" % ("YES" if m.is_drifting else "NO")
	debug_labels["Drift"].add_theme_color_override("font_color", drift_color)

	debug_labels["Grip"].text = "Effective Grip: %.2f" % m.effective_grip
	debug_labels["Steering"].text = "Steer: %.2f -> %.2f (x%.1f)" % [v.steering_input, m.steering_actual, v.get_steering_multiplier()]

	# Hit/Wobble Anzeige
	var hit_color = Color.RED if v.is_steering_impaired else Color.WHITE
	debug_labels["HitCount"].text = "Hits: %d %s" % [m.hit_count, "(IMPAIRED)" if v.is_steering_impaired else ""]
	debug_labels["HitCount"].add_theme_color_override("font_color", hit_color)
	debug_labels["Wobble"].text = "Wobble: %.0f%%" % (m.wobble_intensity * 100)


func set_debug_target(vehicle: Vehicle) -> void:
	debug_target_vehicle = vehicle


func toggle_debug() -> void:
	debug_enabled = not debug_enabled
	debug_panel.visible = debug_enabled
