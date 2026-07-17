extends CharacterBody2D

const WalkState = preload("res://Scripts/states/enemy_walk_state.gd")
const AttackState = preload("res://Scripts/states/enemy_attack_state.gd")
const HurtState = preload("res://Scripts/states/enemy_hurt_state.gd")

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_timer: Timer = $AttackTimer
@onready var ability_effect: Node2D = get_node_or_null("AbilityEffect") as Node2D
@onready var bell_sound: AudioStreamPlayer = get_node_or_null("BellSound") as AudioStreamPlayer

@export var enemy_id := "duende"
@export var display_name := "Duende"
@export var speed := 70.0
@export var max_health := 100.0
@export var contact_range := 78.0
@export var attack_damage := 25
@export var lane_index := 0
@export var courage_reward := 10
@export var attack_interval := 1.25
@export var attack_visual_scale := 1.0
@export var bell_range := 150.0
@export var bell_interval := 5.0
@export var hidden_alpha := 0.34

var health := 100.0
var is_blocked := false
var current_defender: Node2D
var current_state: EnemyState
var current_state_id := ""
var states: Dictionary = {}
var is_hidden_enemy := false
var steal_timer := 2.5
var bell_timer := 2.0
var effect_timer := 0.0
var light_reveal_timer := 0.0
var base_sprite_scale := Vector2.ONE

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	base_sprite_scale = animated_sprite.scale
	attack_timer.wait_time = attack_interval
	if ability_effect != null: ability_effect.visible = false
	states = {"walk": WalkState.new(), "attack": AttackState.new(), "hurt": HurtState.new()}
	if enemy_id == "silampa":
		is_hidden_enemy = true
		modulate.a = hidden_alpha
	transition_to("walk")

func _process(delta: float) -> void:
	_update_timers(delta)
	_process_ability(delta)
	current_state.process(self, delta)

func transition_to(state_id: String) -> void:
	if current_state_id == state_id and state_id != "hurt": return
	current_state_id = state_id
	current_state = states[state_id] as EnemyState
	current_state.enter(self)

func _on_attack_timer_timeout() -> void:
	current_state.on_attack_timer(self)

func _update_timers(delta: float) -> void:
	effect_timer -= delta
	if effect_timer <= 0.0 and ability_effect != null: ability_effect.visible = false
	light_reveal_timer = max(light_reveal_timer - delta, 0.0)

func _process_ability(delta: float) -> void:
	if enemy_id == "silampa": _update_silampa_visibility()
	elif enemy_id == "duende": _process_duende(delta)
	elif enemy_id == "padre": _process_padre(delta)

func is_targetable() -> bool: return not is_hidden_enemy
func reveal_from_light(duration := 0.25) -> void:
	if enemy_id == "silampa": light_reveal_timer = max(light_reveal_timer, duration)

func _update_silampa_visibility() -> void:
	is_hidden_enemy = light_reveal_timer <= 0.0 and _nearby_lights().is_empty()
	modulate.a = hidden_alpha if is_hidden_enemy else 1.0

func _nearby_lights() -> Array[Node]:
	var matches: Array[Node] = []
	for light in get_tree().get_nodes_in_group("light_sources"):
		if light is Node2D and light.global_position.distance_to(global_position) <= float(light.get("light_radius")): matches.append(light)
	return matches

func _process_duende(delta: float) -> void:
	steal_timer -= delta
	if steal_timer <= 0.0 and not _nearby_lights().is_empty():
		steal_timer = 4.0
		get_tree().current_scene.call("add_courage", -5)
		_show_effect(0.35)

func _process_padre(delta: float) -> void:
	bell_timer -= delta
	if bell_timer > 0.0: return
	bell_timer = bell_interval
	if bell_sound != null: bell_sound.play()
	for defender in get_tree().get_nodes_in_group("defenders"):
		if int(defender.get("lane_index")) == lane_index and absf(defender.position.x - position.x) <= bell_range and defender.has_method("apply_stun"): defender.call("apply_stun", 1.6)

func _show_effect(duration: float) -> void:
	if ability_effect != null: ability_effect.visible = true
	effect_timer = duration

func find_defender_in_range() -> Node2D:
	var closest: Node2D
	for defender in get_tree().get_nodes_in_group("defenders"):
		if is_defender_in_range(defender) and (closest == null or defender.position.x > closest.position.x): closest = defender
	return closest

func is_defender_in_range(defender: Node2D) -> bool:
	return defender != null and is_instance_valid(defender) and int(defender.get("lane_index")) == lane_index and position.x - defender.position.x >= -8.0 and position.x - defender.position.x <= contact_range

func deal_damage_to_defender() -> void:
	if current_defender != null and is_defender_in_range(current_defender): current_defender.call("take_damage", attack_damage)
func set_sprite_scale(multiplier: float) -> void: animated_sprite.scale = base_sprite_scale * multiplier
func take_damage(amount: int) -> void:
	health = max(health - amount, 0.0)
	if health <= 0.0:
		get_tree().current_scene.call("on_enemy_defeated", courage_reward)
		queue_free()
	else: transition_to("hurt")
func has_animation(name: String) -> bool: return animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(name)
func play_animation(name: String, fallback := "walk") -> void: animated_sprite.play(name if has_animation(name) else fallback)
func animation_duration(name: String, fallback: float) -> float:
	if not has_animation(name): return fallback
	return max(fallback, float(animated_sprite.sprite_frames.get_frame_count(name)) / animated_sprite.sprite_frames.get_animation_speed(name))
