## Minimax search with alpha-beta pruning.
## No Godot engine dependencies.
class_name Minimax
extends RefCounted

# Difficulty settings: {depth, random_chance}
const DIFFICULTY: Dictionary = {
	1: {"depth": 1, "random": 0.40},
	2: {"depth": 2, "random": 0.20},
	3: {"depth": 3, "random": 0.08},
	4: {"depth": 4, "random": 0.02},
	5: {"depth": 5, "random": 0.00},
}

## Get the AI's chosen move for the given difficulty (1-5).
## AI always plays as Black.
static func get_ai_move(board: Board, difficulty: int) -> Variant:
	var settings: Dictionary = DIFFICULTY.get(difficulty, DIFFICULTY[3])

	# Random move chance (creates natural-feeling mistakes at lower difficulty)
	if randf() < settings["random"]:
		var moves := MoveGenerator.get_all_moves(board, Types.Player.BLACK)
		if moves.is_empty():
			return null
		return moves[randi() % moves.size()]

	var result := _minimax(board, settings["depth"], -999999, 999999, true)
	return result["move"]

## Minimax with alpha-beta pruning.
## maximizing = true means it's Black's turn (AI).
static func _minimax(board: Board, depth: int, alpha: int, beta: int, maximizing: bool) -> Dictionary:
	var player: Types.Player = Types.Player.BLACK if maximizing else Types.Player.WHITE
	var moves := MoveGenerator.get_all_moves(board, player)

	# Leaf node or no moves
	if depth == 0 or moves.is_empty():
		return {"score": Evaluator.evaluate(board), "move": null}

	var best_move = moves[0]

	if maximizing:
		var max_score: int = -999999
		for m in moves:
			var result: Dictionary = board.do_move(m["fr"], m["fc"], m["tr"], m["tc"], m["mt"])
			var new_board: Board = result["board"]
			var piece: Dictionary = result["piece"]

			# Check for immediate win
			if m["mt"] != Types.MoveType.SWAP:
				var winner: int = WinChecker.check_win(new_board, Types.Player.BLACK, piece, m["tr"], m["mt"])
				if winner == Types.Player.BLACK:
					return {"score": Evaluator.TERMINAL_SCORE + depth, "move": m}
				if winner == Types.Player.WHITE:
					continue  # Skip moves that let opponent win (shouldn't happen on our turn)

			var child := _minimax(new_board, depth - 1, alpha, beta, false)
			if child["score"] > max_score:
				max_score = child["score"]
				best_move = m
			alpha = maxi(alpha, child["score"])
			if beta <= alpha:
				break

		return {"score": max_score, "move": best_move}
	else:
		var min_score: int = 999999
		for m in moves:
			var result: Dictionary = board.do_move(m["fr"], m["fc"], m["tr"], m["tc"], m["mt"])
			var new_board: Board = result["board"]
			var piece: Dictionary = result["piece"]

			# Check for immediate win
			if m["mt"] != Types.MoveType.SWAP:
				var winner: int = WinChecker.check_win(new_board, Types.Player.WHITE, piece, m["tr"], m["mt"])
				if winner == Types.Player.WHITE:
					return {"score": -Evaluator.TERMINAL_SCORE - depth, "move": m}
				if winner == Types.Player.BLACK:
					continue

			var child := _minimax(new_board, depth - 1, alpha, beta, true)
			if child["score"] < min_score:
				min_score = child["score"]
				best_move = m
			beta = mini(beta, child["score"])
			if beta <= alpha:
				break

		return {"score": min_score, "move": best_move}
