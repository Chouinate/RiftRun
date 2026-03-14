extends Area2D

signal cargo_sold(earned: int, corp: String)

## Set from GameWorld when spawning: "alpha" or "beta"
var corp_id: String = "alpha"

const DOCK_W := 140.0
const DOCK_H := 90.0
const SELL_COOLDOWN := 1.2

var _sell_cd: float = 0.0
var _flash: float   = 0.0   # 0..1, briefly lit after a sale

var _price_label: Label
var _best_label:  Label
var _name_label:  Label

func _ready() -> void:
	# Collision rectangle
	var rect := RectangleShape2D.new()
	rect.size = Vector2(DOCK_W, DOCK_H)
	var col := CollisionShape2D.new()
	col.shape = rect
	add_child(col)

	# Corp name label
	_name_label = _make_label(14, _corp_color().lightened(0.2))
	_name_label.position = Vector2(-DOCK_W * 0.5, -DOCK_H * 0.5 - 26.0)
	_name_label.text = "ASTRA CO." if corp_id == "alpha" else "VEGA IND."
	add_child(_name_label)

	# Price label
	_price_label = _make_label(22, Color.WHITE)
	_price_label.position = Vector2(-DOCK_W * 0.5, -18.0)
	add_child(_price_label)

	# Best-price indicator
	_best_label = _make_label(13, Color(0.2, 1.0, 0.5))
	_best_label.position = Vector2(-DOCK_W * 0.5, DOCK_H * 0.5 - 6.0)
	_best_label.text = "★ BEST PRICE"
	_best_label.visible = false
	add_child(_best_label)

	body_entered.connect(_on_body_entered)

func _make_label(font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.custom_minimum_size = Vector2(DOCK_W, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _corp_color() -> Color:
	return Color(0.1, 0.55, 1.0) if corp_id == "alpha" else Color(1.0, 0.50, 0.1)

func _process(delta: float) -> void:
	if _sell_cd > 0.0:
		_sell_cd -= delta
	if _flash > 0.0:
		_flash = max(0.0, _flash - delta * 2.0)

	var price      := GameManager.price_alpha if corp_id == "alpha" else GameManager.price_beta
	var other      := GameManager.price_beta  if corp_id == "alpha" else GameManager.price_alpha
	var is_best    := price >= other

	_price_label.text = str(price) + " cr / unit"
	_best_label.visible = is_best
	queue_redraw()

func _draw() -> void:
	var base_col  := _corp_color()
	var rect      := Rect2(-DOCK_W * 0.5, -DOCK_H * 0.5, DOCK_W, DOCK_H)
	var price     := GameManager.price_alpha if corp_id == "alpha" else GameManager.price_beta
	var other     := GameManager.price_beta  if corp_id == "alpha" else GameManager.price_alpha
	var is_best   := price >= other
	var flash_col := Color(0.2, 1.0, 0.5)

	# Background fill
	var fill_alpha := 0.15 + _flash * 0.25
	draw_rect(rect, Color(base_col.r, base_col.g, base_col.b, fill_alpha))

	# Border — green when best, corp color otherwise, extra bright on flash
	var border_col := flash_col if _flash > 0.1 else (Color(0.2, 1.0, 0.5) if is_best else base_col)
	draw_rect(rect, border_col, false, 2.5)

	# Landing pad cross marks
	var line_col := Color(base_col.r, base_col.g, base_col.b, 0.35)
	draw_line(Vector2(-DOCK_W * 0.5 + 12, 0), Vector2(DOCK_W * 0.5 - 12, 0), line_col, 1.5)
	draw_line(Vector2(0, -DOCK_H * 0.5 + 10), Vector2(0, DOCK_H * 0.5 - 10), line_col, 1.5)

	# Corner squares
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			var cx := sx * (DOCK_W * 0.5 - 8)
			var cy := sy * (DOCK_H * 0.5 - 8)
			draw_rect(Rect2(cx - 4, cy - 4, 8, 8), base_col * Color(1, 1, 1, 0.6))

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if _sell_cd > 0.0:
		return
	var earned := GameManager.sell_cargo(corp_id)
	if earned > 0:
		_sell_cd = SELL_COOLDOWN
		_flash   = 1.0
		emit_signal("cargo_sold", earned, corp_id)
