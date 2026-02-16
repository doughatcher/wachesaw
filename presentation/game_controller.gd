## Game controller -- manages game flow, turn logic, AI, and UI.
## Responsive: adapts layout to viewport size.
extends Control

# ---- Mode ----

enum GameMode { AI, LOCAL }

var mode: GameMode = GameMode.AI
var difficulty: int = 3

# ---- Game State ----

var board: Board
var turn: Types.Player = Types.Player.WHITE
var winner: int = -1
var selected: Vector2i = Vector2i(-1, -1)
var valid_moves: Array = []
var move_log: Array[String] = []
var captured_white: Array = []
var captured_black: Array = []
var thinking: bool = false
var move_count: int = 0
var history: Array[Board] = []

# ---- Nodes ----

@onready var board_view: Control = $BoardView
@onready var status_label: Label = $StatusBar/StatusLabel
@onready var move_log_container: VBoxContainer = $InfoPanel/InfoMargin/InfoVBox/MoveLogScroll/MoveLogContainer
@onready var new_game_btn: Button = $BottomBar/NewGameButton
@onready var menu_btn: Button = $TopBar/MenuButton
@onready var undo_btn: Button = $BottomBar/UndoButton
@onready var info_btn: Button = $BottomBar/InfoButton
@onready var info_panel: PanelContainer = $InfoPanel
@onready var close_btn: Button = $InfoPanel/InfoMargin/InfoVBox/InfoHeader/CloseButton
@onready var difficulty_selector: OptionButton = $TopBar/DifficultySelector
@onready var captured_white_label: Label = $CapturedBar/CapturedWhiteLabel
@onready var captured_black_label: Label = $CapturedBar/CapturedBlackLabel

# ---- Initialization ----

func _ready() -> void:
	mode = GameMode.AI if GameSettings.game_mode == 0 else GameMode.LOCAL
	difficulty = GameSettings.difficulty

	board_view.cell_clicked.connect(_on_cell_clicked)
	new_game_btn.pressed.connect(_on_new_game)
	menu_btn.pressed.connect(_on_menu)
	undo_btn.pressed.connect(_on_undo)
	if info_btn:
		info_btn.pressed.connect(_toggle_info)
	if close_btn:
		close_btn.pressed.connect(_toggle_info)
	difficulty_selector.item_selected.connect(_on_difficulty_changed)

	for i in range(1, 6):
		difficulty_selector.add_item("Lv.%d %s" % [i, Types.DIFFICULTY_NAMES[i]], i)
	difficulty_selector.selected = difficulty - 1

	get_viewport().size_changed.connect(_on_viewport_resized)
	# Default info panel open on wide screens
	info_visible = get_viewport_rect().size.x > 700
	_apply_info_layout()

	start_game()

var info_visible: bool = false

func _on_viewport_resized() -> void:
	_apply_info_layout()

func _toggle_info() -> void:
	info_visible = not info_visible
	_apply_info_layout()

func _apply_info_layout() -> void:
	if not info_panel or not board_view:
		return
	info_panel.visible = info_visible
	var right_inset := -268.0 if info_visible else 0.0
	board_view.offset_right = right_inset
	# Also inset the top bar, status bar, bottom bar, and captured bar
	var top_bar := $TopBar as Control
	var status_bar := $StatusBar as Control
	var bottom_bar := $BottomBar as Control
	var captured_bar := $CapturedBar as Control
	if top_bar:
		top_bar.offset_right = right_inset - 8.0
	if status_bar:
		status_bar.offset_right = right_inset - 8.0
	if bottom_bar:
		bottom_bar.offset_right = right_inset - 8.0
	if captured_bar:
		captured_bar.offset_right = right_inset - 12.0

func start_game() -> void:
	board = Board.create()
	turn = Types.Player.WHITE
	winner = -1
	selected = Vector2i(-1, -1)
	valid_moves = []
	move_log = []
	captured_white = []
	captured_black = []
	thinking = false
	move_count = 0
	history = []

	board_view.clear_selection()
	board_view.last_move_from = Vector2i(-1, -1)
	board_view.last_move_to = Vector2i(-1, -1)
	board_view.update_display(board)
	_update_ui()

# ---- Input ----

func _on_cell_clicked(row: int, col: int) -> void:
	if winner != -1 or thinking:
		return
	if mode == GameMode.AI and turn == Types.Player.BLACK:
		return

	var cell = board.get_cell(row, col)

	if cell != null and cell["player"] == turn:
		if selected.x == row and selected.y == col:
			_deselect()
			return
		_select(row, col)
		return

	if selected.x >= 0:
		var move = _find_valid_move(row, col)
		if move != null:
			_execute_move(selected.x, selected.y, row, col, move["type"])
		else:
			_deselect()

func _select(row: int, col: int) -> void:
	selected = Vector2i(row, col)
	valid_moves = MoveGenerator.get_moves_for_cell(board, row, col)
	board_view.set_selection(row, col, valid_moves)

