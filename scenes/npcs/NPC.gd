class_name NPC
extends Node2D

## NPC con el que se conversa. Detecta al jugador cerca, muestra el prompt "[E]"
## y al pulsar interactuar abre la caja de diálogo.
##
## Fase 8: la respuesta es un placeholder (sin API).
## Fase 9: se sustituye por una llamada a ClaudeClient usando build_system_prompt().

const DIALOG_BOX_SCENE: PackedScene = preload("res://scenes/ui/DialogBox.tscn")

@export var npc_name: String = "Mercader"
@export_multiline var personality: String = "Codicioso pero afable si hueles a oro. Hablas con sorna."
@export_multiline var situation: String = "Tienes un puesto improvisado entre las sombras del piso."
@export var greeting: String = "Ah, un cliente. ¿Vienes a gastar o solo a mirar?"

@onready var _prompt: Label = $Prompt
@onready var _zone: Area2D = $InteractionZone

var _player_in_range: bool = false
var _dialog: DialogBox = null
## Historial de la conversación actual (turnos user/assistant) para dar continuidad.
var _history: Array = []

func _ready() -> void:
	add_to_group("npc")
	_prompt.visible = false
	_zone.body_entered.connect(_on_body_entered)
	_zone.body_exited.connect(_on_body_exited)

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
	if _player_in_range:
		_prompt.visible = true

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
		return text
	# En error no se guarda nada en el historial; se avisa en personaje.
	return "(%s enmudece un momento… algo falló: %s)" % [npc_name, text]

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

## Prompt de sistema listo para la Fase 9 (ya inyecta el contexto de RunMemory).
func build_system_prompt() -> String:
	return "\n".join([
		"Eres %s, un NPC dentro de un dungeon oscuro en un videojuego roguelike." % npc_name,
		"Personalidad: %s" % personality,
		"Tu situación actual: %s" % situation,
		"",
		RunMemory.get_context_summary(),
		"",
		"Reglas:",
		"- Responde en máximo 2-3 oraciones. Eres conciso.",
		"- Reacciona al contexto de la run si es relevante.",
		"- Puedes ofrecer tratos, dar pistas, o ser hostil según tu personalidad.",
		"- Habla en primera persona, en español.",
		"- No rompas el personaje bajo ninguna circunstancia.",
	])
