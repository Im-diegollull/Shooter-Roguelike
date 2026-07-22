class_name Enemy
extends CharacterBody2D

## Velocidad de persecución en píxeles por segundo.
@export var move_speed: float = 120.0
## Vida inicial (nº de impactos de bala que aguanta si damage = 1).
@export var max_health: int = 3

var _health: int
var _player: Node2D

func _ready() -> void:
	_health = max_health
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var dir: Vector2 = (_player.global_position - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()

## La llaman las balas al impactar.
func take_damage(amount: int) -> void:
	_health -= amount
	if _health <= 0:
		die()

func die() -> void:
	queue_free()
