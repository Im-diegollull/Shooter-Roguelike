class_name Exit
extends Area2D

## Portal de descenso al siguiente piso. Emite `reached` la primera vez que el
## jugador entra. Se dibuja en código (rombo neón + chevrones) como el resto.

signal reached

const RADIUS := 30.0
const COLOR_RING := Color("5cd6c0")
const COLOR_GLOW := Color(0.36, 0.84, 0.75, 0.14)

var _used: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # capa del jugador
	monitoring = true

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)

	var label := Label.new()
	label.text = "▼ BAJAR ▼"
	label.add_theme_color_override("font_color", COLOR_RING)
	label.add_theme_font_size_override("font_size", 13)
	label.position = Vector2(-34, RADIUS + 6)
	add_child(label)

	body_entered.connect(_on_body_entered)
	_pulse()

func _on_body_entered(body: Node) -> void:
	if _used:
		return
	if body.is_in_group("player"):
		_used = true
		reached.emit()

## Latido suave para que el portal se lea como "interactúa aquí".
func _pulse() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(self, "scale", Vector2.ONE * 1.12, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)

func _draw() -> void:
	# Halo tenue.
	draw_circle(Vector2.ZERO, RADIUS + 6.0, COLOR_GLOW)
	# Rombo neón (contorno).
	var d := RADIUS
	var diamond := PackedVector2Array([
		Vector2(0, -d), Vector2(d, 0), Vector2(0, d), Vector2(-d, 0), Vector2(0, -d),
	])
	draw_polyline(diamond, COLOR_RING, 2.0)
	# Rombo interior más pequeño.
	var i := d * 0.55
	var inner := PackedVector2Array([
		Vector2(0, -i), Vector2(i, 0), Vector2(0, i), Vector2(-i, 0), Vector2(0, -i),
	])
	draw_polyline(inner, Color(COLOR_RING, 0.6), 1.5)
