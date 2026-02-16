## Validates puzzle win conditions with move-count constraints.
## Handles both "capture chief in N moves" and "cross piece in N moves" puzzles.
class_name PuzzleValidator
extends RefCounted

# ─── Win Condition Types ─────────────────────────────────────────

enum WinType {
	CAPTURE_CHIEF,  # Capture opponent's Chief
	CROSS_PIECE,    # Get a piece to the opponent's back row
}

# ─── Validation ──────────────────────────────────────────────────

## Check if the puzzle's win condition is met.
## puzzle_config: {"type": "capture_chief"|"cross_piece", "max_moves": int, "exact_moves": int (optional)}
## player_moves: number of moves the *player* has made (not counting opponent responses)
## Returns: "win", "fail", or "continue"
static func check_puzzle_state(
	board: Board,
	puzzle_config: Dictionary,
	player: Types.Player,
	player_moves: int,
	last_piece: Dictionary,
	last_dest_row: int,
	last_move_type: Types.MoveType
) -> String:
	var win_type: String = puzzle_config.get("type", "capture_chief")
	var max_moves: int = puzzle_config.get("max_moves", 1)
	var exact_moves: int = puzzle_config.get("exact_moves", -1)

	# Check if the win condition is met
	var won := false

	if win_type == "capture_chief":
		var opponent := Types.opponent(player)
		if not board.has_chief(opponent):
			won = true
	elif win_type == "cross_piece":
		if last_move_type != Types.MoveType.SWAP and Types.can_cross_win(last_piece.get("type", -1)):
			var target_row: int = Types.back_row(player)
			if last_dest_row == target_row:
				won = true

	if won:
		# Check move count constraints
		if exact_moves > 0 and player_moves != exact_moves:
			return "fail"  # Solved but not in exactly N moves
		return "win"

	# Check if player has exceeded move limit
	if player_moves >= max_moves:
		return "fail"

	return "continue"

## Check if the player still has legal moves.
static func has_moves(board: Board, player: Types.Player) -> bool:
	return WinChecker.has_legal_moves(board, player)

## Format the puzzle objective as a display string.
static func format_objective(puzzle_config: Dictionary, player_label: String) -> String:
	var win_type: String = puzzle_config.get("type", "capture_chief")
	var max_moves: int = puzzle_config.get("max_moves", 1)
	var exact_moves: int = puzzle_config.get("exact_moves", -1)

	var move_str: String
	if exact_moves > 0:
		move_str = "exactly %d" % exact_moves
	else:
		move_str = "%d" % max_moves
	var move_word := "move" if max_moves == 1 and exact_moves <= 1 else "moves"

	if win_type == "capture_chief":
		return "Capture the enemy Chief in %s %s" % [move_str, move_word]
	elif win_type == "cross_piece":
		return "Cross a piece to the back row in %s %s" % [move_str, move_word]
	else:
		return "Complete the objective in %s %s" % [move_str, move_word]
