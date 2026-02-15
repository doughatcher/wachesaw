## Win condition evaluation.
## No Godot engine dependencies.
class_name WinChecker
extends RefCounted

## Check if the game has been won after a move.
## Returns the winning Player, or -1 if no winner.
##
## Parameters:
##   board: the board state AFTER the move
##   player: the player who just moved
##   piece: the piece that was moved (Dictionary with "type" key)
##   dest_row: the destination row of the move
##   move_type: MOVE or SWAP
static func check_win(board: Board, player: Types.Player, piece: Dictionary, dest_row: int, move_type: Types.MoveType) -> int:
	# Swaps never directly win
	if move_type == Types.MoveType.SWAP:
		return _check_chief_capture(board)

	# 1. Chief capture — did someone lose their Chief?
	var chief_result := _check_chief_capture(board)
	if chief_result != -1:
		return chief_result

	# 2. Back row crossing — did the moved piece reach the opponent's home row?
	if Types.can_cross_win(piece["type"]):
		var target_row: int = Types.back_row(player)
		if dest_row == target_row:
			return player

	return -1

static func _check_chief_capture(board: Board) -> int:
	var white_chief := board.has_chief(Types.Player.WHITE)
	var black_chief := board.has_chief(Types.Player.BLACK)

	if not white_chief:
		return Types.Player.BLACK
	if not black_chief:
		return Types.Player.WHITE

	return -1

## Check if a player has any legal moves.
## If not, that player loses (spec §2.6).
static func has_legal_moves(board: Board, player: Types.Player) -> bool:
	var moves := MoveGenerator.get_all_moves(board, player)
	return moves.size() > 0
