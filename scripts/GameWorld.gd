extends Node2D

const WORLD_W := 3200.0
const WORLD_H := 2400.0

const ROUND_TIME          := 90.0   # seconds
const PRICE_INTERVAL_MIN  := 5.0
const PRICE_INTERVAL_MAX  := 10.0

const ORE_SCENE      := preload("res://scenes/Ore.tscn")
const CORP_DOCK_SCENE := preload("res://scenes/CorpDock.tscn")

# ── State ──────────────────────────────────────────────────────────
var _time_left: float    = ROUND_TIME
var _price_timer: float  = 0.0
var _next_price_cd: float = 7.0
var _ore_left: int       = 0
var _round_ended: bool   = false

# ── HUD node refs ─────────────────────────────────────────────────
var _lbl_credits:     Label
var _lbl_cargo:       Label
var _lbl_round:       Label
var _lbl_timer:       Label
var _lbl_ore_left:    Label
var _lbl_price_alpha: Label
var _lbl_price_beta:  Label
var _lbl_trend_alpha: Label
var _lbl_trend_beta:  Label
var _sell_popup:      Label
var _cargo_full_lbl:  Label
var _popup_timer: float = 0.0
var _warn_flash: float  = 0.0  # countdown flash when price is about to change

@onready var ship: CharacterBody2D = $Ship
@onready var ore_layer: Node2D     = $OreLayer
@onready var dock_layer: Node2D    = $DockLayer
@onready var camera: Camera2D      = $Ship/Camera2D

func _ready() -> void:
	_setup_background()
	_setup_camera()
	_spawn_docks()
	_spawn_ores()
	_build_hud()

	ship.ore_collected.connect(_on_ore_collected)
	GameManager.prices_changed.connect(_on_prices_changed)
	GameManager.cargo_changed.connect(_on_cargo_changed)
	GameManager.credits_changed.connect(_on_credits_changed)

	ship.position = Vector2(WORLD_W * 0.5, WORLD_H * 0.5)
	_update_price_display()

func _setup_camera() -> void:
	camera.limit_left   = 0
	camera.limit_top    = 0
	camera.limit_right  = int(WORLD_W)
	camera.limit_bottom = int(WORLD_H)

func _setup_background() -> void:
	var sf_node := Node2D.new()
	sf_node.z_index = -10
	sf_node.set_script(load("res://scripts/StarField.gd"))
	add_child(sf_node)

# ── Spawning ──────────────────────────────────────────────────────
func _spawn_docks() -> void:
	var dock_a: Area2D = CORP_DOCK_SCENE.instantiate()
	dock_a.corp_id     = "alpha"
	dock_a.position    = Vector2(200.0, WORLD_H * 0.5)
	dock_a.cargo_sold.connect(_on_cargo_sold)
	dock_layer.add_child(dock_a)

	var dock_b: Area2D = CORP_DOCK_SCENE.instantiate()
	dock_b.corp_id     = "beta"
	dock_b.position    = Vector2(WORLD_W - 200.0, WORLD_H * 0.5)
	dock_b.cargo_sold.connect(_on_cargo_sold)
	dock_layer.add_child(dock_b)

func _spawn_ores() -> void:
	# More ores and richer crystals in later rounds
	var count := 28 + (GameManager.round_num - 1) * 9
	_ore_left = count

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# Keep ores away from dock zones and map edges
	var exclude_left  := Rect2(0, WORLD_H * 0.3, 380, WORLD_H * 0.4)
	var exclude_right := Rect2(WORLD_W - 380, WORLD_H * 0.3, 380, WORLD_H * 0.4)

	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 20:
		attempts += 1
		var pos := Vector2(
			rng.randf_range(150.0, WORLD_W - 150.0),
			rng.randf_range(150.0, WORLD_H - 150.0)
		)
		if exclude_left.has_point(pos) or exclude_right.has_point(pos):
			continue

		var ore: Area2D = ORE_SCENE.instantiate()
		ore.position    = pos

		# Richness: rare ore more common in later rounds
		var roll := rng.randf()
		var rare_chance  := 0.06 + (GameManager.round_num - 1) * 0.04
		var uncommon_chance := 0.28 + (GameManager.round_num - 1) * 0.04
		if roll < rare_chance:
			ore.ore_value = 3
		elif roll < rare_chance + uncommon_chance:
			ore.ore_value = 2
		else:
			ore.ore_value = 1

		ore.depleted.connect(_on_ore_depleted)
		ore_layer.add_child(ore)
		placed += 1

	_ore_left = placed

