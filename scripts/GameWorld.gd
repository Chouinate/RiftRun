## GameWorld.gd
## Orchestrates a single mining round:
##   – Spawns planet and ship
##   – Handles click-to-drill input
##   – Manages shot count, price timer, HUD
##   – Transitions to ShopScreen or EndScreen
extends Node2D

# ── Layout constants ───────────────────────────────────────────────
const SCREEN_W      := 1280.0
const SCREEN_H      := 720.0
const PLANET_POS    := Vector2(640.0, 385.0)   # planet centre on screen
const ORBIT_RADIUS  := 280.0                    # must match Ship.ORBIT_RADIUS

# ── Price timing ───────────────────────────────────────────────────
const PRICE_INTERVAL_MIN := 6.0
const PRICE_INTERVAL_MAX := 12.0

# ── Preloads ───────────────────────────────────────────────────────
const PlanetScript := preload("res://scripts/Planet.gd")
const ShipScript   := preload("res://scripts/Ship.gd")

# ── Node refs ──────────────────────────────────────────────────────
var planet: Node2D
var ship:   Node2D

# ── Round state ────────────────────────────────────────────────────
var _shots_left:    int   = 0
var _round_ended:   bool  = false
var _price_timer:   float = 0.0
var _next_price_cd: float = 8.0

# ── HUD node refs ──────────────────────────────────────────────────
var _lbl_credits:     Label
var _lbl_cargo:       Label
var _lbl_round:       Label
var _lbl_shots:       Label
var _lbl_price_alpha: Label
var _lbl_price_beta:  Label
var _lbl_trend_alpha: Label
var _lbl_trend_beta:  Label
var _lbl_ore_left:    Label
var _sell_popup:      Label
var _popup_timer:     float = 0.0
var _cargo_full_lbl:  Label

# ── Sell station display nodes (drawn in world) ────────────────────
var _station_alpha: Node2D
var _station_beta:  Node2D

func _ready() -> void:
	_spawn_planet()
	_spawn_ship()
	_spawn_stations()
	_build_hud()
	_update_price_display()
	_shots_left = GameManager.get_laser_shots()
	_update_shots_label()

# ─────────────────────────────────────────────────────────────────
# Spawning
# ─────────────────────────────────────────────────────────────────
func _spawn_planet() -> void:
	planet          = Node2D.new()
	planet.position = PLANET_POS
	planet.set_script(PlanetScript)
	add_child(planet)
	planet.ore_mined.connect(_on_ore_mined)
	planet.setup(GameManager.round_num, GameManager.has_scanner())

func _spawn_ship() -> void:
	ship          = Node2D.new()
	ship.position = PLANET_POS   # will be overridden by Ship._ready
	ship.set_script(ShipScript)
	# Ship's _refresh_position puts it relative to its own position being planet centre,
	# so we actually parent it under planet for local-space orbit.
	planet.add_child(ship)
	ship.laser_fired.connect(_on_laser_fired)

func _spawn_stations() -> void:
	# Two visual corp stations — purely decorative, selling is via HUD buttons
	_station_alpha = _make_station("alpha", Vector2(80.0, PLANET_POS.y))
	add_child(_station_alpha)

	_station_beta = _make_station("beta", Vector2(SCREEN_W - 80.0, PLANET_POS.y))
	add_child(_station_beta)

func _make_station(corp: String, pos: Vector2) -> Node2D:
	var stn := Node2D.new()
	stn.position = pos
	stn.set_meta("corp", corp)
	return stn

# ─────────────────────────────────────────────────────────────────
# Input
# ─────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if _round_ended:
		return
	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if ship.is_busy():
		return
	if _shots_left <= 0:
		return

	# Convert click to planet-local coordinates
	var local_click := event.position - PLANET_POS
	# Accept clicks within ~1.5× planet radius of planet centre
	if local_click.length() > planet.PLANET_RADIUS * 1.55:
		return

	var angle := atan2(local_click.y, local_click.x)
	ship.move_to_angle(angle)
	_shots_left -= 1
	_update_shots_label()

