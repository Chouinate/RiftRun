## PlanetSelectScreen.gd
## Shown before each mining round. Player picks one of three planets.
extends Control

const SCREEN_W := 1280.0
const SCREEN_H := 720.0

const STAR_COUNT := 160
var _stars: Array = []
var _time:  float = 0.0

# Per-card mini-planet animation
var _planet_pulse: float = 0.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC4E7A9B2
	for _i in STAR_COUNT:
		_stars.append({
			"pos":          Vector2(rng.randf() * SCREEN_W, rng.randf() * SCREEN_H),
			"r":            rng.randf_range(0.5, 2.0),
			"b":            rng.randf_range(0.3, 1.0),
			"blink_speed":  rng.randf_range(0.4, 1.4),
			"blink_offset": rng.randf() * TAU,
		})
	_build_ui()

func _process(delta: float) -> void:
	_time        += delta
	_planet_pulse += delta
	queue_redraw()

func _draw() -> void:
	# Background
	draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color(0.010, 0.016, 0.040))
	# Stars
	for s: Dictionary in _stars:
		var blink: float = 0.5 + 0.5 * sin(_time * float(s["blink_speed"]) + float(s["blink_offset"]))
		var b: float     = float(s["b"]) * (0.7 + 0.3 * blink)
		draw_circle(s["pos"] as Vector2, float(s["r"]), Color(b, b, b * 1.06))

# ── UI ────────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Header
	var title := Label.new()
	title.text                      = "— SELECT PLANET —"
	title.horizontal_alignment      = HORIZONTAL_ALIGNMENT_CENTER
	title.position                  = Vector2(0, 18)
	title.size                      = Vector2(SCREEN_W, 48)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.05, 0.85, 1.0))
	add_child(title)

	var sub := Label.new()
	sub.text                    = "Round %d of %d  ·  Choose your target" % [GameManager.round_num, GameManager.MAX_ROUNDS]
	sub.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	sub.position                = Vector2(0, 62)
	sub.size                    = Vector2(SCREEN_W, 26)
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.38, 0.55, 0.72))
	add_child(sub)

	# Credits display
	var cred := Label.new()
	cred.text                   = "Credits: " + str(GameManager.credits)
	cred.horizontal_alignment   = HORIZONTAL_ALIGNMENT_CENTER
	cred.position               = Vector2(0, 84)
	cred.size                   = Vector2(SCREEN_W, 22)
	cred.add_theme_font_size_override("font_size", 13)
	cred.add_theme_color_override("font_color", Color(0.15, 1.0, 0.48))
	add_child(cred)

	# Three planet cards
	var configs: Array = GameManager.PLANET_CONFIGS
	var card_w  := 310.0
	var gap     := 40.0
	var total_w := configs.size() * card_w + (configs.size() - 1) * gap
	var sx      := (SCREEN_W - total_w) * 0.5

	for i in configs.size():
		var cfg := configs[i] as Dictionary
		var cx  := sx + i * (card_w + gap)
		_build_planet_card(cfg, Vector2(cx, 118), card_w, 520.0, i)

