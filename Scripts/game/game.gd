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
	_setup_card_ui()
	refresh_ui()
	card_ui.disable_all()
	enemy_spawner.call("stop_spawning")
	for enemy in $EnemyContainer.get_children():
		enemy.queue_free()
	start_countdown()

func _process(delta: float) -> void:
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
