extends Node2D

const EnemyCatalog = preload("res://Scripts/gameplay/enemy_catalog.gd")

# Punto de entrada de enemigos y filas donde pueden aparecer.
@export var spawn_x: float = 1040.0
@export var spawn_interval: float = 3.2
@export var lane_y: PackedFloat32Array = [312.0, 358.0, 405.0, 455.0, 510.0]
@export_range(0.5, 1.0, 0.01) var character_scale: float = 0.68
@export_range(0.5, 1.2, 0.01) var silampa_scale: float = 0.92
@export_range(0.5, 1.2, 0.01) var padre_scale: float = 0.98
@export_range(-24.0, 0.0, 1.0) var ground_offset_y: float = -8.0

@onready var spawn_sound: AudioStreamPlayer = $GoblinSpawnSound
@onready var spawn_timer: Timer = $SpawnTimer

# Rotación de enemigos disponibles. El spawner elige una escena de esta lista.
var spawning_enabled: bool = true
var spawn_count: int = 0

func _ready() -> void:
	randomize()
	spawn_timer.wait_time = spawn_interval
	spawn_enemy()
	spawn_timer.start()

# Instancia un enemigo, lo pone en un carril aleatorio y lo agrega al contenedor del juego.
func spawn_enemy() -> void:
	if not spawning_enabled:
		return

	var scene: PackedScene = pick_enemy_scene()
	var enemy: Node2D = scene.instantiate() as Node2D
	var lane_index: int = randi() % lane_y.size()
	var enemy_scale: float = character_scale
	var enemy_id: String = str(enemy.get("enemy_id"))
	if enemy_id == "silampa":
		enemy_scale = silampa_scale
	elif enemy_id == "padre":
		enemy_scale = padre_scale

	enemy.position = Vector2(spawn_x, lane_y[lane_index] + ground_offset_y)
	enemy.scale = Vector2.ONE * enemy_scale
	enemy.set("lane_index", lane_index)

	get_parent().get_node("EnemyContainer").add_child(enemy)
	spawn_count += 1
	if spawn_sound != null and not spawn_sound.playing:
		spawn_sound.play()

# Control simple de dificultad: primero Duendes, luego mezcla, y cada sexto spawn fuerza Padre.
func pick_enemy_scene() -> PackedScene:
	if spawn_count > 0 and spawn_count % 6 == 0:
		return EnemyCatalog.SCENES[2]
	if spawn_count < 3:
		return EnemyCatalog.SCENES[0]
	return EnemyCatalog.SCENES[randi() % EnemyCatalog.SCENES.size()]

func stop_spawning() -> void:
	spawning_enabled = false
	spawn_timer.stop()
	if spawn_sound != null:
		spawn_sound.stop()
