class_name DefenderCardUI
extends Node

signal defender_selected(defender_id: String)

var card_buttons: Dictionary = {}
var cooldown_overlays: Dictionary = {}
var cooldown_labels: Dictionary = {}
var courage_label: Label
var selected_label: Label
var description_label: Label
var timer_label: Label
var card_bar: GridContainer
var tower_toggle: Button

func build(parent: CanvasLayer, defender_order: Array[String], defender_data: Dictionary) -> void:
	_create_timer(parent)
	_create_info_panel(parent)
	_create_cards(parent, defender_order, defender_data)
	_create_tower_toggle(parent)

func refresh(courage: int, selected_defender_id: String, card_cooldowns: Dictionary, defender_data: Dictionary) -> void:
	courage_label.text = "CORAJE  %d" % courage
	var selected_data: Dictionary = defender_data[selected_defender_id] as Dictionary
	selected_label.text = "Seleccionado: %s" % selected_data["name"]
	description_label.text = str(selected_data.get("description", "Listo para defender el istmo."))

	for defender_id in card_buttons:
		var button: Button = card_buttons[defender_id] as Button
		var data: Dictionary = defender_data[defender_id] as Dictionary
		var cooldown_left: float = float(card_cooldowns.get(defender_id, 0.0))
		var affordable: bool = courage >= int(data["cost"])
		var cooling_down: bool = cooldown_left > 0.0
		button.disabled = cooling_down or not affordable
		button.set_pressed_no_signal(defender_id == selected_defender_id)
		_update_cooldown_visual(defender_id, cooldown_left, float(data["cooldown"]))
		if cooling_down:
			button.modulate = Color(0.55, 0.55, 0.55, 1.0)
		elif defender_id == selected_defender_id:
			button.modulate = Color(1.14, 1.06, 0.78, 1.0) if affordable else Color(0.9, 0.72, 0.62, 1.0)
		else:
			button.modulate = Color.WHITE if affordable else Color(0.52, 0.52, 0.52, 1.0)

func update_timer(seconds_remaining: float) -> void:
	var seconds_left: int = max(int(ceil(seconds_remaining)), 0)
	timer_label.text = "Sobrevive: %02d:%02d" % [int(seconds_left / 60), seconds_left % 60]

func disable_all() -> void:
	for button in card_buttons.values():
		(button as Button).disabled = true

func _create_timer(parent: CanvasLayer) -> void:
	timer_label = Label.new()
	timer_label.offset_left = 912.0
	timer_label.offset_top = 28.0
	timer_label.offset_right = 1112.0
	timer_label.offset_bottom = 52.0
	timer_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.62, 1.0))
	timer_label.add_theme_font_size_override("font_size", 15)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(timer_label)

func _create_info_panel(parent: CanvasLayer) -> void:
	var info_panel := PanelContainer.new()
	info_panel.name = "CouragePanel"
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	info_panel.position = Vector2(22.0, 20.0)
	info_panel.size = Vector2(112.0, 28.0)
	info_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.035, 0.035, 0.90), Color(0.75, 0.52, 0.18, 0.95)))
	parent.add_child(info_panel)

	courage_label = Label.new()
	courage_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32, 1.0))
	courage_label.add_theme_font_size_override("font_size", 13)
	courage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	courage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_panel.add_child(courage_label)

	selected_label = Label.new()
	selected_label.position = Vector2(22.0, 110.0)
	selected_label.size = Vector2(200.0, 24.0)
	selected_label.add_theme_color_override("font_color", Color(0.88, 0.82, 0.68, 1.0))
	selected_label.add_theme_font_size_override("font_size", 13)
	parent.add_child(selected_label)
	selected_label.visible = false
	description_label = Label.new()
	description_label.position = Vector2(22.0, 135.0)
	description_label.size = Vector2(200.0, 48.0)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 11)
	description_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.65, 1.0))
	parent.add_child(description_label)
	description_label.visible = false

