## Rover.gd
## A scout probe that launches from the ship, lands on the planet surface,
## and after a scan delay emits scan_complete so ore hints are revealed.
class_name Rover
extends Node2D

signal rover_landed
signal scan_complete

const FLIGHT_SPEED := 180.0   # px/s while travelling to surface

var _target:      Vector2 = Vector2.ZERO
var _scan_delay:  float   = 8.0
var _landed:      bool    = false
var _scan_timer:  float   = 0.0
var _scan_done:   bool    = false
var _pulse:       float   = 0.0   # visual animation

func setup(from_pos: Vector2, planet_world_pos: Vector2,
		   planet_radius: float, scan_delay: float) -> void:
	global_position = from_pos
	_scan_delay     = scan_delay
	# Land at the point on the planet surface closest to the ship
	var dir    := (from_pos - planet_world_pos).normalized()
	_target    = planet_world_pos + dir * (planet_radius - 4.0)
	# Face toward planet on launch
	rotation   = (planet_world_pos - from_pos).angle()

func _process(delta: float) -> void:
	_pulse += delta * 3.0

	if not _landed:
		_fly(delta)
	elif not _scan_done:
		_scan_timer += delta
		if _scan_timer >= _scan_delay:
			_scan_done = true
			emit_signal("scan_complete")
	queue_redraw()

func _fly(delta: float) -> void:
	var dir  := _target - global_position
	var dist := dir.length()
	if dist <= FLIGHT_SPEED * delta:
		global_position = _target
		_landed         = true
		# Rotate so rover sits flat on the surface (perpendicular to planet radius)
		rotation        = dir.angle() + PI * 0.5
		emit_signal("rover_landed")
		return
	global_position += dir.normalized() * FLIGHT_SPEED * delta
	rotation         = dir.angle()

func _draw() -> void:
	if _landed:
		_draw_landed()
	else:
		_draw_flying()

func _draw_flying() -> void:
	# Small probe capsule pointing along +X (rotation handles direction)
	var body := PackedVector2Array([
		Vector2( 9,  0),
		Vector2( 4, -4),
		Vector2(-7, -3),
		Vector2(-9,  0),
		Vector2(-7,  3),
		Vector2( 4,  4),
	])
	draw_colored_polygon(body, Color(0.55, 0.65, 0.70))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0.8, 0.9, 1.0), 1.0)
	# Engine burn at rear
	var fa := 0.6 + 0.4 * sin(_pulse)
	draw_circle(Vector2(-9, 0), 3.5, Color(0.9, 0.55, 0.1, fa))
	draw_circle(Vector2(-9, 0), 1.8, Color(1.0, 0.88, 0.4, fa))
	# Solar panel stubs
	draw_line(Vector2(0, -3), Vector2(0, -8), Color(0.4, 0.65, 0.9), 2.0)
	draw_line(Vector2(0,  3), Vector2(0,  8), Color(0.4, 0.65, 0.9), 2.0)

func _draw_landed() -> void:
	# Body (upright lander box, local Y points away from planet centre)
	draw_rect(Rect2(-6, -10, 12, 10), Color(0.45, 0.55, 0.62))
	draw_rect(Rect2(-6, -10, 12, 10), Color(0.75, 0.88, 1.0), false, 1.0)

	# Landing legs (spread below body)
	draw_line(Vector2(-6, 0), Vector2(-11, 6),  Color(0.6, 0.7, 0.75), 1.5)
	draw_line(Vector2( 6, 0), Vector2( 11, 6),  Color(0.6, 0.7, 0.75), 1.5)
	draw_line(Vector2(-11, 6), Vector2(-13, 6), Color(0.6, 0.7, 0.75), 1.5)
	draw_line(Vector2( 11, 6), Vector2( 13, 6), Color(0.6, 0.7, 0.75), 1.5)

	# Antenna
	draw_line(Vector2(0, -10), Vector2(0, -18), Color(0.75, 0.88, 1.0), 1.2)
	draw_circle(Vector2(0, -18), 2.0, Color(0.75, 0.88, 1.0))

	# Scan status indicator
	if not _scan_done:
		# Pulsing scan ring — shows progress
		var frac   := _scan_timer / _scan_delay
		var pulsed := 0.4 + 0.4 * sin(_pulse * 2.0)
		draw_arc(Vector2.ZERO, 20.0, 0.0, frac * TAU, 24,
				 Color(0.2, 0.9, 0.5, pulsed), 2.5)
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24,
				 Color(0.2, 0.9, 0.5, 0.12), 2.5)
	else:
		# Complete — solid green ring
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 32, Color(0.2, 1.0, 0.5, 0.8), 2.5)
		# Flash pulse
		var bright := 0.5 + 0.5 * sin(_pulse * 4.0)
		draw_circle(Vector2(0, -18), 3.0, Color(0.2, 1.0, 0.5, bright))
