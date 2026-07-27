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

## Fase 8: placeholder. Fase 9 reemplaza el cuerpo por:
##   ClaudeClient.ask(build_system_prompt(), message)  + await de la señal.
func _generate_response(_message: String) -> String:
	# Timer con process_always para que corra aunque el árbol esté en pausa.
	await get_tree().create_timer(0.6).timeout
	return "(%s te observa en silencio. Sus palabras reales llegarán con la IA en la Fase 9.)" % npc_name

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
