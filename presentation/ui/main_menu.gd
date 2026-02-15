## Main menu — mode selection and difficulty picker.
extends Control

@onready var play_ai_btn: Button = %PlayAIButton
@onready var play_local_btn: Button = %PlayLocalButton
@onready var difficulty_buttons: HBoxContainer = %DifficultyButtons
@onready var difficulty_label: Label = %DifficultyLabel

var selected_difficulty: int = 3

func _ready() -> void:
	play_ai_btn.pressed.connect(_on_play_ai)
	play_local_btn.pressed.connect(_on_play_local)
	_create_difficulty_buttons()
	_update_difficulty_label()

func _create_difficulty_buttons() -> void:
	for child in difficulty_buttons.get_children():
		child.queue_free()

	for i in range(1, 6):
		var btn := Button.new()
		btn.text = str(i)
		btn.custom_minimum_size = Vector2(48, 48)
		btn.pressed.connect(_on_difficulty_selected.bind(i))
		difficulty_buttons.add_child(btn)

	_highlight_difficulty()

func _highlight_difficulty() -> void:
	for i in range(difficulty_buttons.get_child_count()):
		var btn: Button = difficulty_buttons.get_child(i)
		var level: int = i + 1
		if level == selected_difficulty:
			btn.add_theme_color_override("font_color", Color.WHITE)
			btn.add_theme_stylebox_override("normal", _make_stylebox(Color("#7fa650")))
		else:
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_stylebox_override("normal")

func _make_stylebox(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	return sb

func _on_difficulty_selected(level: int) -> void:
	selected_difficulty = level
	_highlight_difficulty()
	_update_difficulty_label()

func _update_difficulty_label() -> void:
	difficulty_label.text = Types.DIFFICULTY_NAMES[selected_difficulty]

func _on_play_ai() -> void:
	_start_game(true)

func _on_play_local() -> void:
	_start_game(false)

func _start_game(vs_ai: bool) -> void:
	GameSettings.game_mode = 0 if vs_ai else 1
	GameSettings.difficulty = selected_difficulty
	get_tree().change_scene_to_file("res://scenes/game.tscn")
