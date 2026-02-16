## Global game settings — Autoload singleton.
## Stores settings that persist between scene changes.
extends Node

var game_mode: int = 0  # 0 = AI, 1 = LOCAL
var difficulty: int = 3

# ─── Story Mode Data (passed between scenes) ────────────────────

var story_dialog_data: Array = []   # Dialog lines for the current dialog scene
var story_puzzle_data: Dictionary = {}  # Puzzle config for the current puzzle scene
var story_background: String = "forest"  # Background theme for current story step
