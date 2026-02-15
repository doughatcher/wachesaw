## Legal move generation for all piece types.
## No Godot engine dependencies.
class_name MoveGenerator
extends RefCounted

## A move is represented as:
## {fr: int, fc: int, tr: int, tc: int, mt: MoveType}

static func get_moves(board: Board, row: int, col: int) -> Array:
	var piece = board.get_cell(row, col)
	if piece == null:
		return []

	var moves: Array = []
	var piece_type: Types.PieceType = piece["type"]
	var player: Types.Player = piece["player"]

	# Normal moves (move + capture)
	var directions := Types.get_directions(piece_type)
	for dir in directions:
		var nr: int = row + dir.x
		var nc: int = col + dir.y
		if not board.is_in_bounds(nr, nc):
			continue
		var target = board.get_cell(nr, nc)
		if target == null or target["player"] != player:
			moves.append({"fr": row, "fc": col, "tr": nr, "tc": nc, "mt": Types.MoveType.MOVE})

	# Swap moves (any two friendly adjacent pieces)
	for dir in Types.ALL_ADJACENT:
		var nr: int = row + dir.x
		var nc: int = col + dir.y
		if not board.is_in_bounds(nr, nc):
			continue
		var target = board.get_cell(nr, nc)
		if target != null and target["player"] == player:
			moves.append({"fr": row, "fc": col, "tr": nr, "tc": nc, "mt": Types.MoveType.SWAP})

	return moves

static func get_all_moves(board: Board, player: Types.Player) -> Array:
	var all_moves: Array = []
	for r in range(Board.BOARD_SIZE):
		for c in range(Board.BOARD_SIZE):
			var cell = board.get_cell(r, c)
			if cell != null and cell["player"] == player:
				var piece_moves := get_moves(board, r, c)
				all_moves.append_array(piece_moves)
	return all_moves

static func get_moves_for_cell(board: Board, row: int, col: int) -> Array:
	## Returns moves formatted for the UI: [{row, col, type}]
	var piece = board.get_cell(row, col)
	if piece == null:
		return []

	var result: Array = []
	var piece_type: Types.PieceType = piece["type"]
	var player: Types.Player = piece["player"]

	# Normal moves
	var directions := Types.get_directions(piece_type)
	for dir in directions:
		var nr: int = row + dir.x
		var nc: int = col + dir.y
		if not board.is_in_bounds(nr, nc):
			continue
		var target = board.get_cell(nr, nc)
		if target == null or target["player"] != player:
			result.append({"row": nr, "col": nc, "type": Types.MoveType.MOVE})

	# Swaps
	for dir in Types.ALL_ADJACENT:
		var nr: int = row + dir.x
		var nc: int = col + dir.y
		if not board.is_in_bounds(nr, nc):
			continue
		var target = board.get_cell(nr, nc)
		if target != null and target["player"] == player:
			result.append({"row": nr, "col": nc, "type": Types.MoveType.SWAP})

	return result
