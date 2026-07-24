class_name LevelGenerator
extends Node2D

## Generación procedural de mazmorra con BSP (Binary Space Partitioning).
## Parte el grid en hojas, crea una sala por hoja y conecta salas hermanas
## con pasillos en L. Construye muros con colisión y dibuja el resultado.

const CHASER_SCENE: PackedScene = preload("res://scenes/enemies/Enemy.tscn")
const RANGED_SCENE: PackedScene = preload("res://scenes/enemies/RangedEnemy.tscn")

## Layer 5 (valor 16) reservada para el entorno/muros.
const WALLS_LAYER: int = 16

@export var tile_size: int = 48
@export var grid_width: int = 64
@export var grid_height: int = 44
## Una hoja deja de partirse cuando sus dos lados caben por debajo de esto.
@export var min_leaf_size: int = 13
@export var max_leaf_size: int = 24
## Tamaño mínimo de sala en tiles.
@export var room_min: int = 6
## Pasillos de 2 tiles de ancho.
@export var corridor_width: int = 2
## Rango de enemigos por sala (la sala de inicio nunca tiene).
@export var enemies_per_room_min: int = 1
@export var enemies_per_room_max: int = 3

var rooms: Array[Rect2i] = []

var _rng := RandomNumberGenerator.new()
var _floor: PackedByteArray
var _enemies_root: Node2D

# --- Hoja del árbol BSP ---
class Leaf:
	var x: int
	var y: int
	var w: int
	var h: int
	var left: Leaf = null
	var right: Leaf = null
	var room: Rect2i = Rect2i()

	func _init(px: int, py: int, pw: int, ph: int) -> void:
		x = px
		y = py
		w = pw
		h = ph

func _ready() -> void:
	_rng.randomize()
	generate()
	_build_walls()
	_draw_ready()
	_place_player()
	_spawn_enemies()

# --- Generación ---

func generate() -> void:
	rooms.clear()
	_floor = PackedByteArray()
	_floor.resize(grid_width * grid_height)  # inicializado a 0 (roca)

	# Se deja un borde de 1 tile para que el muro exterior siempre exista.
	var root := Leaf.new(1, 1, grid_width - 2, grid_height - 2)
	_split(root)
	_create_rooms(root)
	_connect(root)

func _split(leaf: Leaf) -> void:
	# Si ya es lo bastante pequeña, hay una probabilidad de parar (variedad).
	if leaf.w <= max_leaf_size and leaf.h <= max_leaf_size and _rng.randf() < 0.25:
		return

	# Orientación: partir por el lado más largo si hay clara diferencia.
	var split_horizontal: bool
	if leaf.w > leaf.h * 1.25:
		split_horizontal = false
	elif leaf.h > leaf.w * 1.25:
		split_horizontal = true
	else:
		split_horizontal = _rng.randf() < 0.5

	var extent: int = leaf.h if split_horizontal else leaf.w
	var max_split: int = extent - min_leaf_size
	if max_split <= min_leaf_size:
		return  # demasiado pequeña para partir respetando el mínimo

	var cut: int = _rng.randi_range(min_leaf_size, max_split)
	if split_horizontal:
		leaf.left = Leaf.new(leaf.x, leaf.y, leaf.w, cut)
		leaf.right = Leaf.new(leaf.x, leaf.y + cut, leaf.w, leaf.h - cut)
	else:
		leaf.left = Leaf.new(leaf.x, leaf.y, cut, leaf.h)
		leaf.right = Leaf.new(leaf.x + cut, leaf.y, leaf.w - cut, leaf.h)

	_split(leaf.left)
	_split(leaf.right)

func _create_rooms(leaf: Leaf) -> void:
	if leaf.left != null or leaf.right != null:
		if leaf.left != null:
			_create_rooms(leaf.left)
		if leaf.right != null:
			_create_rooms(leaf.right)
		return

	# Hoja terminal: se coloca una sala con margen aleatorio dentro de ella.
	var rw: int = mini(_rng.randi_range(room_min, leaf.w - 2), leaf.w - 2)
	var rh: int = mini(_rng.randi_range(room_min, leaf.h - 2), leaf.h - 2)
	var rx: int = leaf.x + _rng.randi_range(1, maxi(1, leaf.w - rw - 1))
	var ry: int = leaf.y + _rng.randi_range(1, maxi(1, leaf.h - rh - 1))
	var room := Rect2i(rx, ry, rw, rh)
	leaf.room = room
	rooms.append(room)
	_carve_rect(room)

