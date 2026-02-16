## Visual board rendering -- draws the 5x5 grid and pieces.
## Dynamically sizes to fill available space. Responsive.
extends Control

signal cell_clicked(row: int, col: int)

# Colors
const COLOR_LIGHT := Color("#f0d9b5")
const COLOR_DARK := Color("#b58863")
const COLOR_SELECTED_LIGHT := Color("#829de0")
const COLOR_SELECTED_DARK := Color("#5c78b8")
const COLOR_LAST_MOVE_LIGHT := Color("#f5f682")
const COLOR_LAST_MOVE_DARK := Color("#d9da40")
const COLOR_CAPTURE_LIGHT := Color("#ee8888")
const COLOR_CAPTURE_DARK := Color("#c85555")
const COLOR_SWAP_LIGHT := Color("#88bce8")
const COLOR_SWAP_DARK := Color("#5c90c0")
const COLOR_VALID_LIGHT := Color("#c8e898")
const COLOR_VALID_DARK := Color("#98c060")
const COLOR_MOVE_DOT := Color(0, 0, 0, 0.22)
const COLOR_CAPTURE_CORNER := Color(0.75, 0.15, 0.15, 0.65)

# Piece colors
const WHITE_FILL := Color("#f5f0e8")
const WHITE_RIM := Color("#c8c0b0")
const WHITE_TOP := Color("#fffdf8")
const WHITE_LETTER := Color("#1a1510")
const BLACK_FILL := Color("#2e2822")
const BLACK_RIM := Color("#1a1510")
const BLACK_TOP := Color("#484038")
const BLACK_LETTER := Color("#e8dcc8")

# State set by the game controller
var board: Board = null
var selected_cell: Vector2i = Vector2i(-1, -1)
var valid_moves: Array = []
var last_move_from: Vector2i = Vector2i(-1, -1)
var last_move_to: Vector2i = Vector2i(-1, -1)

var font: Font

# Computed sizing
var cell_size: float = 80.0
var board_origin: Vector2 = Vector2.ZERO
var label_margin: float = 20.0

func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)
	_compute_layout()

func _on_resized() -> void:
	_compute_layout()
	queue_redraw()

func _compute_layout() -> void:
	var available := size
	if available.x <= 0 or available.y <= 0:
		return
	var usable_w := available.x - label_margin - 4.0
	var usable_h := available.y - label_margin - 4.0
	cell_size = floorf(minf(usable_w, usable_h) / float(Board.BOARD_SIZE))
	cell_size = maxf(cell_size, 40.0)
	var board_px := cell_size * Board.BOARD_SIZE
	board_origin = Vector2(
		label_margin + (usable_w - board_px) / 2.0,
		2.0 + (usable_h - board_px) / 2.0
	)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)

func _handle_click(pos: Vector2) -> void:
	var local := pos - board_origin
	var col: int = int(local.x / cell_size)
	var row: int = int(local.y / cell_size)
	if local.x >= 0 and local.y >= 0 and row >= 0 and row < Board.BOARD_SIZE and col >= 0 and col < Board.BOARD_SIZE:
		cell_clicked.emit(row, col)

