extends Resource
class_name GameConfig
## Zentrale Spielkonfiguration - Single Source of Truth
## Verwendung: Als .tres Resource im Editor oder via GameManager.config

# Spieler
@export_range(1, 4) var player_count: int = 2
@export var max_rounds: int = 5
@export var max_lives: int = 3

# Kamera
@export_group("Camera")
@export var camera_default_height: float = 25.0
@export var camera_min_height: float = 25.0
@export var camera_max_height: float = 100.0
@export var camera_smooth_speed: float = 4.0
@export var camera_height_smooth_speed: float = 8.0

# Gameplay
@export_group("Gameplay")
@export var out_of_bounds_margin: float = 15.0

# Fahrzeug-Physik
@export_group("Vehicle Physics")
@export var vehicle_max_speed: float = 40.0
@export var vehicle_acceleration: float = 60.0
@export var vehicle_brake_power: float = 80.0
@export var vehicle_gravity: float = 40.0
@export_range(0.0, 1.0) var vehicle_collision_bounce: float = 0.25
