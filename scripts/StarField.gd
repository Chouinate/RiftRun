## StarField.gd
## Draws a deterministic star background and faint nebula blobs.
## Attach to a Node2D in world space (z_index = -9).
extends Node2D

const WORLD_W := 3200.0
const WORLD_H := 2400.0

var _stars: Array   = []
var _nebulae: Array = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xB1F7B0A7  # deterministic layout every run

	# Stars
	for _i in 500:
		_stars.append({
			"pos": Vector2(rng.randf() * WORLD_W, rng.randf() * WORLD_H),
			"r":   rng.randf_range(0.5, 2.2),
			"b":   rng.randf_range(0.3, 1.0),
		})

	# Nebulae (soft coloured blobs)
	var nebula_colors := [
		Color(0.10, 0.05, 0.30, 0.06),  # purple
		Color(0.00, 0.10, 0.30, 0.07),  # deep blue
		Color(0.20, 0.00, 0.10, 0.05),  # dark red
	]
	for _i in 8:
		_nebulae.append({
			"pos":   Vector2(rng.randf() * WORLD_W, rng.randf() * WORLD_H),
			"r":     rng.randf_range(200.0, 450.0),
			"color": nebula_colors[rng.randi() % nebula_colors.size()],
		})

func _draw() -> void:
	# Solid space background
	draw_rect(Rect2(0, 0, WORLD_W, WORLD_H), Color(0.016, 0.024, 0.055))

	# Nebulae
	for n in _nebulae:
		draw_circle(n["pos"], n["r"], n["color"])

	# Stars
	for s in _stars:
		var b: float = s["b"]
		draw_circle(s["pos"], s["r"], Color(b, b, b * 1.08))
