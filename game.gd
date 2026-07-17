extends Node2D

# Nodos principales de la escena: aquí se colocan unidades, enemigos y UI.
@onready var unit_container: Node2D = $UnitContainer
@onready var enemy_spawner: Node2D = $EnemySpawner
@onready var game_over_layer: CanvasLayer = $GameOverLayer
@onready var game_over_animation: AnimationPlayer = $GameOverLayer/GameOverAnimation
@onready var background_music: AudioStreamPlayer = $Sound
@onready var canvas_layer: CanvasLayer = $CanvasLayer

# Catálogo de defensores: cada id apunta a su escena y a los datos de la carta.
const DEFENDER_SCENES: Dictionary = {
	"farolero": preload("res://Scenes/Defenders/Farolero.tscn"),
	"pistolero": preload("res://Scenes/Defenders/Pistolero.tscn"),
	"granjero": preload("res://Scenes/Defenders/Granjero.tscn"),
	"escopetero": preload("res://Scenes/Defenders/Escopetero.tscn"),
	"fusilero": preload("res://Scenes/Defenders/Fusilero.tscn"),
	"rastreador": preload("res://Scenes/Defenders/Rastreador.tscn")
}

const DEFENDER_ORDER: Array[String] = ["farolero", "pistolero", "granjero", "escopetero", "fusilero", "rastreador"]

const DEFENDER_DATA: Dictionary = {
	"farolero": {
		"name": "Farolero",
		"cost": 30,
		"cooldown": 4.0,
		"icon": "res://Sprites/Imported/Frames/farolero/idle/00.png"
	},
	"pistolero": {
		"name": "Pistolero",
		"cost": 45,
		"cooldown": 3.5,
		"icon": "res://Sprites/Imported/Frames/pistolero/idle/00.png"
	},
	"granjero": {
		"name": "Granjero",
		"cost": 55,
		"cooldown": 5.0,
		"icon": "res://Sprites/Imported/Frames/granjero/idle/00.png"
	},
	"escopetero": {
		"name": "Escopetero",
		"cost": 65,
		"cooldown": 6.0,
		"icon": "res://Sprites/Imported/Frames/escopetero/idle/00.png"
	},
	"fusilero": {
		"name": "Fusilero",
		"cost": 70,
		"cooldown": 5.5,
		"icon": "res://Sprites/Imported/Frames/fusilero/idle/00.png"
	},
	"rastreador": {
		"name": "Rastreador",
		"cost": 85,
		"cooldown": 7.0,
		"icon": "res://Sprites/Imported/Frames/rastreador/idle/00.png"
	}
}

# Coordenadas del tablero. Los defensores solo se colocan en estas filas y columnas.
const LANE_Y: PackedFloat32Array = [312.0, 358.0, 405.0, 455.0, 510.0]
const GRID_X_START: float = 275.0
const GRID_COLUMN_SPACING: float = 108.0
const GRID_CELL_CLICK_WIDTH: float = 108.0
const GRID_CELL_CLICK_HEIGHT: float = 58.0
const GRID_COLUMNS: int = 6
const CHARACTER_SCALE: float = 0.68
const DEFENDER_GROUND_OFFSET_Y: float = -12.0

# Estado de la partida: recursos, cartas seleccionadas, tiempo y celdas ocupadas.
var occupied_cells: Dictionary = {}
var is_game_over: bool = false
var courage: int = 120
var selected_defender_id: String = "farolero"
var card_buttons: Dictionary = {}
var card_cooldowns: Dictionary = {}
var card_cooldown_overlays: Dictionary = {}
var card_cooldown_labels: Dictionary = {}
var courage_label: Label
var selected_label: Label
var status_label: Label
var timer_label: Label
var survival_time: float = 120.0
var courage_regen_timer: float = 0.0

