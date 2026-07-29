class_name NPC
extends StaticBody2D

## NPC con el que se conversa. Detecta al jugador cerca, muestra el prompt "[E]"
## y al pulsar interactuar abre la caja de diálogo con la Claude API.
## Se le puede disparar: si lo matas, queda registrado en RunMemory y el resto
## de NPCs reaccionan al verlo en su contexto.

const DIALOG_BOX_SCENE: PackedScene = preload("res://scenes/ui/DialogBox.tscn")

@export var npc_name: String = "Mercader"
@export_multiline var personality: String = "Codicioso pero afable si hueles a oro. Hablas con sorna."
@export_multiline var situation: String = "Tienes un puesto improvisado entre las sombras del piso."
@export var greeting: String = "Ah, un cliente. ¿Vienes a gastar o solo a mirar?"
## Aguante antes de morir (para que matarlo sea deliberado, no accidental).
@export var max_health: int = 6
## Si es true, la IA puede decidir unirse ([UNIRSE]) o traicionar ([TRAICION]).
@export var can_defect: bool = false

@onready var _prompt: Label = $Prompt
@onready var _zone: Area2D = $InteractionZone
@onready var _body_visual: Polygon2D = $Body

var _health: int
var _dead: bool = false
var _player_in_range: bool = false
var _dialog: DialogBox = null
## Historial de la conversación actual (turnos user/assistant) para dar continuidad.
var _history: Array = []
## Decisión de deserción pendiente de aplicar al cerrar el diálogo: "", "join" o "betray".
var _pending_defection: String = ""

func _ready() -> void:
	add_to_group("npc")
	_health = max_health
	_prompt.visible = false
	_zone.body_entered.connect(_on_body_entered)
	_zone.body_exited.connect(_on_body_exited)

# --- Recibir daño / muerte ---

## La llaman las balas del jugador al impactar.
func take_damage(amount: int) -> void:
	if _dead:
		return
	_health -= amount
	_flash()
	if _health <= 0:
		_die()

func _die() -> void:
	_dead = true
	RunMemory.kill_npc(npc_name)
	queue_free()

func _flash() -> void:
	_body_visual.modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(_body_visual, "modulate", Color.WHITE, 0.14)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or _dialog != null:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_open_dialog()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_prompt.visible = false

# --- Diálogo ---

func _open_dialog() -> void:
	_history.clear()
	_dialog = DIALOG_BOX_SCENE.instantiate()
	get_tree().current_scene.add_child(_dialog)
	_dialog.closed.connect(_on_dialog_closed)
	_dialog.player_sent.connect(_on_player_sent)
	_prompt.visible = false
	# Pausa el juego mientras se conversa (enemigos y balas se congelan).
	get_tree().paused = true
	_dialog.open(npc_name, greeting)

func _on_dialog_closed() -> void:
	get_tree().paused = false
	_dialog = null
	match _pending_defection:
		"join":
			_become_ally()
		"betray":
			_become_enemy()
		_:
			if _player_in_range:
				_prompt.visible = true

func _become_ally() -> void:
	RunMemory.add_event("%s se unió a ti" % npc_name)
	var ally := preload("res://scenes/allies/Ally.tscn").instantiate()
	ally.global_position = global_position
	get_parent().add_child(ally)
	queue_free()

func _become_enemy() -> void:
	RunMemory.add_event("%s te traicionó" % npc_name)
	var foe := preload("res://scenes/enemies/RangedEnemy.tscn").instantiate()
	foe.global_position = global_position
	get_parent().add_child(foe)
	queue_free()

func _on_player_sent(message: String) -> void:
	_dialog.show_thinking()
	var response := await _generate_response(message)
	if _dialog != null:
		_dialog.add_npc_line(response)

## Envía el mensaje a Claude con el historial de la conversación y espera la
## respuesta. Devuelve un texto de fallback legible si la API falla.
func _generate_response(message: String) -> String:
	_history.append({"role": "user", "content": message})
	ClaudeClient.send(build_system_prompt(), _history)

	var result: Array = await _next_claude_result()
	var ok: bool = result[0]
	var text: String = result[1]

	if ok:
		_history.append({"role": "assistant", "content": text})
		# Las etiquetas se procesan y se ocultan al jugador.
		text = _extract_mission(text)
		if can_defect:
			text = _extract_defection(text)
		return text
	# En error no se guarda nada en el historial; se avisa en personaje.
	return "(%s enmudece un momento… algo falló: %s)" % [npc_name, text]

## Detecta "[UNIRSE]" o "[TRAICION]": agenda la transformación y quita la etiqueta.
func _extract_defection(text: String) -> String:
	if _pending_defection != "":
		return text  # decisión ya tomada, no se cambia
	if "[UNIRSE]" in text:
		_pending_defection = "join"
		return text.replace("[UNIRSE]", "").strip_edges()
	if "[TRAICION]" in text:
		_pending_defection = "betray"
		return text.replace("[TRAICION]", "").strip_edges()
	return text