func _deselect() -> void:
	selected = Vector2i(-1, -1)
	valid_moves = []
	board_view.clear_selection()

func _find_valid_move(row: int, col: int):
	for m in valid_moves:
		if m["row"] == row and m["col"] == col:
			return m
	return null

# ---- Move Execution ----

func _execute_move(fr: int, fc: int, tr: int, tc: int, move_type: Types.MoveType) -> void:
	history.append(board.clone())
	var notation := board.move_to_notation(fr, fc, tr, tc, move_type)
	var result := board.do_move(fr, fc, tr, tc, move_type)
	board = result["board"]
	var piece: Dictionary = result["piece"]
	var captured = result["captured"]

	if captured != null:
		if turn == Types.Player.WHITE:
			captured_white.append(captured["type"])
		else:
			captured_black.append(captured["type"])

	move_log.append(notation)
	move_count += 1

	_deselect()
	board_view.set_last_move(fr, fc, tr, tc)
	board_view.update_display(board)

	var win_result: int = WinChecker.check_win(board, turn, piece, tr, move_type)
	if win_result != -1:
		winner = win_result
		_update_ui()
		return

	var next_player := Types.opponent(turn)
	if not WinChecker.has_legal_moves(board, next_player):
		winner = turn
		_update_ui()
		return

	turn = next_player
	_update_ui()

	if mode == GameMode.AI and turn == Types.Player.BLACK and winner == -1:
		_ai_move()

func _ai_move() -> void:
	thinking = true
	_update_ui()
	await get_tree().create_timer(0.15).timeout
	var ai_move = Minimax.get_ai_move(board, difficulty)
	if ai_move != null:
		_execute_move(ai_move["fr"], ai_move["fc"], ai_move["tr"], ai_move["tc"], ai_move["mt"])
	thinking = false
	_update_ui()

# ---- Undo ----

func _on_undo() -> void:
	if history.is_empty() or winner != -1:
		return
	if mode == GameMode.AI and history.size() >= 2:
		board = history[-2]
		history.resize(history.size() - 2)
		move_log.resize(move_log.size() - 2)
		move_count -= 2
	else:
		board = history[-1]
		history.resize(history.size() - 1)
		move_log.resize(move_log.size() - 1)
		move_count -= 1
	turn = Types.Player.WHITE if move_count % 2 == 0 else Types.Player.BLACK
	winner = -1
	_deselect()
	board_view.last_move_from = Vector2i(-1, -1)
	board_view.last_move_to = Vector2i(-1, -1)
	board_view.update_display(board)
	_update_ui()

# ---- UI Updates ----

func _update_ui() -> void:
	if winner != -1:
		var wname := "White" if winner == Types.Player.WHITE else "Black"
		var flavor := ""
		if mode == GameMode.AI:
			flavor = " - Happy Hunting!" if winner == Types.Player.WHITE else " - Place of Great Weeping..."
		status_label.text = "%s wins!%s" % [wname, flavor]
		status_label.add_theme_color_override("font_color", Color("#7fa650"))
	elif thinking:
		status_label.text = "AI thinking..."
		status_label.remove_theme_color_override("font_color")
	else:
		var tname := "White" if turn == Types.Player.WHITE else "Black"
		status_label.text = "%s to move" % tname
		status_label.remove_theme_color_override("font_color")

	# Captured pieces display
	if captured_white_label:
		var cap_w := ""
		for t in captured_white:
			cap_w += Types.get_letter(t) + " "
		captured_white_label.text = cap_w.strip_edges()
		captured_white_label.add_theme_font_size_override("font_size", 13)
		captured_white_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))

	if captured_black_label:
		var cap_b := ""
		for t in captured_black:
			cap_b += Types.get_letter(t) + " "
		captured_black_label.text = cap_b.strip_edges()
		captured_black_label.add_theme_font_size_override("font_size", 13)
		captured_black_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))

	_update_move_log()
	undo_btn.disabled = history.is_empty() or winner != -1
	difficulty_selector.visible = mode == GameMode.AI

func _update_move_log() -> void:
	if not move_log_container:
		return
	for child in move_log_container.get_children():
		child.queue_free()

	if move_log.is_empty():
		var lbl := Label.new()
		lbl.text = "Game start"
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.25))
		move_log_container.add_child(lbl)
		return

	var move_num: int = 0
	var i: int = 0
	while i < move_log.size():
		move_num += 1
		var line := "%d. %s" % [move_num, move_log[i]]
		if i + 1 < move_log.size():
			line += "  %s" % move_log[i + 1]
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		move_log_container.add_child(lbl)
		i += 2

# ---- Buttons ----

func _on_new_game() -> void:
	start_game()

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_difficulty_changed(index: int) -> void:
	difficulty = index + 1
	start_game()
