## CargoPod.gd
## A small cargo shuttle that flies from the player ship to a sell station.
## Emits pod_arrived(corp, cargo_amount) on arrival, then frees itself.
class_name CargoPod
extends Node2D

signal pod_arrived(corp: String, cargo_amount: int)

var _corp:        String  = ""
var _cargo:       int     = 0
var _target:      Vector2 = Vector2.ZERO
var _speed:       float   = 130.0
var _flicker:     float   = 0.0
var _initialized: bool    = false

func setup(corp: String, cargo_amount: int,
		from_pos: Vector2, to_pos: Vector2, speed: float) -> void:
	_corp        = corp
	_cargo       = cargo_amount
	_target      = to_pos
	_speed       = speed
	global_position = from_pos
	rotation     = (to_pos - from_pos).angle()
	_initialized = true

func _process(delta: float) -> void:
	if not _initialized:
		return
	_flicker += delta * 10.0

	var dir  := _target - global_position
	var dist := dir.length()
	if dist <= _speed * delta:
		global_position = _target
		emit_signal("pod_arrived", _corp, _cargo)
		queue_free()
		return

	global_position += dir.normalized() * _speed * delta
	rotation = dir.angle()
	queue_redraw()

func _draw() -> void:
	if not _initialized:
		return

	# All geometry is in local space; +X axis points toward destination.
	var col := Color(0.08, 0.50, 1.0) if _corp == "alpha" else Color(1.0, 0.50, 0.08)

	# ── Main body ─────────────────────────────────────────────────
	var body := PackedVector2Array([
		Vector2( 12,   0),   # nose
		Vector2(  5,  -5),
		Vector2( -6,  -4),
		Vector2(-10,   0),
		Vector2( -6,   4),
		Vector2(  5,   5),
	])
	draw_colored_polygon(body, Color(col.r * 0.4, col.g * 0.4, col.b * 0.4))
	draw_colored_polygon(body, Color(col.r, col.g, col.b, 0.85))
	draw_polyline(body + PackedVector2Array([body[0]]), col, 1.0)

	# ── Small wings ───────────────────────────────────────────────
	var wing_t := PackedVector2Array([
		Vector2( 0, -4), Vector2(-4, -9), Vector2(-8, -5), Vector2(-6, -3)
	])
	var wing_b := PackedVector2Array([
		Vector2( 0,  4), Vector2(-4,  9), Vector2(-8,  5), Vector2(-6,  3)
	])
	draw_colored_polygon(wing_t, Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, 0.85))
	draw_colored_polygon(wing_b, Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, 0.85))
	draw_polyline(wing_t + PackedVector2Array([wing_t[0]]), col, 0.8)
	draw_polyline(wing_b + PackedVector2Array([wing_b[0]]), col, 0.8)

	# ── Cockpit dot ───────────────────────────────────────────────
	draw_circle(Vector2(6, 0), 2.0, Color(0.7, 0.95, 1.0, 0.9))

	# ── Engine exhaust (rear, -X) ─────────────────────────────────
	var fa := 0.55 + 0.45 * sin(_flicker)
	var fb := 0.50 + 0.50 * sin(_flicker * 1.4 + 1.1)
	draw_circle(Vector2(-10,  0), 4.0, Color(1.0, 0.55, 0.10, fa))
	draw_circle(Vector2(-10,  0), 2.2, Color(1.0, 0.88, 0.30, fa * 0.8))
	draw_circle(Vector2( -8, -3), 2.0, Color(col.r, col.g, col.b, fb * 0.6))
	draw_circle(Vector2( -8,  3), 2.0, Color(col.r, col.g, col.b, fb * 0.6))
