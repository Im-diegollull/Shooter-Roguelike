extends Node

## CORO — el sistema de guía del Pozo (autoload). La Voz 9 (Emilia) le habla al
## jugador durante la partida con tono de manual de seguridad: avisa, felicita,
## corrige. Amable y seca. A veces se le escapa algo que no es "de sistema": son
## las semillas de quién es ella (ver lore EL CORO).
##
## No bloquea el juego: muestra una banda superior que aparece y se desvanece.
## Se apaga solo cuando no hay jugador en escena (menús) y durante las pausas.

const COLOR_CORO := Color("7fe0d4")
const COLOR_TAG := Color("4a8f86")
const SHOW_TIME := 3.6
const FADE := 0.45
## Rango de espera (segundos) entre líneas ambientales espontáneas.
const IDLE_MIN := 15.0
const IDLE_MAX := 28.0
## Probabilidad de que CORO comente una baja (no habla en cada muerte).
const KILL_COMMENT_CHANCE := 0.28

# --- Repertorio (tono manual de seguridad; algunas líneas siembran el lore) ---

const LINES_WELCOME: Array[String] = [
	"Bienvenido al turno de trabajo. Manténgase en las zonas iluminadas.",
	"Descenso registrado. Su seguridad es prioridad de Caldera.",
	"Nuevo sector operativo. El Pozo agradece su esfuerzo.",
]

const LINES_KILL: Array[String] = [
	"Amenaza neutralizada. Buen trabajo.",
	"Registro de bajas actualizado. Eficiencia aceptable.",
	"Cuidado a tu izquierda.",
	"El sector se despeja. Continúe.",
]

const LINES_LOW_HEALTH: Array[String] = [
	"Signos vitales en descenso. Busque un punto seguro.",
	"Advertencia: integridad física comprometida.",
	"Cuídate. …Disculpe. Protocolo: cuídese, operario.",
]

const LINES_AMBIENT: Array[String] = [
	"Los ascensores siguen operativos gracias a nueve voluntarios.",
	"Gracias por su trabajo. El pago se procesa al finalizar. Siempre.",
	"Sector estable. Continúe descendiendo.",
	"Si escucha una voz que recuerda su nombre, repórtela. Es un fallo.",
	"Caldera le desea una jornada productiva.",
]

var _layer: CanvasLayer
var _panel: PanelContainer
var _label: Label
var _queue: Array[String] = []
var _showing: bool = false
var _last_line: String = ""
var _idle_time: float = 0.0
var _idle_next: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_build()
	_reset_idle()
	RunMemory.kill_registered.connect(_on_kill)

func _process(delta: float) -> void:
	# Líneas ambientales: solo si hay jugador en escena y no hay nada mostrándose.
	if _showing or not _queue.is_empty():
		return
	if get_tree().get_first_node_in_group("player") == null:
		return
	_idle_time += delta
	if _idle_time >= _idle_next:
		say(_pick(LINES_AMBIENT))
		_reset_idle()

# --- API pública (la llaman el generador, el player, etc.) ---

## Llamar al entrar a un piso nuevo.
func announce_floor() -> void:
	_queue.clear()  # una llegada nueva pisa avisos viejos
	say(_pick(LINES_WELCOME))
	_reset_idle()

## Avisa cuando la vida del jugador queda crítica (1 segmento o ratio bajo).
func on_player_hit(current: int, maximum: int) -> void:
	if current <= 0:
		return
	if current == 1 or float(current) / maxf(maximum, 1) <= 0.34:
		say(_pick(LINES_LOW_HEALTH))
		_reset_idle()

## Encola una línea de CORO (la usan las categorías y se puede llamar directo).
func say(text: String) -> void:
	if text.is_empty():
		return
	_queue.append(text)
	if not _showing:
		_play_next()

# --- Interno ---

func _on_kill(_total: int) -> void:
	if _rng.randf() <= KILL_COMMENT_CHANCE:
		say(_pick(LINES_KILL))
		_reset_idle()

func _reset_idle() -> void:
	_idle_time = 0.0
	_idle_next = _rng.randf_range(IDLE_MIN, IDLE_MAX)

## Elige una línea evitando repetir la anterior inmediata.
func _pick(pool: Array[String]) -> String:
	if pool.size() == 1:
		return pool[0]
	var line := pool[_rng.randi() % pool.size()]
	var guard := 0
	while line == _last_line and guard < 6:
		line = pool[_rng.randi() % pool.size()]
		guard += 1
	_last_line = line
	return line

func _play_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	_label.text = _queue.pop_front()
	_panel.modulate.a = 0.0
	_panel.visible = true
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, FADE)
	tw.tween_interval(SHOW_TIME)
	tw.tween_property(_panel, "modulate:a", 0.0, FADE)
	tw.tween_callback(_play_next)

# --- UI (banda superior, construida en código como el HUD y el DialogBox) ---

func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 8  # bajo el DialogBox (10), sobre el HUD
	add_child(_layer)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.offset_top = 22
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_panel.add_child(row)

	var tag := Label.new()
	tag.text = "◗ CORO"
	tag.add_theme_color_override("font_color", COLOR_TAG)
	tag.add_theme_font_size_override("font_size", 14)
	row.add_child(tag)

	_label = Label.new()
	_label.add_theme_color_override("font_color", COLOR_CORO)
	_label.add_theme_font_size_override("font_size", 16)
	row.add_child(_label)

func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.08, 0.9)
	sb.border_color = COLOR_TAG
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb
