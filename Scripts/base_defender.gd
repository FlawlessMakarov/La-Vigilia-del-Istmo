extends Area2D

const IdleState = preload("res://Scripts/states/defender_idle_state.gd")
const AttackState = preload("res://Scripts/states/defender_attack_state.gd")
const ReloadState = preload("res://Scripts/states/defender_reload_state.gd")
const HurtState = preload("res://Scripts/states/defender_hurt_state.gd")
const StunnedState = preload("res://Scripts/states/defender_stunned_state.gd")

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var light_aura: Node2D = get_node_or_null("LightAura") as Node2D
@onready var gunshot_sound: AudioStreamPlayer = get_node_or_null("GunshotSound") as AudioStreamPlayer
@onready var reload_sound: AudioStreamPlayer = get_node_or_null("ReloadSound") as AudioStreamPlayer
@onready var light_sound: AudioStreamPlayer = get_node_or_null("LightSound") as AudioStreamPlayer

@export var defender_id := "pistolero"
@export var display_name := "Pistolero"
@export var max_health := 100
@export var damage := 20
@export var attack_range := 850.0
@export var fire_rate := 1.0
@export var lane_index := -1
@export var light_radius := 430.0
@export var courage_generated := 10
@export var courage_interval := 5.0
@export var max_targets := 1
@export var lane_spread := 0
@export var piercing_shots := false

var grid_cell := Vector2i(-1, -1)
var health := 100
var shoot_cooldown := 0.0
var courage_timer := 0.0
var pending_hurt := false
var current_state: DefenderState
var current_state_id := ""
var states: Dictionary

func _ready() -> void:
	health = max_health
	add_to_group("defenders")
	if defender_id == "farolero": add_to_group("light_sources")
	states = {"idle": IdleState.new(), "attack": AttackState.new(), "reload": ReloadState.new(), "hurt": HurtState.new(), "stunned": StunnedState.new()}
	transition_to("idle")

func _process(delta: float) -> void:
	shoot_cooldown = max(shoot_cooldown - delta, 0.0)
	current_state.process(self, delta)

func transition_to(state_id: String, duration := 0.0) -> void:
	current_state_id = state_id
	current_state = states[state_id] as DefenderState
	if state_id == "stunned": (current_state as StunnedState).set_duration(duration)
	current_state.enter(self)

func process_farolero(delta: float) -> void:
	courage_timer -= delta
	if courage_timer <= 0.0:
		courage_timer = courage_interval
		get_tree().current_scene.call("add_courage", courage_generated)
		flash_light()
	if light_aura != null:
		var scale_value := light_radius / 72.0 * (1.0 + sin(Time.get_ticks_msec() / 240.0) * 0.06)
		light_aura.scale = Vector2.ONE * scale_value
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if str(enemy.get("enemy_id")) == "silampa" and global_position.distance_to(enemy.global_position) <= light_radius: enemy.call("reveal_from_light", 0.25)

func process_attacker() -> void:
	if shoot_cooldown > 0.0: return
	var targets := find_targets()
	if targets.is_empty(): return
	shoot_cooldown = fire_rate
	transition_to("attack")
	if gunshot_sound != null: gunshot_sound.play()
	for target in targets: target.call("take_damage", damage)

func find_targets() -> Array[Node2D]:
	var matches: Array[Node2D] = []
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Node2D
		if enemy != null and enemy.has_method("is_targetable") and enemy.call("is_targetable") and abs(int(enemy.get("lane_index")) - lane_index) <= lane_spread and enemy.position.x - position.x >= -8.0 and enemy.position.x - position.x <= attack_range: matches.append(enemy)
	matches.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.x < b.position.x)
	return matches if piercing_shots else matches.slice(0, min(max_targets, matches.size()))

func flash_light() -> void:
	if light_aura != null: light_aura.visible = true
	if light_sound != null: light_sound.play()
	if current_state_id == "idle": transition_to("attack")
func clear_attack_effects() -> void: pass
func apply_stun(duration: float) -> void:
	pending_hurt = false
	transition_to("stunned", duration)
func take_damage(amount: int) -> void:
	health = max(health - amount, 0)
	if health <= 0: queue_free()
	elif current_state_id == "idle" or current_state_id == "reload": transition_to("hurt")
	elif current_state_id != "stunned": pending_hurt = true
func heal(amount: int) -> void: health = min(health + amount, max_health)
func has_animation(name: String) -> bool: return animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(name)
func play_animation(name: String, fallback := "idle") -> void: animated_sprite.play(name if has_animation(name) else fallback)
func animation_duration(name: String, fallback: float) -> float:
	if not has_animation(name): return fallback
	return max(fallback, float(animated_sprite.sprite_frames.get_frame_count(name)) / animated_sprite.sprite_frames.get_animation_speed(name))
