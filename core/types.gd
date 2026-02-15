## Core game types and data structures.
## No Godot engine dependencies — pure data.
class_name Types
extends RefCounted

# ─── Piece Types ─────────────────────────────────────────────────

enum PieceType {
	CHIEF,
	KEEPER,
	HUNTER,
	RIVER_RUNNER,
	TRADER,
}

enum Player {
	WHITE,
	BLACK,
}

enum MoveType {
	MOVE,     # Normal move (may capture)
	SWAP,     # Swap with friendly adjacent piece
}

# ─── Direction Constants ─────────────────────────────────────────

const STRAIGHT: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(0, -1), Vector2i(0, 1),
]

const DIAGONAL: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(-1, 1),
	Vector2i(1, -1),  Vector2i(1, 1),
]

const KNIGHT_MOVES: Array[Vector2i] = [
	Vector2i(-2, -1), Vector2i(-2, 1),
	Vector2i(2, -1),  Vector2i(2, 1),
	Vector2i(-1, -2), Vector2i(-1, 2),
	Vector2i(1, -2),  Vector2i(1, 2),
]

const ALL_ADJACENT: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(0, -1), Vector2i(0, 1),
	Vector2i(-1, -1), Vector2i(-1, 1),
	Vector2i(1, -1),  Vector2i(1, 1),
]

# ─── Piece Info ──────────────────────────────────────────────────

const PIECE_INFO: Dictionary = {
	PieceType.CHIEF: {
		"name": "Chief",
		"sym_w": "♔", "sym_b": "♚",
		"can_cross_win": false,
		"is_leader": true,
		"material_value": 0,
	},
	PieceType.KEEPER: {
		"name": "Keeper",
		"sym_w": "♕", "sym_b": "♛",
		"can_cross_win": true,
		"is_leader": false,
		"material_value": 900,
	},
	PieceType.HUNTER: {
		"name": "Hunter",
		"sym_w": "♖", "sym_b": "♜",
		"can_cross_win": true,
		"is_leader": false,
		"material_value": 500,
	},
	PieceType.RIVER_RUNNER: {
		"name": "River Runner",
		"sym_w": "♗", "sym_b": "♝",
		"can_cross_win": true,
		"is_leader": false,
		"material_value": 400,
	},
	PieceType.TRADER: {
		"name": "Trader",
		"sym_w": "♘", "sym_b": "♞",
		"can_cross_win": false,
		"is_leader": false,
		"material_value": 700,
	},
}

# ─── Helper Functions ────────────────────────────────────────────

static func get_directions(piece_type: PieceType) -> Array[Vector2i]:
	match piece_type:
		PieceType.CHIEF, PieceType.KEEPER:
			return ALL_ADJACENT.duplicate()
		PieceType.HUNTER:
			return STRAIGHT.duplicate()
		PieceType.RIVER_RUNNER:
			return DIAGONAL.duplicate()
		PieceType.TRADER:
			return KNIGHT_MOVES.duplicate()
	return []

static func get_symbol(piece_type: PieceType, player: Player) -> String:
	var info: Dictionary = PIECE_INFO[piece_type]
	return info["sym_w"] if player == Player.WHITE else info["sym_b"]

static func get_letter(piece_type: PieceType) -> String:
	match piece_type:
		PieceType.CHIEF: return "K"
		PieceType.KEEPER: return "Q"
		PieceType.HUNTER: return "R"
		PieceType.RIVER_RUNNER: return "B"
		PieceType.TRADER: return "N"
	return "?"

static func get_piece_name(piece_type: PieceType) -> String:
	return PIECE_INFO[piece_type]["name"]

static func can_cross_win(piece_type: PieceType) -> bool:
	return PIECE_INFO[piece_type]["can_cross_win"]

static func get_material_value(piece_type: PieceType) -> int:
	return PIECE_INFO[piece_type]["material_value"]

static func opponent(player: Player) -> Player:
	return Player.BLACK if player == Player.WHITE else Player.WHITE

static func back_row(player: Player) -> int:
	## The row a player must reach to win by crossing.
	## White attacks toward row 0 (Black's home), Black attacks toward row 4 (White's home).
	return 0 if player == Player.WHITE else 4

# ─── Column/Row Labels ──────────────────────────────────────────

const COL_LABELS: Array[String] = ["a", "b", "c", "d", "e"]
const ROW_LABELS: Array[String] = ["5", "4", "3", "2", "1"]

const DIFFICULTY_NAMES: Array[String] = ["", "Beginner", "Easy", "Medium", "Hard", "Expert"]
