extends CharacterBody2D

signal ore_collected(amount: int)

const FRICTION      := 0.82
const WORLD_BOUNDS  := Rect2(60.0, 60.0, 3080.0, 2280.0)

var mining_target: Area2D = null
var is_mining: bool       = false
var _mine_timer: float    = 0.0
var _mine_progress: float = 0.0
var _round_active: bool   = true

# Engine glow tweak while moving
var _moving: bool = false

@onready var visual: Polygon2D          = $Visual
@onready var engine_glow: Polygon2D     = $EngineGlow
@onready var mining_area: Area2D        = $MiningArea
@onready var mining_col: CollisionShape2D = $MiningArea/CollisionShape2D

func _ready() -> void:
	add_to_group("player")
	_refresh_mining_shape()
	mining_area.area_entered.connect(_on_mining_area_entered)
	mining_area.area_exited.connect(_on_mining_area_exited)

func _refresh_mining_shape() -> void:
	var circle = CircleShape2D.new()
	circle.radius = GameManager.get_mining_range()
	mining_col.shape = circle

func _physics_process(delta: float) -> void:
	if not _round_active:
		return

	# ── Movement ────────────────────────────────────────────────
	var dir := _get_input_dir()
	var speed := GameManager.get_ship_speed()

	if dir != Vector2.ZERO:
		velocity = velocity.lerp(dir * speed, 0.18)
		# Rotate ship visual toward movement direction
		visual.rotation    = lerp_angle(visual.rotation, dir.angle() + PI * 0.5, 0.25)
		engine_glow.rotation = visual.rotation
		_moving = true
	else:
		velocity *= FRICTION
		_moving = false

	move_and_slide()

	# Clamp to world bounds
	position.x = clamp(position.x, WORLD_BOUNDS.position.x, WORLD_BOUNDS.end.x)
	position.y = clamp(position.y, WORLD_BOUNDS.position.y, WORLD_BOUNDS.end.y)

	# Engine glow visibility
	engine_glow.visible = _moving

	# ── Mining ───────────────────────────────────────────────────
	if is_mining:
		if not is_instance_valid(mining_target) or mining_target.is_depleted:
			_cancel_mining()
			return
		_mine_timer -= delta
		_mine_progress = 1.0 - clamp(_mine_timer / GameManager.get_mining_time(), 0.0, 1.0)
		mining_target.set_mining_progress(_mine_progress)
		if _mine_timer <= 0.0:
			_complete_mine()
	else:
		# Cargo full → no mining
		if GameManager.cargo < GameManager.get_cargo_cap():
			_pick_nearest_ore()

func _get_input_dir() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("ui_up")    or Input.is_key_pressed(KEY_W): dir.y -= 1.0
	if Input.is_action_pressed("ui_down")  or Input.is_key_pressed(KEY_S): dir.y += 1.0
	if Input.is_action_pressed("ui_left")  or Input.is_key_pressed(KEY_A): dir.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D): dir.x += 1.0
	return dir.normalized() if dir.length() > 0.0 else Vector2.ZERO

func _pick_nearest_ore() -> void:
	var overlapping := mining_area.get_overlapping_areas()
	if overlapping.is_empty():
		return
	var best_ore: Area2D  = null
	var best_dist: float  = INF
	for area in overlapping:
		if area.is_in_group("ore") and not area.is_depleted:
			var d := area.global_position.distance_to(global_position)
			if d < best_dist:
				best_dist = d
				best_ore  = area
	if best_ore:
		_start_mining(best_ore)

func _start_mining(ore: Area2D) -> void:
	mining_target  = ore
	is_mining      = true
	_mine_timer    = GameManager.get_mining_time()
	_mine_progress = 0.0

func _complete_mine() -> void:
	if is_instance_valid(mining_target):
		var amount := mining_target.ore_value
		mining_target.deplete()
		GameManager.add_cargo(amount)
		emit_signal("ore_collected", amount)
	_cancel_mining()

func _cancel_mining() -> void:
	if is_instance_valid(mining_target):
		mining_target.set_mining_progress(0.0)
	mining_target  = null
	is_mining      = false
	_mine_timer    = 0.0
	_mine_progress = 0.0

func _on_mining_area_entered(_area: Area2D) -> void:
	pass  # handled in _physics_process

func _on_mining_area_exited(area: Area2D) -> void:
	if area == mining_target:
		_cancel_mining()

func stop_round() -> void:
	_round_active = false
	velocity = Vector2.ZERO
