class_name EndingScreen
extends CanvasLayer

## Final de la run (condición de victoria): al completar el último piso y tocar el
## portal, llegas al Núcleo. La consola de la Voz 9 dice tu nombre y se te ofrecen
## los tres finales de EL CORO (ver lore §5). Construida en código, estética neón.

const COLOR_ACCENT := Color("5cd6c0")
const COLOR_TITLE := Color("ffd166")
const COLOR_TEXT := Color(0.88, 0.92, 0.96)
const COLOR_SOFT := Color(0.6, 0.7, 0.72)
const COLOR_DIM := Color(0.01, 0.02, 0.03, 0.92)
const COLOR_CARD_BG := Color(0.06, 0.08, 0.11, 1.0)

## Atención mínima a Cuervo para que vuelva y muera cubriéndote (si no, se queda
## con su permiso). Su lealtad se mide con lo que ya hay en RunMemory.
const CUERVO_LOYAL_THRESHOLD := 3

## Los tres finales (id, título, resumen para la carta, texto final completo).
const ENDINGS: Array[Dictionary] = [
	{
		"id": "sacarla",
		"title": "SACARLA",
		"card": "Extraes la Voz 9 y subes con ella.",
		"text": "Extraes la Voz 9. Emilia sube contigo: respira, camina, tiene sus ojos.\n"
			+ "Pero vuelve en blanco, sin los tres años, sin ti.\n"
			+ "La tienes de vuelta y no la tienes.",
	},
	{
		"id": "soltarlas",
		"title": "SOLTARLAS",
		"card": "Apagas CORO. Las nueve voces se liberan.",
		"text": "Apagas CORO entero. Las nueve voces se sueltan y se apagan a la vez,\n"
			+ "como una sola. El Pozo se queda mudo. Emilia se apaga con ellas.\n"
			+ "Nadie más volverá a firmar.",
	},
	{
		"id": "firmar",
		"title": "FIRMAR",
		"card": "Tomas el trato: tu voz por la suya.",
		"text": "Tomas el trato de la Curadora: tu voz por la de ella. Emilia sube sin mirar atrás.\n"
			+ "La última escena la juegas desde dentro del sistema,\n"
			+ "diciéndole a un desconocido nuevo: cuidado a tu izquierda.",
	},
]

enum Phase { CHOICE, RESULT }

var _phase: int = Phase.CHOICE
var _root: Control
var _choice_ids: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # funciona con el árbol en pausa
	layer = 13  # por encima de todo

## Abre el final (fase de elección).
func open() -> void:
	_build_choice()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _phase == Phase.CHOICE:
		var idx := -1
		match event.keycode:
			KEY_1, KEY_KP_1: idx = 0
			KEY_2, KEY_KP_2: idx = 1
			KEY_3, KEY_KP_3: idx = 2
		if idx >= 0 and idx < _choice_ids.size():
			get_viewport().set_input_as_handled()
			_choose(_choice_ids[idx])
	else:
		if event.physical_keycode == KEY_R:
			get_viewport().set_input_as_handled()
			_restart()
		elif event.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_to_menu()

# --- Fase 1: llegada al Núcleo + elección ---

func _build_choice() -> void:
	_phase = Phase.CHOICE
	var col := _fresh_root()

	_add_label(col, "EL NÚCLEO", 30, COLOR_ACCENT)
	_add_label(col, _arrival_text(), 16, COLOR_TEXT, 720)
	_add_spacer(col, 10)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)

	_choice_ids.clear()
	for i in ENDINGS.size():
		var e: Dictionary = ENDINGS[i]
		_choice_ids.append(e["id"])
		row.add_child(_make_card(i, e))

	_add_label(col, "Elige un final    ·    1 · 2 · 3", 13, COLOR_SOFT)

## Texto de llegada, con la rama Cuervo según la atención que se le prestó.
func _arrival_text() -> String:
	var base := "Llegaste al fondo. La consola de la Voz 9 parpadea y, por un segundo,\n" \
		+ "dice tu nombre — y no sabe por qué."
	var cuervo: String
	if RunMemory.cuervo_attention >= CUERVO_LOYAL_THRESHOLD:
		cuervo = "\n\nCuervo volvió con la Llave. Cae cubriéndote la espalda, sin chistes esta vez."
	elif RunMemory.cuervo_attention > 0:
		cuervo = "\n\nDe Cuervo no queda ni la radio. Se llevó su permiso y su silencio."
	else:
		cuervo = "\n\nBajaste solo el último tramo. Nadie te levantó."
	return base + cuervo

# --- Fase 2: resultado del final elegido ---

func _choose(id: String) -> void:
	RunMemory.add_event("Final de la run: %s" % id)
	_phase = Phase.RESULT
	var data := _find(id)
	var col := _fresh_root()

	_add_label(col, data["title"], 30, COLOR_TITLE)
	_add_spacer(col, 6)
	_add_label(col, data["text"], 18, COLOR_TEXT, 760)
	_add_spacer(col, 8)
	_add_label(col, "Piso alcanzado: %d    ·    Bajas: %d"
		% [RunMemory.floors_cleared + 1, RunMemory.player_kills], 14, COLOR_SOFT)
	_add_spacer(col, 14)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	row.add_child(_make_button("REINICIAR   (R)", _restart))
	row.add_child(_make_button("MENÚ   (Esc)", _to_menu))

func _restart() -> void:
	RunMemory.reset()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _to_menu() -> void:
	RunMemory.reset()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

# --- Utilidades de construcción ---

## Reinicia el contenido de la pantalla (dim + columna centrada) y la devuelve.
func _fresh_root() -> VBoxContainer:
	if _root != null:
		_root.queue_free()
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = COLOR_DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_root = dim

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	return col

func _add_label(parent: Node, text: String, size: int, color: Color, max_w: int = 0) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	if max_w > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(max_w, 0)
	parent.add_child(l)

func _add_spacer(parent: Node, h: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)

func _make_card(index: int, data: Dictionary) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(240, 170)
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_stylebox_override("normal", _card_style(false))
	card.add_theme_stylebox_override("hover", _card_style(true))
	card.add_theme_stylebox_override("pressed", _card_style(true))
	card.pressed.connect(_choose.bind(data["id"]))

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

	_add_label(vb, "%d" % (index + 1), 15, COLOR_ACCENT)
	_add_label(vb, data["title"], 22, COLOR_TITLE)
	_add_label(vb, data["card"], 14, COLOR_TEXT, 200)
	return card

func _make_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(190, 0)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_color_override("font_hover_color", COLOR_TITLE)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", _card_style(false))
	b.add_theme_stylebox_override("hover", _card_style(true))
	b.add_theme_stylebox_override("pressed", _card_style(true))
	b.pressed.connect(on_press)
	return b

func _find(id: String) -> Dictionary:
	for e in ENDINGS:
		if e["id"] == id:
			return e
	return ENDINGS[0]

func _card_style(highlight: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.13, 0.17, 1.0) if highlight else COLOR_CARD_BG
	sb.border_color = COLOR_TITLE if highlight else COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb
