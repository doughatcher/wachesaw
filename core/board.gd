## Board state representation and manipulation.
## No Godot engine dependencies — pure data.
class_name Board
extends RefCounted

const BOARD_SIZE: int = 5

# Board is a flat array of size BOARD_SIZE * BOARD_SIZE.
# Each cell is either null or a Dictionary: {"type": PieceType, "player": Player}
var cells: Array = []
var move_count: int = 0

# ─── Layout ──────────────────────────────────────────────────────

## White home row layout (row 4, bottom from visual perspective).
## Matches spec §2.2: Hunter, River Runner, Chief, Keeper, Trader
const WHITE_LAYOUT: Array = [
	Types.PieceType.HUNTER,
	Types.PieceType.RIVER_RUNNER,
	Types.PieceType.CHIEF,
	Types.PieceType.KEEPER,
	Types.PieceType.TRADER,
]

## Black home row layout (row 0, top).
## Mirrored: Trader, Keeper, Chief, River Runner, Hunter
const BLACK_LAYOUT: Array = [
	Types.PieceType.TRADER,
	Types.PieceType.KEEPER,
	Types.PieceType.CHIEF,
	Types.PieceType.RIVER_RUNNER,
	Types.PieceType.HUNTER,
]

# ─── Construction ────────────────────────────────────────────────

func _init() -> void:
	cells.resize(BOARD_SIZE * BOARD_SIZE)
	cells.fill(null)

static func create() -> Board:
	var board := Board.new()
	# Place white pieces on row 4 (visual bottom)
	for col in range(BOARD_SIZE):
		board.set_cell(4, col, WHITE_LAYOUT[col], Types.Player.WHITE)
	# Place black pieces on row 0 (visual top)
	for col in range(BOARD_SIZE):
		board.set_cell(0, col, BLACK_LAYOUT[col], Types.Player.BLACK)
	return board

# ─── Cell Access ─────────────────────────────────────────────────

func _idx(row: int, col: int) -> int:
	return row * BOARD_SIZE + col

func get_cell(row: int, col: int):
	if row < 0 or row >= BOARD_SIZE or col < 0 or col >= BOARD_SIZE:
		return null
	return cells[_idx(row, col)]

func set_cell(row: int, col: int, piece_type: Types.PieceType, player: Types.Player) -> void:
	cells[_idx(row, col)] = {"type": piece_type, "player": player}

func clear_cell(row: int, col: int) -> void:
	cells[_idx(row, col)] = null

func is_in_bounds(row: int, col: int) -> bool:
	return row >= 0 and row < BOARD_SIZE and col >= 0 and col < BOARD_SIZE

# ─── Clone ───────────────────────────────────────────────────────

func clone() -> Board:
	var new_board := Board.new()
	for i in range(cells.size()):
		if cells[i] != null:
			new_board.cells[i] = cells[i].duplicate()
		else:
			new_board.cells[i] = null
	new_board.move_count = move_count
	return new_board

# ─── Move Execution ─────────────────────────────────────────────

## Execute a move and return {board, piece, captured}.
## Does NOT modify this board — returns a new one.
func do_move(fr: int, fc: int, tr: int, tc: int, move_type: Types.MoveType) -> Dictionary:
	var new_board := clone()
	var piece: Dictionary = new_board.get_cell(fr, fc).duplicate()
	var captured = null

	if move_type == Types.MoveType.SWAP:
		var target = new_board.get_cell(tr, tc)
		new_board.cells[new_board._idx(tr, tc)] = new_board.cells[new_board._idx(fr, fc)]
		new_board.cells[new_board._idx(fr, fc)] = target
	else:
		captured = new_board.get_cell(tr, tc)
		new_board.cells[new_board._idx(tr, tc)] = piece
		new_board.clear_cell(fr, fc)

	new_board.move_count = move_count + 1

	return {
		"board": new_board,
		"piece": piece,
		"captured": captured,
	}

# ─── Queries ─────────────────────────────────────────────────────

func has_chief(player: Types.Player) -> bool:
	for i in range(cells.size()):
		var c = cells[i]
		if c != null and c["type"] == Types.PieceType.CHIEF and c["player"] == player:
			return true
	return false

func get_pieces(player: Types.Player) -> Array:
	## Returns array of {row, col, type, player}
	var result: Array = []
	for i in range(cells.size()):
		var c = cells[i]
		if c != null and c["player"] == player:
			var row: int = i / BOARD_SIZE
			var col: int = i % BOARD_SIZE
			result.append({"row": row, "col": col, "type": c["type"], "player": c["player"]})
	return result

# ─── Notation ────────────────────────────────────────────────────

func move_to_notation(fr: int, fc: int, tr: int, tc: int, move_type: Types.MoveType) -> String:
	var piece = get_cell(fr, fc)
	if piece == null:
		return "?"
	var letter := Types.get_letter(piece["type"])
	var dest := Types.COL_LABELS[tc] + Types.ROW_LABELS[tr]

	if move_type == Types.MoveType.SWAP:
		return letter + "sw" + dest
	elif get_cell(tr, tc) != null:
		return letter + "x" + dest
	else:
		return letter + dest
