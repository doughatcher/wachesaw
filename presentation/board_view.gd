## Visual board rendering with animations and theme integration.
## Dynamically sizes to fill available space. Responsive.
extends Control

signal cell_clicked(row: int, col: int)
signal animation_finished()

# ─── Default Colors (overridden by theme) ────────────────────────

var color_light := Color("#f0d9b5")
var color_dark := Color("#b58863")
var color_selected_light := Color("#829de0")
var color_selected_dark := Color("#5c78b8")
var color_last_move_light := Color("#f5f682")
var color_last_move_dark := Color("#d9da40")
var color_capture_light := Color("#ee8888")
var color_capture_dark := Color("#c85555")
var color_swap_light := Color("#88bce8")
var color_swap_dark := Color("#5c90c0")
var color_valid_light := Color("#c8e898")
var color_valid_dark := Color("#98c060")
var color_move_dot := Color(0, 0, 0, 0.22)
var color_capture_corner := Color(0.75, 0.15, 0.15, 0.65)
var color_border := Color("#3d3a37")
var color_shadow := Color(0, 0, 0, 0.3)
var color_label := Color(1, 1, 1, 0.3)

# Piece colors
var white_piece_color := Color("#f5f0e8")
var white_outline_color := Color("#1a1510")
var black_piece_color := Color("#2e2822")
var black_outline_color := Color("#e8dcc8")

# Theme effects
var piece_glow_color := Color(0, 0, 0, 0)
var cell_shimmer_color := Color(0, 0, 0, 0)
var themed: bool = false
var board_time: float = 0.0

# Chess unicode symbols
const PIECE_CHARS := {
	Types.PieceType.CHIEF: ["\u2654", "\u265a"],       # white king, black king
	Types.PieceType.KEEPER: ["\u2655", "\u265b"],      # white queen, black queen
	Types.PieceType.HUNTER: ["\u2656", "\u265c"],      # white rook, black rook
	Types.PieceType.RIVER_RUNNER: ["\u2657", "\u265d"],# white bishop, black bishop
	Types.PieceType.TRADER: ["\u2658", "\u265e"],      # white knight, black knight
}

# State set by the game controller
var board: Board = null
var selected_cell: Vector2i = Vector2i(-1, -1)
var valid_moves: Array = []
var last_move_from: Vector2i = Vector2i(-1, -1)
var last_move_to: Vector2i = Vector2i(-1, -1)

var font: Font
var symbol_font: Font

# Computed sizing
var cell_size: float = 80.0
var board_origin: Vector2 = Vector2.ZERO
var label_margin: float = 20.0

# ---- Animation State ----
var animating: bool = false
var anim_t: float = 0.0
const ANIM_DURATION := 0.2
const RESET_ANIM_DURATION := 0.35

# Moving pieces: Array of {from: Vector2i, to: Vector2i, cell: Dictionary}
var anim_moves: Array = []
# Captured piece fading out: {pos: Vector2i, cell: Dictionary, alpha: float}
var anim_capture: Dictionary = {}
# After-animation board to switch to
var anim_target_board: Board = null

# Win effect
var win_flash_t: float = -1.0
var win_player: int = -1
const WIN_FLASH_DURATION := 1.5

# Board flash overlay
var board_flash_alpha: float = 0.0

func _ready() -> void:
	font = ThemeDB.fallback_font
	symbol_font = load("res://presentation/fonts/NotoSansSymbols2-Regular.ttf")
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)
	_compute_layout()
	set_process(true)

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

func _process(delta: float) -> void:
	var needs_redraw := false
	board_time += delta

	# Piece movement animation
	if animating:
		anim_t += delta
		var dur := RESET_ANIM_DURATION if anim_moves.size() > 2 else ANIM_DURATION
		if anim_t >= dur:
			_finish_animation()
		needs_redraw = true

	# Win flash
	if win_flash_t >= 0.0:
		win_flash_t += delta
		if win_flash_t > WIN_FLASH_DURATION:
			win_flash_t = -1.0
		needs_redraw = true

	if needs_redraw or themed:
		queue_redraw()

