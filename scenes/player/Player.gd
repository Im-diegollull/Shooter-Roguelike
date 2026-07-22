class_name Player
extends CharacterBody2D

## Velocidad de movimiento en píxeles por segundo.
@export var move_speed: float = 260.0

func _physics_process(_delta: float) -> void:
	# Input.get_vector ya devuelve el vector normalizado y aplica deadzone,
	# así que la diagonal no va más rápido que los ejes.
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed
	move_and_slide()

func _process(_delta: float) -> void:
	# El cuerpo apunta hacia el ratón (estilo twin-stick).
	look_at(get_global_mouse_position())
