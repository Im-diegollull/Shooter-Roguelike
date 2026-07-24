extends Node

## Memoria de la run actual (autoload "RunMemory").
## Acumula lo que hace el jugador para dárselo como contexto a los NPCs.

var events: Array[String] = []
var player_kills: int = 0
var floors_cleared: int = 0
var npcs_helped: Array[String] = []
var npcs_killed: Array[String] = []

## Reinicia la memoria al empezar una run nueva.
func reset() -> void:
	events.clear()
	player_kills = 0
	floors_cleared = 0
	npcs_helped.clear()
	npcs_killed.clear()

func add_event(description: String) -> void:
	events.append(description)

func register_kill() -> void:
	player_kills += 1

func help_npc(npc_name: String) -> void:
	if npc_name not in npcs_helped:
		npcs_helped.append(npc_name)
		add_event("Ayudaste a %s" % npc_name)

func kill_npc(npc_name: String) -> void:
	if npc_name not in npcs_killed:
		npcs_killed.append(npc_name)
		add_event("Mataste a %s" % npc_name)

## Resumen en texto plano que se inyecta en el system prompt de los NPCs.
func get_context_summary() -> String:
	return "\n".join([
		"Estado de la run actual:",
		"- Pisos completados: %d" % floors_cleared,
		"- Enemigos eliminados: %d" % player_kills,
		"- NPCs ayudados: %s" % _join_or_none(npcs_helped),
		"- NPCs eliminados: %s" % _join_or_none(npcs_killed),
		"- Eventos recientes: %s" % _join_or_none(events.slice(-5)),
	])

func _join_or_none(list: Array) -> String:
	return ", ".join(list) if not list.is_empty() else "ninguno"
