extends Node

# ── Signals ──────────────────────────────────────────────────────
signal credits_changed(new_val: int)
signal cargo_changed(cargo: int, cap: int)
signal prices_changed(alpha: int, beta: int, prev_alpha: int, prev_beta: int)

# ── Constants ─────────────────────────────────────────────────────
const MAX_ROUNDS: int = 5

# ── Player State ─────────────────────────────────────────────────
var credits: int = 0
var cargo: int = 0
var round_num: int = 1

# ── Market ───────────────────────────────────────────────────────
var price_alpha: int = 20
var price_beta: int = 18
var prev_alpha: int = 20
var prev_beta: int = 18

# ── Upgrades ─────────────────────────────────────────────────────
# level, max_level, base_cost, cost_scale (multiplier per level bought)
var upgrades: Dictionary = {
	"cargo_hold": {
		"name": "Cargo Hold",
		"desc": "Expand your cargo bay by 10 units per level.",
		"level": 0, "max_level": 4,
		"base_cost": 150, "cost_scale": 1.8
	},
	"thrusters": {
		"name": "Thrusters",
		"desc": "Increase ship movement speed.",
		"level": 0, "max_level": 4,
		"base_cost": 120, "cost_scale": 1.7
	},
	"mining_laser": {
		"name": "Mining Laser",
		"desc": "Mine crystals faster per level.",
		"level": 0, "max_level": 4,
		"base_cost": 130, "cost_scale": 1.7
	},
	"tractor_beam": {
		"name": "Tractor Beam",
		"desc": "Increase ore collection radius.",
		"level": 0, "max_level": 3,
		"base_cost": 200, "cost_scale": 2.0
	},
	"market_feed": {
		"name": "Market Feed",
		"desc": "Price change warning flashes 3s early.",
		"level": 0, "max_level": 1,
		"base_cost": 350, "cost_scale": 1.0
	},
}

# ── Derived stat helpers ──────────────────────────────────────────
func get_cargo_cap() -> int:
	return 10 + upgrades["cargo_hold"]["level"] * 10

func get_ship_speed() -> float:
	return 160.0 + upgrades["thrusters"]["level"] * 55.0

func get_mining_time() -> float:
	return max(0.12, 0.90 - upgrades["mining_laser"]["level"] * 0.18)

func get_mining_range() -> float:
	return 40.0 + upgrades["tractor_beam"]["level"] * 25.0

func has_market_feed() -> bool:
	return upgrades["market_feed"]["level"] > 0

# ── Upgrade shop helpers ──────────────────────────────────────────
func get_upgrade_cost(key: String) -> int:
	var u = upgrades[key]
	return int(u["base_cost"] * pow(u["cost_scale"], u["level"]))

func can_afford_upgrade(key: String) -> bool:
	var u = upgrades[key]
	return u["level"] < u["max_level"] and credits >= get_upgrade_cost(key)

func buy_upgrade(key: String) -> bool:
	if not can_afford_upgrade(key):
		return false
	credits -= get_upgrade_cost(key)
	upgrades[key]["level"] += 1
	emit_signal("credits_changed", credits)
	return true

# ── Cargo / Credits ───────────────────────────────────────────────
func add_cargo(amount: int):
	var cap = get_cargo_cap()
	cargo = min(cargo + amount, cap)
	emit_signal("cargo_changed", cargo, cap)

func sell_cargo(corp: String) -> int:
	if cargo <= 0:
		return 0
	var price = price_alpha if corp == "alpha" else price_beta
	var earned = cargo * price
	credits += earned
	cargo = 0
	emit_signal("credits_changed", credits)
	emit_signal("cargo_changed", 0, get_cargo_cap())
	return earned

# ── Market ────────────────────────────────────────────────────────
func update_prices():
	prev_alpha = price_alpha
	prev_beta  = price_beta

	# Random walk with occasional spikes
	price_alpha = clamp(price_alpha + randi_range(-9, 9), 8, 58)
	price_beta  = clamp(price_beta  + randi_range(-9, 9), 8, 58)

	if randf() < 0.12:
		price_alpha = randi_range(38, 58)
	if randf() < 0.12:
		price_beta = randi_range(38, 58)

	# Very occasionally both drop to create tension
	if randf() < 0.06:
		price_alpha = randi_range(8, 18)
		price_beta  = randi_range(8, 18)

	emit_signal("prices_changed", price_alpha, price_beta, prev_alpha, prev_beta)

# ── Game flow ─────────────────────────────────────────────────────
func reset_for_new_game():
	credits  = 0
	cargo    = 0
	round_num = 1
	for key in upgrades:
		upgrades[key]["level"] = 0
	price_alpha = randi_range(15, 30)
	price_beta  = randi_range(15, 30)
	prev_alpha  = price_alpha
	prev_beta   = price_beta

func prepare_next_round():
	cargo = 0
	round_num += 1
	update_prices()
