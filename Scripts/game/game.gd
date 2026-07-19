extends Node2D

## Controlador de partida: coordina tablero, recursos, UI y final de juego.

const GameConfig = preload("res://Scripts/core/game_config.gd")
const GridBoard = preload("res://Scripts/core/grid_board.gd")
const DefenderCardUI = preload("res://Scripts/ui/defender_card_ui.gd")

@onready var unit_container: Node2D = $UnitContainer
@onready var enemy_spawner: Node2D = $EnemySpawner
@onready var game_over_layer: CanvasLayer = $GameOverLayer
@onready var game_over_animation: AnimationPlayer = $GameOverLayer/GameOverAnimation
@onready var background_music: AudioStreamPlayer = $Sound
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var game_camera: Camera2D = $Camera2D

var board: GridBoard
var card_ui: DefenderCardUI
var is_game_over := false
var courage := GameConfig.STARTING_COURAGE
var selected_defender_id := "farolero"
var card_cooldowns: Dictionary = {}
var survival_time := GameConfig.SURVIVAL_DURATION
var courage_regen_timer := 0.0
var status_label: Label
var countdown_active := true
var countdown_label: Label
var preview_enemies: Array[Node2D] = []
var preview_is_visible := false
var enemy_info_label: Label
var eye_button: Button
var eye_pupil: Label
var eye_animation_time := 0.0
var highlighted_preview_enemy: Node2D
var preview_base_modulates: Dictionary = {}

func _ready() -> void:
	visible = true
	game_over_layer.visible = false
	board = GridBoard.new(
		GameConfig.LANE_Y,
		GameConfig.GRID_COLUMNS,
		GameConfig.GRID_X_START,
		GameConfig.GRID_COLUMN_SPACING,
		GameConfig.GRID_CELL_CLICK_WIDTH,
		GameConfig.GRID_CELL_CLICK_HEIGHT
	)
	_setup_status_label()
	if status_label != null:
		status_label.visible = false
	_setup_card_ui()
	refresh_ui()
	enemy_spawner.call("stop_spawning")
	for enemy in $EnemyContainer.get_children():
		enemy.queue_free()
	_create_enemy_preview()
	build_preparation_controls()

func _process(delta: float) -> void:
	if countdown_active and eye_button != null and is_instance_valid(eye_button):
		update_eye_animation(delta)
	if preview_is_visible:
		update_enemy_hover()
	if is_game_over or countdown_active:
		return

	survival_time -= delta
	courage_regen_timer -= delta
	if courage_regen_timer <= 0.0:
		courage_regen_timer = GameConfig.COURAGE_REGEN_INTERVAL
		add_courage(GameConfig.COURAGE_REGEN_AMOUNT)

	_update_card_cooldowns(delta)
	card_ui.update_timer(survival_time)
	if survival_time <= 0.0:
		start_victory()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and preview_is_visible:
		update_enemy_hover()
	if is_game_over or countdown_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := board.world_to_cell(get_global_mouse_position())
		if cell.x != -1:
			place_defender(cell, selected_defender_id)

func _setup_status_label() -> void:
	if not has_node("CanvasLayer/UI/LabelMessage"):
		return
	status_label = $CanvasLayer/UI/LabelMessage
	status_label.text = "1. Haz clic en una carta. 2. Haz clic en una celda del campo."
	status_label.offset_left = 650.0
	status_label.offset_top = 612.0
	status_label.offset_right = 1118.0
	status_label.offset_bottom = 642.0

func _setup_card_ui() -> void:
	card_ui = DefenderCardUI.new()
	add_child(card_ui)
	card_ui.defender_selected.connect(_on_defender_card_selected)
	card_ui.build(canvas_layer, GameConfig.DEFENDER_ORDER, GameConfig.DEFENDER_DATA)
	for defender_id in GameConfig.DEFENDER_ORDER:
		card_cooldowns[defender_id] = 0.0

