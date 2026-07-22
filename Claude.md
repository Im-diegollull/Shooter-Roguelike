# CLAUDE.md — Shooter Roguelike con NPCs Inteligentes

## Contexto del proyecto

Proyecto personal de portafolio. Top-down shooter roguelike con NPCs que conversan
usando IA real (Claude API). Cada run es distinta — mundo procedural y diálogos generados.
Motor: **Godot 4** (estándar) en **macOS**.
Objetivo final: build web publicada en **itch.io**.
Duración estimada: **3 meses**.

---

## Descripción del juego

Top-down shooter roguelike donde el jugador avanza por pisos de un dungeon generado
proceduralmente. En cada piso hay NPCs (mercaderes, prisioneros, aliados dudosos) con
los que puedes conversar en lenguaje natural. Los NPCs recuerdan lo que hiciste en la
run, reaccionan a tus decisiones y pueden darte misiones emergentes.

Referentes de jugabilidad: *Enter the Gungeon*, *Hades* (simplificados).
Twist: los diálogos NO son scriptados — van a la Claude API en tiempo real.

---

## Stack

| Componente | Tecnología |
|---|---|
| Motor | Godot 4 |
| Lenguaje | GDScript |
| IA / diálogos | Claude API (claude-sonnet-4-6) |
| HTTP requests | HTTPRequest node de Godot |
| Arte | Assets gratis (Kenney, itch.io) |
| Audio | Packs gratis de freesound.org |
| Deploy | itch.io (build HTML5) |
| Control de versiones | Git + GitHub |

---

## Arquitectura del proyecto

```
project/
├── assets/
│   ├── sprites/        # Personaje, enemigos, NPCs, tilesets
│   ├── audio/          # SFX y música
│   └── fonts/
├── scenes/
│   ├── player/         # Player.tscn + Player.gd
│   ├── enemies/        # Enemy.tscn + Enemy.gd
│   ├── npcs/           # NPC.tscn + NPC.gd
│   ├── world/          # Level.tscn, Room.tscn
│   └── ui/             # HUD.tscn, DialogBox.tscn, MainMenu.tscn
├── scripts/
│   ├── generation/     # Generación procedural de niveles
│   ├── ai/             # ClaudeClient.gd — wrapper de la API
│   └── managers/       # GameManager.gd, RunMemory.gd
└── CLAUDE.md
```

---

## Sistema de IA — Diseño clave

### ClaudeClient.gd
Wrapper que hace HTTP POST a la Claude API desde Godot.

```gdscript
# scripts/ai/ClaudeClient.gd
extends Node

const API_URL = "https://api.anthropic.com/v1/messages"
const API_KEY = ""  # Cargar desde variable de entorno o config externa
const MODEL = "claude-sonnet-4-6"

signal response_received(text: String)

func send_message(system_prompt: String, user_message: String) -> void:
    var http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_request_completed.bind(http))

    var headers = [
        "Content-Type: application/json",
        "x-api-key: " + API_KEY,
        "anthropic-version: 2023-06-01"
    ]

    var body = JSON.stringify({
        "model": MODEL,
        "max_tokens": 300,
        "system": system_prompt,
        "messages": [{"role": "user", "content": user_message}]
    })

    http.request(API_URL, headers, HTTPClient.METHOD_POST, body)

func _on_request_completed(result, response_code, headers, body, http):
    http.queue_free()
    var json = JSON.parse_string(body.get_string_from_utf8())
    if json and json.has("content"):
        response_received.emit(json["content"][0]["text"])
```

### RunMemory.gd
Objeto global que acumula eventos de la run actual para dárselos como contexto a los NPCs.

```gdscript
# scripts/managers/RunMemory.gd
extends Node

var events: Array[String] = []
var player_kills: int = 0
var floors_cleared: int = 0
var npcs_helped: Array[String] = []
var npcs_killed: Array[String] = []

func add_event(description: String) -> void:
    events.append(description)

func get_context_summary() -> String:
    return """
    Run actual:
    - Pisos completados: %d
    - Enemigos eliminados: %d
    - NPCs ayudados: %s
    - NPCs eliminados: %s
    - Eventos recientes: %s
    """ % [
        floors_cleared,
        player_kills,
        ", ".join(npcs_helped) if npcs_helped else "ninguno",
        ", ".join(npcs_killed) if npcs_killed else "ninguno",
        ", ".join(events.slice(-5)) if events else "ninguno"
    ]
```

### System prompt base para NPCs

```
Eres [NOMBRE], un NPC dentro de un dungeon oscuro en un videojuego roguelike.
Personalidad: [PERSONALIDAD DEL NPC].
Tu situación actual: [SITUACIÓN].

Contexto de lo que ha pasado en esta run:
[RunMemory.get_context_summary()]

Reglas:
- Responde en máximo 2-3 oraciones. Eres conciso.
- Reacciona al contexto de la run si es relevante.
- Puedes ofrecer tratos, dar pistas, o ser hostil según tu personalidad.
- Habla en primera persona, en español.
- No rompas el personaje bajo ninguna circunstancia.
```

---

## Tipos de NPCs

| NPC | Personalidad | Mecánica |
|---|---|---|
| **Mercader** | Codicioso, amigable si compras | Vende armas/upgrades |
| **Prisionero** | Asustado, agradecido si lo liberas | Da pistas del piso |
| **Oráculo** | Misterioso, habla en acertijos | Predice eventos del siguiente piso |
| **Desertor** | Paranoico, desconfiado | Puede unirse o traicionarte |
| **Jefe derrotado** | Amargo, herido | Da lore del mundo si lo perdonas |

---

## Roadmap

### Mes 1 — Base del shooter
**Objetivo:** shooter top-down jugable sin IA todavía.

- [ ] Movimiento top-down del jugador (8 direcciones)
- [ ] Sistema de disparo (raycast o proyectil físico)
- [ ] Enemigos básicos: se mueven hacia el jugador y atacan
- [ ] Generación procedural de salas (BSP)
- [ ] Sistema de vida + muerte + restart
- [ ] HUD básico (vida, munición)
- [ ] Cámara top-down con suavizado

**Milestone:** video de combate funcionando en nivel generado.

---

### Mes 2 — Integración de IA
**Objetivo:** NPCs que conversan de verdad dentro del juego.

- [ ] Implementar ClaudeClient.gd (HTTP a la API)
- [ ] Implementar RunMemory.gd (contexto global de la run)
- [ ] Crear escena de NPC con trigger de interacción (tecla E)
- [ ] UI de diálogo: caja de texto con input del jugador
- [ ] Probar conversación básica con un Mercader
- [ ] Integrar contexto de RunMemory en el system prompt
- [ ] NPCs reaccionan si mataste a otro NPC en la run
- [ ] Sistema de misiones emergentes simples (NPC pide algo, jugador lo cumple)

**Milestone:** video de conversación real con NPC que recuerda eventos de la run.

---

### Mes 3 — Pulido y deploy
**Objetivo:** juego completo y publicado.

- [ ] Todos los tipos de NPC implementados con personalidades distintas
- [ ] Progresión: upgrades entre pisos
- [ ] Arte consistente (sprites top-down de Kenney o similar)
- [ ] SFX: disparos, pasos, impactos, diálogo
- [ ] Música de fondo por piso
- [ ] Manejo de errores de API (timeout, sin conexión)
- [ ] Exportar HTML5 y publicar en itch.io
- [ ] README con GIF de gameplay + video de conversación con NPC
- [ ] Screenshots para página de itch.io

**Milestone:** link de itch.io público y compartible.

---

## Decisiones técnicas clave

### Top-down movement
Usar `CharacterBody2D` con `move_and_slide()`.
Velocidad normalizada en diagonal para evitar que vaya más rápido en 45°:
```gdscript
var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
velocity = direction.normalized() * SPEED
move_and_slide()
```

### Sistema de disparo
Opción A (simple): instanciar una escena `Bullet` con `CharacterBody2D` que viaja en dirección del mouse.
Opción B (preciso): `RayCast2D` instantáneo, sin proyectil físico.
→ Usar Opción A para que las balas sean visibles y se sientan bien.

### Seguridad de la API Key
**Nunca hardcodear la API key en el código.**
En desarrollo: cargar desde un archivo `config.cfg` en `.gitignore`.
En build web (itch.io): considerar un backend proxy simple (FastAPI) que tenga la key.

```gdscript
# Cargar key desde archivo externo
func load_api_key() -> String:
    var config = ConfigFile.new()
    config.load("user://config.cfg")
    return config.get_value("api", "key", "")
```

### Latencia de la API
Los requests a Claude toman 1-3 segundos. Mientras espera:
- Mostrar animación de "NPC pensando..." (puntos suspensivos animados)
- Deshabilitar input del jugador durante el diálogo
- Timeout de 10s con mensaje de fallback si falla

---

## Recursos

| Recurso | URL |
|---|---|
| Godot 4 | https://godotengine.org |
| Claude API docs | https://docs.anthropic.com |
| Assets top-down Kenney | https://kenney.nl/assets/tiny-dungeon |
| Top-down shooter assets | https://limezu.itch.io/moderninteriors (gratis) |
| Audio gratis | https://freesound.org |
| Docs HTTPRequest Godot | https://docs.godotengine.org/en/stable/classes/class_httprequest.html |

---

## Convenciones de código (GDScript)

```gdscript
# Variables: snake_case, siempre tipadas
var player_health: int = 100
var move_speed: float = 200.0

# Constantes: UPPER_SNAKE_CASE
const MAX_HEALTH: int = 100

# Funciones: snake_case
func take_damage(amount: int) -> void:
    player_health -= amount

# Nodos en escena: PascalCase
# Señales: snake_case, verbo en pasado
signal npc_dialogue_started(npc_name: String)
signal player_died()
```

---

## Estado actual

- [ ] Godot 4 instalado
- [ ] Proyecto creado
- [ ] Repositorio GitHub creado
- [ ] API key de Anthropic obtenida

**Próximo paso:** implementar movimiento top-down del jugador (Player.gd).