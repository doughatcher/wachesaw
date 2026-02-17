## Watches map JSON files for changes and hot-reloads them.
## Autoload singleton. Polls for changes every POLL_INTERVAL seconds.
##
## On native: uses FileAccess + modification times.
## On web: uses HTTPRequest to fetch live JSON from the dev server at /data/*.
##
## Supports two file formats:
##   1. Standalone puzzle files (same format as story puzzle steps)
##   2. Story chapter files (with "steps" array) — extracts the target puzzle
##
## Usage:
##   # Watch from CLI (native):   godot -- --map-watch=story/chapter_1.json --puzzle=ch1_p03
##   # Watch from URL (web):      http://localhost:8000/?watch=story/chapter_1.json&puzzle=ch1_p03
##
##   MapWatcher.map_changed.connect(_on_map_changed)
##
## The emitted signal carries the parsed puzzle Dictionary (same format as story puzzle steps).
extends Node

## Emitted when a watched map file changes. Payload is the parsed puzzle Dictionary.
signal map_changed(puzzle_data: Dictionary)

## Emitted when a watched file has a parse error.
signal map_error(file_path: String, error_message: String)

const POLL_INTERVAL: float = 0.5  # seconds

# ─── Watch State ─────────────────────────────────────────────────

var _watch_path: String = ""
var _last_modified: int = 0
var _last_content_hash: int = 0  # Used on web (no mod-time access)
var _poll_timer: float = 0.0
var _active: bool = false
var _is_web: bool = false

# ─── HTTP (web only) ────────────────────────────────────────────

var _http: HTTPRequest = null
var _http_base_url: String = ""
var _http_pending: bool = false

# ─── Autostart ───────────────────────────────────────────────────

func _ready() -> void:
	_is_web = OS.has_feature("web")

	if _is_web:
		_http = HTTPRequest.new()
		_http.timeout = 5.0
		add_child(_http)
		_http.request_completed.connect(_on_http_completed)
		# Base URL is the same origin the game was served from
		var origin = JavaScriptBridge.eval("window.location.origin")
		_http_base_url = str(origin) if origin != null else ""
		print("[MapWatcher] Web mode, base URL: %s" % _http_base_url)

	# Auto-start if GameSettings has a watch path (set from CLI or URL params)
	if not GameSettings.map_watch_path.is_empty():
		# Defer so the main scene has time to initialize
		call_deferred("_autostart")

# ─── Public API ──────────────────────────────────────────────────

## Start watching a map file for changes.
## Immediately loads the file on first call.
func watch_file(path: String) -> void:
	_watch_path = path
	_last_modified = 0
	_last_content_hash = 0
	_active = true
	_poll_timer = 0.0
	print("[MapWatcher] Watching: %s" % path)
	# Immediate first load
	_check_and_reload()

## Start watching a directory for any .json file changes.
## On web, directory watching is not supported — use a specific file path.
func watch_directory(dir_path: String) -> void:
	if _is_web:
		push_warning("[MapWatcher] Directory watching not supported on web. Use a specific file path.")
		return
	_watch_path = dir_path
	_last_modified = 0
	_active = true
	_poll_timer = 0.0
	print("[MapWatcher] Watching directory: %s" % dir_path)
	_check_and_reload()

## Stop watching.
func stop() -> void:
	_active = false
	_watch_path = ""
	_last_modified = 0
	_last_content_hash = 0
	print("[MapWatcher] Stopped watching")

## Returns true if currently watching a file.
func is_watching() -> bool:
	return _active

## Returns the current watch path.
func get_watch_path() -> String:
	return _watch_path

# ─── Polling ─────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _active:
		return
	_poll_timer += delta
	if _poll_timer < POLL_INTERVAL:
		return
	_poll_timer = 0.0
	_check_and_reload()

func _check_and_reload() -> void:
	if _watch_path.is_empty():
		return

	if _is_web:
		_check_and_reload_web()
	else:
		_check_and_reload_native()

# ─── Native (FileAccess) ────────────────────────────────────────