func _ready() -> void:
	visible = true
	game_over_layer.visible = false
	if has_node("CanvasLayer/UI/LabelMessage"):
		status_label = $CanvasLayer/UI/LabelMessage
		status_label.text = "1. Haz clic en una carta. 2. Haz clic en una celda del campo."
		status_label.offset_left = 650.0
		status_label.offset_top = 612.0
		status_label.offset_right = 1118.0
		status_label.offset_bottom = 642.0
	setup_defender_cards()
	setup_timer_label()
	update_courage_ui()
	update_timer_label()

func _process(delta: float) -> void:
	if is_game_over:
		return

	survival_time -= delta
	courage_regen_timer -= delta
	if courage_regen_timer <= 0.0:
		courage_regen_timer = 2.0
		add_courage(4)

	update_card_cooldowns(delta)
	update_timer_label()
	if survival_time <= 0.0:
		start_victory()

# Click izquierdo en el campo: convierte la posición del mouse en celda y coloca la carta seleccionada.
func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell: Vector2i = get_cell_from_world(get_global_mouse_position())
		if cell.x != -1:
			place_defender(cell, selected_defender_id)

# La UI de cartas se crea por código para que agregar/quitar defensores sea solo cambiar DEFENDER_DATA.
func setup_defender_cards() -> void:
	var info_panel: PanelContainer = PanelContainer.new()
	info_panel.name = "CouragePanel"
	info_panel.offset_left = 936.0
	info_panel.offset_top = 258.0
	info_panel.offset_right = 1124.0
	info_panel.offset_bottom = 292.0
	info_panel.add_theme_stylebox_override("panel", make_panel_style(Color(0.03, 0.035, 0.035, 0.90), Color(0.75, 0.52, 0.18, 0.95)))
	canvas_layer.add_child(info_panel)

	courage_label = Label.new()
	courage_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32, 1.0))
	courage_label.add_theme_font_size_override("font_size", 18)
	courage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	courage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_panel.add_child(courage_label)

	selected_label = Label.new()
	selected_label.offset_left = 936.0
	selected_label.offset_top = 298.0
	selected_label.offset_right = 1124.0
	selected_label.offset_bottom = 322.0
	selected_label.add_theme_color_override("font_color", Color(0.88, 0.82, 0.68, 1.0))
	selected_label.add_theme_font_size_override("font_size", 13)
	canvas_layer.add_child(selected_label)

	var card_bar: GridContainer = GridContainer.new()
	card_bar.name = "DefenderCards"
	card_bar.offset_left = 936.0
	card_bar.offset_top = 314.0
	card_bar.offset_right = 1124.0
	card_bar.offset_bottom = 606.0
	card_bar.columns = 2
	card_bar.add_theme_constant_override("h_separation", 6)
	card_bar.add_theme_constant_override("v_separation", 6)
	canvas_layer.add_child(card_bar)

	for defender_id in DEFENDER_ORDER:
		var data: Dictionary = DEFENDER_DATA[defender_id] as Dictionary
		var button: Button = Button.new()
		button.name = "%sCard" % defender_id.capitalize()
		button.custom_minimum_size = Vector2(91, 82)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.toggle_mode = true
		button.text = "%s\n%d" % [data["name"], data["cost"]]
		button.add_theme_font_size_override("font_size", 10)
		button.add_theme_color_override("font_color", Color(0.96, 0.88, 0.68, 1.0))
		button.add_theme_color_override("font_disabled_color", Color(0.54, 0.54, 0.54, 1.0))
		button.add_theme_stylebox_override("normal", make_card_style(false))
		button.add_theme_stylebox_override("hover", make_card_style(true))
		button.add_theme_stylebox_override("pressed", make_card_style(true))
		button.add_theme_stylebox_override("disabled", make_disabled_card_style())
		button.pressed.connect(_on_defender_card_pressed.bind(defender_id))

		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = load(data["icon"])
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.expand_mode = 1
		icon_rect.stretch_mode = 5
		icon_rect.offset_left = 18.0
		icon_rect.offset_top = 7.0
		icon_rect.offset_right = 73.0
		icon_rect.offset_bottom = 54.0
		button.add_child(icon_rect)

		var cooldown_overlay: ColorRect = ColorRect.new()
		cooldown_overlay.name = "CooldownOverlay"
		cooldown_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown_overlay.color = Color(0.02, 0.025, 0.025, 0.72)
		cooldown_overlay.offset_left = 0.0
		cooldown_overlay.offset_top = 0.0
		cooldown_overlay.offset_right = 91.0
		cooldown_overlay.offset_bottom = 0.0
		cooldown_overlay.visible = false
		button.add_child(cooldown_overlay)

		var cooldown_label: Label = Label.new()
		cooldown_label.name = "CooldownLabel"
		cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown_label.offset_left = 0.0
		cooldown_label.offset_top = 0.0
		cooldown_label.offset_right = 91.0
		cooldown_label.offset_bottom = 82.0
		cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cooldown_label.add_theme_font_size_override("font_size", 22)
		cooldown_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9, 0.9))
		cooldown_label.visible = false
		button.add_child(cooldown_label)

		card_bar.add_child(button)
		card_buttons[defender_id] = button
		card_cooldowns[defender_id] = 0.0
		card_cooldown_overlays[defender_id] = cooldown_overlay
		card_cooldown_labels[defender_id] = cooldown_label