# ─────────────────────────────────────────────────────────────────
# Per-frame
# ─────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _round_ended:
		return

	# Price timer
	_price_timer += delta
	if _price_timer >= _next_price_cd:
		_price_timer   = 0.0
		_next_price_cd = randf_range(PRICE_INTERVAL_MIN, PRICE_INTERVAL_MAX)
		GameManager.update_prices()

	# HUD refresh
	_lbl_credits.text = "Credits: " + str(GameManager.credits)
	_lbl_cargo.text   = "Cargo: " + str(GameManager.cargo) + " / " + str(GameManager.get_cargo_cap())
	_lbl_round.text   = "Round " + str(GameManager.round_num) + " / " + str(GameManager.MAX_ROUNDS)
	_lbl_ore_left.text = "Ore: " + str(planet.get_ore_remaining()) + " cells"

	_cargo_full_lbl.visible = GameManager.cargo >= GameManager.get_cargo_cap()

	# Sell popup fade
	if _popup_timer > 0.0:
		_popup_timer -= delta
		if _popup_timer <= 0.0:
			_sell_popup.visible = false

	# Station redraw
	_station_alpha.queue_redraw()
	_station_beta.queue_redraw()

	# Check round-end condition: no shots left AND ship is idle
	if _shots_left <= 0 and not ship.is_busy():
		_end_round()

func _draw() -> void:
	# Background
	draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color(0.012, 0.018, 0.042))
	_draw_stars()
	_draw_orbit_ring()
	_draw_stations()

func _draw_stars() -> void:
	# Seeded stars so they don't flicker each frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xB1F7B0A7
	for _i in 280:
		var px := rng.randf() * SCREEN_W
		var py := rng.randf() * SCREEN_H
		var b  := rng.randf_range(0.25, 0.85)
		var r  := rng.randf_range(0.4, 1.8)
		draw_circle(Vector2(px, py), r, Color(b, b, b * 1.06))

func _draw_orbit_ring() -> void:
	# Dashed orbit circle around planet
	var steps  := 72
	var on_len := 0.06 * TAU   # arc length of dash
	var off_len:= 0.04 * TAU
	var t      := 0.0
	while t < TAU:
		var t_end := minf(t + on_len, TAU)
		draw_arc(PLANET_POS, ORBIT_RADIUS, t, t_end, 8, Color(0.2, 0.5, 0.8, 0.22), 1.2)
		t += on_len + off_len

func _draw_stations() -> void:
	# Simple station silhouettes drawn directly here
	_draw_one_station("alpha", Vector2(80.0, PLANET_POS.y))
	_draw_one_station("beta",  Vector2(SCREEN_W - 80.0, PLANET_POS.y))

func _draw_one_station(corp: String, pos: Vector2) -> void:
	var base_col := Color(0.08, 0.45, 1.0) if corp == "alpha" else Color(1.0, 0.45, 0.08)
	# Main body
	draw_rect(Rect2(pos.x - 22, pos.y - 28, 44, 56), base_col * Color(1,1,1,0.2))
	draw_rect(Rect2(pos.x - 22, pos.y - 28, 44, 56), base_col * Color(1,1,1,0.6), false, 1.5)
	# Solar panel arms
	draw_line(pos + Vector2(-22, -10), pos + Vector2(-42, -10), base_col * Color(1,1,1,0.5), 3.0)
	draw_line(pos + Vector2(-42, -16), pos + Vector2(-42, -4),  base_col * Color(1,1,1,0.5), 3.0)
	draw_line(pos + Vector2( 22, -10), pos + Vector2( 42, -10), base_col * Color(1,1,1,0.5), 3.0)
	draw_line(pos + Vector2( 42, -16), pos + Vector2( 42, -4),  base_col * Color(1,1,1,0.5), 3.0)
	# Docking light
	var blink := fmod(Time.get_ticks_msec() * 0.001, 1.0) > 0.5
	draw_circle(pos + Vector2(0, 18), 4.0, base_col if blink else base_col * Color(1,1,1,0.2))