func _check_and_reload_native() -> void:
	var file_path := _resolve_file_path()
	if file_path.is_empty():
		return

	var mod_time := FileAccess.get_modified_time(file_path)
	if mod_time == _last_modified:
		return

	_last_modified = mod_time
	print("[MapWatcher] Change detected: %s (modified at %d)" % [file_path, mod_time])

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		var err_msg := "Cannot open file: %s" % file_path
		push_warning("[MapWatcher] %s" % err_msg)
		map_error.emit(file_path, err_msg)
		return
	var text := file.get_as_text()
	file.close()
	_parse_and_emit(text, file_path)

## If _watch_path is a directory, find the most recently modified .json file in it.
## If it's a file, return it directly.
func _resolve_file_path() -> String:
	if _watch_path.ends_with(".json"):
		if FileAccess.file_exists(_watch_path):
			return _watch_path
		# Try user:// equivalent for paths outside res://
		if FileAccess.file_exists("res://" + _watch_path):
			return "res://" + _watch_path
		return ""

	# Directory mode: find the newest .json file
	var dir := DirAccess.open(_watch_path)
	if dir == null:
		return ""

	var newest_path := ""
	var newest_time: int = 0

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path: String = _watch_path.path_join(file_name)
			var mod: int = FileAccess.get_modified_time(full_path)
			if mod > newest_time:
				newest_time = mod
				newest_path = full_path
		file_name = dir.get_next()
	dir.list_dir_end()

	return newest_path

# ─── Web (HTTPRequest) ──────────────────────────────────────────

func _check_and_reload_web() -> void:
	if _http_pending:
		return  # Still waiting for previous request

	# Convert res://data/... → /data/...
	var url_path: String = _watch_path.replace("res://", "/")
	var url: String = _http_base_url + url_path

	_http_pending = true
	var err := _http.request(url)
	if err != OK:
		_http_pending = false
		push_warning("[MapWatcher] HTTP request failed: %s (error %d)" % [url, err])

func _on_http_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_http_pending = false

	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("[MapWatcher] HTTP request error: result=%d" % result)
		return
	if code != 200:
		if code == 404:
			push_warning("[MapWatcher] File not found on server (404): %s" % _watch_path)
		else:
			push_warning("[MapWatcher] HTTP %d for %s" % [code, _watch_path])
		return

	var text := body.get_string_from_utf8()
	if text.strip_edges().is_empty():
		return

	# Detect changes by hashing content (mod-time not available on web)
	var content_hash := text.hash()
	if content_hash == _last_content_hash:
		return  # No change

	_last_content_hash = content_hash
	print("[MapWatcher] Change detected via HTTP: %s" % _watch_path)
	_parse_and_emit(text, _watch_path)

# ─── Shared Parse + Emit ────────────────────────────────────────

func _parse_and_emit(text: String, source_path: String) -> void:
	if text.strip_edges().is_empty():
		return

	var data = JSON.parse_string(text)
	if data == null:
		var err_msg := "Invalid JSON in: %s" % source_path
		push_warning("[MapWatcher] %s" % err_msg)
		map_error.emit(source_path, err_msg)
		return

	if data is not Dictionary:
		var err_msg := "Expected JSON object in: %s" % source_path
		push_warning("[MapWatcher] %s" % err_msg)
		map_error.emit(source_path, err_msg)
		return

	# Detect chapter files (have a "steps" array) vs standalone puzzle files
	var puzzle_data: Dictionary
	if data.has("steps") and data["steps"] is Array:
		puzzle_data = _extract_puzzle_from_chapter(data, source_path)
		if puzzle_data.is_empty():
			return  # Error already reported
	else:
		# Standalone puzzle file — apply defaults
		puzzle_data = _apply_defaults(data, source_path)

	print("[MapWatcher] Loaded: %s — \"%s\"" % [source_path, puzzle_data.get("title", "")])
	map_changed.emit(puzzle_data)

