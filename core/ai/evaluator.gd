## Static board evaluation for the AI.
## Scores from Black's perspective (positive = good for Black).
## No Godot engine dependencies.
class_name Evaluator
extends RefCounted

const TERMINAL_SCORE: int = 100000

static func evaluate(board: Board) -> int:
	var score: int = 0
	var white_chief := false
	var black_chief := false

	for r in range(Board.BOARD_SIZE):
		for c in range(Board.BOARD_SIZE):
			var cell = board.get_cell(r, c)
			if cell == null:
				continue

			var piece_type: Types.PieceType = cell["type"]
			var player: Types.Player = cell["player"]

			# Track chiefs
			if piece_type == Types.PieceType.CHIEF:
				if player == Types.Player.WHITE:
					white_chief = true
				else:
					black_chief = true

			# Sign: +1 for black, -1 for white
			var sign: int = 1 if player == Types.Player.BLACK else -1

			# Material value
			score += sign * Types.get_material_value(piece_type)

			# Advancement bonus (only for pieces that can win by crossing)
			if Types.can_cross_win(piece_type):
				var advancement: int
				if player == Types.Player.BLACK:
					advancement = r  # Black advances toward row 4
				else:
					advancement = 4 - r  # White advances toward row 0
				score += sign * advancement * 18

			# Center control bonus
			var center_dist: int = absi(r - 2) + absi(c - 2)
			score += sign * (4 - center_dist) * 6

	# Terminal states
	if not white_chief:
		return TERMINAL_SCORE
	if not black_chief:
		return -TERMINAL_SCORE

	return score