# ─────────────────────────────────────────────────────────────────
# HUD
# ─────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	# Top bar background
	var bar := ColorRect.new()
	bar.color = Color(0.04, 0.07, 0.14, 0.93)
	bar.size  = Vector2(SCREEN_W, 58)
	hud.add_child(bar)

	# ── Left: credits / cargo / round ─────────────────────────────
	_lbl_credits = _mk(hud, "Credits: 0",   Vector2(12,  4), 18, Color(0.15, 1.00, 0.48))
	_lbl_cargo   = _mk(hud, "Cargo: 0 / 15",Vector2(12, 27), 14, Color(0.35, 0.78, 1.00))
	_lbl_round   = _mk(hud, "Round 1 / 5",  Vector2(12, 44), 11, Color(0.45, 0.56, 0.68))

	# ── Centre: price board ────────────────────────────────────────
	_build_price_hud(hud)

	# ── Right: shots / ore ────────────────────────────────────────
	_lbl_shots    = _mk(hud, "Shots: 15",    Vector2(1090, 4),  18, Color(1.00, 0.82, 0.20))
	_lbl_ore_left = _mk(hud, "Ore: --",      Vector2(1100, 30), 14, Color(0.55, 1.00, 0.75))

	# ── Sell buttons at bottom ─────────────────────────────────────
	_build_sell_buttons(hud)

	# ── Sell popup ────────────────────────────────────────────────
	_sell_popup = _mk(hud, "", Vector2(490, 68), 22, Color(0.15, 1.0, 0.48))
	_sell_popup.visible = false

	# ── Cargo-full warning ────────────────────────────────────────
	_cargo_full_lbl = _mk(hud, "⚠ CARGO FULL  —  SELL BEFORE MINING MORE!",
		Vector2(310, 90), 17, Color(1.0, 0.82, 0.10))
	_cargo_full_lbl.visible = false

	# ── No-shots warning ─────────────────────────────────────────
	# (handled via shots label colour in _update_shots_label)

func _build_price_hud(hud: CanvasLayer) -> void:
	var bg_a := ColorRect.new()
	bg_a.color    = Color(0.02, 0.14, 0.30, 0.90)
	bg_a.size     = Vector2(152, 58)
	bg_a.position = Vector2(488, 0)
	hud.add_child(bg_a)

	_mk(hud, "ASTRA CO.", Vector2(496, 3), 11, Color(0.30, 0.70, 1.00))
	_lbl_price_alpha = _mk(hud, "-- cr", Vector2(496, 18), 20, Color(0.20, 0.70, 1.00))
	_lbl_trend_alpha = _mk(hud, "",      Vector2(570, 22), 16, Color.WHITE)

	var bg_b := ColorRect.new()
	bg_b.color    = Color(0.28, 0.10, 0.02, 0.90)
	bg_b.size     = Vector2(152, 58)
	bg_b.position = Vector2(644, 0)
	hud.add_child(bg_b)

	_mk(hud, "VEGA IND.", Vector2(652, 3), 11, Color(1.00, 0.58, 0.20))
	_lbl_price_beta  = _mk(hud, "-- cr", Vector2(652, 18), 20, Color(1.00, 0.65, 0.20))
	_lbl_trend_beta  = _mk(hud, "",      Vector2(726, 22), 16, Color.WHITE)

