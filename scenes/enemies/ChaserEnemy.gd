class_name ChaserEnemy
extends Enemy

## Enemigo melee: persigue al jugador en línea recta y hace daño por contacto.

func _physics_process(_delta: float) -> void:
	velocity = _direction_to_player() * move_speed
	move_and_slide()
