extends Control

const STAR_COUNT := 120
var _stars: Array = []
var _time: float  = 0.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for _i in STAR_COUNT:
		_stars.append({
			"pos": Vector2(rng.randf() * 1280.0, rng.randf() * 720.0),
			"r":   rng.randf_range(0.5, 1.8),
			"b":   rng.randf_range(0.3, 0.9),
		})
	_build_ui()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.014, 0.020, 0.050))
	for s: Dictionary in _stars:
		var b: float = float(s["b"])
		draw_circle(s["pos"] as Vector2, float(s["r"]), Color(b, b, b))

func _build_ui() -> void:
	var cx := 640.0
	var cy := 360.0

	var panel := PanelContainer.new()
	panel.position = Vector2(cx - 270.0, cy - 210.0)
	panel.size     = Vector2(540.0, 420.0)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	# Title
	var title_lbl := Label.new()
	title_lbl.text = "RIFT RUN COMPLETE"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 30)
	title_lbl.add_theme_color_override("font_color", Color(0.05, 0.85, 1.0))
	vbox.add_child(title_lbl)

	# Divider
	var div := HSeparator.new()
	vbox.add_child(div)

	# Final credits
	var credits_lbl := Label.new()
	credits_lbl.text = "Final Credits"
	credits_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_lbl.add_theme_font_size_override("font_size", 16)
	credits_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
	vbox.add_child(credits_lbl)

	var amount_lbl := Label.new()
	amount_lbl.text = str(GameManager.credits) + " cr"
	amount_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_lbl.add_theme_font_size_override("font_size", 48)
	amount_lbl.add_theme_color_override("font_color", Color(0.15, 1.0, 0.48))
	vbox.add_child(amount_lbl)

	# Rating
	var rating_lbl := Label.new()
	rating_lbl.text = _get_rating()
	rating_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rating_lbl.add_theme_font_size_override("font_size", 20)
	rating_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	vbox.add_child(rating_lbl)

	var rating_desc := Label.new()
	rating_desc.text = _get_rating_desc()
	rating_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rating_desc.add_theme_font_size_override("font_size", 13)
	rating_desc.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
	vbox.add_child(rating_desc)

	var div2 := HSeparator.new()
	vbox.add_child(div2)

	# Buttons
	var btn_restart := Button.new()
	btn_restart.text = "PLAY AGAIN"
	btn_restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_restart.add_theme_font_size_override("font_size", 16)
	btn_restart.pressed.connect(_on_restart)
	vbox.add_child(btn_restart)

	var btn_menu := Button.new()
	btn_menu.text = "MAIN MENU"
	btn_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_menu.add_theme_font_size_override("font_size", 16)
	btn_menu.pressed.connect(_on_menu)
	vbox.add_child(btn_menu)

func _get_rating() -> String:
	var c := GameManager.credits
	if   c >= 8000: return "⭐⭐⭐  VOID EMPEROR"
	elif c >= 5000: return "⭐⭐  MARKET MASTER"
	elif c >= 2500: return "⭐  RIFT RUNNER"
	else:            return "SPACE VAGRANT"

func _get_rating_desc() -> String:
	var c := GameManager.credits
	if   c >= 8000: return "The corporations fear you."
	elif c >= 5000: return "You read the market like a star chart."
	elif c >= 2500: return "Not bad for a newcomer."
	else:            return "Keep practicing, pilot."

func _on_restart() -> void:
	GameManager.reset_for_new_game()
	get_tree().change_scene_to_file("res://scenes/GameWorld.tscn")

func _on_menu() -> void:
	GameManager.reset_for_new_game()
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")