# Muestra el contador de supervivencia en la parte derecha.
func setup_timer_label() -> void:
	timer_label = Label.new()
	timer_label.offset_left = 936.0
	timer_label.offset_top = 228.0
	timer_label.offset_right = 1124.0
	timer_label.offset_bottom = 252.0
	timer_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.62, 1.0))
	timer_label.add_theme_font_size_override("font_size", 15)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas_layer.add_child(timer_label)

func update_timer_label() -> void:
	if timer_label == null:
		return
	var seconds_left: int = max(int(ceil(survival_time)), 0)
	var minutes: int = int(seconds_left / 60)
	var seconds: int = seconds_left % 60
	timer_label.text = "Sobrevive: %02d:%02d" % [minutes, seconds]

# Estilos reutilizados por los paneles y botones de carta.
func make_panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style

func make_card_style(active: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.12, 0.075, 0.98) if not active else Color(0.30, 0.21, 0.10, 0.99)
	style.border_color = Color(0.52, 0.34, 0.14, 1.0) if not active else Color(1.0, 0.78, 0.28, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_top = 51
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_bottom = 3
	return style

func make_disabled_card_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = make_card_style(false)
	style.bg_color = Color(0.06, 0.06, 0.055, 0.95)
	style.border_color = Color(0.20, 0.18, 0.15, 0.85)
	return style

func _on_defender_card_pressed(defender_id: String) -> void:
	var cooldown_left: float = float(card_cooldowns.get(defender_id, 0.0))
	selected_defender_id = defender_id
	var data: Dictionary = DEFENDER_DATA[defender_id] as Dictionary
	var cost: int = int(data["cost"])
	if cooldown_left > 0.0:
		show_status("%s sigue recargando: %.1fs." % [data["name"], cooldown_left])
	elif courage < cost:
		show_status("Falta Coraje para %s. Necesitas %d." % [data["name"], cost])
	else:
		show_status("Seleccionaste %s. Ahora haz clic en una celda del campo." % data["name"])
	update_courage_ui()

# Refresca coraje, carta seleccionada y estado visual de cada carta.
func update_courage_ui() -> void:
	if courage_label != null:
		courage_label.text = "Coraje: %d" % courage
	if selected_label != null:
		var selected_data: Dictionary = DEFENDER_DATA[selected_defender_id] as Dictionary
		selected_label.text = "Seleccionado: %s" % selected_data["name"]

	for defender_id in card_buttons.keys():
		var button: Button = card_buttons[defender_id] as Button
		var data: Dictionary = DEFENDER_DATA[defender_id] as Dictionary
		var affordable: bool = courage >= int(data["cost"])
		var cooldown_left: float = float(card_cooldowns.get(defender_id, 0.0))
		var cooling_down: bool = cooldown_left > 0.0
		button.disabled = cooling_down or not affordable
		button.set_pressed_no_signal(defender_id == selected_defender_id)
		update_card_cooldown_visual(defender_id)
		if cooling_down:
			button.modulate = Color(0.55, 0.55, 0.55, 1.0)
		elif defender_id == selected_defender_id:
			button.modulate = Color(1.14, 1.06, 0.78, 1.0) if affordable else Color(0.9, 0.72, 0.62, 1.0)
		else:
			button.modulate = Color.WHITE if affordable else Color(0.52, 0.52, 0.52, 1.0)

func update_card_cooldowns(delta: float) -> void:
	var changed: bool = false
	for defender_id in card_cooldowns.keys():
		var cooldown_left: float = float(card_cooldowns[defender_id])
		if cooldown_left <= 0.0:
			continue
		card_cooldowns[defender_id] = max(cooldown_left - delta, 0.0)
		changed = true
	if changed:
		update_courage_ui()

func update_card_cooldown_visual(defender_id: String) -> void:
	var overlay: ColorRect = card_cooldown_overlays.get(defender_id, null) as ColorRect
	var label: Label = card_cooldown_labels.get(defender_id, null) as Label
	if overlay == null or label == null:
		return

	var data: Dictionary = DEFENDER_DATA[defender_id] as Dictionary
	var cooldown_duration: float = float(data["cooldown"])
	var cooldown_left: float = float(card_cooldowns.get(defender_id, 0.0))
	if cooldown_left <= 0.0 or cooldown_duration <= 0.0:
		overlay.visible = false
		label.visible = false
		return

	var ratio: float = clamp(cooldown_left / cooldown_duration, 0.0, 1.0)
	overlay.visible = true
	overlay.offset_top = 0.0
	overlay.offset_bottom = 82.0 * ratio
	label.visible = true
	label.text = "%d" % int(ceil(cooldown_left))

func add_courage(amount: int) -> void:
	courage = max(courage + amount, 0)
	update_courage_ui()

func on_enemy_defeated(courage_reward: int) -> void:
	add_courage(courage_reward)
	heal_defenders(12)
	show_status("Enemigo eliminado: +%d Coraje y defensores curados." % courage_reward)

# Pequeño bono de curación global cuando cae un enemigo.
func heal_defenders(amount: int) -> void:
	var defenders: Array[Node] = get_tree().get_nodes_in_group("defenders")
	for defender_node in defenders:
		if defender_node != null and is_instance_valid(defender_node) and defender_node.has_method("heal"):
			defender_node.call("heal", amount)

func show_status(message: String) -> void:
	if status_label != null:
		status_label.text = message

# Conversión mundo -> tablero. Si el click cae fuera de una fila/columna válida, devuelve (-1, -1).
func get_cell_from_world(world_position: Vector2) -> Vector2i:
	var lane_index: int = get_nearest_lane(world_position.y)
	if lane_index == -1:
		return Vector2i(-1, -1)

	var column: int = int(round((world_position.x - GRID_X_START) / GRID_COLUMN_SPACING))
	if column < 0 or column >= GRID_COLUMNS:
		return Vector2i(-1, -1)

	var column_center: float = GRID_X_START + column * GRID_COLUMN_SPACING
	if abs(world_position.x - column_center) > GRID_CELL_CLICK_WIDTH * 0.5:
		return Vector2i(-1, -1)

	return Vector2i(column, lane_index)

func get_nearest_lane(world_y: float) -> int:
	var nearest_lane: int = -1
	var nearest_distance: float = INF

	for i in range(LANE_Y.size()):
		var distance: float = absf(world_y - LANE_Y[i])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_lane = i

	if nearest_distance > GRID_CELL_CLICK_HEIGHT * 0.5:
		return -1

	return nearest_lane

# Instancia el defensor, cobra su costo y registra la celda como ocupada.
func place_defender(cell: Vector2i, defender_id: String) -> void:
	if not DEFENDER_SCENES.has(defender_id):
		return

	var data: Dictionary = DEFENDER_DATA[defender_id] as Dictionary
	var cost: int = int(data["cost"])
	var cooldown_left: float = float(card_cooldowns.get(defender_id, 0.0))
	if cooldown_left > 0.0:
		show_status("%s recarga en %.1fs." % [data["name"], cooldown_left])
		return

	if courage < cost:
		show_status("Falta Coraje para colocar %s. Necesitas %d." % [data["name"], cost])
		return

	var key: String = get_cell_key(cell)
	if occupied_cells.has(key):
		show_status("Esa celda ya tiene un defensor. Elige otra celda.")
		return

	var defender_scene: PackedScene = DEFENDER_SCENES[defender_id] as PackedScene
	var defender: Node2D = defender_scene.instantiate() as Node2D
	defender.position = Vector2(
		GRID_X_START + cell.x * GRID_COLUMN_SPACING,
		LANE_Y[cell.y] + DEFENDER_GROUND_OFFSET_Y
	)
	defender.scale = Vector2.ONE * CHARACTER_SCALE
	defender.set("lane_index", cell.y)
	defender.set("grid_cell", cell)
	defender.tree_exiting.connect(_on_defender_removed.bind(key))

	occupied_cells[key] = true
	unit_container.add_child(defender)
	add_courage(-cost)
	card_cooldowns[defender_id] = float(data["cooldown"])
	update_courage_ui()
	show_status("Colocaste %s. Puedes elegir otra carta o colocar otro." % data["name"])

func get_cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]

