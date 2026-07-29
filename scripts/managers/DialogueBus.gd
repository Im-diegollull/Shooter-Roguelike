extends Node

## DialogueBus — árbitro central de quién tiene "la palabra" en un diálogo y de
## las INTERRUPCIONES (ver lore EL CORO §6). Prioridades: system > combat > npc.
## Una prioridad mayor puede pisar a una menor: la línea se corta a media palabra
## y el remanente oculto se guarda en RunMemory.interrupted_lines.
##
## Regla de oro del lore: una interrupción nunca es decorativa. Siempre tapa algo
## que el jugador debería haber sabido. Cuando llegue la traición, tiene que poder
## decir "estaba ahí y no lo vi".
##
## Hoy está implementado el tipo CORO (el sistema pisa al NPC), que es el más
## importante para el hilo argumental. Combate y radio de Cuervo quedan como
## prioridades reservadas para cuando el diálogo ocurra en tiempo real.

enum Priority { NPC = 0, COMBAT = 1, SYSTEM = 2 }

## Probabilidad de que CORO corte una respuesta del NPC (si es lo bastante larga).
const CORO_INTERRUPT_CHANCE := 0.22
## No cortar líneas más cortas que esto: no habría nada que ocultar.
const MIN_LINE_TO_CUT := 45

## Líneas con las que CORO pisa el diálogo: van de puro "sistema" a cada vez menos
## de sistema (semillas de que la Voz 9 es una persona). La última es un glitch.
const CORO_INTERRUPT_LINES: Array[String] = [
	"Atención de sistema: actividad registrada en este sector. Prosiga.",
	"Aviso de rutina. Mantenga la vía despejada, por favor.",
	"Interrupción de seguridad. …¿Sigues ahí? Disculpe. Continúe con su tarea.",
	"No le hagas caso a— …ignore el mensaje anterior. Ignore el mensaje anterior.",
]

var _holder: int = -1
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

# --- Arbitraje de prioridad (reservado para interrupciones en tiempo real) ---

func request_floor(priority: int) -> bool:
	if priority < _holder:
		return false
	_holder = priority
	return true

func release_floor() -> void:
	_holder = -1

# --- Interrupción de CORO sobre una línea de NPC ---

## Decide si CORO corta `npc_line`. Si corta: guarda el remanente en RunMemory y
## devuelve {"cut": true, "shown": <línea a media palabra>, "coro": <línea de CORO>}.
## Si no: {"cut": false}.
func maybe_coro_interrupt(speaker: String, npc_line: String) -> Dictionary:
	if npc_line.length() < MIN_LINE_TO_CUT:
		return {"cut": false}
	if _rng.randf() > CORO_INTERRUPT_CHANCE:
		return {"cut": false}
	var parts := cut_midword(npc_line)
	RunMemory.record_interruption(speaker, parts["hidden"])
	return {"cut": true, "shown": parts["shown"], "coro": _pick_coro_line()}

## Corta un texto a media palabra en un punto intermedio. Devuelve
## {"shown": <parte visible + guion de corte>, "hidden": <lo que se ocultó>}.
func cut_midword(text: String) -> Dictionary:
	var lo := int(text.length() * 0.4)
	var hi := int(text.length() * 0.7)
	var idx := _rng.randi_range(lo, hi)
	var shown := text.substr(0, idx)
	var hidden := text.substr(idx)
	# El corte cae donde caiga (a media palabra); el guion vende el corte brusco.
	return {"shown": shown.rstrip(" ") + "—", "hidden": hidden.strip_edges()}

func _pick_coro_line() -> String:
	return CORO_INTERRUPT_LINES[_rng.randi() % CORO_INTERRUPT_LINES.size()]