## Apply a themed color palette from AnimatedBackground.
func set_board_palette(palette: Dictionary) -> void:
	themed = true
	color_light = palette.get("cell_light", color_light)
	color_dark = palette.get("cell_dark", color_dark)
	color_selected_light = palette.get("selected_light", color_selected_light)
	color_selected_dark = palette.get("selected_dark", color_selected_dark)
	color_last_move_light = palette.get("last_move_light", color_last_move_light)
	color_last_move_dark = palette.get("last_move_dark", color_last_move_dark)
	color_valid_light = palette.get("valid_light", color_valid_light)
	color_valid_dark = palette.get("valid_dark", color_valid_dark)
	color_capture_light = palette.get("capture_light", color_capture_light)
	color_capture_dark = palette.get("capture_dark", color_capture_dark)
	color_swap_light = palette.get("swap_light", color_swap_light)
	color_swap_dark = palette.get("swap_dark", color_swap_dark)
	color_move_dot = palette.get("move_dot", color_move_dot)
	color_capture_corner = palette.get("capture_corner", color_capture_corner)
	color_border = palette.get("border", color_border)
	color_shadow = palette.get("shadow", color_shadow)
	color_label = palette.get("label", color_label)
	white_piece_color = palette.get("white_piece", white_piece_color)
	white_outline_color = palette.get("white_outline", white_outline_color)
	black_piece_color = palette.get("black_piece", black_piece_color)
	black_outline_color = palette.get("black_outline", black_outline_color)
	piece_glow_color = palette.get("piece_glow", piece_glow_color)
	cell_shimmer_color = palette.get("cell_shimmer", cell_shimmer_color)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)

func _handle_click(pos: Vector2) -> void:
	if animating:
		return
	var local := pos - board_origin
	var col: int = int(local.x / cell_size)
	var row: int = int(local.y / cell_size)
	if local.x >= 0 and local.y >= 0 and row >= 0 and row < Board.BOARD_SIZE and col >= 0 and col < Board.BOARD_SIZE:
		cell_clicked.emit(row, col)

# ---- Animation API ----

func animate_move(from: Vector2i, to: Vector2i, captured_pos: Vector2i, captured_cell, new_board: Board) -> void:
	anim_moves = [{"from": from, "to": to, "cell": board.get_cell(from.x, from.y)}]
	if captured_cell != null:
		anim_capture = {"pos": captured_pos, "cell": captured_cell, "alpha": 1.0}
	else:
		anim_capture = {}
	anim_target_board = new_board
	anim_t = 0.0
	animating = true

func animate_swap(pos_a: Vector2i, pos_b: Vector2i, new_board: Board) -> void:
	anim_moves = [
		{"from": pos_a, "to": pos_b, "cell": board.get_cell(pos_a.x, pos_a.y)},
		{"from": pos_b, "to": pos_a, "cell": board.get_cell(pos_b.x, pos_b.y)},
	]
	anim_capture = {}
	anim_target_board = new_board
	anim_t = 0.0
	animating = true

func animate_reset(old_board: Board, new_board: Board) -> void:
	# Move every piece from old position to new position
	anim_moves = []
	# Collect all pieces on old board
	var old_pieces: Array = []
	for r in range(Board.BOARD_SIZE):
		for c in range(Board.BOARD_SIZE):
			var cell = old_board.get_cell(r, c)
			if cell != null:
				old_pieces.append({"pos": Vector2i(r, c), "cell": cell})
	# Match to new board by piece identity
	var used_new: Array = []
	for op in old_pieces:
		var best_dist := 999.0
		var best_new := Vector2i(-1, -1)
		for r in range(Board.BOARD_SIZE):
			for c in range(Board.BOARD_SIZE):
				var nc = new_board.get_cell(r, c)
				if nc != null and nc["type"] == op["cell"]["type"] and nc["player"] == op["cell"]["player"]:
					var key := Vector2i(r, c)
					if key not in used_new:
						var dist := Vector2(op["pos"]).distance_to(Vector2(key))
						if dist < best_dist:
							best_dist = dist
							best_new = key
		if best_new.x >= 0:
			used_new.append(best_new)
			anim_moves.append({"from": op["pos"], "to": best_new, "cell": op["cell"]})
	# Pieces only on new board (previously captured) fade in from their spot
	for r in range(Board.BOARD_SIZE):
		for c in range(Board.BOARD_SIZE):
			var nc = new_board.get_cell(r, c)
			if nc != null and Vector2i(r, c) not in used_new:
				anim_moves.append({"from": Vector2i(r, c), "to": Vector2i(r, c), "cell": nc})
	anim_capture = {}
	anim_target_board = new_board
	anim_t = 0.0
	animating = true

func _finish_animation() -> void:
	animating = false
	anim_moves = []
	anim_capture = {}
	if anim_target_board != null:
		board = anim_target_board
		anim_target_board = null
	queue_redraw()
	animation_finished.emit()

func trigger_win_effect(player: int) -> void:
	win_player = player
	win_flash_t = 0.0