func start_countdown() -> void:
	if not countdown_active:
		return
	if eye_button != null and is_instance_valid(eye_button):
		eye_button.queue_free()
		eye_button = null
	if enemy_info_label != null:
		enemy_info_label.visible = false
	clear_enemy_preview()
	countdown_label = Label.new()
	countdown_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	countdown_label.position = Vector2(-180, -80)
	countdown_label.size = Vector2(360, 160)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 82)
	countdown_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.2))
	canvas_layer.add_child(countdown_label)
	_run_countdown()

func build_preparation_controls() -> void:
	var start := Button.new()
	start.text = "INICIAR RONDA"
	start.position = Vector2(20, 610)
	start.size = Vector2(188, 34)
	start.add_theme_font_size_override("font_size", 15)
	start.pressed.connect(func() -> void:
		start.disabled = true
		start_countdown()
	)
	canvas_layer.add_child(start)
	eye_button = Button.new()
	eye_button.text = "\u25EF"
	eye_button.position = Vector2(830, 22)
	eye_button.size = Vector2(60, 48)
	eye_button.pivot_offset = eye_button.size * 0.5
	eye_button.add_theme_font_size_override("font_size", 34)
	eye_button.pressed.connect(toggle_enemy_preview)
	canvas_layer.add_child(eye_button)
	eye_pupil = Label.new()
	eye_pupil.text = "\u25CF"
	eye_pupil.position = Vector2(20, 14)
	eye_pupil.size = Vector2(20, 20)
	eye_pupil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eye_pupil.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	eye_pupil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eye_pupil.add_theme_font_size_override("font_size", 14)
	eye_pupil.add_theme_color_override("font_color", Color(0.12, 0.06, 0.025, 1.0))
	eye_button.add_child(eye_pupil)
	enemy_info_label = Label.new()
	enemy_info_label.position = Vector2(570, 76)
	enemy_info_label.size = Vector2(310, 56)
	enemy_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemy_info_label.add_theme_font_size_override("font_size", 14)
	enemy_info_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42, 1.0))
	canvas_layer.add_child(enemy_info_label)
	show_status("Elige torres a la izquierda y pulsa INICIAR RONDA.")

func toggle_enemy_preview() -> void:
	if preview_is_visible:
		_hide_enemy_preview()
		return
	preview_is_visible = true
	var pan := create_tween()
	pan.set_trans(Tween.TRANS_SINE)
	pan.set_ease(Tween.EASE_IN_OUT)
	pan.tween_property(game_camera, "position:x", 700.0, 0.65)
	show_status("Vista de enemigos: Duende, Silampa y Padre sin Cabeza. Pulsa el ojo para volver.")

func clear_enemy_preview() -> void:
	for enemy in preview_enemies:
		if is_instance_valid(enemy): enemy.queue_free()
	preview_enemies.clear()
	preview_base_modulates.clear()
	highlighted_preview_enemy = null
	preview_is_visible = false
	var pan := create_tween()
	pan.set_trans(Tween.TRANS_SINE)
	pan.set_ease(Tween.EASE_IN_OUT)
	pan.tween_property(game_camera, "position:x", 576.0, 0.65)

func _create_enemy_preview() -> void:
	var scenes := [preload("res://Scenes/Enemies/PadreSinCabeza.tscn"), preload("res://Scenes/Enemies/Silampa.tscn"), preload("res://Scenes/Enemies/Duende.tscn")]
	for index in scenes.size():
		var enemy := (scenes[index] as PackedScene).instantiate() as Node2D
		enemy.position = Vector2(1160 + index * 52, 330 + index * 70)
		$EnemyContainer.add_child(enemy)
		enemy.set_process(false)
		enemy.remove_from_group("enemies")
		var sprite := enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite != null:
			sprite.stop()
		preview_enemies.append(enemy)
		preview_base_modulates[enemy.get_instance_id()] = enemy.modulate

