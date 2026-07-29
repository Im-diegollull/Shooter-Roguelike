class_name DialogBox
extends CanvasLayer

## Caja de diálogo retro-moderna, construida en código (como el HUD).
## Muestra la conversación con un NPC y recoge el texto que escribe el jugador.
## No sabe nada de la API: emite `player_sent` y el NPC decide qué responder.

signal closed
signal player_sent(message: String)

const COLOR_ACCENT := Color("5cd6c0")
const COLOR_NPC := Color("ffd166")
const COLOR_PLAYER := Color("8ecae6")
const COLOR_CORO := Color("7fe0d4")
const COLOR_PANEL_BG := Color(0.05, 0.06, 0.09, 0.97)
const COLOR_DIM := Color(0.02, 0.02, 0.04, 0.55)

const HINT := "ENTER  enviar        ESC  salir"

var _title: Label
var _log: RichTextLabel
var _input: LineEdit
var _status: Label
var _npc_name: String = ""
var _thinking: bool = false

func _ready() -> void:
	# Debe seguir vivo aunque el árbol esté en pausa durante la conversación.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()

# --- API pública (la usa el NPC) ---

func open(npc_name: String, greeting: String) -> void:
	_npc_name = npc_name
	_title.text = npc_name.to_upper()
	if not greeting.is_empty():
		add_npc_line(greeting)
	_input.grab_focus()

func add_player_line(text: String) -> void:
	_append("Tú:", COLOR_PLAYER, text)

## `reactivate=false` deja el input bloqueado (p.ej. si CORO va a pisar la línea).
func add_npc_line(text: String, reactivate: bool = true) -> void:
	_append("%s:" % _npc_name, COLOR_NPC, text)
	if reactivate:
		_reactivate()

## CORO pisa el diálogo con un aviso de sistema (interrupción, ver DialogueBus).
func add_coro_line(text: String) -> void:
	_append("CORO:", COLOR_CORO, text)
	_reactivate()

func _reactivate() -> void:
	_thinking = false
	_status.text = HINT
	_input.editable = true
	_input.grab_focus()

func show_thinking() -> void:
	_thinking = true
	_input.editable = false
	_status.text = "%s está pensando…" % _npc_name

func close() -> void:
	closed.emit()
	queue_free()

# --- Entrada ---

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func _on_submit(text: String) -> void:
	if _thinking:
		return
	var msg := text.strip_edges()
	if msg.is_empty():
		return
	_input.clear()
	add_player_line(msg)
	player_sent.emit(msg)

# --- Construcción de la UI ---

func _append(speaker: String, color: Color, text: String) -> void:
	_log.append_text("[color=#%s][b]%s[/b][/color] %s\n\n" % [color.to_html(false), speaker, text])

func _build() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = COLOR_DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # bloquea clics al mundo
	add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_top = -300
	panel.offset_bottom = -28
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	_title = Label.new()
	_title.text = "NPC"
	_title.add_theme_color_override("font_color", COLOR_NPC)
	_title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_title)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.fit_content = false
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_color_override("default_color", Color(0.86, 0.9, 0.95))
	_log.add_theme_font_size_override("normal_font_size", 17)
	vbox.add_child(_log)

	_input = LineEdit.new()
	_input.placeholder_text = "Escribe tu mensaje…"
	_input.add_theme_stylebox_override("normal", _input_style())
	_input.add_theme_stylebox_override("focus", _input_style(true))
	_input.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98))
	_input.add_theme_color_override("caret_color", COLOR_ACCENT)
	_input.text_submitted.connect(_on_submit)
	vbox.add_child(_input)

	_status = Label.new()
	_status.text = HINT
	_status.add_theme_color_override("font_color", COLOR_ACCENT)
	_status.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_status)

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL_BG
	sb.border_color = COLOR_ACCENT
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb

func _input_style(focused: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.11, 0.15, 1.0)
	sb.border_color = COLOR_ACCENT if focused else Color(0.3, 0.4, 0.45)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb
