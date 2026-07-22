class_name Player
extends CharacterBody2D

const BULLET_SCENE: PackedScene = preload("res://scenes/bullets/Bullet.tscn")

## Velocidad de movimiento en píxeles por segundo.
@export var move_speed: float = 260.0
## Disparos por segundo mientras se mantiene pulsado el botón.
@export var fire_rate: float = 6.0

@onready var muzzle: Marker2D = $Muzzle

var _fire_cooldown: float = 0.0

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

func _process(_delta: float) -> void:
	# El cuerpo apunta hacia el ratón (estilo twin-stick).
	look_at(get_global_mouse_position())

func _shoot() -> void:
	var bullet: Bullet = BULLET_SCENE.instantiate()
	bullet.global_position = muzzle.global_position
	bullet.direction = (get_global_mouse_position() - global_position).normalized()
	bullet.rotation = bullet.direction.angle()
	# Se añade al mundo (padre del player) para que no se mueva con el jugador.
	get_parent().add_child(bullet)