func _draw() -> void:
	if board == null:
		return

	var cs := cell_size
	var origin := board_origin
	var board_px := cs * Board.BOARD_SIZE

	# Board shadow
	draw_rect(Rect2(origin + Vector2(3, 3), Vector2(board_px, board_px)), Color(0, 0, 0, 0.3))

	for r in range(Board.BOARD_SIZE):
		for c in range(Board.BOARD_SIZE):
			var rect := Rect2(origin + Vector2(c * cs, r * cs), Vector2(cs, cs))
			var light: bool = (r + c) % 2 == 0
			var color: Color = COLOR_LIGHT if light else COLOR_DARK

			var is_selected: bool = selected_cell.x == r and selected_cell.y == c
			var is_last: bool = (last_move_from.x == r and last_move_from.y == c) or \
								(last_move_to.x == r and last_move_to.y == c)
			var move_info = _find_valid_move(r, c)
			var cell = board.get_cell(r, c)

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

			# Move dot
			if move_info != null and cell == null and move_info["type"] == Types.MoveType.MOVE:
				var center := rect.position + rect.size / 2.0
				draw_circle(center, cs * 0.16, COLOR_MOVE_DOT)

			# Capture corner triangles
			if move_info != null and cell != null and move_info["type"] == Types.MoveType.MOVE:
				_draw_capture_corners(rect)

			# Swap indicator dots
			if move_info != null and move_info["type"] == Types.MoveType.SWAP:
				var cx := rect.position.x + cs * 0.82
				var cy := rect.position.y + cs * 0.18
				draw_circle(Vector2(cx - 4, cy), 3.0, Color("#3070c0"))
				draw_circle(Vector2(cx + 4, cy), 3.0, Color("#3070c0"))

			# Draw piece
			if cell != null:
				_draw_piece(rect, cell)

	# Border
	draw_rect(Rect2(origin, Vector2(board_px, board_px)), Color("#3d3a37"), false, 2.0)

	# Coordinate labels
	var label_size := clampi(int(cs * 0.14), 9, 13)
	for c in range(Board.BOARD_SIZE):
		var pos := origin + Vector2(c * cs + cs / 2.0 - 3, board_px + label_size + 4)
		draw_string(font, pos, Types.COL_LABELS[c], HORIZONTAL_ALIGNMENT_CENTER, -1, label_size, Color(1, 1, 1, 0.3))
	for r in range(Board.BOARD_SIZE):
		var pos := origin + Vector2(-label_margin + 4, r * cs + cs / 2.0 + 4)
		draw_string(font, pos, Types.ROW_LABELS[r], HORIZONTAL_ALIGNMENT_RIGHT, -1, label_size, Color(1, 1, 1, 0.3))

func _draw_piece(rect: Rect2, cell: Dictionary) -> void:
	var cs := cell_size
	var pc := rect.position + rect.size / 2.0
	var is_white: bool = cell["player"] == Types.Player.WHITE
	var radius := cs * 0.38

	# Drop shadow
	draw_circle(pc + Vector2(1.5, 3.0), radius + 1.0, Color(0, 0, 0, 0.35))

	# Outer rim
	var rim_c := WHITE_RIM if is_white else BLACK_RIM
	draw_circle(pc, radius + 1.5, rim_c)

	# Main fill
	var fill_c := WHITE_FILL if is_white else BLACK_FILL
	draw_circle(pc, radius, fill_c)

	# Inner highlight (top crescent for 3D feel)
	var top_c := WHITE_TOP if is_white else BLACK_TOP
	draw_circle(pc + Vector2(-1.5, -2.0), radius * 0.82, top_c)

	# Flatten center
	draw_circle(pc, radius * 0.72, fill_c)

	# Bottom shadow
	var bottom_shadow := Color(0, 0, 0, 0.12) if is_white else Color(0, 0, 0, 0.2)
	draw_circle(pc + Vector2(0, 2.0), radius * 0.65, bottom_shadow)
	draw_circle(pc, radius * 0.65, fill_c)

	# Letter
	var letter := Types.get_letter(cell["type"])
	var lcolor := WHITE_LETTER if is_white else BLACK_LETTER
	var fsize := clampi(int(cs * 0.36), 16, 32)
	var ts := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	var ascent := font.get_ascent(fsize)
	draw_string(font, Vector2(pc.x - ts.x / 2.0, pc.y + ascent * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, lcolor)

func _draw_capture_corners(rect: Rect2) -> void:
	var s := cell_size * 0.22
	var pts: PackedVector2Array
	pts = PackedVector2Array([rect.position, rect.position + Vector2(s, 0), rect.position + Vector2(0, s)])
	draw_colored_polygon(pts, COLOR_CAPTURE_CORNER)
	var tr_pt := rect.position + Vector2(rect.size.x, 0)
	pts = PackedVector2Array([tr_pt, tr_pt + Vector2(-s, 0), tr_pt + Vector2(0, s)])
	draw_colored_polygon(pts, COLOR_CAPTURE_CORNER)
	var bl_pt := rect.position + Vector2(0, rect.size.y)
	pts = PackedVector2Array([bl_pt, bl_pt + Vector2(s, 0), bl_pt + Vector2(0, -s)])
	draw_colored_polygon(pts, COLOR_CAPTURE_CORNER)
	var br_pt := rect.position + rect.size
	pts = PackedVector2Array([br_pt, br_pt + Vector2(-s, 0), br_pt + Vector2(0, -s)])
	draw_colored_polygon(pts, COLOR_CAPTURE_CORNER)

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
