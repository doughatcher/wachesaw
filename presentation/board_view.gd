## Visual board rendering — draws the 5×5 grid and pieces.
## This is the only layer that touches Godot's scene tree.
extends Control

signal cell_clicked(row: int, col: int)

const CELL_SIZE: int = 80
const BOARD_PX: int = CELL_SIZE * Board.BOARD_SIZE

# Colors matching the prototype's chess style
const COLOR_LIGHT := Color("#f0d9b5")
const COLOR_DARK := Color("#b58863")
const COLOR_SELECTED_LIGHT := Color("#6db4e8")
const COLOR_SELECTED_DARK := Color("#4a90c0")
const COLOR_LAST_MOVE_LIGHT := Color("#f7ec7a")
const COLOR_LAST_MOVE_DARK := Color("#dac534")
const COLOR_CAPTURE_LIGHT := Color("#f09090")
const COLOR_CAPTURE_DARK := Color("#c86060")
const COLOR_SWAP_LIGHT := Color("#90c0e8")
const COLOR_SWAP_DARK := Color("#6898c0")
const COLOR_VALID_LIGHT := Color("#cce8a0")
const COLOR_VALID_DARK := Color("#9cc068")
const COLOR_MOVE_DOT := Color(0, 0, 0, 0.2)
const COLOR_CAPTURE_BORDER := Color(0.67, 0.12, 0.12, 0.55)

# State set by the game controller
var board: Board = null
var selected_cell: Vector2i = Vector2i(-1, -1)
var valid_moves: Array = []  # [{row, col, type}]
var last_move_from: Vector2i = Vector2i(-1, -1)
var last_move_to: Vector2i = Vector2i(-1, -1)

# Labels
var col_labels: Array[Label] = []
var row_labels: Array[Label] = []

var font: Font

func _ready() -> void:
	custom_minimum_size = Vector2(BOARD_PX + 24, BOARD_PX + 48)
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	# Only handle mouse button — emulate_mouse_from_touch converts touch→mouse,
	# so handling both types causes select-then-immediately-deselect.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)

func _handle_click(pos: Vector2) -> void:
	# Offset for labels
	var board_origin := Vector2(22, 24)
	var local := pos - board_origin
	var col: int = int(local.x) / CELL_SIZE
	var row: int = int(local.y) / CELL_SIZE
	if row >= 0 and row < Board.BOARD_SIZE and col >= 0 and col < Board.BOARD_SIZE:
		cell_clicked.emit(row, col)

func _draw() -> void:
	if board == null:
		return

	var origin := Vector2(22, 24)

	# Draw board squares
	for r in range(Board.BOARD_SIZE):
		for c in range(Board.BOARD_SIZE):
			var rect := Rect2(origin + Vector2(c * CELL_SIZE, r * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))
			var light: bool = (r + c) % 2 == 0
			var color: Color = COLOR_LIGHT if light else COLOR_DARK

			var is_selected: bool = selected_cell.x == r and selected_cell.y == c
			var is_last: bool = (last_move_from.x == r and last_move_from.y == c) or \
								(last_move_to.x == r and last_move_to.y == c)
			var move_info = _find_valid_move(r, c)
			var cell = board.get_cell(r, c)

			# Layer coloring (priority: selected > move indicator > last move > default)
			if is_selected:
				color = COLOR_SELECTED_LIGHT if light else COLOR_SELECTED_DARK
			elif move_info != null:
				if move_info["type"] == Types.MoveType.MOVE and cell != null:
					color = COLOR_CAPTURE_LIGHT if light else COLOR_CAPTURE_DARK
				elif move_info["type"] == Types.MoveType.SWAP:
					color = COLOR_SWAP_LIGHT if light else COLOR_SWAP_DARK
				elif move_info["type"] == Types.MoveType.MOVE:
					color = COLOR_VALID_LIGHT if light else COLOR_VALID_DARK
			elif is_last and not is_selected:
				color = COLOR_LAST_MOVE_LIGHT if light else COLOR_LAST_MOVE_DARK

			draw_rect(rect, color)

			# Draw move dot (empty valid move square)
			if move_info != null and cell == null and move_info["type"] == Types.MoveType.MOVE:
				var center := rect.position + rect.size / 2.0
				draw_circle(center, 13.0, COLOR_MOVE_DOT)

			# Draw capture border
			if move_info != null and cell != null and move_info["type"] == Types.MoveType.MOVE:
				draw_rect(Rect2(rect.position + Vector2(3, 3), rect.size - Vector2(6, 6)), COLOR_CAPTURE_BORDER, false, 3.0)

			# Draw swap indicator
			if move_info != null and move_info["type"] == Types.MoveType.SWAP:
				draw_string(font, rect.position + Vector2(rect.size.x - 18, 16), "sw", HORIZONTAL_ALIGNMENT_RIGHT, -1, 11, Color("#1a5090"))

			# Draw piece
			if cell != null:
				var is_white: bool = cell["player"] == Types.Player.WHITE
				var pc := rect.position + rect.size / 2.0
				# Shadow
				draw_circle(pc + Vector2(1, 2), 28.0, Color(0, 0, 0, 0.25))
				# Piece disc
				var fill_c := Color("#f0e4d0") if is_white else Color("#3a3028")
				var rim_c := Color("#8a8070") if is_white else Color("#5a5048")
				draw_circle(pc, 29.0, rim_c)
				draw_circle(pc, 27.0, fill_c)
				# Letter
				var letter := Types.get_letter(cell["type"])
				var lcolor := Color("#2a1e14") if is_white else Color("#ecdcc4")
				var fsize := 26
				var ts := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
				var ascent := font.get_ascent(fsize)
				draw_string(font, Vector2(pc.x - ts.x / 2.0, pc.y + ascent * 0.35), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, lcolor)

	# Draw border
	draw_rect(Rect2(origin, Vector2(BOARD_PX, BOARD_PX)), Color("#3d3a37"), false, 2.0)

	# Column labels
	for c in range(Board.BOARD_SIZE):
		var pos := origin + Vector2(c * CELL_SIZE + CELL_SIZE / 2.0 - 4, BOARD_PX + 16)
		draw_string(font, pos, Types.COL_LABELS[c], HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1, 1, 1, 0.25))

	# Row labels
	for r in range(Board.BOARD_SIZE):
		var pos := origin + Vector2(-18, r * CELL_SIZE + CELL_SIZE / 2.0 + 4)
		draw_string(font, pos, Types.ROW_LABELS[r], HORIZONTAL_ALIGNMENT_RIGHT, -1, 11, Color(1, 1, 1, 0.25))

func _find_valid_move(row: int, col: int):
	for m in valid_moves:
		if m["row"] == row and m["col"] == col:
			return m
	return null

func update_display(new_board: Board) -> void:
	board = new_board
	queue_redraw()

func set_selection(row: int, col: int, moves: Array) -> void:
	selected_cell = Vector2i(row, col)
	valid_moves = moves
	queue_redraw()

func clear_selection() -> void:
	selected_cell = Vector2i(-1, -1)
	valid_moves = []
	queue_redraw()

func set_last_move(from_row: int, from_col: int, to_row: int, to_col: int) -> void:
	last_move_from = Vector2i(from_row, from_col)
	last_move_to = Vector2i(to_row, to_col)
	queue_redraw()
