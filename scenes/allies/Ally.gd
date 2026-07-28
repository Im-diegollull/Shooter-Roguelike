class_name Ally
extends CharacterBody2D

## Compañero que se une al jugador (p. ej. el Desertor tras convencerlo).
## Sigue al jugador a cierta distancia y dispara al enemigo más cercano.

const BULLET_SCENE: PackedScene = preload("res://scenes/bullets/Bullet.tscn")

@export var move_speed: float = 220.0
## Distancia a la que se queda respecto al jugador (no se le pega encima).
@export var follow_distance: float = 90.0
@export var shoot_range: float = 380.0
@export var fire_interval: float = 0.8

var _player: Node2D
var _fire_cd: float = 0.0

func _ready() -> void:
	add_to_group("ally")
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if is_instance_valid(_player):
		var to_player: Vector2 = _player.global_position - global_position
		velocity = to_player.normalized() * move_speed if to_player.length() > follow_distance else Vector2.ZERO
		move_and_slide()

	_fire_cd = maxf(_fire_cd - delta, 0.0)
	if _fire_cd <= 0.0:
		var target: Node2D = _nearest_enemy()
		if target != null:
			_shoot_at(target.global_position)
			_fire_cd = fire_interval

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist: float = shoot_range
	for e in get_tree().get_nodes_in_group("enemy"):
		var d: float = global_position.distance_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best

func _shoot_at(pos: Vector2) -> void:
	var bullet: Bullet = BULLET_SCENE.instantiate()
	bullet.global_position = global_position
	bullet.direction = (pos - global_position).normalized()
	bullet.rotation = bullet.direction.angle()
	get_parent().add_child(bullet)