## Fill in reasonable defaults for a standalone map file.
func _apply_defaults(data: Dictionary, file_path: String) -> Dictionary:
	var d := data.duplicate(true)
	if not d.has("id"):
		d["id"] = file_path.get_file().get_basename()
	if not d.has("title"):
		d["title"] = d["id"].capitalize()
	if not d.has("description"):
		d["description"] = ""
	if not d.has("player"):
		d["player"] = "white"
	if not d.has("board"):
		d["board"] = []
	if not d.has("win_condition"):
		d["win_condition"] = {"type": "capture_chief", "max_moves": 99}
	if not d.has("opponent_moves"):
		d["opponent_moves"] = []
	if not d.has("type"):
		d["type"] = "puzzle"
	return d

## Extract a puzzle step from a story chapter file.
## Uses GameSettings.map_watch_puzzle_id to find the puzzle by ID.
## If no ID is set, loads the first puzzle in the chapter.
func _extract_puzzle_from_chapter(chapter_data: Dictionary, file_path: String) -> Dictionary:
	var steps: Array = chapter_data.get("steps", [])
	var target_id: String = GameSettings.map_watch_puzzle_id
	var chapter_bg: String = chapter_data.get("default_background", "forest")

	# Collect all puzzle steps
	var puzzles: Array[Dictionary] = []
	for step in steps:
		if step is Dictionary and step.get("type") == "puzzle":
			puzzles.append(step)

	if puzzles.is_empty():
		var err_msg := "No puzzle steps found in chapter: %s" % file_path
		push_warning("[MapWatcher] %s" % err_msg)
		map_error.emit(file_path, err_msg)
		return {}

	# Find by ID or default to first puzzle
	var found: Dictionary = {}
	if not target_id.is_empty():
		for p in puzzles:
			if p.get("id", "") == target_id:
				found = p
				break
		if found.is_empty():
			# Try numeric index (e.g., --puzzle=3 for the 3rd puzzle)
			if target_id.is_valid_int():
				var idx: int = target_id.to_int() - 1  # 1-based
				if idx >= 0 and idx < puzzles.size():
					found = puzzles[idx]
			if found.is_empty():
				var ids: Array[String] = []
				for p in puzzles:
					ids.append(p.get("id", "?"))
				var err_msg := "Puzzle '%s' not found in %s. Available: %s" % [target_id, file_path, ", ".join(ids)]
				push_warning("[MapWatcher] %s" % err_msg)
				map_error.emit(file_path, err_msg)
				return {}
	else:
		found = puzzles[0]
		if puzzles.size() > 1:
			var ids: Array[String] = []
			for p in puzzles:
				ids.append(p.get("id", "?"))
			print("[MapWatcher] Chapter has %d puzzles: %s (loading first: %s)" % [
				puzzles.size(), ", ".join(ids), found.get("id", "?")])

	# Apply chapter background if puzzle doesn't specify its own
	var result := found.duplicate(true)
	if not result.has("background"):
		result["background"] = chapter_bg

	print("[MapWatcher] Extracted puzzle '%s' from chapter" % result.get("id", "?"))
	return result

# ─── Autostart ───────────────────────────────────────────────────

func _autostart() -> void:
	var path := GameSettings.map_watch_path
	print("[MapWatcher] Auto-starting watch: %s" % path)

	# Listen for changes to load/reload the puzzle scene
	map_changed.connect(_on_auto_load)

	if path.ends_with(".json"):
		watch_file(path)
	elif not _is_web:
		watch_directory(path)

## Handles auto-loading: on first load, transitions to puzzle scene.
## On subsequent loads while already on the puzzle scene, the PuzzleController
## handles the hot-reload via its own connection.
func _on_auto_load(puzzle_data: Dictionary) -> void:
	GameSettings.story_puzzle_data = puzzle_data
	GameSettings.story_background = puzzle_data.get("background", "forest")
	SceneManager.story_active = false  # Not in story mode, skip auto-advance

	# If we're not on the puzzle scene, transition to it
	var current_scene := get_tree().current_scene
	if current_scene == null or current_scene.scene_file_path != "res://scenes/puzzle.tscn":
		SceneManager.change_scene("res://scenes/puzzle.tscn")