# ── HUD ───────────────────────────────────────────────────────────
func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	# Top bar background
	var bar := ColorRect.new()
	bar.color = Color(0.04, 0.07, 0.14, 0.92)
	bar.size  = Vector2(1280, 60)
	hud.add_child(bar)

	# ── Left column: credits / cargo / round ──────────────────────
	_lbl_credits = _mk_lbl("Credits: 0", Vector2(12, 4), 18, Color(0.15, 1.0, 0.48))
	hud.add_child(_lbl_credits)

	_lbl_cargo = _mk_lbl("Cargo: 0 / 10", Vector2(12, 27), 14, Color(0.35, 0.78, 1.0))
	hud.add_child(_lbl_cargo)

	_lbl_round = _mk_lbl("Round 1 / 5", Vector2(12, 45), 11, Color(0.45, 0.56, 0.68))
	hud.add_child(_lbl_round)

	# ── Center: price board ───────────────────────────────────────
	_build_price_hud(hud)

	# ── Right column: timer / ore count ──────────────────────────
	_lbl_timer = _mk_lbl("90s", Vector2(1190, 4), 22, Color(1.0, 0.48, 0.08))
	hud.add_child(_lbl_timer)

	_lbl_ore_left = _mk_lbl("Ore: --", Vector2(1155, 35), 14, Color(0.55, 1.0, 0.75))
	hud.add_child(_lbl_ore_left)

	# ── Sell popup (centre, just below bar) ───────────────────────
	_sell_popup = _mk_lbl("", Vector2(490, 70), 22, Color(0.15, 1.0, 0.48))
	_sell_popup.visible = false
	hud.add_child(_sell_popup)

	# ── Cargo-full warning ────────────────────────────────────────
	_cargo_full_lbl = _mk_lbl("⚠ CARGO FULL — SELL NOW!", Vector2(380, 96), 18, Color(1.0, 0.82, 0.0))
	_cargo_full_lbl.visible = false
	hud.add_child(_cargo_full_lbl)

	# ── Dock direction arrows ─────────────────────────────────────
	var arrow_lbl_a := _mk_lbl("◀ ASTRA CO.", Vector2(8, 65), 13, Color(0.1, 0.55, 1.0))
	hud.add_child(arrow_lbl_a)

	var arrow_lbl_b := _mk_lbl("VEGA IND. ▶", Vector2(1150, 65), 13, Color(1.0, 0.50, 0.10))
	hud.add_child(arrow_lbl_b)

func _build_price_hud(hud: CanvasLayer) -> void:
	# Alpha panel
	var bg_a := ColorRect.new()
	bg_a.color    = Color(0.02, 0.15, 0.32, 0.88)
	bg_a.size     = Vector2(150, 60)
	bg_a.position = Vector2(488, 0)
	hud.add_child(bg_a)

	var name_a := _mk_lbl("ASTRA CO.", Vector2(496, 3), 11, Color(0.3, 0.7, 1.0))
	hud.add_child(name_a)

	_lbl_price_alpha = _mk_lbl("-- cr", Vector2(496, 18), 20, Color(0.2, 0.7, 1.0))
	hud.add_child(_lbl_price_alpha)

	_lbl_trend_alpha = _mk_lbl("", Vector2(570, 22), 16, Color.WHITE)
	hud.add_child(_lbl_trend_alpha)

	# Beta panel
	var bg_b := ColorRect.new()
	bg_b.color    = Color(0.28, 0.10, 0.02, 0.88)
	bg_b.size     = Vector2(150, 60)
	bg_b.position = Vector2(642, 0)
	hud.add_child(bg_b)

	var name_b := _mk_lbl("VEGA IND.", Vector2(650, 3), 11, Color(1.0, 0.58, 0.2))
	hud.add_child(name_b)

	_lbl_price_beta = _mk_lbl("-- cr", Vector2(650, 18), 20, Color(1.0, 0.65, 0.2))
	hud.add_child(_lbl_price_beta)

	_lbl_trend_beta = _mk_lbl("", Vector2(724, 22), 16, Color.WHITE)
	hud.add_child(_lbl_trend_beta)

