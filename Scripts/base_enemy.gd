extends CharacterBody2D

# Estados simples del enemigo: caminar, atacar o reaccionar al daño.
enum EnemyState { WALK, ATTACK, HURT }

# Nodos comunes. Algunas escenas agregan AbilityEffect o BellSound y otras no.
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_timer: Timer = $AttackTimer
@onready var ability_effect: Node2D = get_node_or_null("AbilityEffect") as Node2D
@onready var bell_sound: AudioStreamPlayer = get_node_or_null("BellSound") as AudioStreamPlayer

# Valores configurables por tipo de enemigo desde cada .tscn.
@export var enemy_id: String = "duende"
@export var display_name: String = "Duende"
@export var speed: float = 70.0
@export var max_health: float = 100.0
@export var contact_range: float = 78.0
@export var attack_damage: int = 25
@export var lane_index: int = 0
@export var courage_reward: int = 10
@export var attack_interval: float = 1.25
@export var attack_visual_scale: float = 1.0
@export var bell_range: float = 150.0
@export var bell_interval: float = 5.0
@export var hidden_alpha: float = 0.34

# Estado runtime: vida, objetivo actual, timers de habilidad y estado visual.
var health: float = 100.0
var is_blocked: bool = false
var current_defender: Node2D = null
var is_hidden_enemy: bool = false
var steal_timer: float = 2.5
var bell_timer: float = 2.0
var effect_timer: float = 0.0
var light_reveal_timer: float = 0.0
var state: EnemyState = EnemyState.HURT
var state_remaining: float = 0.0
var base_sprite_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	base_sprite_scale = animated_sprite.scale
	attack_timer.wait_time = attack_interval
	attack_timer.one_shot = false
	attack_timer.stop()
	if ability_effect != null:
		ability_effect.visible = false
	if enemy_id == "silampa":
		is_hidden_enemy = true
		modulate = Color(1, 1, 1, hidden_alpha)
	enter_state(EnemyState.WALK)

func _process(delta: float) -> void:
	update_timers(delta)
	process_enemy_ability(delta)

	var defender_in_range: Node2D = find_defender_in_range()
	current_defender = defender_in_range

	if state == EnemyState.HURT:
		update_state(delta)
		return

	if defender_in_range != null:
		if state != EnemyState.ATTACK:
			enter_state(EnemyState.ATTACK)
		return

	if state != EnemyState.WALK:
		enter_state(EnemyState.WALK)
	position.x -= speed * delta

# Timers compartidos por efectos visuales y revelado temporal de Silampa.
func update_timers(delta: float) -> void:
	if effect_timer > 0.0:
		effect_timer -= delta
		if effect_timer <= 0.0 and ability_effect != null:
			ability_effect.visible = false
	if light_reveal_timer > 0.0:
		light_reveal_timer -= delta

# Cada enemy_id activa una habilidad distinta sin crear scripts separados.
func process_enemy_ability(delta: float) -> void:
	if enemy_id == "silampa":
		update_silampa_visibility()
	elif enemy_id == "duende":
		process_duende_steal(delta)
	elif enemy_id == "padre":
		process_padre_bell(delta)

# HURT pausa movimiento/ataque por un instante y luego vuelve a decidir.
func update_state(delta: float) -> void:
	if state != EnemyState.HURT:
		return

	state_remaining -= delta
	if state_remaining > 0.0:
		return

	if current_defender != null and is_defender_in_range(current_defender):
		enter_state(EnemyState.ATTACK)
	else:
		enter_state(EnemyState.WALK)

# Entrada central de estados; mantiene ataque, timer y animación sincronizados.
func enter_state(new_state: EnemyState) -> void:
	if state == new_state and new_state != EnemyState.HURT:
		return

	state = new_state
	match state:
		EnemyState.WALK:
			is_blocked = false
			state_remaining = 0.0
			set_sprite_scale(1.0)
			if not attack_timer.is_stopped():
				attack_timer.stop()
			play_animation("walk")
		EnemyState.ATTACK:
			is_blocked = true
			state_remaining = 0.0
			set_sprite_scale(attack_visual_scale)
			play_animation("attack", "walk")
			deal_damage_to_defender()
			attack_timer.start()
		EnemyState.HURT:
			is_blocked = true
			set_sprite_scale(1.0)
			if not attack_timer.is_stopped():
				attack_timer.stop()
			state_remaining = animation_duration("hurt", 0.18)
			play_animation("hurt", "walk")

func is_targetable() -> bool:
	return not is_hidden_enemy

# Llamado por el Farolero cuando la Silampa entra en el radio de luz.
func reveal_from_light(duration: float = 0.25) -> void:
	if enemy_id != "silampa":
		return
	light_reveal_timer = max(light_reveal_timer, duration)
	is_hidden_enemy = false
	modulate = Color(1, 1, 1, 1)

# La Silampa se oculta si no hay luz cercana; oculta significa que los defensores no la targetean.
func update_silampa_visibility() -> void:
	var revealed: bool = light_reveal_timer > 0.0
	var lights: Array[Node] = get_light_sources()
	for light_node in lights:
		var light: Node2D = light_node as Node2D
		if light != null and is_instance_valid(light):
			var radius: float = float(light.get("light_radius"))
			if light.global_position.distance_to(global_position) <= radius:
				revealed = true
				break

	is_hidden_enemy = not revealed
	if is_hidden_enemy:
		modulate = Color(1, 1, 1, hidden_alpha)
	else:
		modulate = Color(1, 1, 1, 1)

# Busca luces por grupo y también por defender_id, para sobrevivir a cambios de escena/grupos.
func get_light_sources() -> Array[Node]:
	var sources: Array[Node] = []
	var seen: Dictionary = {}

	for light_node in get_tree().get_nodes_in_group("light_sources"):
		if light_node != null and is_instance_valid(light_node):
			sources.append(light_node)
			seen[light_node.get_instance_id()] = true

	for defender_node in get_tree().get_nodes_in_group("defenders"):
		if defender_node != null and is_instance_valid(defender_node):
			if seen.has(defender_node.get_instance_id()):
				continue
			if str(defender_node.get("defender_id")) == "farolero":
				sources.append(defender_node)
				seen[defender_node.get_instance_id()] = true

	return sources

# El Duende roba coraje si se acerca a una fuente de luz.
func process_duende_steal(delta: float) -> void:
	steal_timer -= delta
	if steal_timer > 0.0:
		return
	steal_timer = 4.0

	var lights: Array[Node] = get_tree().get_nodes_in_group("light_sources")
	for light_node in lights:
		var light: Node2D = light_node as Node2D
		if light != null and is_instance_valid(light) and light.global_position.distance_to(global_position) <= 115.0:
			var game: Node = get_tree().current_scene
			if game != null and game.has_method("add_courage"):
				game.call("add_courage", -5)
			show_ability_effect(0.35)
			return

# El Padre toca campana y aturde defensores en su carril.
func process_padre_bell(delta: float) -> void:
	bell_timer -= delta
	if bell_timer > 0.0:
		return
	bell_timer = bell_interval
	if bell_sound != null:
		bell_sound.play()

	var defenders: Array[Node] = get_tree().get_nodes_in_group("defenders")
	for defender_node in defenders:
		var defender: Node2D = defender_node as Node2D
		if defender != null and is_instance_valid(defender):
			if int(defender.get("lane_index")) == lane_index and absf(defender.position.x - position.x) <= bell_range:
				if defender.has_method("apply_stun"):
					defender.call("apply_stun", 1.6)

func show_ability_effect(duration: float) -> void:
	if ability_effect != null:
		ability_effect.visible = true
	effect_timer = duration

# Encuentra el defensor más adelantado que puede bloquear al enemigo.
func set_sprite_scale(multiplier: float) -> void:
	animated_sprite.scale = base_sprite_scale * multiplier

func find_defender_in_range() -> Node2D:
	var defenders: Array[Node] = get_tree().get_nodes_in_group("defenders")
	var closest: Node2D = null

	for defender_node in defenders:
		var defender: Node2D = defender_node as Node2D
		if defender != null and is_defender_in_range(defender):
			if closest == null or defender.position.x > closest.position.x:
				closest = defender

	return closest

func is_defender_in_range(defender: Node2D) -> bool:
	if defender == null or not is_instance_valid(defender):
		return false
	var defender_lane: int = int(defender.get("lane_index"))
	var forward_distance: float = position.x - defender.position.x
	return defender_lane == lane_index and forward_distance >= -8.0 and forward_distance <= contact_range

func begin_attack() -> void:
	enter_state(EnemyState.ATTACK)

func _on_attack_timer_timeout() -> void:
	if state != EnemyState.ATTACK:
		return
	if current_defender == null or not is_defender_in_range(current_defender):
		enter_state(EnemyState.WALK)
		return
	deal_damage_to_defender()

func deal_damage_to_defender() -> void:
	if current_defender != null and is_defender_in_range(current_defender):
		current_defender.call("take_damage", attack_damage)

# Cuando muere avisa al Game para dar recompensa y curar defensores.
func take_damage(amount: int) -> void:
	health = max(health - amount, 0.0)
	if health <= 0.0:
		var game: Node = get_tree().current_scene
		if game != null and game.has_method("on_enemy_defeated"):
			game.call("on_enemy_defeated", courage_reward)
		elif game != null and game.has_method("add_courage"):
			game.call("add_courage", courage_reward)
		queue_free()
	else:
		enter_state(EnemyState.HURT)

# Helpers de animación con fallback: algunos enemigos no tienen todas las animaciones.
func has_animation(animation_name: String) -> bool:
	return animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(animation_name)

func play_animation(animation_name: String, fallback_animation: String = "walk") -> void:
	if has_animation(animation_name):
		animated_sprite.play(animation_name)
	elif has_animation(fallback_animation):
		animated_sprite.play(fallback_animation)

func animation_duration(animation_name: String, fallback_duration: float) -> float:
	if not has_animation(animation_name):
		return fallback_duration
	var frame_count: int = animated_sprite.sprite_frames.get_frame_count(animation_name)
	var animation_speed: float = animated_sprite.sprite_frames.get_animation_speed(animation_name)
	if frame_count <= 0 or animation_speed <= 0.0:
		return fallback_duration
	return max(fallback_duration, float(frame_count) / animation_speed)
