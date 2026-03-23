## Planet.gd
## Manages a circular grid representing a planet cross-section.
## Ore veins are hidden inside rock; the player drills by angle to reveal them.
class_name Planet
extends Node2D

signal ore_mined(ore_type: int, value: int)

# ── Constants ─────────────────────────────────────────────────────
const PLANET_RADIUS := 210.0
const CELL_SIZE     := 13
const GRID_HALF     := 17          # cells span -17..+17 each axis

enum Cell { EMPTY = 0, ROCK = 1, ORE_1 = 2, ORE_2 = 3, ORE_3 = 4 }

const ORE_VALUES: Dictionary = { Cell.ORE_1: 1, Cell.ORE_2: 2, Cell.ORE_3: 3 }

## Ore colours: green / cyan / orange-gold
const ORE_COLORS: Dictionary = {
	Cell.ORE_1: Color(0.20, 0.92, 0.45),
	Cell.ORE_2: Color(0.18, 0.68, 1.00),
	Cell.ORE_3: Color(1.00, 0.60, 0.12),
}

## Rock shade palette for a little visual texture
const ROCK_SHADES: Array[Color] = [
	Color(0.145, 0.100, 0.068),
	Color(0.162, 0.112, 0.076),
	Color(0.125, 0.088, 0.060),
	Color(0.180, 0.125, 0.085),
	Color(0.135, 0.095, 0.065),
	Color(0.170, 0.118, 0.080),
]

# ── State ──────────────────────────────────────────────────────────
var _grid:          Dictionary = {}   # Vector2i -> Cell (only cells inside planet stored)
var _surface_hints: Dictionary = {}   # Vector2i -> Color
var _show_scanner:  bool       = false

## Laser animation
var _laser_from:  Vector2 = Vector2.ZERO
var _laser_to:    Vector2 = Vector2.ZERO
var _laser_alpha: float   = 0.0

# ── Public API ────────────────────────────────────────────────────
func setup(round_num: int, show_scanner: bool) -> void:
	_show_scanner = show_scanner
	_init_grid()
	_generate_ores(round_num)
	if _show_scanner:
		_compute_surface_hints()

func get_ore_remaining() -> int:
	var n := 0
	for key: Vector2i in _grid:
		if (_grid[key] as int) > Cell.ROCK:
			n += 1
	return n

func fire_laser(angle: float, depth_frac: float, width: int) -> int:
	## angle      — angle from planet centre to ship (radians)
	## depth_frac — 0..1 fraction of PLANET_RADIUS the beam reaches
	## width      — extra cell columns each side (0 = single-cell beam)
	var inward  := Vector2.from_angle(angle + PI)   # toward centre
	var perp    := inward.rotated(PI * 0.5)          # perpendicular
	var max_len := PLANET_RADIUS * depth_frac

	var start       := Vector2.from_angle(angle) * (PLANET_RADIUS + 4.0)
	var total_value := 0
	var dug         := {}                             # avoid double-counting

	for col in range(-width, width + 1):
		var offset := perp * col * CELL_SIZE
		var pos    := start + offset
		var dist   := 0.0

		while dist <= max_len:
			var cx  := int(round(pos.x / float(CELL_SIZE)))
			var cy  := int(round(pos.y / float(CELL_SIZE)))
			var ck  := Vector2i(cx, cy)

			if _grid.has(ck) and not dug.has(ck):
				dug[ck] = true
				var ctype: int = _grid[ck]
				if ctype > Cell.ROCK:
					total_value += ORE_VALUES[ctype]
					emit_signal("ore_mined", ctype, ORE_VALUES[ctype])
				if ctype != Cell.EMPTY:
					_grid[ck] = Cell.EMPTY
					_surface_hints.erase(ck)

			pos  += inward * (CELL_SIZE * 0.5)
			dist += CELL_SIZE * 0.5

	# Set up laser visual
	_laser_from  = Vector2.from_angle(angle) * (PLANET_RADIUS + 55.0)
	var end_dist := PLANET_RADIUS - max_len
	_laser_to    = Vector2.from_angle(angle) * maxf(end_dist, 8.0) * (1.0 if end_dist > 0 else -1.0)
	# If depth >= 1 the beam reaches the core
	if depth_frac >= 1.0:
		_laser_to = Vector2.ZERO
	_laser_alpha = 1.0

	queue_redraw()
	return total_value

# ── Grid initialisation ───────────────────────────────────────────
func _init_grid() -> void:
	_grid.clear()
	_surface_hints.clear()
	for cx in range(-GRID_HALF, GRID_HALF + 1):
		for cy in range(-GRID_HALF, GRID_HALF + 1):
			var wp := Vector2(cx * CELL_SIZE, cy * CELL_SIZE)
			if wp.length() <= PLANET_RADIUS:
				_grid[Vector2i(cx, cy)] = Cell.ROCK

