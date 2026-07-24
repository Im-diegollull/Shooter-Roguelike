extends Node

## Wrapper para hablar con la Claude API vía HTTP (autoload "ClaudeClient").
## La API key NUNCA se hardcodea: se carga de res://config.cfg (en .gitignore)
## o de la variable de entorno ANTHROPIC_API_KEY.

const API_URL := "https://api.anthropic.com/v1/messages"
const ANTHROPIC_VERSION := "2023-06-01"
## Haiku 4.5: rápido y barato, ideal para diálogos cortos de NPC.
const MODEL := "claude-haiku-4-5"
const MAX_TOKENS := 300
const TIMEOUT_SECONDS := 12.0

## Se emite con el texto de la respuesta del NPC.
signal response_received(text: String)
## Se emite con un mensaje de error legible (timeout, sin key, error HTTP...).
signal request_failed(reason: String)

var _api_key: String = ""

func _ready() -> void:
	_api_key = _load_api_key()
	if _api_key.is_empty():
		push_warning("ClaudeClient: sin API key. Crea res://config.cfg con [api] key=\"...\".")

func has_key() -> bool:
	return not _api_key.is_empty()

## Envía una conversación completa.
## `messages` = Array de {"role": "user"/"assistant", "content": String}.
func send(system_prompt: String, messages: Array) -> void:
	if _api_key.is_empty():
		request_failed.emit("Falta la API key (res://config.cfg o ANTHROPIC_API_KEY).")
		return

	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_SECONDS
	add_child(http)
	http.request_completed.connect(_on_completed.bind(http))

	var headers := [
		"Content-Type: application/json",
		"x-api-key: " + _api_key,
		"anthropic-version: " + ANTHROPIC_VERSION,
	]
	var body := JSON.stringify({
		"model": MODEL,
		"max_tokens": MAX_TOKENS,
		"system": system_prompt,
		"messages": messages,
	})
	var err := http.request(API_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		request_failed.emit("No se pudo iniciar la petición (error %d)." % err)

## Conveniencia para un único turno de usuario.
func ask(system_prompt: String, user_message: String) -> void:
	send(system_prompt, [{"role": "user", "content": user_message}])

func _on_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		request_failed.emit("Fallo de red (result %d). ¿Sin conexión o timeout?" % result)
		return

	var json: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(json) != TYPE_DICTIONARY:
		request_failed.emit("Respuesta no válida de la API.")
		return

	if response_code != 200:
		var msg := "Error HTTP %d" % response_code
		if json.has("error") and json["error"] is Dictionary:
			msg += ": " + str(json["error"].get("message", ""))
		request_failed.emit(msg)
		return

	# Estructura esperada: {"content": [{"type": "text", "text": "..."}], ...}
	if json.has("content") and json["content"] is Array and not json["content"].is_empty():
		var first: Variant = json["content"][0]
		if first is Dictionary and first.has("text"):
			response_received.emit(str(first["text"]))
			return
	request_failed.emit("La respuesta no contenía texto.")

func _load_api_key() -> String:
	# 1) Variable de entorno (útil en dev/CI).
	var env_key := OS.get_environment("ANTHROPIC_API_KEY")
	if not env_key.is_empty():
		return env_key
	# 2) Archivo local ignorado por git.
	var config := ConfigFile.new()
	if config.load("res://config.cfg") == OK:
		return config.get_value("api", "key", "")
	return ""
