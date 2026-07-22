extends Node2D

## Fondo con rejilla sutil tipo Tron (estética retro-moderna).
@export var cell_size: float = 48.0
@export var bg_color: Color = Color("14161e")
@export var line_color: Color = Color(0.36, 0.84, 0.75, 0.06)
@export var view_size: Vector2 = Vector2(1280, 720)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, view_size), bg_color)
	var x: float = 0.0
	while x <= view_size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, view_size.y), line_color, 1.0)
		x += cell_size
	var y: float = 0.0
	while y <= view_size.y:
		draw_line(Vector2(0.0, y), Vector2(view_size.x, y), line_color, 1.0)
		y += cell_size