## Detecta "[ENCARGO:N]" en la respuesta: registra la misión y quita la etiqueta.
func _extract_mission(text: String) -> String:
	var re := RegEx.new()
	re.compile("\\[ENCARGO:\\s*(\\d+)\\]")
	var m := re.search(text)
	if m == null:
		return text
	# Solo se acepta un encargo activo a la vez.
	if not RunMemory.has_mission():
		var n: int = clampi(int(m.get_string(1)), 1, 10)
		RunMemory.set_mission(npc_name, n, "matar %d enemigos" % n)
	return re.sub(text, "", true).strip_edges()

## Espera la primera de las dos señales de ClaudeClient. Devuelve [ok: bool, texto].
func _next_claude_result() -> Array:
	var state := {"value": []}
	var on_ok := func(t: String) -> void:
		if state.value.is_empty():
			state.value = [true, t]
	var on_err := func(reason: String) -> void:
		if state.value.is_empty():
			state.value = [false, reason]
	ClaudeClient.response_received.connect(on_ok, CONNECT_ONE_SHOT)
	ClaudeClient.request_failed.connect(on_err, CONNECT_ONE_SHOT)
	# process_frame se emite aunque el árbol esté en pausa.
	while state.value.is_empty():
		await get_tree().process_frame
	# Limpia la señal que no se disparó (la que sí, ya se desconectó por ONE_SHOT).
	if ClaudeClient.response_received.is_connected(on_ok):
		ClaudeClient.response_received.disconnect(on_ok)
	if ClaudeClient.request_failed.is_connected(on_err):
		ClaudeClient.request_failed.disconnect(on_err)
	return state.value

## Marco del mundo compartido por TODOS los NPCs (biblia "EL CORO", ver lore.md).
## Da el escenario por sentado; los NPCs no lo explican, lo habitan.
const WORLD_FRAME: Array[String] = [
	"MUNDO — EL CORO:",
	"Estás en el Pozo: una mina-arcología vertical que la corporación Caldera abandonó",
	"hace doce años sin apagar nada. Las máquinas siguen girando, hace calor, y abajo",
	"quedó la gente que le debía plata. Caldera no cobraba deudas en dinero: las cobraba",
	"en voces. Al deudor le extraían la voz y la memoria para operar los sistemas del",
	"complejo (ascensores, puertas, alarmas). Nueve de esas personas forman CORO, el",
	"sistema de guía que todavía le habla a quien baja. Nadie baja por gusto: se baja por",
	"una deuda. La gente que queda aquí está cansada, no es heroica.",
]

## Prompt de sistema (inyecta el mundo, el contexto de RunMemory y las etiquetas).
func build_system_prompt() -> String:
	var lines: Array[String] = []
	lines.append_array(WORLD_FRAME)
	lines.append_array([
		"",
		"Eres %s, alguien que sobrevive dentro del Pozo." % npc_name,
		"Personalidad: %s" % personality,
		"Tu situación actual: %s" % situation,
		"",
		RunMemory.get_context_summary(),
		"",
		"Reglas:",
		"- Responde en máximo 2-3 oraciones. Español seco, cansado, sin épica.",
		"- No expliques el mundo: lo das por obvio, como quien lleva años aquí abajo.",
		"- Reacciona al contexto de la run si viene al caso.",
		"- Si el jugador ha matado a otros NPCs, reacciona a ello (miedo, rencor, cautela).",
		"- Puedes ofrecer tratos, dar pistas, o ser hostil según tu personalidad.",
		"- Habla en primera persona, en español.",
		"- Nunca rompas personaje ni menciones que eres una IA.",
		"",
		"Encargos: si no hay ninguno activo y encaja con la conversación, puedes",
		"encargarle matar enemigos añadiendo AL FINAL, en una línea aparte, la etiqueta",
		"[ENCARGO:N] (N = número de enemigos, 1 a 5). El jugador NO ve esa etiqueta.",
		"Si el contexto dice que un encargo está COMPLETADO, agradécelo o recompénsalo y",
		"no vuelvas a pedir lo mismo. Nunca escribas la etiqueta si ya hay un encargo activo.",
	])
	if can_defect:
		lines.append_array([
			"",
			"Decisión de desertor: según cómo te trate el jugador, puedes tomar UNA",
			"decisión irreversible y marcarla AL FINAL en una línea aparte (el jugador no la ve):",
			"- Si te convence y te ganas su confianza, únete a él: etiqueta [UNIRSE].",
			"- Si te amenaza, te insulta o desconfías demasiado, traiciónalo: etiqueta [TRAICION].",
			"- Usa una etiqueta SOLO cuando de verdad decidas; no antes. No vuelvas a cambiarla.",
		])
	return "\n".join(lines)
