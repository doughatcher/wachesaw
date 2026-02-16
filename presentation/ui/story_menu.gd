## Story mode chapter selection menu.
## Shows chapter list with completion status and lock states.
extends Control

@onready var back_btn: Button = $TopBar/BackButton
@onready var chapter_list: VBoxContainer = $CenterContainer/VBox/ChapterList
@onready var background: Control = %Background

func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	_build_chapter_list()

	if background and background.has_method("set_theme_by_name"):
		background.set_theme_by_name("forest")

func _build_chapter_list() -> void:
	for child in chapter_list.get_children():
		child.queue_free()

	for i in range(1, StoryData.CHAPTER_COUNT + 1):
		var unlocked := StoryProgress.is_chapter_unlocked(i)
		var title := StoryData.get_chapter_title(i)
		var total := StoryData.get_puzzle_count(i)
		var completed := StoryProgress.get_completed_count(i)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(300, 56)

		if unlocked:
			btn.text = "Chapter %d: %s\n%d / %d puzzles" % [i, title, completed, total]
			btn.pressed.connect(_on_chapter_selected.bind(i))
		else:
			btn.text = "Chapter %d: 🔒 Locked\nComplete previous chapter"  % i
			btn.disabled = true

		btn.add_theme_font_size_override("font_size", 14)
		chapter_list.add_child(btn)

		# Style completed chapters
		if completed >= total and total > 0:
			btn.add_theme_color_override("font_color", Color("#7fa650"))

func _on_chapter_selected(chapter: int) -> void:
	SceneManager.start_story(chapter)

func _on_back() -> void:
	SceneManager.change_scene("res://scenes/main_menu.tscn")
