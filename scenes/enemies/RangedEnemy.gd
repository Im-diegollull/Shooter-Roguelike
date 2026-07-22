class_name RangedEnemy
extends Enemy

## Enemigo a distancia: mantiene una distancia preferida del jugador (kiting)
## y le dispara balas cada cierto intervalo.

const ENEMY_BULLET: PackedScene = preload("res://scenes/bullets/EnemyBullet.tscn")

## Distancia a la que intenta mantenerse del jugador.
@export var preferred_distance: float = 320.0
## Margen de tolerancia alrededor de la distancia preferida.
@export var distance_margin: float = 40.0
## Segundos entre disparos.
@export var fire_interval: float = 1.6
## Velocidad de sus balas.
@export var bullet_speed: float = 340.0

var _fire_timer: float = 0.0

func _physics_process(delta: float) -> void:
	var dir: Vector2 = _direction_to_player()
	var dist: float = _distance_to_player()

	# Kiting: si está lejos se acerca, si está cerca retrocede, si está en rango orbita.
	if dist > preferred_distance + distance_margin:
		velocity = dir * move_speed
	elif dist < preferred_distance - distance_margin:
		velocity = -dir * move_speed
	else:
		velocity = dir.orthogonal() * move_speed * 0.5
	move_and_slide()

	_fire_timer -= delta
	if _fire_timer <= 0.0 and dir != Vector2.ZERO:
		_shoot(dir)
		_fire_timer = fire_interval

func _shoot(dir: Vector2) -> void:
	var bullet: Bullet = ENEMY_BULLET.instantiate()
	bullet.global_position = global_position + dir * 22.0
	bullet.direction = dir
	bullet.speed = bullet_speed
	bullet.rotation = dir.angle()
	get_parent().add_child(bullet)
