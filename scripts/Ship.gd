## Ship.gd
## The player ship hovers in orbit around the planet.
## Click anywhere → ship rotates to that angle → fires laser.
class_name Ship
extends Node2D

signal laser_fired(angle: float)

const ORBIT_RADIUS  := 280.0
const ROTATE_SPEED  := 2.8   # rad / sec
const COOLDOWN_TIME := 0.55  # seconds after firing before IDLE again

enum State { IDLE, ROTATING, FIRING, COOLDOWN }

var current_angle: float = -PI * 0.5   # start at top of planet
var target_angle:  float = -PI * 0.5
var _state:        State = State.IDLE
var _cooldown:     float = 0.0

# Thruster animation
var _engine_flicker: float = 0.0

func _ready() -> void:
	_refresh_position()

func is_busy() -> bool:
	return _state != State.IDLE

func move_to_angle(angle: float) -> void:
	if _state != State.IDLE:
		return
	target_angle = angle
	_state       = State.ROTATING

func _process(delta: float) -> void:
	_engine_flicker += delta * 8.0

	match _state:
		State.ROTATING:
			var diff := angle_difference(current_angle, target_angle)
			var step := ROTATE_SPEED * delta
			if absf(diff) <= step:
				current_angle = target_angle
				_state        = State.FIRING
				_do_fire()
			else:
				current_angle += signf(diff) * step

		State.COOLDOWN:
			_cooldown -= delta
			if _cooldown <= 0.0:
				_state = State.IDLE

	_refresh_position()
	queue_redraw()

func _refresh_position() -> void:
	position = Vector2(cos(current_angle), sin(current_angle)) * ORBIT_RADIUS
	# Nose (-Y in local space) should face the planet centre (0,0 in parent space)
	var to_centre := (Vector2.ZERO - position).normalized()
	rotation      = to_centre.angle() + PI * 0.5

func _do_fire() -> void:
	_state    = State.COOLDOWN
	_cooldown = COOLDOWN_TIME
	emit_signal("laser_fired", current_angle)

func _draw() -> void:
	# ── Outer hull (dark base layer) ─────────────────────────────
	var hull_outer := PackedVector2Array([
		Vector2(  0, -23),   # nose
		Vector2( 14,   3),
		Vector2( 13,  14),
		Vector2(  8,  24),
		Vector2( -8,  24),
		Vector2(-13,  14),
		Vector2(-14,   3),
	])
	draw_colored_polygon(hull_outer, Color(0.05, 0.22, 0.48))
	draw_polyline(hull_outer + PackedVector2Array([hull_outer[0]]), Color(0.10, 0.55, 0.95), 1.3)

	# ── Inner hull panel (bright top coat) ───────────────────────
	var hull_inner := PackedVector2Array([
		Vector2(  0, -17),
		Vector2(  9,   3),
		Vector2(  8,  13),
		Vector2(  5,  20),
		Vector2( -5,  20),
		Vector2( -8,  13),
		Vector2( -9,   3),
	])
	draw_colored_polygon(hull_inner, Color(0.18, 0.72, 1.00))

	# ── Wings ─────────────────────────────────────────────────────
	var wing_l := PackedVector2Array([
		Vector2(-14,  3), Vector2(-26, 13), Vector2(-20, 22), Vector2(-13, 14)
	])
	var wing_r := PackedVector2Array([
		Vector2( 14,  3), Vector2( 26, 13), Vector2( 20, 22), Vector2( 13, 14)
	])
	draw_colored_polygon(wing_l, Color(0.07, 0.38, 0.75))
	draw_colored_polygon(wing_r, Color(0.07, 0.38, 0.75))
	draw_polyline(wing_l + PackedVector2Array([wing_l[0]]), Color(0.10, 0.55, 0.95), 1.0)
	draw_polyline(wing_r + PackedVector2Array([wing_r[0]]), Color(0.10, 0.55, 0.95), 1.0)
	# Accent stripe along leading edge
	draw_line(wing_l[0], wing_l[1], Color(0.35, 0.90, 1.0, 0.7), 1.5)
	draw_line(wing_r[0], wing_r[1], Color(0.35, 0.90, 1.0, 0.7), 1.5)
	# Wing tip lights
	draw_circle(wing_l[1], 2.0, Color(1.0, 0.3, 0.3, 0.9))
	draw_circle(wing_r[1], 2.0, Color(0.3, 1.0, 0.3, 0.9))

	# ── Side engine pods ─────────────────────────────────────────
	var pod_pts_l := PackedVector2Array([
		Vector2(-18, 10), Vector2(-14,  8), Vector2(-14, 22), Vector2(-18, 22)
	])
	var pod_pts_r := PackedVector2Array([
		Vector2( 18, 10), Vector2( 14,  8), Vector2( 14, 22), Vector2( 18, 22)
	])
	draw_colored_polygon(pod_pts_l, Color(0.06, 0.28, 0.58))
	draw_colored_polygon(pod_pts_r, Color(0.06, 0.28, 0.58))
	draw_polyline(pod_pts_l + PackedVector2Array([pod_pts_l[0]]), Color(0.10, 0.50, 0.85), 1.0)
	draw_polyline(pod_pts_r + PackedVector2Array([pod_pts_r[0]]), Color(0.10, 0.50, 0.85), 1.0)

	# ── Cockpit ───────────────────────────────────────────────────
	draw_circle(Vector2( 0, -10), 5.5, Color(0.08, 0.45, 0.78))
	draw_circle(Vector2( 0, -10), 4.5, Color(0.20, 0.72, 1.00, 0.95))
	draw_circle(Vector2(-1.5, -11.5), 2.0, Color(0.75, 0.97, 1.0, 0.85))  # glare

	# ── Engine exhausts ───────────────────────────────────────────
	var moving := (_state == State.ROTATING)
	if moving:
		var flicker_a := 0.6 + 0.4 * sin(_engine_flicker)
		var flicker_b := 0.5 + 0.5 * sin(_engine_flicker * 1.3 + 0.8)
		# Main centre engine
		draw_circle(Vector2( 0, 25), 6.0, Color(1.00, 0.45, 0.08, flicker_a))
		draw_circle(Vector2( 0, 27), 3.5, Color(1.00, 0.82, 0.25, flicker_a * 0.75))
		# Side engine pods
		draw_circle(Vector2(-16, 23), 3.5, Color(0.70, 0.25, 1.00, flicker_b))
		draw_circle(Vector2( 16, 23), 3.5, Color(0.70, 0.25, 1.00, flicker_b))
		draw_circle(Vector2(-16, 25), 2.0, Color(0.90, 0.60, 1.00, flicker_b * 0.7))
		draw_circle(Vector2( 16, 25), 2.0, Color(0.90, 0.60, 1.00, flicker_b * 0.7))
	else:
		draw_circle(Vector2( 0, 25), 4.0, Color(1.00, 0.35, 0.05, 0.30))
		draw_circle(Vector2(-16, 23), 2.5, Color(0.70, 0.25, 1.00, 0.22))
		draw_circle(Vector2( 16, 23), 2.5, Color(0.70, 0.25, 1.00, 0.22))

	# ── IDLE ready-ring ───────────────────────────────────────────
	if _state == State.IDLE:
		draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 36, Color(0.15, 1.0, 0.55, 0.28), 1.5)