func _build_planet_card(cfg: Dictionary, pos: Vector2, w: float, h: float, idx: int) -> void:
	var name_str: String = cfg.get("name", "???")
	var desc_str: String = cfg.get("desc", "")
	var rich: float      = cfg.get("richness", 1.0)
	var rare_b: bool     = cfg.get("rare_boost", false)

	# Card background
	var bg := ColorRect.new()
	bg.color    = Color(0.04, 0.07, 0.16, 0.88)
	bg.position = pos
	bg.size     = Vector2(w, h)
	add_child(bg)

	# Card border (drawn via a Panel-like approach using a Label stretch hack)
	var border_node := _mk_label("", pos, Vector2(w, h), 1, Color(0.08, 0.45, 1.0, 0.45))
	border_node.add_theme_stylebox_override("normal", _border_stylebox(Color(0.08, 0.45, 1.0, 0.45)))
	add_child(border_node)

	# Planet name
	var name_lbl := _mk_label(name_str, pos + Vector2(0, 10), Vector2(w, 36), 24, Color(0.15, 0.92, 1.0))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_lbl)

	# Ore richness bar label
	var rich_pct := int(rich * 100.0)
	var rich_col := Color(0.3, 1.0, 0.4) if rich >= 1.0 else Color(1.0, 0.7, 0.3)
	var rich_lbl := _mk_label("Richness: %d%%" % rich_pct,
		pos + Vector2(20, 48), Vector2(w - 40, 20), 13, rich_col)
	add_child(rich_lbl)

	var rare_lbl := _mk_label(
		"Rare core: YES" if rare_b else "Rare core: —",
		pos + Vector2(20, 66), Vector2(w - 40, 18), 12,
		Color(1.0, 0.65, 0.12) if rare_b else Color(0.4, 0.5, 0.6))
	add_child(rare_lbl)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text         = desc_str
	desc_lbl.position     = pos + Vector2(20, 90)
	desc_lbl.size         = Vector2(w - 40, 40)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.60, 0.70, 0.80))
	add_child(desc_lbl)

	# Mini planet preview (drawn via SubViewport substitute — just a Node2D with _draw)
	var planet_node := _PlanetPreview.new(idx, rich, rare_b)
	planet_node.position = pos + Vector2(w * 0.5, 270)
	add_child(planet_node)

	# Select button
	var btn := Button.new()
	btn.text     = "SELECT  ▶"
	btn.position = pos + Vector2(w * 0.5 - 90, h - 60)
	btn.size     = Vector2(180, 44)
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(func(): _on_select(cfg))
	add_child(btn)

func _on_select(cfg: Dictionary) -> void:
	GameManager.planet_config = cfg
	get_tree().change_scene_to_file("res://scenes/GameWorld.tscn")

# ── Helpers ───────────────────────────────────────────────────────
func _mk_label(text: String, pos: Vector2, sz: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text     = text
	l.position = pos
	l.size     = sz
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l

func _border_stylebox(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color           = Color(0, 0, 0, 0)
	sb.border_color       = col
	sb.border_width_left   = 1
	sb.border_width_right  = 1
	sb.border_width_top    = 1
	sb.border_width_bottom = 1
	return sb

# ── Inline mini-planet Node2D ──────────────────────────────────────
class _PlanetPreview extends Node2D:
	var _idx:    int
	var _rich:   float
	var _rare_b: bool
	var _t:      float = 0.0

	func _init(idx: int, rich: float, rare_b: bool) -> void:
		_idx   = idx
		_rich  = rich
		_rare_b = rare_b

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var radius := 90.0
		# Planet body
		var body_col := [
			Color(0.15, 0.35, 0.55),
			Color(0.20, 0.45, 0.25),
			Color(0.45, 0.20, 0.15),
		][_idx]
		draw_circle(Vector2.ZERO, radius, body_col)

		# Surface band stripes
		for band in 4:
			var a_start := band * TAU / 4.0 + _t * 0.05
			var a_end   := a_start + TAU / 8.0
			draw_arc(Vector2.ZERO, radius * 0.72, a_start, a_end, 12,
					 Color(1, 1, 1, 0.06), radius * 0.28)

		# Ore shimmer hints on surface
		var hint_col := Color(1.0, 0.65, 0.12) if _rare_b else Color(0.20, 0.92, 0.45)
		var hint_a   := 0.25 + 0.15 * sin(_t * 2.0 + float(_idx))
		draw_arc(Vector2.ZERO, radius * 0.85, 0.3, 1.1, 12, Color(hint_col.r, hint_col.g, hint_col.b, hint_a), 4.0)
		draw_arc(Vector2.ZERO, radius * 0.75, 2.5, 3.8, 12, Color(hint_col.r, hint_col.g, hint_col.b, hint_a * 0.7), 3.0)

		# Planet border
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.7, 0.8, 0.9, 0.55), 2.0)

		# Atmosphere glow
		draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 48, Color(0.3, 0.7, 1.0, 0.12), 8.0)
