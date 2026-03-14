extends Area2D

signal depleted

## 1 = common (green), 2 = uncommon (cyan), 3 = rare (orange)
var ore_value: int    = 1
var is_depleted: bool = false

var _progress: float  = 0.0   # 0..1 mining progress shown as arc
var _poly: PackedVector2Array
var _base_color: Color
var _angle_offset: float       # slow rotation per ore

func _ready() -> void:
	add_to_group("ore")
	_angle_offset = randf() * TAU

	_generate_shape()

	# Collision shape — small circle for the ore body
	var shape := CircleShape2D.new()
	shape.radius = 12.0 + ore_value * 2.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

func _generate_shape() -> void:
	var points := randi_range(5, 8)
	var base_r  := 10.0 + ore_value * 5.0
	_poly = PackedVector2Array()
	for i in points:
		var angle := (float(i) / float(points)) * TAU
		var r     := base_r * randf_range(0.65, 1.35)
		_poly.append(Vector2(cos(angle) * r, sin(angle) * r))

	match ore_value:
		1: _base_color = Color(0.30, 1.00, 0.60)   # green
		2: _base_color = Color(0.20, 0.80, 1.00)   # cyan
		3: _base_color = Color(1.00, 0.55, 0.10)   # orange
		_: _base_color = Color.WHITE

func _process(delta: float) -> void:
	if is_depleted:
		return
	_angle_offset += delta * 0.4
	queue_redraw()

func _draw() -> void:
	if is_depleted:
		return

	# Outer soft glow
	var glow_col := _base_color * Color(1, 1, 1, 0.18)
	var glow_poly := PackedVector2Array()
	for p in _poly:
		glow_poly.append(p * 1.5)
	draw_colored_polygon(glow_poly, PackedColorArray([glow_col, glow_col, glow_col, glow_col, glow_col, glow_col, glow_col, glow_col]))

	# Crystal body
	draw_colored_polygon(_poly, PackedColorArray([_base_color] * _poly.size()))

	# Bright inner highlight
	var inner := PackedVector2Array()
	for p in _poly:
		inner.append(p * 0.45)
	var bright := _base_color.lightened(0.4)
	draw_colored_polygon(inner, PackedColorArray([bright] * inner.size()))

	# Mining progress arc — yellow ring
	if _progress > 0.0:
		var r := 18.0 + ore_value * 3.0
		draw_arc(Vector2.ZERO, r, -PI * 0.5, -PI * 0.5 + TAU * _progress, 24, Color(1.0, 0.95, 0.1, 0.9), 2.5)

func set_mining_progress(p: float) -> void:
	_progress = p
	queue_redraw()

func deplete() -> void:
	if is_depleted:
		return
	is_depleted = true
	emit_signal("depleted")
	set_process(false)
	set_deferred("monitoring", false)

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
