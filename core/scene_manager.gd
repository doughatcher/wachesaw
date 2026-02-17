## Scene manager -- handles transitions and story mode sequencing.
## Autoload singleton. Owns the fade overlay CanvasLayer.
extends Node

# ─── Fade Overlay ────────────────────────────────────────────────

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _transitioning: bool = false

const FADE_OUT_DURATION := 0.3
const FADE_IN_DURATION := 0.35

# ─── Story State ─────────────────────────────────────────────────

var story_active: bool = false
var story_chapter: int = 1
var story_steps: Array = []
var story_step_index: int = 0
var story_default_background: String = "forest"

# ─── Setup ───────────────────────────────────────────────────────

func _ready() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100  # Always on top
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)

# ─── Scene Transitions ──────────────────────────────────────────

func change_scene(scene_path: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, FADE_OUT_DURATION)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(scene_path)
		_fade_in()
	)

func _fade_in() -> void:
	# Wait one frame for the new scene to initialize
	await get_tree().process_frame
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 0.0, FADE_IN_DURATION)
	tween.tween_callback(func():
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_transitioning = false
	)

# ─── Story Mode ──────────────────────────────────────────────────

func start_story(chapter: int) -> void:
	story_active = true
	story_chapter = chapter
	story_steps = StoryData.get_chapter_steps(chapter)
	story_default_background = StoryData.get_chapter_default_background(chapter)
	story_step_index = 0
	load_current_step()

func advance_story() -> void:
	if not story_active:
		return
	story_step_index += 1
	if story_step_index >= story_steps.size():
		if MapWatcher.is_watching():
			# Wrap back to the last puzzle step instead of ending
			for i in range(story_steps.size() - 1, -1, -1):
				if story_steps[i] is Dictionary and story_steps[i].get("type") == "puzzle":
					go_to_step(i)
					return
			story_step_index = 0
			return
		_on_chapter_complete()
		return
	StoryProgress.set_current_position(story_chapter, story_step_index)
	load_current_step()

func go_to_step(index: int) -> void:
	if not story_active or story_steps.is_empty():
		return
	story_step_index = clampi(index, 0, story_steps.size() - 1)
	load_current_step()

func get_puzzle_step_indices() -> Array[int]:
	var indices: Array[int] = []
	for i in range(story_steps.size()):
		if story_steps[i] is Dictionary and story_steps[i].get("type") == "puzzle":
			indices.append(i)
	return indices

func load_current_step() -> void:
	if story_step_index >= story_steps.size():
		_on_chapter_complete()
		return

	var step: Dictionary = story_steps[story_step_index]
	var step_type: String = step.get("type", "")

	match step_type:
		"dialog":
			GameSettings.story_dialog_data = step.get("lines", [])
			GameSettings.story_background = step.get("background", story_default_background)
			change_scene("res://scenes/dialog.tscn")
		"puzzle":
			GameSettings.story_puzzle_data = step
			GameSettings.story_background = step.get("background", story_default_background)
			change_scene("res://scenes/puzzle.tscn")
		_:
			push_warning("SceneManager: Unknown step type: %s" % step_type)
			advance_story()

func get_current_step() -> Dictionary:
	if story_step_index >= 0 and story_step_index < story_steps.size():
		return story_steps[story_step_index]
	return {}

func _on_chapter_complete() -> void:
	story_active = false
	story_steps = []
	story_step_index = 0
	change_scene("res://scenes/story_menu.tscn")

func stop_story() -> void:
	story_active = false
	story_steps = []
	story_step_index = 0
	change_scene("res://scenes/main_menu.tscn")