func _on_defender_removed(key: String) -> void:
	occupied_cells.erase(key)

func _on_game_over_line_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		start_game_over()

# Ganar es sobrevivir hasta que el contador llega a cero.
func start_victory() -> void:
	if is_game_over:
		return

	is_game_over = true
	for button in card_buttons.values():
		(button as Button).disabled = true
	enemy_spawner.call("stop_spawning")
	stop_all_gameplay_audio()
	set_gameplay_processing(false)
	if has_node("GameOverLayer/CenterBox/GameOverTitle"):
		$GameOverLayer/CenterBox/GameOverTitle.text = "VICTORIA"
		$GameOverLayer/CenterBox/GameOverTitle.add_theme_color_override("font_color", Color(0.95, 0.74, 0.22, 1.0))
	if has_node("GameOverLayer/CenterBox/GameOverMessage"):
		$GameOverLayer/CenterBox/GameOverMessage.text = "Sobreviviste dos minutos. El pueblo sigue en pie."
	game_over_layer.visible = true
	game_over_animation.play("fade_to_black")

# Perder ocurre cuando un enemigo cruza la línea izquierda.
func start_game_over() -> void:
	if is_game_over:
		return

	is_game_over = true
	for button in card_buttons.values():
		(button as Button).disabled = true
	enemy_spawner.call("stop_spawning")
	background_music.stop()
	stop_all_gameplay_audio()
	set_gameplay_processing(false)
	game_over_layer.visible = true
	game_over_animation.play("fade_to_black")

# Al terminar la partida se apagan sonidos y procesamiento para congelar el tablero.
func stop_all_gameplay_audio() -> void:
	var audio_nodes: Array[Node] = find_children("*", "AudioStreamPlayer", true, false)
	for audio_node in audio_nodes:
		var player: AudioStreamPlayer = audio_node as AudioStreamPlayer
		if player != null:
			player.stop()

func set_gameplay_processing(enabled: bool) -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var defenders: Array[Node] = get_tree().get_nodes_in_group("defenders")
	for enemy in enemies:
		enemy.set_process(enabled)
	for defender in defenders:
		defender.set_process(enabled)

func _on_retry_button_pressed() -> void:
	get_tree().reload_current_scene()

func _on_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")
