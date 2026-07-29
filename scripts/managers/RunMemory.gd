extends Node

## Memoria de la run actual (autoload "RunMemory").
## Acumula lo que hace el jugador para dárselo como contexto a los NPCs.

## La emite register_kill(); CORO y otros sistemas reaccionan sin acoplarse.
signal kill_registered(total: int)

var events: Array[String] = []
var player_kills: int = 0
var floors_cleared: int = 0
var npcs_helped: Array[String] = []
var npcs_killed: Array[String] = []

## --- Misión emergente activa (una a la vez, por simplicidad) ---
var mission_giver: String = ""
var mission_desc: String = ""
## Valor de player_kills que hay que alcanzar para completar el encargo.
var mission_kill_target: int = 0

## --- Cuervo (ver lore EL CORO) ---
## Cuántas veces el jugador le ha hablado. Su lealtad se compra prestándole
## atención (respondiéndole cuando pregunta cosas), no con oro ni amenazas.
var cuervo_attention: int = 0

## --- Interrupciones de diálogo (foreshadowing, ver lore EL CORO §6) ---
## Cada vez que una interrupción corta una línea a media palabra, el remanente
## oculto se guarda aquí. Lo que nunca se retoma es lo que duele.
## Cada entrada: {"speaker": String, "hidden": String}.
var interrupted_lines: Array[Dictionary] = []

## Reinicia la memoria al empezar una run nueva.
func reset() -> void:
	events.clear()
	player_kills = 0
	floors_cleared = 0
	npcs_helped.clear()
	npcs_killed.clear()
	cuervo_attention = 0
	interrupted_lines.clear()
	clear_mission()

func add_event(description: String) -> void:
	events.append(description)

func register_kill() -> void:
	player_kills += 1
	kill_registered.emit(player_kills)

## La llama Cuervo cada vez que el jugador le habla (mide la atención).
func note_cuervo_attention() -> void:
	cuervo_attention += 1

## Guarda el remanente oculto de una línea cortada por una interrupción.
func record_interruption(speaker: String, hidden: String) -> void:
	if hidden.strip_edges().is_empty():
		return
	interrupted_lines.append({"speaker": speaker, "hidden": hidden})

## Devuelve (y consume) el último remanente oculto de un speaker, o "" si no hay.
## Para que un NPC pueda retomar ("te estaba diciendo que…") — o nunca.
func take_interruption_for(speaker: String) -> String:
	for i in range(interrupted_lines.size() - 1, -1, -1):
		if interrupted_lines[i]["speaker"] == speaker:
			var hidden: String = interrupted_lines[i]["hidden"]
			interrupted_lines.remove_at(i)
			return hidden
	return ""

## Etiqueta legible del nivel de atención acumulada hacia Cuervo.
func cuervo_attention_level() -> String:
	if cuervo_attention <= 1:
		return "casi ninguna"
	elif cuervo_attention <= 3:
		return "algo"
	return "bastante"

func help_npc(npc_name: String) -> void:
	if npc_name not in npcs_helped:
		npcs_helped.append(npc_name)
		add_event("Ayudaste a %s" % npc_name)

func kill_npc(npc_name: String) -> void:
	if npc_name not in npcs_killed:
		npcs_killed.append(npc_name)
		add_event("Mataste a %s" % npc_name)

# --- Misiones emergentes ---

func has_mission() -> bool:
	return not mission_giver.is_empty()

## `kills_needed` es relativo al momento del encargo.
func set_mission(giver: String, kills_needed: int, desc: String) -> void:
	mission_giver = giver
	mission_kill_target = player_kills + kills_needed
	mission_desc = desc
	add_event("%s te encargó: %s" % [giver, desc])

func mission_completed() -> bool:
	return has_mission() and player_kills >= mission_kill_target

func clear_mission() -> void:
	mission_giver = ""
	mission_desc = ""
	mission_kill_target = 0

func _mission_line() -> String:
	if not has_mission():
		return "- Encargo activo: ninguno"
	if mission_completed():
		return "- Encargo de %s: COMPLETADO (%s). ¡El jugador ya lo cumplió!" % [mission_giver, mission_desc]
	var faltan: int = maxi(mission_kill_target - player_kills, 0)
	return "- Encargo de %s: PENDIENTE (%s). Faltan %d enemigos." % [mission_giver, mission_desc, faltan]

## Resumen en texto plano que se inyecta en el system prompt de los NPCs.
func get_context_summary() -> String:
	return "\n".join([
		"Estado de la run actual:",
		"- Pisos completados: %d" % floors_cleared,
		"- Enemigos eliminados: %d" % player_kills,
		"- NPCs ayudados: %s" % _join_or_none(npcs_helped),
		"- NPCs eliminados: %s" % _join_or_none(npcs_killed),
		_mission_line(),
		"- Eventos recientes: %s" % _join_or_none(events.slice(-5)),
	])

func _join_or_none(list: Array) -> String:
	return ", ".join(list) if not list.is_empty() else "ninguno"
