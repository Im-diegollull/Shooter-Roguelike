extends CanvasLayer

# --- Paleta retro-moderna ---
const COLOR_HP_FULL := Color("ff5470")
const COLOR_HP_EMPTY := Color("2a2f3d")
const COLOR_ACCENT := Color("5cd6c0")
const COLOR_PANEL_BG := Color(0.06, 0.07, 0.1, 0.85)

var _player: Player
var _pips: Array[Panel] = []
var _pip_row: HBoxContainer
var _game_over: Control
var _dead: bool = false

func _ready() -> void:
	_build_health_panel()
	_build_game_over()
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.health_changed.connect(_on_health_changed)
		_player.died.connect(_on_player_died)
		_on_health_changed(_player.current_health, _player.max_health)

func _unhandled_input(event: InputEvent) -> void:
	if not _dead or not (event is InputEventKey and event.pressed):
		return
	if event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
	elif event.physical_keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

# --- Construcción del HUD ---

func _build_health_panel() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	add_child(margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	margin.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var label := Label.new()
	label.text = "VITALIDAD"
	label.add_theme_color_override("font_color", COLOR_ACCENT)
	label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(label)

	_pip_row = HBoxContainer.new()
	_pip_row.add_theme_constant_override("separation", 6)
	vbox.add_child(_pip_row)

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL_BG
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb

func _pip_style(filled: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_HP_FULL if filled else COLOR_HP_EMPTY
	sb.set_corner_radius_all(6)
	if filled:
		sb.border_color = Color(1, 1, 1, 0.28)
		sb.set_border_width_all(1)
	return sb

func _rebuild_pips(count: int) -> void:
	for c in _pip_row.get_children():
		c.queue_free()
	_pips.clear()
	for i in count:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(24, 24)
		_pip_row.add_child(pip)
		_pips.append(pip)

func _on_health_changed(current: int, max_health: int) -> void:
	if _pips.size() != max_health:
		_rebuild_pips(max_health)
	for i in _pips.size():
		_pips[i].add_theme_stylebox_override("panel", _pip_style(i < current))

# --- Pantalla de muerte ---

func _build_game_over() -> void:
	_game_over = Control.new()
	_game_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_over.visible = false
	add_child(_game_over)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.03, 0.05, 0.72)
	_game_over.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over.add_child(center)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	center.add_child(vb)

	var title := Label.new()
	title.text = "HAS MUERTO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_HP_FULL)
	title.add_theme_font_size_override("font_size", 64)
	vb.add_child(title)

	var hint := Label.new()
	hint.text = "R  REINTENTAR      ESC  MENÚ"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", COLOR_ACCENT)
	hint.add_theme_font_size_override("font_size", 20)
	vb.add_child(hint)

func _on_player_died() -> void:
	_dead = true
	_game_over.visible = true
