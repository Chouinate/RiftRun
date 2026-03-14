## Ship.gd
## The player ship hovers in orbit around the planet.
## Click anywhere → ship rotates to that angle → fires laser.
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
	# Ship body — nose at local (0, -len), pointing toward planet
	var body := PackedVector2Array([
		Vector2( 0,  -18),   # nose
		Vector2( 11,   5),
		Vector2(  6,  11),
		Vector2(  4,  20),
		Vector2( -4,  20),
		Vector2( -6,  11),
		Vector2(-11,   5),
	])
	var hull_col := Color(0.18, 0.82, 1.00)
	draw_colored_polygon(body, PackedColorArray([hull_col] * body.size()))

	# Cockpit window
	draw_circle(Vector2(0, -8), 4.0, Color(0.6, 0.95, 1.0, 0.9))

	# Engine exhaust (bottom)
	var moving := (_state == State.ROTATING)
	if moving:
		var flicker_a := 0.6 + 0.4 * sin(_engine_flicker)
		draw_circle(Vector2(0, 20), 5.5, Color(1.0, 0.45, 0.10, flicker_a))
		draw_circle(Vector2(0, 22), 3.0, Color(1.0, 0.80, 0.30, flicker_a * 0.7))
	else:
		# Dim idle glow
		draw_circle(Vector2(0, 20), 3.5, Color(1.0, 0.35, 0.05, 0.35))

	# Wing accents
	draw_line(Vector2(-11, 5), Vector2(-14, 14), Color(0.1, 0.55, 0.95), 1.5)
	draw_line(Vector2( 11, 5), Vector2( 14, 14), Color(0.1, 0.55, 0.95), 1.5)

	# Ready indicator ring when IDLE (subtle teal ring)
	if _state == State.IDLE:
		draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 24, Color(0.15, 1.0, 0.55, 0.35), 1.5)
