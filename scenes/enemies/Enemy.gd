class_name Enemy
extends CharacterBody2D

## Clase base de enemigos: vida, daño, muerte y utilidades para localizar al jugador.
## Las subclases (ChaserEnemy, RangedEnemy) definen el comportamiento en _physics_process.

## Velocidad de movimiento en píxeles por segundo.
@export var move_speed: float = 120.0
## Vida inicial (nº de impactos de bala que aguanta si damage = 1).
@export var max_health: int = 3
## Daño que hace al jugador al tocarlo.
@export var contact_damage: int = 1

var _health: int
var _player: Node2D

func _ready() -> void:
	add_to_group("enemy")
	_health = max_health
	_player = get_tree().get_first_node_in_group("player")

## La llaman las balas del jugador al impactar.
func take_damage(amount: int) -> void:
	_health -= amount
	_flash()
	if _health <= 0:
		die()

func die() -> void:
	queue_free()

# --- Utilidades para subclases ---

func _direction_to_player() -> Vector2:
	if not is_instance_valid(_player):
		return Vector2.ZERO
	return (_player.global_position - global_position).normalized()

func _distance_to_player() -> float:
	if not is_instance_valid(_player):
		return INF
	return global_position.distance_to(_player.global_position)

func _flash() -> void:
	# Destello blanco breve como feedback de impacto.
	modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.14)