func _create_cards(parent: CanvasLayer, defender_order: Array[String], defender_data: Dictionary) -> void:
	card_bar = GridContainer.new()
	card_bar.name = "DefenderCards"
	card_bar.position = Vector2(22.0, 96.0)
	card_bar.size = Vector2(76.0, 336.0)
	card_bar.columns = 1
	card_bar.add_theme_constant_override("v_separation", 3)
	card_bar.visible = false
	parent.add_child(card_bar)

	for defender_id in defender_order:
		var data: Dictionary = defender_data[defender_id] as Dictionary
		var button := Button.new()
		button.name = "%sCard" % defender_id.capitalize()
		button.custom_minimum_size = Vector2(76, 52)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.toggle_mode = true
		button.text = ""
		button.add_theme_color_override("font_color", Color(0.96, 0.88, 0.68, 1.0))
		button.add_theme_color_override("font_disabled_color", Color(0.54, 0.54, 0.54, 1.0))
		button.add_theme_stylebox_override("normal", _make_card_style(false))
		button.add_theme_stylebox_override("hover", _make_card_style(true))
		button.add_theme_stylebox_override("pressed", _make_card_style(true))
		button.add_theme_stylebox_override("disabled", _make_disabled_card_style())
		button.pressed.connect(_emit_selection.bind(defender_id))

		var icon_rect := TextureRect.new()
		var source_texture := load(data["icon"]) as Texture2D
		var portrait := AtlasTexture.new()
		portrait.atlas = source_texture
		var source_size := source_texture.get_size()
		portrait.region = Rect2(source_size.x * 0.15, 0.0, source_size.x * 0.70, source_size.y * 0.62)
		icon_rect.texture = portrait
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		icon_rect.position = Vector2(4.0, 2.0)
		icon_rect.size = Vector2(48.0, 47.0)
		button.add_child(icon_rect)

		var price_label := Label.new()
		price_label.text = "%d C" % int(data["cost"])
		price_label.position = Vector2(45.0, 28.0)
		price_label.size = Vector2(29.0, 20.0)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price_label.add_theme_font_size_override("font_size", 10)
		price_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.32, 1.0))
		button.add_child(price_label)

		var overlay := ColorRect.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.color = Color(0.02, 0.025, 0.025, 0.72)
		overlay.size = Vector2(76.0, 0.0)
		overlay.visible = false
		button.add_child(overlay)

		var cooldown_label := Label.new()
		cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown_label.size = Vector2(76.0, 52.0)
		cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cooldown_label.add_theme_font_size_override("font_size", 22)
		cooldown_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9, 0.9))
		cooldown_label.visible = false
		button.add_child(cooldown_label)

		card_bar.add_child(button)
		card_buttons[defender_id] = button
		cooldown_overlays[defender_id] = overlay
		cooldown_labels[defender_id] = cooldown_label

func _update_cooldown_visual(defender_id: String, cooldown_left: float, cooldown_duration: float) -> void:
	var overlay: ColorRect = cooldown_overlays[defender_id] as ColorRect
	var label: Label = cooldown_labels[defender_id] as Label
	var cooling_down := cooldown_left > 0.0 and cooldown_duration > 0.0
	overlay.visible = cooling_down
	label.visible = cooling_down
	if cooling_down:
		overlay.size.y = 52.0 * clamp(cooldown_left / cooldown_duration, 0.0, 1.0)
		label.text = "%d" % int(ceil(cooldown_left))

func _create_tower_toggle(parent: CanvasLayer) -> void:
	tower_toggle = Button.new()
	tower_toggle.text = "TORRES v"
	tower_toggle.position = Vector2(22.0, 54.0)
	tower_toggle.size = Vector2(76.0, 34.0)
	tower_toggle.add_theme_font_size_override("font_size", 11)
	tower_toggle.pressed.connect(_toggle_tower_column)
	parent.add_child(tower_toggle)

func _toggle_tower_column() -> void:
	card_bar.visible = not card_bar.visible
	tower_toggle.text = "TORRES ^" if card_bar.visible else "TORRES v"

func _emit_selection(defender_id: String) -> void:
	defender_selected.emit(defender_id)

func _make_panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

func _make_card_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.12, 0.075, 0.98) if not active else Color(0.30, 0.21, 0.10, 0.99)
	style.border_color = Color(0.52, 0.34, 0.14, 1.0) if not active else Color(1.0, 0.78, 0.28, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_top = 2
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_bottom = 2
	return style

func _make_disabled_card_style() -> StyleBoxFlat:
	var style := _make_card_style(false)
	style.bg_color = Color(0.06, 0.06, 0.055, 0.95)
	style.border_color = Color(0.20, 0.18, 0.15, 0.85)
	return style
