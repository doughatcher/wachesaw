## Loads and validates story chapter JSON data.
## Converts JSON board layouts into Board instances.
## No Godot engine dependencies beyond FileAccess/JSON.
class_name StoryData
extends RefCounted

const CHAPTER_COUNT: int = 5
const DATA_PATH: String = "res://data/story/"

# ─── Piece type mapping from JSON strings ────────────────────────

const PIECE_MAP: Dictionary = {
	"CHIEF": Types.PieceType.CHIEF,
	"KEEPER": Types.PieceType.KEEPER,
	"HUNTER": Types.PieceType.HUNTER,
	"RIVER_RUNNER": Types.PieceType.RIVER_RUNNER,
	"TRADER": Types.PieceType.TRADER,
}

const PLAYER_MAP: Dictionary = {
	"white": Types.Player.WHITE,
	"black": Types.Player.BLACK,
}

# ─── Loading ─────────────────────────────────────────────────────

static func load_chapter(chapter_num: int) -> Dictionary:
	var path := DATA_PATH + "chapter_%d.json" % chapter_num
	if not FileAccess.file_exists(path):
		push_error("StoryData: Chapter file not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if data == null:
		push_error("StoryData: Failed to parse JSON: %s" % path)
		return {}
	return data

static func get_chapter_title(chapter_num: int) -> String:
	var data := load_chapter(chapter_num)
	return data.get("title", "Chapter %d" % chapter_num)

static func get_chapter_default_background(chapter_num: int) -> String:
	var data := load_chapter(chapter_num)
	return data.get("default_background", "forest")

static func get_chapter_steps(chapter_num: int) -> Array:
	var data := load_chapter(chapter_num)
	return data.get("steps", [])

static func get_puzzle_count(chapter_num: int) -> int:
	var steps := get_chapter_steps(chapter_num)
	var count := 0
	for step in steps:
		if step.get("type") == "puzzle":
			count += 1
	return count

static func get_puzzle_ids(chapter_num: int) -> Array[String]:
	var steps := get_chapter_steps(chapter_num)
	var ids: Array[String] = []
	for step in steps:
		if step.get("type") == "puzzle":
			ids.append(step.get("id", ""))
	return ids

# ─── Board Construction ──────────────────────────────────────────

## Build a Board from a JSON board layout.
## Layout is a 5x5 array where each cell is null or {"type": "CHIEF", "player": "white"}
static func build_board(board_data: Array) -> Board:
	var board := Board.new()
	for row in range(Board.BOARD_SIZE):
		if row >= board_data.size():
			break
		var row_data: Array = board_data[row]
		for col in range(Board.BOARD_SIZE):
			if col >= row_data.size():
				break
			var cell = row_data[col]
			if cell != null and cell is Dictionary:
				var piece_type_str: String = cell.get("type", "")
				var player_str: String = cell.get("player", "")
				if PIECE_MAP.has(piece_type_str) and PLAYER_MAP.has(player_str):
					board.set_cell(row, col, PIECE_MAP[piece_type_str], PLAYER_MAP[player_str])
				else:
					push_warning("StoryData: Invalid piece at [%d][%d]: %s" % [row, col, str(cell)])
	return board

## Parse a move string like "Kc3" or "Rxb4" into a move dictionary.
## Returns null if the notation can't be parsed.
static func parse_move_notation(notation: String, board: Board, player: Types.Player):
	# Find the move among all legal moves that matches this notation
	var all_moves := MoveGenerator.get_all_moves(board, player)
	for move in all_moves:
		var move_notation := board.move_to_notation(move["fr"], move["fc"], move["tr"], move["tc"], move["mt"])
		if move_notation == notation:
			return move
	return null
