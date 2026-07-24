extends Node2D

## Fondo con rejilla sutil tipo Tron (estética retro-moderna).
## Sigue a la cámara y se redibuja alrededor de la vista para sentirse infinita.
@export var cell_size: float = 48.0
@export var bg_color: Color = Color("14161e")
@export var line_color: Color = Color(0.36, 0.84, 0.75, 0.06)

var _view: Vector2

func _ready() -> void:
	_view = get_viewport_rect().size

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# Centro de lo que muestra la cámara (ya suavizado). Sin cámara, centro fijo.
	var cam: Camera2D = get_viewport().get_camera_2d()
	var center: Vector2 = cam.get_screen_center_position() if cam else _view * 0.5

	# Rect de la vista con un margen de dos celdas para que no se noten los bordes.
	var half: Vector2 = _view * 0.5 + Vector2(cell_size, cell_size) * 2.0
	var left: float = center.x - half.x
	var right: float = center.x + half.x
	var top: float = center.y - half.y
	var bottom: float = center.y + half.y

	draw_rect(Rect2(Vector2(left, top), Vector2(right - left, bottom - top)), bg_color)

	# Se empieza en el múltiplo de cell_size anterior al borde: las líneas quedan
	# "ancladas" al mundo y dan sensación de rejilla infinita al desplazarse.
	var x: float = floorf(left / cell_size) * cell_size
	while x <= right:
		draw_line(Vector2(x, top), Vector2(x, bottom), line_color, 1.0)
		x += cell_size
	var y: float = floorf(top / cell_size) * cell_size
	while y <= bottom:
		draw_line(Vector2(left, y), Vector2(right, y), line_color, 1.0)
		y += cell_size
