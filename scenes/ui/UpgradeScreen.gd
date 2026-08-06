class_name UpgradeScreen
extends CanvasLayer

## Pantalla de mejora entre pisos (roguelike). Al bajar por el portal, el juego
## se pausa y ofrece 3 mejoras al azar; el jugador elige una (clic o teclas 1-3).
## Construida en código, con la estética neón del DialogBox/HUD.

signal chosen(upgrade_id: String)

const COLOR_ACCENT := Color("5cd6c0")
const COLOR_TITLE := Color("ffd166")
const COLOR_TEXT := Color(0.86, 0.9, 0.95)
const COLOR_DIM := Color(0.02, 0.03, 0.05, 0.78)
const COLOR_CARD_BG := Color(0.06, 0.08, 0.11, 1.0)

## Repertorio de mejoras (id, título, descripción). Se ofrecen 3 distintas al azar.
const UPGRADES: Array[Dictionary] = [
	{"id": "fire_rate", "title": "CADENCIA", "desc": "+20% de velocidad de disparo"},
	{"id": "damage", "title": "PERFORACIÓN", "desc": "+1 de daño por bala"},
	{"id": "max_health", "title": "BLINDAJE", "desc": "+1 de vida máxima (y la recupera)"},
	{"id": "move_speed", "title": "REFLEJOS", "desc": "+12% de velocidad de movimiento"},
	{"id": "heal", "title": "REPARACIÓN", "desc": "Recupera 2 de vida"},
]

var _card_ids: Array[String] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	# Debe funcionar con el árbol en pausa (los hijos heredan el modo).
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12  # por encima del diálogo (10) y de CORO (8)
	_rng.randomize()

## Abre la pantalla para el piso indicado y elige 3 mejoras al azar.
func open(floor_number: int) -> void:
	_pick_three()
	_build(floor_number)

func _pick_three() -> void:
	var pool := UPGRADES.duplicate()
	pool.shuffle()
	_card_ids.clear()
	for i in mini(3, pool.size()):
		_card_ids.append(pool[i]["id"])

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var idx := -1
	match event.keycode:
		KEY_1, KEY_KP_1: idx = 0
		KEY_2, KEY_KP_2: idx = 1
		KEY_3, KEY_KP_3: idx = 2
	if idx >= 0 and idx < _card_ids.size():
		get_viewport().set_input_as_handled()
		_pick(_card_ids[idx])

func _pick(id: String) -> void:
	chosen.emit(id)
	queue_free()

# --- Construcción de la UI ---

func _build(floor_number: int) -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = COLOR_DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # bloquea clics al mundo
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	var header := Label.new()
	header.text = "DESCENSO AL PISO %d" % floor_number
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", COLOR_ACCENT)
	header.add_theme_font_size_override("font_size", 26)
	col.add_child(header)

	var sub := Label.new()
	sub.text = "Elige una mejora"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", COLOR_TEXT)
	sub.add_theme_font_size_override("font_size", 15)
	col.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	col.add_child(spacer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)

	for i in _card_ids.size():
		row.add_child(_make_card(i, _find(_card_ids[i])))

	var hint := Label.new()
	hint.text = "Clic  ·  o teclas  1 · 2 · 3"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.45, 0.6, 0.62))
	hint.add_theme_font_size_override("font_size", 13)
	col.add_child(hint)

func _make_card(index: int, data: Dictionary) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(230, 180)
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_stylebox_override("normal", _card_style(false))
	card.add_theme_stylebox_override("hover", _card_style(true))
	card.add_theme_stylebox_override("pressed", _card_style(true))
	card.pressed.connect(_pick.bind(data["id"]))

	# El contenido va dentro del botón; ignora el ratón para que el clic sea del botón.
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 16
	vb.offset_right = -16
	vb.offset_top = 16
	vb.offset_bottom = -16
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	card.add_child(vb)

	var num := Label.new()
	num.text = "%d" % (index + 1)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_theme_color_override("font_color", COLOR_ACCENT)
	num.add_theme_font_size_override("font_size", 15)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(num)

	var title := Label.new()
	title.text = data["title"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", COLOR_TITLE)
	title.add_theme_font_size_override("font_size", 21)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(title)

	var desc := Label.new()
	desc.text = data["desc"]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", COLOR_TEXT)
	desc.add_theme_font_size_override("font_size", 14)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(desc)

	return card

func _find(id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return {"id": id, "title": id, "desc": ""}

func _card_style(highlight: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.13, 0.17, 1.0) if highlight else COLOR_CARD_BG
	sb.border_color = COLOR_TITLE if highlight else COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb
