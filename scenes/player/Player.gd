class_name Player
extends CharacterBody2D

const BULLET_SCENE: PackedScene = preload("res://scenes/bullets/Bullet.tscn")

signal health_changed(current_health: int, max_health: int)
signal died

## Velocidad de movimiento en píxeles por segundo.
@export var move_speed: float = 260.0
## Disparos por segundo mientras se mantiene pulsado el botón.
@export var fire_rate: float = 6.0
## Vida máxima (nº de segmentos del HUD).
@export var max_health: int = 5
## Segundos de invulnerabilidad tras recibir un golpe.
@export var invuln_time: float = 0.8
## Cuántos píxeles se adelanta la cámara hacia el ratón (feel twin-stick).
@export var look_ahead_distance: float = 110.0

@onready var muzzle: Marker2D = $Muzzle
@onready var hurtbox: Area2D = $Hurtbox
@onready var body_visual: Polygon2D = $Body
@onready var camera: Camera2D = $Camera2D

var current_health: int
var _fire_cooldown: float = 0.0
var _invuln: float = 0.0
var _dead: bool = false

func _ready() -> void:
	current_health = max_health

func _physics_process(delta: float) -> void:
	# Input.get_vector ya devuelve el vector normalizado y aplica deadzone,
	# así que la diagonal no va más rápido que los ejes.
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed
	move_and_slide()

	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	if Input.is_action_pressed("shoot") and _fire_cooldown <= 0.0:
		_shoot()
		_fire_cooldown = 1.0 / fire_rate

	_update_invuln(delta)

func _process(_delta: float) -> void:
	# El cuerpo apunta hacia el ratón (estilo twin-stick).
	look_at(get_global_mouse_position())
	_update_camera()

func _update_camera() -> void:
	# La cámara se adelanta un poco hacia el ratón; el suavizado del Camera2D
	# hace el resto. Se fija la posición global para que la rotación del cuerpo
	# (look_at) no arrastre la cámara.
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	camera.global_position = global_position + to_mouse.limit_length(look_ahead_distance)

func _update_invuln(delta: float) -> void:
	if _invuln > 0.0:
		_invuln -= delta
		# Parpadeo mientras es invulnerable.
		body_visual.visible = fmod(_invuln, 0.16) < 0.08
	else:
		body_visual.visible = true
		_check_contact_damage()

func _check_contact_damage() -> void:
	for b in hurtbox.get_overlapping_bodies():
		if b is Enemy:
			take_damage(b.contact_damage)
			return

func take_damage(amount: int) -> void:
	if _dead or _invuln > 0.0:
		return
	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, max_health)
	_invuln = invuln_time
	if current_health <= 0:
		_die()

func _shoot() -> void:
	var bullet: Bullet = BULLET_SCENE.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.direction = (get_global_mouse_position() - global_position).normalized()
	bullet.rotation = bullet.direction.angle()
	# Se añade al mundo (padre del player) para que no se mueva con el jugador.
	get_parent().add_child(bullet)

func _die() -> void:
	_dead = true
	died.emit()
	set_physics_process(false)
	set_process(false)
	visible = false
