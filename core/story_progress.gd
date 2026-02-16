## Tracks story mode progress -- which puzzles are completed.
## Autoload singleton. Saves to user://story_progress.cfg
extends Node

const SAVE_PATH: String = "user://story_progress.cfg"

var _config: ConfigFile = ConfigFile.new()
var _loaded: bool = false

# ─── Lifecycle ───────────────────────────────────────────────────

func _ready() -> void:
	load_progress()

# ─── Puzzle Completion ───────────────────────────────────────────

func is_puzzle_completed(puzzle_id: String) -> bool:
	return _config.get_value("puzzles", puzzle_id, false)

func mark_completed(puzzle_id: String) -> void:
	_config.set_value("puzzles", puzzle_id, true)
	save_progress()

func get_completed_count(chapter_num: int) -> int:
	var ids := StoryData.get_puzzle_ids(chapter_num)
	var count := 0
	for id in ids:
		if is_puzzle_completed(id):
			count += 1
	return count

# ─── Chapter Unlocking ───────────────────────────────────────────

func is_chapter_unlocked(chapter_num: int) -> bool:
	if chapter_num == 1:
		return true
	# Must complete all puzzles in the previous chapter
	var prev_total := StoryData.get_puzzle_count(chapter_num - 1)
	var prev_completed := get_completed_count(chapter_num - 1)
	return prev_completed >= prev_total and prev_total > 0

# ─── Story Position ─────────────────────────────────────────────

func get_current_chapter() -> int:
	return _config.get_value("position", "chapter", 1)

func get_current_step() -> int:
	return _config.get_value("position", "step", 0)

func set_current_position(chapter: int, step: int) -> void:
	_config.set_value("position", "chapter", chapter)
	_config.set_value("position", "step", step)
	save_progress()

# ─── Persistence ─────────────────────────────────────────────────

func save_progress() -> void:
	var err := _config.save(SAVE_PATH)
	if err != OK:
		push_error("StoryProgress: Failed to save: %s" % error_string(err))
		return
	# On web, flush the virtual filesystem to IndexedDB so saves persist
	if OS.has_feature("web"):
		_sync_web_fs()

func load_progress() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var err := _config.load(SAVE_PATH)
		if err != OK:
			push_error("StoryProgress: Failed to load: %s" % error_string(err))
	_loaded = true

func reset_progress() -> void:
	_config = ConfigFile.new()
	save_progress()

func _sync_web_fs() -> void:
	# Godot's web export uses Emscripten's virtual filesystem backed by IndexedDB.
	# FS.syncfs(false, ...) flushes pending writes so data survives page reloads.
	JavaScriptBridge.eval("
		if (typeof FS !== 'undefined' && FS.syncfs) {
			FS.syncfs(false, function(err) {
				if (err) console.warn('FS.syncfs error:', err);
			});
		}
	")
