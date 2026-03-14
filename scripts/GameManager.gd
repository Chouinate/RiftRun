extends Node

# ── Signals ──────────────────────────────────────────────────────
signal credits_changed(new_val: int)
signal cargo_changed(cargo: int, cap: int)
signal prices_changed(alpha: int, beta: int, prev_alpha: int, prev_beta: int)

# ── Constants ─────────────────────────────────────────────────────
const MAX_ROUNDS: int = 5

# ── Player State ─────────────────────────────────────────────────
var credits:  int = 0
var cargo:    int = 0
var round_num: int = 1

# ── Market ───────────────────────────────────────────────────────
var price_alpha: int = 20
var price_beta:  int = 18
var prev_alpha:  int = 20
var prev_beta:   int = 18

# ── Upgrades ─────────────────────────────────────────────────────
var upgrades: Dictionary = {
	"laser_shots": {
		"name":       "Extra Shots",
		"desc":       "Gain 5 additional laser shots each round.",
		"level": 0,  "max_level": 5,
		"base_cost":  100, "cost_scale": 1.65
	},
	"deep_beam": {
		"name":       "Deep Beam",
		"desc":       "Laser penetrates deeper into the planet.",
		"level": 0,  "max_level": 4,
		"base_cost":  160, "cost_scale": 1.80
	},
	"wide_beam": {
		"name":       "Wide Beam",
		"desc":       "Beam is wider — mines adjacent columns per shot.",
		"level": 0,  "max_level": 3,
		"base_cost":  220, "cost_scale": 2.00
	},
	"scanner": {
		"name":       "Surface Scanner",
		"desc":       "Tints the planet surface where ore lies beneath.",
		"level": 0,  "max_level": 1,
		"base_cost":  320, "cost_scale": 1.00
	},
	"cargo_hold": {
		"name":       "Cargo Hold",
		"desc":       "Increase max cargo capacity by 15 units.",
		"level": 0,  "max_level": 4,
		"base_cost":  130, "cost_scale": 1.60
	},
}

# ── Derived stat helpers ──────────────────────────────────────────
func get_laser_shots() -> int:
	return 15 + upgrades["laser_shots"]["level"] * 5

func get_laser_depth() -> float:
	## fraction of planet radius the laser reaches (0.55 base → 1.0 max)
	return minf(1.0, 0.55 + upgrades["deep_beam"]["level"] * 0.115)

func get_laser_width() -> int:
	## extra cell columns each side of centre (0 = single column)
	return upgrades["wide_beam"]["level"]

func has_scanner() -> bool:
	return upgrades["scanner"]["level"] > 0

func get_cargo_cap() -> int:
	return 15 + upgrades["cargo_hold"]["level"] * 15

# ── Upgrade helpers ───────────────────────────────────────────────
func get_upgrade_cost(key: String) -> int:
	var u := upgrades[key]
	return int(u["base_cost"] * pow(u["cost_scale"], u["level"]))

func can_afford_upgrade(key: String) -> bool:
	var u := upgrades[key]
	return u["level"] < u["max_level"] and credits >= get_upgrade_cost(key)

func buy_upgrade(key: String) -> bool:
	if not can_afford_upgrade(key):
		return false
	credits -= get_upgrade_cost(key)
	upgrades[key]["level"] += 1
	emit_signal("credits_changed", credits)
	return true

# ── Cargo / Credits ───────────────────────────────────────────────
func add_cargo(amount: int) -> void:
	var cap := get_cargo_cap()
	cargo   = mini(cargo + amount, cap)
	emit_signal("cargo_changed", cargo, cap)

func sell_cargo(corp: String) -> int:
	if cargo <= 0:
		return 0
	var price  := price_alpha if corp == "alpha" else price_beta
	var earned := cargo * price
	credits    += earned
	cargo       = 0
	emit_signal("credits_changed", credits)
	emit_signal("cargo_changed", 0, get_cargo_cap())
	return earned

# ── Market ────────────────────────────────────────────────────────
func update_prices() -> void:
	prev_alpha = price_alpha
	prev_beta  = price_beta

	price_alpha = clamp(price_alpha + randi_range(-9, 9), 8, 58)
	price_beta  = clamp(price_beta  + randi_range(-9, 9), 8, 58)

	if randf() < 0.12: price_alpha = randi_range(38, 58)
	if randf() < 0.12: price_beta  = randi_range(38, 58)
	if randf() < 0.06:
		price_alpha = randi_range(8, 18)
		price_beta  = randi_range(8, 18)

	emit_signal("prices_changed", price_alpha, price_beta, prev_alpha, prev_beta)

# ── Game flow ─────────────────────────────────────────────────────
func reset_for_new_game() -> void:
	credits   = 0
	cargo     = 0
	round_num = 1
	for key in upgrades:
		upgrades[key]["level"] = 0
	price_alpha = randi_range(15, 30)
	price_beta  = randi_range(15, 30)
	prev_alpha  = price_alpha
	prev_beta   = price_beta

func prepare_next_round() -> void:
	cargo = 0
	round_num += 1
	update_prices()
