extends Node

# ── Signals ──────────────────────────────────────────────────────
signal credits_changed(new_val: int)
signal cargo_changed(cargo: int, cap: int)
signal prices_changed(alpha: int, beta: int, prev_alpha: int, prev_beta: int)

# ── Constants ─────────────────────────────────────────────────────
const MAX_ROUNDS: int = 5

# ── Planet configs (shown on selection screen each round) ─────────
const PLANET_CONFIGS: Array = [
	{
		"name": "IXION-7",
		"desc": "Shallow deposits, fast to map.",
		"richness": 1.0,
		"rare_boost": false,
	},
	{
		"name": "CERES-3",
		"desc": "Balanced ore throughout the crust.",
		"richness": 1.2,
		"rare_boost": false,
	},
	{
		"name": "DEEP-NULL",
		"desc": "Sparse surface, rich rare core.",
		"richness": 0.85,
		"rare_boost": true,
	},
]

# ── Player State ─────────────────────────────────────────────────
var credits:   int        = 0
var cargo:     int        = 0
var round_num: int        = 1
var planet_config: Dictionary = PLANET_CONFIGS[0]

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
		"name":       "Rover Scanner",
		"desc":       "Upgrades rover scan quality — reveals hints faster each round.",
		"level": 0,  "max_level": 4,
		"base_cost":  200, "cost_scale": 1.65
	},
	"cargo_hold": {
		"name":       "Cargo Hold",
		"desc":       "Increase max cargo capacity by 15 units.",
		"level": 0,  "max_level": 4,
		"base_cost":  130, "cost_scale": 1.60
	},
	"pod_speed": {
		"name":       "Pod Drive",
		"desc":       "Cargo pod flies faster to the station.",
		"level": 0,  "max_level": 4,
		"base_cost":  150, "cost_scale": 1.70
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

## Seconds the rover takes to complete its scan (reduced by Scanner upgrade).
func get_scan_delay() -> float:
	return maxf(1.0, 8.0 - upgrades["scanner"]["level"] * 1.75)

func get_cargo_cap() -> int:
	return 15 + upgrades["cargo_hold"]["level"] * 15

func get_pod_speed() -> float:
	return 130.0 + upgrades["pod_speed"]["level"] * 55.0

# ── Upgrade helpers ───────────────────────────────────────────────
func get_upgrade_cost(key: String) -> int:
	var u: Dictionary = upgrades[key]
	return int(u["base_cost"] * pow(u["cost_scale"], u["level"]))

func can_afford_upgrade(key: String) -> bool:
	var u: Dictionary = upgrades[key]
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

	# Anti-correlated drift: shared swing pushes the two prices in opposite directions
	var swing := randi_range(-7, 7)
	price_alpha = clamp(price_alpha + swing + randi_range(-2, 2), 8, 58)
	price_beta  = clamp(price_beta  - swing + randi_range(-2, 2), 8, 58)

	# Occasional individual spikes / crashes
	if randf() < 0.10: price_alpha = randi_range(38, 58)
	if randf() < 0.10: price_beta  = randi_range(38, 58)
	if randf() < 0.04: price_alpha = randi_range(8, 18)
	if randf() < 0.04: price_beta  = randi_range(8, 18)

	emit_signal("prices_changed", price_alpha, price_beta, prev_alpha, prev_beta)

# ── Game flow ─────────────────────────────────────────────────────
func reset_for_new_game() -> void:
	credits       = 0
	cargo         = 0
	round_num     = 1
	planet_config = PLANET_CONFIGS[0]
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