# ---- Drawing ----

func _draw() -> void:
	if board == null and anim_target_board == null:
		return

	var cs := cell_size
	var origin := board_origin
	var board_px := cs * Board.BOARD_SIZE
	var draw_board := board if board != null else anim_target_board

	# Board shadow
	draw_rect(Rect2(origin + Vector2(4, 4), Vector2(board_px, board_px)), color_shadow)

	# Outer glow when themed
	if themed:
		var glow_c := piece_glow_color
		glow_c.a = 0.08 + sin(board_time * 0.5) * 0.03
		draw_rect(Rect2(origin - Vector2(3, 3), Vector2(board_px + 6, board_px + 6)), glow_c)

	# Cells that are currently being animated (skip drawing their pieces normally)
	var anim_cells: Array[Vector2i] = []
	if animating:
		for am in anim_moves:
			anim_cells.append(am["from"])
			anim_cells.append(am["to"])
		if anim_capture.size() > 0:
			anim_cells.append(anim_capture["pos"])

	for r in range(Board.BOARD_SIZE):
		for c in range(Board.BOARD_SIZE):
			var rect := Rect2(origin + Vector2(c * cs, r * cs), Vector2(cs, cs))
			var light: bool = (r + c) % 2 == 0
			var color: Color = color_light if light else color_dark

			var is_selected: bool = selected_cell.x == r and selected_cell.y == c
			var is_last: bool = (last_move_from.x == r and last_move_from.y == c) or \
								(last_move_to.x == r and last_move_to.y == c)
			var move_info = _find_valid_move(r, c)
			var cell = draw_board.get_cell(r, c)

			if is_selected:
				color = color_selected_light if light else color_selected_dark
			elif move_info != null:
				if move_info["type"] == Types.MoveType.MOVE and cell != null:
					color = color_capture_light if light else color_capture_dark
				elif move_info["type"] == Types.MoveType.SWAP:
					color = color_swap_light if light else color_swap_dark
				elif move_info["type"] == Types.MoveType.MOVE:
					color = color_valid_light if light else color_valid_dark
			elif is_last and not is_selected:
				color = color_last_move_light if light else color_last_move_dark

			draw_rect(rect, color)

			# Subtle cell shimmer effect when themed
			if themed:
				var shimmer_phase := board_time * 0.8 + r * 1.1 + c * 0.7
				var shimmer_alpha := (sin(shimmer_phase) * 0.5 + 0.5) * 0.06
				if light:
					shimmer_alpha *= 1.5
				var sc := cell_shimmer_color
				sc.a = shimmer_alpha
				draw_rect(rect, sc)

			# Move dot
			if move_info != null and cell == null and move_info["type"] == Types.MoveType.MOVE:
				var center := rect.position + rect.size / 2.0
				draw_circle(center, cs * 0.16, color_move_dot)

			# Capture corner triangles
			if move_info != null and cell != null and move_info["type"] == Types.MoveType.MOVE:
				_draw_capture_corners(rect)

			# Swap indicator dots
			if move_info != null and move_info["type"] == Types.MoveType.SWAP:
				var swap_cx := rect.position.x + cs * 0.82
				var swap_cy := rect.position.y + cs * 0.18
				var swap_dot_c := color_swap_light.lightened(0.3)
				draw_circle(Vector2(swap_cx - 4, swap_cy), 3.0, swap_dot_c)
				draw_circle(Vector2(swap_cx + 4, swap_cy), 3.0, swap_dot_c)

			# Draw static piece (skip if animating)
			if cell != null and Vector2i(r, c) not in anim_cells:
				_draw_piece_at(origin + Vector2(c * cs + cs / 2.0, r * cs + cs / 2.0), cell, 1.0)

	# Border
	draw_rect(Rect2(origin, Vector2(board_px, board_px)), color_border, false, 2.0)

	# Draw animated pieces on top (so they appear above the board)
	if animating:
		var dur := RESET_ANIM_DURATION if anim_moves.size() > 2 else ANIM_DURATION
		var t := clampf(anim_t / dur, 0.0, 1.0)
		# Ease out cubic
		var et := 1.0 - pow(1.0 - t, 3.0)

		for am in anim_moves:
			var from_px := origin + Vector2(am["from"].y * cs + cs / 2.0, am["from"].x * cs + cs / 2.0)
			var to_px := origin + Vector2(am["to"].y * cs + cs / 2.0, am["to"].x * cs + cs / 2.0)
			var pos := from_px.lerp(to_px, et)
			_draw_piece_at(pos, am["cell"], 1.0)

		# Fading captured piece
		if anim_capture.size() > 0:
			var cap_alpha := 1.0 - t
			var cap_pos := origin + Vector2(anim_capture["pos"].y * cs + cs / 2.0, anim_capture["pos"].x * cs + cs / 2.0)
			_draw_piece_at(cap_pos, anim_capture["cell"], cap_alpha)

	# Win flash overlay
	if win_flash_t >= 0.0:
		var wt := win_flash_t / WIN_FLASH_DURATION
		# Pulse 3 times then fade
		var pulse := sin(wt * PI * 6.0) * 0.5 + 0.5
		var fade := 1.0 - wt
		var win_color := Color("#7fa650") if win_player == Types.Player.WHITE else Color("#c05050")
		win_color.a = pulse * fade * 0.25
		draw_rect(Rect2(origin, Vector2(board_px, board_px)), win_color)

	# Coordinate labels
	var label_size := clampi(int(cs * 0.14), 9, 13)
	for c in range(Board.BOARD_SIZE):
		var pos := origin + Vector2(c * cs + cs / 2.0 - 3, board_px + label_size + 4)
		draw_string(font, pos, Types.COL_LABELS[c], HORIZONTAL_ALIGNMENT_CENTER, -1, label_size, color_label)
	for r in range(Board.BOARD_SIZE):
		var pos := origin + Vector2(-label_margin + 4, r * cs + cs / 2.0 + 4)
		draw_string(font, pos, Types.ROW_LABELS[r], HORIZONTAL_ALIGNMENT_RIGHT, -1, label_size, color_label)

