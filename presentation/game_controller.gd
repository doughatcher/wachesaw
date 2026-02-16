## Game controller — manages game flow, turn logic, AI, and UI wiring.
extends Control

# ─── Mode ────────────────────────────────────────────────────────

enum GameMode { AI, LOCAL }

var mode: GameMode = GameMode.AI
var difficulty: int = 3

# ─── Game State ──────────────────────────────────────────────────

var board: Board
var turn: Types.Player = Types.Player.WHITE
var winner: int = -1  # -1 = no winner, otherwise Types.Player value
var selected: Vector2i = Vector2i(-1, -1)
var valid_moves: Array = []
var move_log: Array[String] = []
var captured_white: Array = []  # Types captured BY white (black pieces)
var captured_black: Array = []  # Types captured BY black (white pieces)
var thinking: bool = false
var move_count: int = 0
var history: Array[Board] = []  # For undo

# ─── Nodes ───────────────────────────────────────────────────────

@onready var board_view: Control = %BoardView
@onready var status_label: Label = %StatusLabel
@onready var move_log_container: VBoxContainer = %MoveLogContainer
@onready var captured_top: Label = %CapturedTop
@onready var captured_bottom: Label = %CapturedBottom
@onready var new_game_btn: Button = %NewGameButton
@onready var menu_btn: Button = %MenuButton
@onready var undo_btn: Button = %UndoButton
@onready var difficulty_selector: OptionButton = %DifficultySelector

# ─── Initialization ─────────────────────────────────────────────

func _ready() -> void:
	# Read settings from autoload
	mode = GameMode.AI if GameSettings.game_mode == 0 else GameMode.LOCAL
	difficulty = GameSettings.difficulty

	board_view.cell_clicked.connect(_on_cell_clicked)
	new_game_btn.pressed.connect(_on_new_game)
	menu_btn.pressed.connect(_on_menu)
	undo_btn.pressed.connect(_on_undo)
	difficulty_selector.item_selected.connect(_on_difficulty_changed)

	# Populate difficulty dropdown
	for i in range(1, 6):
		difficulty_selector.add_item("Lv.%d %s" % [i, Types.DIFFICULTY_NAMES[i]], i)
	difficulty_selector.selected = difficulty - 1

	start_game()

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

	_update_ui()
	board_view.clear_selection()
	board_view.last_move_from = Vector2i(-1, -1)
	board_view.last_move_to = Vector2i(-1, -1)
	board_view.update_display(board)

# ─── Input ───────────────────────────────────────────────────────

func _on_cell_clicked(row: int, col: int) -> void:
	if winner != -1 or thinking:
		return
	if mode == GameMode.AI and turn == Types.Player.BLACK:
		return

	var cell = board.get_cell(row, col)

	# Clicking own piece — select it (or deselect if already selected)
	if cell != null and cell["player"] == turn:
		if selected.x == row and selected.y == col:
			_deselect()
			return
		_select(row, col)
		return

	# Clicking with a piece selected — try to execute move
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

# ─── Move Execution ─────────────────────────────────────────────

func _execute_move(fr: int, fc: int, tr: int, tc: int, move_type: Types.MoveType) -> void:
	# Save for undo
	history.append(board.clone())

	# Generate notation before executing
	var notation := board.move_to_notation(fr, fc, tr, tc, move_type)

	# Execute
	var result := board.do_move(fr, fc, tr, tc, move_type)
	board = result["board"]
	var piece: Dictionary = result["piece"]
	var captured = result["captured"]

	# Track captures
	if captured != null:
		if turn == Types.Player.WHITE:
			captured_white.append(captured["type"])
		else:
			captured_black.append(captured["type"])

	# Log
	move_log.append(notation)
	move_count += 1

	# Update visuals
	_deselect()
	board_view.set_last_move(fr, fc, tr, tc)
	board_view.update_display(board)

	# Check win
	var win_result: int = WinChecker.check_win(board, turn, piece, tr, move_type)
	if win_result != -1:
		winner = win_result
		_update_ui()
		return

	# Check if opponent has legal moves
	var next_player := Types.opponent(turn)
	if not WinChecker.has_legal_moves(board, next_player):
		winner = turn  # Opponent can't move = current player wins
		_update_ui()
		return

	# Switch turn
	turn = next_player
	_update_ui()

	# Trigger AI
	if mode == GameMode.AI and turn == Types.Player.BLACK and winner == -1:
		_ai_move()

func _ai_move() -> void:
	thinking = true
	_update_ui()

	# Use a timer to let the UI update before the AI thinks
	await get_tree().create_timer(0.15).timeout

	var ai_move = Minimax.get_ai_move(board, difficulty)
	if ai_move != null:
		_execute_move(ai_move["fr"], ai_move["fc"], ai_move["tr"], ai_move["tc"], ai_move["mt"])

	thinking = false
	_update_ui()

# ─── Undo ────────────────────────────────────────────────────────

func _on_undo() -> void:
	if history.is_empty() or winner != -1:
		return

	# In AI mode, undo both the AI's move and the player's move
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

# ─── UI Updates ──────────────────────────────────────────────────

func _update_ui() -> void:
	# Status
	if winner != -1:
		var winner_name := "White" if winner == Types.Player.WHITE else "Black"
		var flavor := ""
		if mode == GameMode.AI:
			flavor = " - Happy Hunting!" if winner == Types.Player.WHITE else " - Place of Great Weeping..."
		status_label.text = "%s wins!%s" % [winner_name, flavor]
		status_label.add_theme_color_override("font_color", Color("#7fa650"))
	elif thinking:
		status_label.text = "AI thinking..."
		status_label.remove_theme_color_override("font_color")
	else:
		var turn_name := "White" if turn == Types.Player.WHITE else "Black"
		status_label.text = "%s to move" % turn_name
		status_label.remove_theme_color_override("font_color")

	# Captured pieces
	var cap_top_text := ""
	for t in captured_black:
		cap_top_text += Types.get_letter(t) + " "
	captured_top.text = cap_top_text.strip_edges()

	var cap_bottom_text := ""
	for t in captured_white:
		cap_bottom_text += Types.get_letter(t) + " "
	captured_bottom.text = cap_bottom_text.strip_edges()

	# Move log
	_update_move_log()

	# Undo button
	undo_btn.disabled = history.is_empty() or winner != -1

	# Difficulty selector visibility
	difficulty_selector.visible = mode == GameMode.AI

func _update_move_log() -> void:
	# Clear existing
	for child in move_log_container.get_children():
		child.queue_free()

	if move_log.is_empty():
		var lbl := Label.new()
		lbl.text = "White opens."
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

# ─── Buttons ─────────────────────────────────────────────────────

func _on_new_game() -> void:
	start_game()

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_difficulty_changed(index: int) -> void:
	difficulty = index + 1
	start_game()

# ─── Public API (called from main menu) ─────────────────────────

func set_mode(new_mode: GameMode) -> void:
	mode = new_mode

func set_difficulty_level(level: int) -> void:
	difficulty = clampi(level, 1, 5)
	if difficulty_selector:
		difficulty_selector.selected = difficulty - 1
