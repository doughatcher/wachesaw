## Global game settings — Autoload singleton.
## Stores settings that persist between scene changes.
extends Node

var game_mode: int = 0  # 0 = AI, 1 = LOCAL
var difficulty: int = 3

# ─── Story Mode Data (passed between scenes) ────────────────────

var story_dialog_data: Array = []   # Dialog lines for the current dialog scene
var story_puzzle_data: Dictionary = {}  # Puzzle config for the current puzzle scene
var story_background: String = "forest"  # Background theme for current story step

# ─── Map Watching (dev feature) ──────────────────────────────────

## Path to watch for map changes. Set via CLI: --map-watch=path/to/file.json
## When set, the game boots directly into the puzzle scene and hot-reloads on save.
var map_watch_path: String = ""

## Puzzle ID to load from a chapter file. Set via CLI: --puzzle=ch1_p03
## If empty, loads the first puzzle found in the chapter.
var map_watch_puzzle_id: String = ""

func _ready() -> void:
	if OS.has_feature("web"):
		_parse_web_params()
	else:
		_parse_cli_args()

func _parse_cli_args() -> void:
	# Parse CLI args for --map-watch and --puzzle
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map-watch="):
			map_watch_path = arg.substr("--map-watch=".length())
			if not map_watch_path.begins_with("res://") and not map_watch_path.begins_with("user://"):
				if not map_watch_path.begins_with("/"):
					map_watch_path = "res://data/" + map_watch_path
			print("[GameSettings] Map watch mode: %s" % map_watch_path)
		elif arg.begins_with("--puzzle="):
			map_watch_puzzle_id = arg.substr("--puzzle=".length())
			print("[GameSettings] Watch puzzle ID: %s" % map_watch_puzzle_id)

func _parse_web_params() -> void:
	# Read watch config injected by dev_server.py as window.WACHESAW_WATCH
	# This is more reliable than URL params which can be stripped by port forwarding.
	var watch_val = JavaScriptBridge.eval("window.WACHESAW_WATCH ? window.WACHESAW_WATCH.watch : ''")
	var watch: String = str(watch_val) if watch_val != null else ""
	print("[GameSettings] WACHESAW_WATCH.watch = '%s'" % watch)

	if watch.is_empty() or watch == "null" or watch == "undefined":
		print("[GameSettings] No watch config found — normal boot.")
		return

	map_watch_path = "res://data/" + watch
	print("[GameSettings] Web watch mode: %s" % map_watch_path)

	var puzzle_val = JavaScriptBridge.eval("window.WACHESAW_WATCH ? (window.WACHESAW_WATCH.puzzle || '') : ''")
	var puzzle: String = str(puzzle_val) if puzzle_val != null else ""
	if not puzzle.is_empty() and puzzle != "null" and puzzle != "undefined":
		map_watch_puzzle_id = puzzle
		print("[GameSettings] Web watch puzzle ID: %s" % map_watch_puzzle_id)
