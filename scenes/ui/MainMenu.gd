extends Control

# --- Paleta retro-moderna (coherente con el HUD) ---
const COLOR_TITLE := Color("5cd6c0")
const COLOR_ACCENT := Color("ff5470")
const COLOR_TEXT := Color("cdd3e0")
const COLOR_BTN_BG := Color(0.09, 0.1, 0.14, 0.92)
const COLOR_BG := Color("14161e")

const GRID_CELL := 48.0
const GRID_LINE := Color(0.36, 0.84, 0.75, 0.06)

const MAIN_SCENE := "res://scenes/world/Main.tscn"

var _view: Vector2

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_view = get_viewport_rect().size
	_build_ui()

func _draw() -> void:
	# Rejilla de fondo tipo Tron, igual que en el juego.
	draw_rect(Rect2(Vector2.ZERO, _view), COLOR_BG)
	var x: float = 0.0
	while x <= _view.x:
		draw_line(Vector2(x, 0.0), Vector2(x, _view.y), GRID_LINE, 1.0)
		x += GRID_CELL
	var y: float = 0.0
	while y <= _view.y:
		draw_line(Vector2(0.0, y), Vector2(_view.x, y), GRID_LINE, 1.0)
		y += GRID_CELL

func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)

	var title := Label.new()
	title.text = "SHOOTER ROGUELIKE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_TITLE)
	title.add_theme_font_size_override("font_size", 56)
	vb.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "NPCS QUE PIENSAN · CADA RUN ES DISTINTA"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", COLOR_ACCENT)
	subtitle.add_theme_font_size_override("font_size", 16)
	vb.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vb.add_child(spacer)

	vb.add_child(_make_button("JUGAR", _on_play))
	vb.add_child(_make_button("SALIR", _on_quit))

func _make_button(text: String, handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 56)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", COLOR_TITLE)
	btn.add_theme_color_override("font_pressed_color", COLOR_TITLE)
	btn.add_theme_stylebox_override("normal", _btn_style(COLOR_BTN_BG, COLOR_TITLE, 2))
	btn.add_theme_stylebox_override("hover", _btn_style(Color(0.12, 0.16, 0.2, 0.95), COLOR_TITLE, 2))
	btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.08, 0.1, 0.13, 1.0), COLOR_ACCENT, 2))
	btn.add_theme_stylebox_override("focus", _btn_style(Color(0, 0, 0, 0), COLOR_TITLE, 2))
	btn.pressed.connect(handler)
	return btn

func _btn_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(8)
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func _on_play() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)

func _on_quit() -> void:
	get_tree().quit()