func _connect(leaf: Leaf) -> void:
	if leaf.left == null or leaf.right == null:
		return
	_connect(leaf.left)
	_connect(leaf.right)
	_carve_corridor(_room_center(leaf.left), _room_center(leaf.right))

func _room_center(leaf: Leaf) -> Vector2i:
	if leaf.room.size != Vector2i.ZERO:
		return leaf.room.position + leaf.room.size / 2
	if leaf.left != null:
		return _room_center(leaf.left)
	return _room_center(leaf.right)

# --- Tallado ---

func _carve_rect(r: Rect2i) -> void:
	for xx in range(r.position.x, r.position.x + r.size.x):
		for yy in range(r.position.y, r.position.y + r.size.y):
			_set_floor(xx, yy)

func _carve_corridor(a: Vector2i, b: Vector2i) -> void:
	var x: int = a.x
	var y: int = a.y
	while x != b.x:
		_carve_thick(x, y, true)
		x += signi(b.x - x)
	while y != b.y:
		_carve_thick(x, y, false)
		y += signi(b.y - y)
	_carve_thick(b.x, b.y, false)

func _carve_thick(x: int, y: int, horizontal: bool) -> void:
	# Ensancha el pasillo perpendicular a su dirección de avance.
	for offset in range(corridor_width):
		if horizontal:
			_set_floor(x, y + offset)
		else:
			_set_floor(x + offset, y)

func _set_floor(x: int, y: int) -> void:
	if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
		return
	_floor[y * grid_width + x] = 1

func _is_floor(x: int, y: int) -> bool:
	if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
		return false
	return _floor[y * grid_width + x] == 1

# --- Muros con colisión ---

func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	body.collision_layer = WALLS_LAYER
	body.collision_mask = 0
	add_child(body)

	# Un tile es muro si es roca y toca suelo por algún lado (contorno cerrado).
	for y in grid_height:
		for x in grid_width:
			if _is_floor(x, y) or not _touches_floor(x, y):
				continue
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(tile_size, tile_size)
			shape.shape = rect
			shape.position = Vector2((x + 0.5) * tile_size, (y + 0.5) * tile_size)
			body.add_child(shape)

func _touches_floor(x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if _is_floor(x + dx, y + dy):
				return true
	return false

# --- Colocación de entidades ---

func _place_player() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null or rooms.is_empty():
		return
	player.global_position = _tile_center(rooms[0].position + rooms[0].size / 2)

func _spawn_enemies() -> void:
	_enemies_root = Node2D.new()
	_enemies_root.name = "Enemies"
	add_child(_enemies_root)

	# La sala 0 es el spawn del jugador: se deja despejada.
	for i in range(1, rooms.size()):
		var room := rooms[i]
		var count := _rng.randi_range(enemies_per_room_min, enemies_per_room_max)
		for _n in count:
			var scene := RANGED_SCENE if _rng.randf() < 0.4 else CHASER_SCENE
			var enemy: Node2D = scene.instantiate()
			var tx := _rng.randi_range(room.position.x + 1, room.position.x + room.size.x - 2)
			var ty := _rng.randi_range(room.position.y + 1, room.position.y + room.size.y - 2)
			enemy.global_position = _tile_center(Vector2i(tx, ty))
			_enemies_root.add_child(enemy)

func _tile_center(tile: Vector2i) -> Vector2:
	return Vector2((tile.x + 0.5) * tile_size, (tile.y + 0.5) * tile_size)

# --- Dibujo (estética Tron: suelo tenue + contorno neón) ---

@export var floor_color: Color = Color(0.10, 0.13, 0.19, 1.0)
@export var wall_edge_color: Color = Color(0.36, 0.84, 0.75, 0.55)
@export var edge_width: float = 2.0

func _draw_ready() -> void:
	queue_redraw()

func _draw() -> void:
	if _floor.is_empty():
		return
	var t := float(tile_size)
	for y in grid_height:
		for x in grid_width:
			if not _is_floor(x, y):
				continue
			var origin := Vector2(x * t, y * t)
			draw_rect(Rect2(origin, Vector2(t, t)), floor_color)
			# Contorno neón donde el suelo linda con roca.
			if not _is_floor(x - 1, y):
				draw_line(origin, origin + Vector2(0, t), wall_edge_color, edge_width)
			if not _is_floor(x + 1, y):
				draw_line(origin + Vector2(t, 0), origin + Vector2(t, t), wall_edge_color, edge_width)
			if not _is_floor(x, y - 1):
				draw_line(origin, origin + Vector2(t, 0), wall_edge_color, edge_width)
			if not _is_floor(x, y + 1):
				draw_line(origin + Vector2(0, t), origin + Vector2(t, t), wall_edge_color, edge_width)
