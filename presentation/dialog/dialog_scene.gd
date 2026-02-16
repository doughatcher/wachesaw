## Visual novel-style dialog scene.
## Displays sequential dialog lines with typewriter effect.
## Tap/click/Space to advance or skip typewriter.
extends Control

# ─── Nodes ───────────────────────────────────────────────────────

@onready var background: ColorRect = $Background
@onready var portrait_rect: TextureRect = $DialogPanel/HBox/PortraitRect
@onready var speaker_label: Label = $DialogPanel/HBox/TextVBox/SpeakerLabel
@onready var dialog_text: RichTextLabel = $DialogPanel/HBox/TextVBox/DialogText
@onready var continue_hint: Label = $DialogPanel/ContinueHint
@onready var skip_btn: Button = $SkipButton

# ─── State ───────────────────────────────────────────────────────

var lines: Array = []
var current_line: int = 0
var typing: bool = false
var _tween: Tween = null

const CHAR_DELAY: float = 0.025  # seconds per character

# ─── Portrait Colors (placeholder until art) ─────────────────────

const PORTRAIT_COLORS: Dictionary = {
	"Nume": Color("#4a7c3f"),
	"Elder": Color("#8b7355"),
	"Dark Force": Color("#3d1f3d"),
	"Narrator": Color(0, 0, 0, 0),
}

# ─── Initialization ─────────────────────────────────────────────

func _ready() -> void:
	lines = GameSettings.story_dialog_data
	skip_btn.pressed.connect(_on_skip)

	if lines.is_empty():
		SceneManager.advance_story()
		return

	_show_line(0)

# ─── Input ───────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_advance()
	elif event is InputEventScreenTouch and event.pressed:
		_advance()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("click") or event.is_action_pressed("touch"):
		_advance()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_advance()

func _advance() -> void:
	if typing:
		# Skip typewriter — show full text instantly
		_skip_typewriter()
	else:
		# Next line
		current_line += 1
		if current_line >= lines.size():
			_finish()
		else:
			_show_line(current_line)

# ─── Display ────────────────────────────────────────────────────

func _show_line(index: int) -> void:
	var line: Dictionary = lines[index]
	var speaker = line.get("speaker", null)
	var text: String = line.get("text", "")
	var portrait_key: String = line.get("portrait", "")

	# Speaker name
	if speaker != null and speaker != "":
		speaker_label.text = speaker
		speaker_label.visible = true
	else:
		speaker_label.text = ""
		speaker_label.visible = false

	# Portrait placeholder (colored rectangle)
	if speaker != null and speaker != "":
		portrait_rect.visible = true
		portrait_rect.modulate = PORTRAIT_COLORS.get(speaker, Color("#666666"))
	else:
		portrait_rect.visible = false

	# Narration gets italic BBCode
	if speaker == null or speaker == "":
		dialog_text.text = "[i]%s[/i]" % text
	else:
		dialog_text.text = text

	# Typewriter effect
	dialog_text.visible_ratio = 0.0
	continue_hint.visible = false
	typing = true

	if _tween and _tween.is_valid():
		_tween.kill()

	var char_count := dialog_text.get_total_character_count()
	var duration := char_count * CHAR_DELAY

	_tween = create_tween()
	_tween.tween_property(dialog_text, "visible_ratio", 1.0, duration)
	_tween.tween_callback(_on_type_complete)

func _skip_typewriter() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	dialog_text.visible_ratio = 1.0
	_on_type_complete()

func _on_type_complete() -> void:
	typing = false
	continue_hint.visible = true

# ─── Finish ──────────────────────────────────────────────────────

func _finish() -> void:
	SceneManager.advance_story()

func _on_skip() -> void:
	_finish()