func _draw_piece_at(center: Vector2, cell: Dictionary, alpha: float) -> void:
	var cs := cell_size
	var pc := center
	var is_white: bool = cell["player"] == Types.Player.WHITE

	var syms: Array = PIECE_CHARS[cell["type"]]
	var sym: String = syms[0] if is_white else syms[1]

	# Use themed colors
	var lcolor: Color
	var outline_color: Color
	if is_white:
		lcolor = white_piece_color
		lcolor.a = alpha
		outline_color = white_outline_color
		outline_color.a = alpha
	else:
		lcolor = black_piece_color
		lcolor.a = alpha
		outline_color = black_outline_color
		outline_color.a = alpha

	var fsize := clampi(int(cs * 0.72), 28, 64)
	var draw_font: Font = symbol_font if symbol_font else font
	var ts := draw_font.get_string_size(sym, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	var ascent := draw_font.get_ascent(fsize)
	var text_pos := Vector2(pc.x - ts.x / 2.0, pc.y + ascent * 0.36)

	# Piece glow effect when themed
	if themed and piece_glow_color.a > 0:
		var glow_alpha := alpha * (0.15 + sin(board_time * 1.5 + pc.x * 0.03 + pc.y * 0.02) * 0.08)
		var gc := piece_glow_color
		gc.a = glow_alpha
		draw_circle(pc, cs * 0.38, gc)

	# Thick contrasting outline
	var outline_w := maxf(cs * 0.022, 2.0)
	for ox in [-outline_w, 0.0, outline_w]:
		for oy in [-outline_w, 0.0, outline_w]:
			if ox == 0.0 and oy == 0.0:
				continue
			draw_string(draw_font, text_pos + Vector2(ox, oy), sym, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, outline_color)

	# Main glyph on top
	draw_string(draw_font, text_pos, sym, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, lcolor)

func _draw_capture_corners(rect: Rect2) -> void:
	var s := cell_size * 0.22
	var pts: PackedVector2Array
	pts = PackedVector2Array([rect.position, rect.position + Vector2(s, 0), rect.position + Vector2(0, s)])
	draw_colored_polygon(pts, color_capture_corner)
	var tr_pt := rect.position + Vector2(rect.size.x, 0)
	pts = PackedVector2Array([tr_pt, tr_pt + Vector2(-s, 0), tr_pt + Vector2(0, s)])
	draw_colored_polygon(pts, color_capture_corner)
	var bl_pt := rect.position + Vector2(0, rect.size.y)
	pts = PackedVector2Array([bl_pt, bl_pt + Vector2(s, 0), bl_pt + Vector2(0, -s)])
	draw_colored_polygon(pts, color_capture_corner)
	var br_pt := rect.position + rect.size
	pts = PackedVector2Array([br_pt, br_pt + Vector2(-s, 0), br_pt + Vector2(0, -s)])
	draw_colored_polygon(pts, color_capture_corner)

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