func _mk_lbl(text: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text     = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

# ── Per-frame ─────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _round_ended:
		return

	# Round timer
	_time_left -= delta
	var secs := int(ceil(_time_left))
	_lbl_timer.text = str(secs) + "s"

	if _time_left <= 15.0:
		var flash_on := fmod(_time_left, 0.6) > 0.3
		_lbl_timer.add_theme_color_override("font_color",
			Color(1.0, 0.15, 0.15) if flash_on else Color(1.0, 0.48, 0.08))

	if _time_left <= 0.0 or _ore_left <= 0:
		_end_round()
		return

	# Price change countdown
	_price_timer += delta
	var warning_threshold := 3.0 if GameManager.has_market_feed() else 0.0
	if _price_timer >= _next_price_cd - warning_threshold and warning_threshold > 0.0:
		# Flash price labels to warn of incoming change
		var flash := fmod(_price_timer, 0.5) > 0.25
		_lbl_price_alpha.add_theme_color_override("font_color",
			Color(1.0, 1.0, 0.2) if flash else Color(0.2, 0.7, 1.0))
		_lbl_price_beta.add_theme_color_override("font_color",
			Color(1.0, 1.0, 0.2) if flash else Color(1.0, 0.65, 0.2))

	if _price_timer >= _next_price_cd:
		_price_timer   = 0.0
		_next_price_cd = randf_range(PRICE_INTERVAL_MIN, PRICE_INTERVAL_MAX)
		GameManager.update_prices()

	# HUD refresh
	_lbl_credits.text  = "Credits: " + str(GameManager.credits)
	_lbl_cargo.text    = "Cargo: " + str(GameManager.cargo) + " / " + str(GameManager.get_cargo_cap())
	_lbl_round.text    = "Round " + str(GameManager.round_num) + " / " + str(GameManager.MAX_ROUNDS)
	_lbl_ore_left.text = "Ore: " + str(_ore_left)

	# Cargo full warning
	_cargo_full_lbl.visible = GameManager.cargo >= GameManager.get_cargo_cap()

	# Sell popup fade
	if _popup_timer > 0.0:
		_popup_timer -= delta
		if _popup_timer <= 0.0:
			_sell_popup.visible = false

# ── Signal handlers ───────────────────────────────────────────────
func _on_ore_depleted() -> void:
	_ore_left = max(0, _ore_left - 1)

func _on_ore_collected(_amount: int) -> void:
	pass  # tracked via depleted signal

func _on_cargo_sold(earned: int, _corp: String) -> void:
	_sell_popup.text    = "+" + str(earned) + " credits!"
	_sell_popup.visible = true
	_popup_timer        = 2.2

func _on_prices_changed(a: int, b: int, _pa: int, _pb: int) -> void:
	_update_price_display()

func _on_cargo_changed(_cargo: int, _cap: int) -> void:
	pass  # HUD updates in _process

func _on_credits_changed(_val: int) -> void:
	pass  # HUD updates in _process

func _update_price_display() -> void:
	var pa := GameManager.price_alpha
	var pb := GameManager.price_beta
	var ppa := GameManager.prev_alpha
	var ppb := GameManager.prev_beta

	_lbl_price_alpha.text = str(pa) + " cr"
	_lbl_price_beta.text  = str(pb) + " cr"

	_lbl_trend_alpha.text = _trend_char(pa, ppa)
	_lbl_trend_alpha.add_theme_color_override("font_color", _trend_color(pa, ppa))

	_lbl_trend_beta.text = _trend_char(pb, ppb)
	_lbl_trend_beta.add_theme_color_override("font_color", _trend_color(pb, ppb))

	# Reset price label colours (may have been flashing)
	_lbl_price_alpha.add_theme_color_override("font_color", Color(0.2, 0.7, 1.0))
	_lbl_price_beta.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))

func _trend_char(now: int, prev: int) -> String:
	if now > prev: return "▲"
	if now < prev: return "▼"
	return "─"

func _trend_color(now: int, prev: int) -> Color:
	if now > prev: return Color(0.2, 1.0, 0.3)
	if now < prev: return Color(1.0, 0.3, 0.3)
	return Color(0.7, 0.7, 0.7)

# ── Round end ─────────────────────────────────────────────────────
func _end_round() -> void:
	if _round_ended:
		return
	_round_ended = true

	ship.stop_round()

	if GameManager.round_num >= GameManager.MAX_ROUNDS:
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://scenes/EndScreen.tscn")
	else:
		GameManager.prepare_next_round()
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://scenes/ShopScreen.tscn")
