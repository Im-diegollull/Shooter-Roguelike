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

# --- Función jugable: radar de amenazas + guía a la salida ---

## Cada cuánto (segundos) CORO revisa el entorno del jugador. No hace falta cada
## frame: con esto basta para avisar a tiempo sin coste.
const SCAN_INTERVAL := 0.3
## Un enemigo dentro de este radio del jugador se considera una amenaza cercana.
const THREAT_RADIUS := 340.0
## Solo se "olvida" un enemigo (y podrá volver a avisar) al salir de este radio
## mayor: evita que un enemigo que oscila en el borde avise una y otra vez.
const THREAT_FORGET_RADIUS := 520.0
## Mínimo entre dos avisos de amenaza seguidos (no spamear en un enjambre).
const THREAT_GAP := 2.6
## Semiángulo (radianes) del cono de puntería del jugador. Solo se avisa de
## enemigos FUERA de ese cono: los que ya estás mirando no necesitan aviso.
const FRONT_HALF_ANGLE := 1.0  # ~57°
## Más allá de este ángulo respecto a tu puntería, el enemigo está "a tu espalda".
const BEHIND_ANGLE := 2.35  # ~135°

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

## Aviso de amenaza. %s se sustituye por la dirección ("a tu izquierda", etc.).
const LINES_THREAT: Array[String] = [
	"Cuidado, %s.",
	"Contacto %s. Muévase.",
	"Amenaza %s, operario.",
	"Atención: hostil %s.",
]

## Guía al portal de descenso cuando el sector queda limpio. %s = dirección.
const LINES_EXIT: Array[String] = [
	"Sector despejado. El descenso está %s.",
	"Ruta libre. La bajada queda %s. Buen trabajo.",
	"Sin hostiles. Portal de descenso %s.",
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
var _tween: Tween = null

# Estado del radar / guía.
var _scan_time: float = 0.0
var _threat_gap: float = 0.0
## Enemigos ya avisados (instance_id → true) hasta que se alejen o mueran.
var _warned: Dictionary = {}
## Si en este piso llegó a haber enemigos (para no "despejar" un piso vacío).
var _saw_enemies: bool = false
## Si ya se guio al portal en este piso (una sola vez por piso).
var _exit_announced: bool = false

func _ready() -> void:
	_rng.randomize()
	_build()
	_reset_idle()
	RunMemory.kill_registered.connect(_on_kill)

func _process(delta: float) -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	# Radar de amenazas + guía a la salida (función jugable): en tiempo real,
	# pero sin escanear cada frame.
	_threat_gap = maxf(_threat_gap - delta, 0.0)
	_scan_time += delta
	if _scan_time >= SCAN_INTERVAL:
		_scan_time = 0.0
		_scan_threats(player)
		_check_sector_clear(player)

	# Líneas ambientales: solo si no hay nada mostrándose ni en cola.
	if _showing or not _queue.is_empty():
		return
	_idle_time += delta
	if _idle_time >= _idle_next:
		say(_pick(LINES_AMBIENT))
		_reset_idle()

# --- Radar de amenazas ---

## Busca enemigos cercanos FUERA del cono de puntería del jugador y avisa de su
## dirección. Cada enemigo avisa una sola vez hasta que se aleja o muere.
func _scan_threats(player: Node2D) -> void:
	var aim := Vector2.from_angle(player.global_rotation)  # look_at apunta el +x
	var nearest: Node2D = null
	var nearest_d := THREAT_RADIUS
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node2D):
			continue
		_saw_enemies = true
		var to_e: Vector2 = e.global_position - player.global_position
		var d := to_e.length()
		var id := e.get_instance_id()
		# Olvida a los que se alejan lo bastante: podrán volver a avisar.
		if d > THREAT_FORGET_RADIUS:
			_warned.erase(id)
			continue
		if d > THREAT_RADIUS or _warned.has(id):
			continue
		# Solo lo que NO estás mirando (fuera de tu cono de puntería).
		if absf(aim.angle_to(to_e)) < FRONT_HALF_ANGLE:
			continue
		if d < nearest_d:
			nearest_d = d
			nearest = e
	if nearest != null and _threat_gap <= 0.0:
		var to_e: Vector2 = nearest.global_position - player.global_position
		_warned[nearest.get_instance_id()] = true
		_threat_gap = THREAT_GAP
		_alert(_pick(LINES_THREAT) % _threat_direction(aim, to_e))
	# Limpia ids de enemigos ya muertos para que el diccionario no crezca.
	_prune_warned()

## Guía al portal cuando el sector queda sin enemigos (una vez por piso).
func _check_sector_clear(player: Node2D) -> void:
	if _exit_announced or not _saw_enemies:
		return
	if not get_tree().get_nodes_in_group("enemy").is_empty():
		return
	_exit_announced = true
	var exit: Node2D = get_tree().get_first_node_in_group("exit")
	if exit == null:
		return
	var dir := _cardinal(exit.global_position - player.global_position)
	_alert(_pick(LINES_EXIT) % dir)

func _prune_warned() -> void:
	for id in _warned.keys():
		if not is_instance_id_valid(id):
			_warned.erase(id)

## Dirección de la amenaza relativa a hacia dónde apunta el jugador: si está muy
## por detrás, "a tu espalda"; si no, el punto cardinal en pantalla.
func _threat_direction(aim: Vector2, to_enemy: Vector2) -> String:
	if absf(aim.angle_to(to_enemy)) >= BEHIND_ANGLE:
		return "a tu espalda"
	return _cardinal(to_enemy)

## Punto cardinal en pantalla (arriba = -y) del vector dado.
func _cardinal(v: Vector2) -> String:
	if absf(v.x) >= absf(v.y):
		return "a tu derecha" if v.x >= 0.0 else "a tu izquierda"
	return "abajo" if v.y >= 0.0 else "arriba"

# --- API pública (la llaman el generador, el player, etc.) ---

## Llamar al entrar a un piso nuevo.
func announce_floor() -> void:
	_queue.clear()  # una llegada nueva pisa avisos viejos
	# Reinicia el radar/guía para el piso nuevo.
	_warned.clear()
	_saw_enemies = false
	_exit_announced = false
	_threat_gap = 0.0
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

## Aviso urgente (amenaza / salida): pisa lo que se esté mostrando y sale ya.
## No debe esperar en la cola: para eso sirve como función jugable.
func _alert(text: String) -> void:
	if text.is_empty():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_queue.clear()
	_queue.append(text)
	_showing = false
	_reset_idle()
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
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, FADE)
	_tween.tween_interval(SHOW_TIME)
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE)
	_tween.tween_callback(_play_next)

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
