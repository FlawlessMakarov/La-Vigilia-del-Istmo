extends Area2D

# Máquina de estados visual: evita que attack/reload/hurt/stun se pisen entre sí.
enum AnimationState { IDLE, ATTACK, RELOAD, HURT, STUNNED }

const LIGHT_AURA_BASE_RADIUS: float = 72.0

# Nodos opcionales: no todos los defensores tienen luz o sonidos de recarga.
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var light_aura: Node2D = get_node_or_null("LightAura") as Node2D
@onready var gunshot_sound: AudioStreamPlayer = get_node_or_null("GunshotSound") as AudioStreamPlayer
@onready var reload_sound: AudioStreamPlayer = get_node_or_null("ReloadSound") as AudioStreamPlayer
@onready var light_sound: AudioStreamPlayer = get_node_or_null("LightSound") as AudioStreamPlayer

# Cada escena de defensor sobreescribe estos valores desde el inspector/tscn.
@export var defender_id: String = "pistolero"
@export var display_name: String = "Pistolero"
@export var max_health: int = 100
@export var damage: int = 20
@export var attack_range: float = 850.0
@export var fire_rate: float = 1.0
@export var lane_index: int = -1
@export var light_radius: float = 430.0
@export var courage_generated: int = 10
@export var courage_interval: float = 5.0
@export var max_targets: int = 1
@export var lane_spread: int = 0
@export var piercing_shots: bool = false

# Estado runtime: celda ocupada, vida actual, cooldowns y animación en curso.
var grid_cell: Vector2i = Vector2i(-1, -1)
var health: int = 100
var shoot_cooldown: float = 0.0
var courage_timer: float = 0.0
var state: AnimationState = AnimationState.IDLE
var state_remaining: float = 0.0
var pending_hurt: bool = false

func _ready() -> void:
	health = max_health
	add_to_group("defenders")
	if defender_id == "farolero":
		add_to_group("light_sources")

	clear_attack_effects()
	enter_state(AnimationState.IDLE)

func _process(delta: float) -> void:
	if shoot_cooldown > 0.0:
		shoot_cooldown -= delta

	update_state(delta)

	if defender_id == "farolero":
		process_farolero(delta)
	elif state == AnimationState.IDLE:
		process_attacker()

# Termina estados temporales y decide cuál animación sigue.
func update_state(delta: float) -> void:
	if state == AnimationState.IDLE:
		return

	state_remaining -= delta
	if state_remaining > 0.0:
		return

	match state:
		AnimationState.ATTACK:
			clear_attack_effects()
			if pending_hurt:
				pending_hurt = false
				enter_state(AnimationState.HURT)
			elif has_animation("reload") and defender_id != "granjero" and defender_id != "farolero":
				enter_state(AnimationState.RELOAD)
			else:
				enter_state(AnimationState.IDLE)
		AnimationState.RELOAD:
			if pending_hurt:
				pending_hurt = false
				enter_state(AnimationState.HURT)
			else:
				enter_state(AnimationState.IDLE)
		AnimationState.HURT:
			enter_state(AnimationState.IDLE)
		AnimationState.STUNNED:
			modulate = Color.WHITE
			enter_state(AnimationState.IDLE)
		_:
			enter_state(AnimationState.IDLE)

# Entrada única a estados para que el cambio de animación sea consistente.
func enter_state(new_state: AnimationState, duration_override: float = -1.0) -> void:
	state = new_state

	match state:
		AnimationState.IDLE:
			state_remaining = 0.0
			modulate = Color.WHITE
			play_animation("idle")
		AnimationState.ATTACK:
			state_remaining = duration_override if duration_override > 0.0 else animation_duration("attack", 0.24)
			play_animation("attack")
		AnimationState.RELOAD:
			state_remaining = duration_override if duration_override > 0.0 else animation_duration("reload", 0.22)
			play_animation("reload")
			if reload_sound != null and defender_id == "pistolero":
				reload_sound.play()
		AnimationState.HURT:
			clear_attack_effects()
			state_remaining = duration_override if duration_override > 0.0 else animation_duration("hurt", 0.2)
			play_animation("hurt")
		AnimationState.STUNNED:
			clear_attack_effects()
			modulate = Color(0.55, 0.67, 1.0, 1.0)
			state_remaining = max(duration_override, 0.05)

# El Farolero no ataca: genera coraje, pulsa luz y revela Silampas.
func process_farolero(delta: float) -> void:
	courage_timer -= delta
	if courage_timer <= 0.0:
		courage_timer = courage_interval
		var game: Node = get_tree().current_scene
		if game != null and game.has_method("add_courage"):
			game.call("add_courage", courage_generated)
		flash_light()

	if light_aura != null:
		var pulse: float = 1.0 + sin(Time.get_ticks_msec() / 240.0) * 0.06
		var radius_scale: float = light_radius / LIGHT_AURA_BASE_RADIUS
		light_aura.scale = Vector2(radius_scale * pulse, radius_scale * pulse)

	reveal_silampas_in_light()

# Defensores ofensivos buscan enemigos en su carril y rango.
func process_attacker() -> void:
	if shoot_cooldown > 0.0:
		return

	var targets: Array[Node2D] = find_targets()
	if targets.is_empty():
		return

	shoot_cooldown = fire_rate
	enter_state(AnimationState.ATTACK)

	if defender_id == "granjero":
		play_slash_sound()
	else:
		play_weapon_sound()

	for target in targets:
		if target != null and is_instance_valid(target):
			target.call("take_damage", damage)

# Devuelve enemigos targeteables adelante del defensor, ordenados del más cercano al más lejano.
func find_targets() -> Array[Node2D]:
	var matches: Array[Node2D] = []
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")

	for enemy_node in enemies:
		var enemy: Node2D = enemy_node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_targetable") and not bool(enemy.call("is_targetable")):
			continue
		var enemy_lane: int = int(enemy.get("lane_index"))
		if abs(enemy_lane - lane_index) > lane_spread:
			continue

		var forward_distance: float = enemy.position.x - position.x
		if forward_distance >= -8.0 and forward_distance <= attack_range:
			matches.append(enemy)

	matches.sort_custom(sort_targets)
	if not piercing_shots and matches.size() > max_targets:
		matches = matches.slice(0, max_targets)
	return matches

func sort_targets(a: Node2D, b: Node2D) -> bool:
	var a_lane_distance: int = abs(int(a.get("lane_index")) - lane_index)
	var b_lane_distance: int = abs(int(b.get("lane_index")) - lane_index)
	if a_lane_distance != b_lane_distance:
		return a_lane_distance < b_lane_distance
	return a.position.x < b.position.x

func play_weapon_sound() -> void:
	if gunshot_sound != null:
		gunshot_sound.play()

# Granjero conserva solo el sonido del corte; el slash visual fue removido.
func play_slash_sound() -> void:
	if gunshot_sound != null:
		gunshot_sound.play()

func flash_light() -> void:
	if light_aura != null:
		light_aura.visible = true
		light_aura.modulate = Color(1.0, 0.82, 0.28, 0.52)
	if light_sound != null:
		light_sound.play()
	if state == AnimationState.IDLE:
		enter_state(AnimationState.ATTACK, animation_duration("attack", 0.45))

# La Silampa se vuelve atacable solo si está iluminada.
func reveal_silampas_in_light() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy_node in enemies:
		var enemy: Node2D = enemy_node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if str(enemy.get("enemy_id")) != "silampa":
			continue
		if global_position.distance_to(enemy.global_position) <= light_radius:
			if enemy.has_method("reveal_from_light"):
				enemy.call("reveal_from_light", 0.25)

func clear_attack_effects() -> void:
	pass

func apply_stun(duration: float) -> void:
	pending_hurt = false
	enter_state(AnimationState.STUNNED, duration)

# En daño, si estaba atacando se agenda HURT para después; así no corta la animación actual.
func take_damage(amount: int) -> void:
	health = max(health - amount, 0)
	if health <= 0:
		queue_free()
	elif state == AnimationState.IDLE or state == AnimationState.RELOAD:
		enter_state(AnimationState.HURT)
	elif state != AnimationState.STUNNED:
		pending_hurt = true

func heal(amount: int) -> void:
	if health <= 0:
		return
	health = min(health + amount, max_health)

# Helpers de animación: permiten escenas sin todas las animaciones.
func has_animation(animation_name: String) -> bool:
	return animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(animation_name)

func play_animation(animation_name: String, fallback_animation: String = "idle") -> void:
	if has_animation(animation_name):
		animated_sprite.play(animation_name)
	elif has_animation(fallback_animation):
		animated_sprite.play(fallback_animation)

func animation_duration(animation_name: String, fallback_duration: float) -> float:
	if not has_animation(animation_name):
		return fallback_duration
	var frame_count: int = animated_sprite.sprite_frames.get_frame_count(animation_name)
	var speed: float = animated_sprite.sprite_frames.get_animation_speed(animation_name)
	if frame_count <= 0 or speed <= 0.0:
		return fallback_duration
	return max(fallback_duration, float(frame_count) / speed)
