class_name Bullet
extends Area2D

@export var speed: float = 620.0
@export var lifetime: float = 2.0
@export var damage: int = 1

## Dirección de viaje (unitaria). La asigna quien instancia la bala.
var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	# Se autodestruye tras un tiempo para no acumular balas fuera de pantalla.
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
