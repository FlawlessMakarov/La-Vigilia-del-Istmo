extends Control

var level_panel: PanelContainer

func _ready() -> void:
	$MenuPanel/Buttons/PlayButton.grab_focus()

func _on_play_button_pressed() -> void:
	if level_panel == null:
		build_level_selector()
	level_panel.visible = true
	$MenuPanel.visible = false

func build_level_selector() -> void:
	level_panel = PanelContainer.new()
	level_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	level_panel.position = Vector2(-430, -235)
	level_panel.size = Vector2(860, 470)
	level_panel.add_theme_stylebox_override("panel", make_panel_style())
	add_child(level_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	level_panel.add_child(layout)
	var title := Label.new()
	title.text = "ELIGE TU VIGILIA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	layout.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Pasa el mouse sobre una noche para iluminarla"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	layout.add_child(subtitle)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 18)
	layout.add_child(cards)
	for level in range(1, 4):
		cards.add_child(make_level_card(level))
	var back := Button.new()
	back.text = "VOLVER"
	back.custom_minimum_size = Vector2(180, 42)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(show_main_menu)
	layout.add_child(back)

func make_level_card(level: int) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(230, 250)
	card.text = "NOCHE %d\n\n%s" % [level, "DEFENSA DEL ISTMO" if level == 1 else "PRÓXIMAMENTE"]
	card.add_theme_font_size_override("font_size", 20)
	card.add_theme_color_override("font_color", Color(0.98, 0.88, 0.63))
	card.add_theme_stylebox_override("normal", make_level_style(Color(0.10, 0.12, 0.13, 0.96), Color(0.43, 0.29, 0.12)))
	card.add_theme_stylebox_override("hover", make_level_style(Color(0.34, 0.23, 0.08, 0.99), Color(1.0, 0.78, 0.24)))
	card.add_theme_stylebox_override("pressed", make_level_style(Color(0.46, 0.31, 0.10, 1.0), Color(1.0, 0.9, 0.45)))
	if level == 1:
		card.pressed.connect(start_level)
	else:
		card.disabled = true
	return card

func start_level() -> void:
	get_tree().change_scene_to_file("res://Scenes/Game/game.tscn")

func show_main_menu() -> void:
	level_panel.visible = false
	$MenuPanel.visible = true

func make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.025, 0.035, 0.94)
	style.border_color = Color(0.82, 0.58, 0.20, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	return style

func make_level_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 8
	return style

func _on_exit_button_pressed() -> void:
	get_tree().quit()