# ── Ore generation ────────────────────────────────────────────────
func _generate_ores(round_num: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# Common (green) — surface to mid
	_place_blobs(rng, Cell.ORE_1,
		5 + (round_num - 1) * 2,
		4, 11,
		PLANET_RADIUS * 0.28, PLANET_RADIUS * 0.96)

	# Uncommon (cyan) — mid depth
	_place_blobs(rng, Cell.ORE_2,
		3 + (round_num - 1),
		3, 7,
		PLANET_RADIUS * 0.08, PLANET_RADIUS * 0.65)

	# Rare (orange) — deep / core
	_place_blobs(rng, Cell.ORE_3,
		1 + int((round_num - 1) * 0.5),
		2, 5,
		0.0, PLANET_RADIUS * 0.38)

func _place_blobs(rng: RandomNumberGenerator, ore_type: int,
		count: int, min_sz: int, max_sz: int,
		min_r: float, max_r: float) -> void:

	for _i in count:
		var r         := rng.randf_range(min_r, max_r)
		var angle     := rng.randf() * TAU
		var seed_w    := Vector2(cos(angle), sin(angle)) * r
		var seed_cell := Vector2i(int(round(seed_w.x / CELL_SIZE)), int(round(seed_w.y / CELL_SIZE)))

		var blob_sz  := rng.randi_range(min_sz, max_sz)
		var frontier := [seed_cell]
		var visited  := { seed_cell: true }
		var placed   := 0

		while not frontier.is_empty() and placed < blob_sz:
			var idx := rng.randi() % frontier.size()
			var cur := frontier[idx] as Vector2i
			frontier.remove_at(idx)

			if _grid.has(cur):
				_grid[cur] = ore_type
				placed += 1

			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb := cur + d
				if not visited.has(nb) and _grid.has(nb) and rng.randf() < 0.68:
					visited[nb] = true
					frontier.append(nb)

# ── Surface hint computation (scanner upgrade) ────────────────────
func _compute_surface_hints() -> void:
	_surface_hints.clear()
	var dirs_4 := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

	for key: Vector2i in _grid:
		if (_grid[key] as int) != Cell.ROCK:
			continue
		# Surface cell = has at least one neighbour outside the planet
		var is_surface := false
		for d: Vector2i in dirs_4:
			if not _grid.has(key + d):
				is_surface = true
				break
		if not is_surface:
			continue

		# Probe inward (toward centre) up to 6 cells
		var toward_centre := -Vector2(key.x, key.y).normalized()
		var best_type     := Cell.EMPTY
		var best_val      := 0
		for step in range(1, 7):
			var probe := Vector2(key.x, key.y) + toward_centre * step
			var pk    := Vector2i(int(round(probe.x)), int(round(probe.y)))
			if _grid.has(pk):
				var pt: int = _grid[pk]
				if pt > Cell.ROCK:
					var v: int = ORE_VALUES[pt]
					if v > best_val:
						best_val  = v
						best_type = pt

		if best_type != Cell.EMPTY:
			_surface_hints[key] = ORE_COLORS[best_type]

# ── Process / Draw ────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _laser_alpha > 0.0:
		_laser_alpha = maxf(0.0, _laser_alpha - delta * 2.8)
		queue_redraw()

func _draw() -> void:
	# ── Planet background ──────────────────────────────────────────
	draw_circle(Vector2.ZERO, PLANET_RADIUS + 1.0, Color(0.10, 0.07, 0.044))

	# ── Grid cells ─────────────────────────────────────────────────
	var hcs := CELL_SIZE * 0.5
	for key: Vector2i in _grid:
		var ctype: int = _grid[key]
		var wp    := Vector2(key.x * CELL_SIZE, key.y * CELL_SIZE)
		var rect  := Rect2(wp.x - hcs, wp.y - hcs, CELL_SIZE, CELL_SIZE)

		match ctype:
			Cell.EMPTY:
				draw_rect(rect, Color(0.008, 0.008, 0.025))

			Cell.ROCK:
				var shade_idx: int = absi(key.x * 3 + key.y * 7) % ROCK_SHADES.size()
				draw_rect(rect, ROCK_SHADES[shade_idx])

			_:  # ore
				var ore_col: Color = ORE_COLORS[ctype]
				# Dim outer fill
				draw_rect(rect, ore_col * Color(1, 1, 1, 0.30))
				# Bright inner crystal
				var inner := Rect2(wp.x - hcs * 0.55, wp.y - hcs * 0.55, CELL_SIZE * 0.55, CELL_SIZE * 0.55)
				draw_rect(inner, ore_col)
				# Tiny highlight
				draw_rect(Rect2(wp.x - 2, wp.y - 2, 3, 3), Color(1, 1, 1, 0.6))

	# ── Scanner surface hints ──────────────────────────────────────
	if _show_scanner:
		for key: Vector2i in _surface_hints:
			if _grid.get(key, Cell.EMPTY) == Cell.ROCK:
				var wp   := Vector2(key.x * CELL_SIZE, key.y * CELL_SIZE)
				var hint_col: Color = _surface_hints[key]
				draw_rect(
					Rect2(wp.x - hcs, wp.y - hcs, CELL_SIZE, CELL_SIZE),
					Color(hint_col.r, hint_col.g, hint_col.b, 0.38)
				)

	# ── Planet border ──────────────────────────────────────────────
	draw_arc(Vector2.ZERO, PLANET_RADIUS, 0.0, TAU, 80, Color(0.52, 0.40, 0.26), 2.5)

	# ── Laser beam ────────────────────────────────────────────────
	if _laser_alpha > 0.0:
		var a := _laser_alpha
		# Wide glow
		draw_line(_laser_from, _laser_to, Color(0.15, 1.00, 0.45, a * 0.28), 10.0)
		# Core beam
		draw_line(_laser_from, _laser_to, Color(0.35, 1.00, 0.55, a), 3.0)
		# Bright core
		draw_line(_laser_from, _laser_to, Color(0.80, 1.00, 0.85, a * 0.6), 1.5)