func _build_sell_buttons(hud: CanvasLayer) -> void:
	# Bottom sell bar
	var sell_bar := ColorRect.new()
	sell_bar.color    = Color(0.04, 0.07, 0.14, 0.90)
	sell_bar.size     = Vector2(SCREEN_W, 46)
	sell_bar.position = Vector2(0, SCREEN_H - 46)
	hud.add_child(sell_bar)

	# Sell-to-Alpha button (left)
	var btn_a := _make_sell_btn("SELL TO ASTRA CO.", Vector2(40, SCREEN_H - 40))
	btn_a.pressed.connect(func(): _on_sell("alpha"))
	hud.add_child(btn_a)

	# Sell-to-Beta button (right)
	var btn_b := _make_sell_btn("SELL TO VEGA IND.", Vector2(SCREEN_W - 280, SCREEN_H - 40))
	btn_b.pressed.connect(func(): _on_sell("beta"))
	hud.add_child(btn_b)

	# Tip in centre
	_mk(hud, "click the planet to drill", Vector2(500, SCREEN_H - 36), 13, Color(0.40, 0.50, 0.62))

func _make_sell_btn(text: String, pos: Vector2) -> Button:
	var btn := Button.new()
	btn.text     = text
	btn.position = pos
	btn.size     = Vector2(240, 34)
	btn.add_theme_font_size_override("font_size", 14)
	return btn

func _mk(parent: Node, text: String, pos: Vector2, fs: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text     = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", fs)
	lbl.add_theme_color_override("font_color", col)
	parent.add_child(lbl)
	return lbl

# ─────────────────────────────────────────────────────────────────
# Signal handlers
# ─────────────────────────────────────────────────────────────────
func _on_laser_fired(angle: float) -> void:
	var mined := planet.fire_laser(
		angle,
		GameManager.get_laser_depth(),
		GameManager.get_laser_width()
	)
	if mined > 0:
		GameManager.add_cargo(mined)

func _on_ore_mined(_ore_type: int, _value: int) -> void:
	pass  # total handled in _on_laser_fired return value

func _on_sell(corp: String) -> void:
	if GameManager.cargo <= 0:
		return
	var earned := GameManager.sell_cargo(corp)
	if earned > 0:
		_sell_popup.text    = "+" + str(earned) + " credits!"
		_sell_popup.visible = true
		_popup_timer        = 2.5

func _update_shots_label() -> void:
	_lbl_shots.text = "Shots: " + str(_shots_left)
	var col := Color(1.0, 0.82, 0.20) if _shots_left > 3 else Color(1.0, 0.30, 0.30)
	_lbl_shots.add_theme_color_override("font_color", col)

func _update_price_display() -> void:
	var pa  := GameManager.price_alpha
	var pb  := GameManager.price_beta
	var ppa := GameManager.prev_alpha
	var ppb := GameManager.prev_beta

	_lbl_price_alpha.text = str(pa) + " cr"
	_lbl_price_beta.text  = str(pb) + " cr"

	_lbl_trend_alpha.text = _trend_ch(pa, ppa)
	_lbl_trend_alpha.add_theme_color_override("font_color", _trend_col(pa, ppa))
	_lbl_trend_beta.text  = _trend_ch(pb, ppb)
	_lbl_trend_beta.add_theme_color_override("font_color", _trend_col(pb, ppb))

func _trend_ch(now: int, prev: int) -> String:
	if now > prev: return "▲"
	if now < prev: return "▼"
	return "─"

func _trend_col(now: int, prev: int) -> Color:
	if now > prev: return Color(0.2, 1.0, 0.3)
	if now < prev: return Color(1.0, 0.3, 0.3)
	return Color(0.7, 0.7, 0.7)

# ─────────────────────────────────────────────────────────────────
# Round end
# ─────────────────────────────────────────────────────────────────
func _end_round() -> void:
	if _round_ended:
		return
	_round_ended = true

	if GameManager.round_num >= GameManager.MAX_ROUNDS:
		await get_tree().create_timer(0.8).timeout
		get_tree().change_scene_to_file("res://scenes/EndScreen.tscn")
	else:
		GameManager.prepare_next_round()
		await get_tree().create_timer(0.8).timeout
		get_tree().change_scene_to_file("res://scenes/ShopScreen.tscn")