func _hide_enemy_preview() -> void:
	preview_is_visible = false
	var pan := create_tween()
	pan.set_trans(Tween.TRANS_SINE)
	pan.set_ease(Tween.EASE_IN_OUT)
	pan.tween_property(game_camera, "position:x", 576.0, 0.65)
	if enemy_info_label != null:
		enemy_info_label.text = ""
	set_preview_highlight(null)

func update_enemy_hover() -> void:
	if enemy_info_label == null:
		return
	var names := ["Padre sin Cabeza: aturde con su campana.", "Silampa: se revela con el Farolero.", "Duende: roba Coraje cerca de la luz."]
	var mouse := get_global_mouse_position()
	for index in preview_enemies.size():
		if mouse.distance_to(preview_enemies[index].global_position) < 58.0:
			enemy_info_label.text = names[index]
			set_preview_highlight(preview_enemies[index])
			return
	enemy_info_label.text = ""
	set_preview_highlight(null)

func set_preview_highlight(enemy: Node2D) -> void:
	if highlighted_preview_enemy == enemy:
		return
	if highlighted_preview_enemy != null and is_instance_valid(highlighted_preview_enemy):
		var previous_id := highlighted_preview_enemy.get_instance_id()
		highlighted_preview_enemy.modulate = preview_base_modulates.get(previous_id, Color.WHITE)
	highlighted_preview_enemy = enemy
	if enemy == null:
		return
	var base: Color = preview_base_modulates.get(enemy.get_instance_id(), Color.WHITE)
	enemy.modulate = Color(1.75, 1.5, 0.72, max(base.a, 0.9))
	var glow := Color(1.18, 1.10, 0.82, max(base.a, 0.9))
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(enemy, "modulate", glow, 0.22)

func update_eye_animation(delta: float) -> void:
	eye_animation_time += delta
	var pulse := 1.0 + sin(eye_animation_time * 3.2) * 0.035
	eye_button.scale = Vector2.ONE * pulse
	var eye_center := eye_button.position + eye_button.size * 0.5
	var cursor_direction := get_viewport().get_mouse_position() - eye_center
	if cursor_direction.length_squared() > 0.01:
		cursor_direction = cursor_direction.normalized()
	eye_pupil.position = Vector2(20, 14) + cursor_direction * 6.0

func _run_countdown() -> void:
	for number in [3, 2, 1]:
		countdown_label.text = str(number)
		await get_tree().create_timer(1.0).timeout
	countdown_label.text = "¡DEFIENDE!"
	countdown_label.add_theme_font_size_override("font_size", 52)
	await get_tree().create_timer(0.85).timeout
	countdown_label.queue_free()
	countdown_active = false
	enemy_spawner.call("start_spawning")
	refresh_ui()
	show_status("¡La ronda comenzó! Defiende el istmo.")

func _on_defender_card_selected(defender_id: String) -> void:
	selected_defender_id = defender_id
	var data: Dictionary = GameConfig.DEFENDER_DATA[defender_id] as Dictionary
	var cooldown_left: float = float(card_cooldowns.get(defender_id, 0.0))
	if cooldown_left > 0.0:
		show_status("%s sigue recargando: %.1fs." % [data["name"], cooldown_left])
	elif courage < int(data["cost"]):
		show_status("Falta Coraje para %s. Necesitas %d." % [data["name"], data["cost"]])
	else:
		show_status("Seleccionaste %s. Ahora haz clic en una celda del campo." % data["name"])
	refresh_ui()

func _update_card_cooldowns(delta: float) -> void:
	var changed := false
	for defender_id in card_cooldowns:
		var cooldown_left: float = float(card_cooldowns[defender_id])
		if cooldown_left > 0.0:
			card_cooldowns[defender_id] = max(cooldown_left - delta, 0.0)
			changed = true
	if changed:
		refresh_ui()

func refresh_ui() -> void:
	if card_ui != null:
		card_ui.refresh(courage, selected_defender_id, card_cooldowns, GameConfig.DEFENDER_DATA)

func add_courage(amount: int) -> void:
	courage = max(courage + amount, 0)
	refresh_ui()

func on_enemy_defeated(courage_reward: int) -> void:
	add_courage(courage_reward)
	heal_defenders(12)
	show_status("Enemigo eliminado: +%d Coraje y defensores curados." % courage_reward)

func heal_defenders(amount: int) -> void:
	for defender in get_tree().get_nodes_in_group("defenders"):
		if defender != null and is_instance_valid(defender) and defender.has_method("heal"):
			defender.call("heal", amount)

func show_status(message: String) -> void:
	if status_label != null:
		status_label.text = message

func place_defender(cell: Vector2i, defender_id: String) -> void:
	if not GameConfig.DEFENDER_SCENES.has(defender_id):
		return
	var data: Dictionary = GameConfig.DEFENDER_DATA[defender_id] as Dictionary
	var cooldown_left: float = float(card_cooldowns.get(defender_id, 0.0))
	if cooldown_left > 0.0:
		show_status("%s recarga en %.1fs." % [data["name"], cooldown_left])
		return
	if courage < int(data["cost"]):
		show_status("Falta Coraje para colocar %s. Necesitas %d." % [data["name"], data["cost"]])
		return
	if board.is_occupied(cell):
		show_status("Esa celda ya tiene un defensor. Elige otra celda.")
		return

	var defender_scene: PackedScene = GameConfig.DEFENDER_SCENES[defender_id] as PackedScene
	var defender: Node2D = defender_scene.instantiate() as Node2D
	defender.position = board.cell_to_world(cell) + Vector2(0.0, GameConfig.DEFENDER_GROUND_OFFSET_Y)
	defender.scale = Vector2.ONE * GameConfig.CHARACTER_SCALE
	defender.set("lane_index", cell.y)
	defender.set("grid_cell", cell)
	defender.tree_exiting.connect(_on_defender_removed.bind(cell))
	board.occupy(cell)
	unit_container.add_child(defender)
	add_courage(-int(data["cost"]))
	card_cooldowns[defender_id] = float(data["cooldown"])
	refresh_ui()
	show_status("Colocaste %s. Puedes elegir otra carta o colocar otro." % data["name"])

func _on_defender_removed(cell: Vector2i) -> void:
	board.release(cell)

func _on_game_over_line_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		start_game_over()

func start_victory() -> void:
	if is_game_over:
		return
	is_game_over = true
	card_ui.disable_all()
	enemy_spawner.call("stop_spawning")
	stop_all_gameplay_audio()
	set_gameplay_processing(false)
	$GameOverLayer/CenterBox/GameOverTitle.text = "VICTORIA"
	$GameOverLayer/CenterBox/GameOverTitle.add_theme_color_override("font_color", Color(0.95, 0.74, 0.22, 1.0))
	$GameOverLayer/CenterBox/GameOverMessage.text = "Sobreviviste dos minutos. El pueblo sigue en pie."
	game_over_layer.visible = true
	game_over_animation.play("fade_to_black")

func start_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	card_ui.disable_all()
	enemy_spawner.call("stop_spawning")
	background_music.stop()
	stop_all_gameplay_audio()
	set_gameplay_processing(false)
	game_over_layer.visible = true
	game_over_animation.play("fade_to_black")

func stop_all_gameplay_audio() -> void:
	for audio_node in find_children("*", "AudioStreamPlayer", true, false):
		var player := audio_node as AudioStreamPlayer
		if player != null:
			player.stop()

func set_gameplay_processing(enabled: bool) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_process(enabled)
	for defender in get_tree().get_nodes_in_group("defenders"):
		defender.set_process(enabled)

func _on_retry_button_pressed() -> void:
	get_tree().reload_current_scene()

func _on_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menu/menu.tscn")
