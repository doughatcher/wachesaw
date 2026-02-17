## Puzzle game controller -- manages puzzle-specific game flow.
## Loads pre-made board positions, validates solutions against move constraints,
## handles scripted opponent responses.
extends Control

# ─── Puzzle Config ───────────────────────────────────────────────

var puzzle_data: Dictionary = {}
var puzzle_id: String = ""
var puzzle_title: String = ""
var puzzle_description: String = ""
var win_condition: Dictionary = {}
var player_side: Types.Player = Types.Player.WHITE
var opponent_side: Types.Player = Types.Player.BLACK
var scripted_moves: Array = []  # Opponent's scripted responses

# ─── Game State ──────────────────────────────────────────────────

var board: Board
var initial_board: Board  # For reset
var turn: Types.Player = Types.Player.WHITE
var winner: int = -1
var selected: Vector2i = Vector2i(-1, -1)
var valid_moves: Array = []
var player_move_count: int = 0
var total_move_count: int = 0
var opponent_move_index: int = 0
var failed_attempts: int = 0

# ─── Nodes ───────────────────────────────────────────────────────

@onready var board_view: Control = $BoardView
@onready var title_label: Label = $TopBar/TitleLabel
@onready var status_label: Label = $StatusBar/StatusLabel
@onready var objective_label: Label = $ObjectiveBar/ObjectiveLabel
@onready var move_counter: Label = $ObjectiveBar/MoveCounter
@onready var retry_btn: Button = $BottomBar/RetryButton
@onready var undo_btn: Button = $BottomBar/UndoButton
@onready var skip_btn: Button = $BottomBar/SkipButton
@onready var menu_btn: Button = $TopBar/MenuButton
@onready var hint_label: Label = $HintLabel
@onready var background: Control = %Background

var history: Array[Board] = []
var pending_after_anim: Callable = Callable()

# ─── Initialization ─────────────────────────────────────────────

func _ready() -> void:
	puzzle_data = GameSettings.story_puzzle_data

	# Set animated background theme
	if background and background.has_method("set_theme_by_name"):
		background.set_theme_by_name(GameSettings.story_background)
		if background.has_method("get_board_palette"):
			board_view.set_board_palette(background.get_board_palette())

	# Connect map watcher for hot-reload
	if MapWatcher.is_watching():
		MapWatcher.map_changed.connect(_on_map_file_changed)

	_load_puzzle_data()

	# Connect signals
	board_view.cell_clicked.connect(_on_cell_clicked)
	board_view.animation_finished.connect(_on_animation_finished)
	retry_btn.pressed.connect(_on_retry)
	undo_btn.pressed.connect(_on_undo)
	skip_btn.pressed.connect(_on_skip)
	menu_btn.pressed.connect(_on_menu)

	_start_puzzle()

func _exit_tree() -> void:
	# Disconnect watcher to avoid calling into a freed node
	if MapWatcher.map_changed.is_connected(_on_map_file_changed):
		MapWatcher.map_changed.disconnect(_on_map_file_changed)

func _load_puzzle_data() -> void:
	puzzle_id = puzzle_data.get("id", "unknown")
	puzzle_title = puzzle_data.get("title", "Puzzle")
	puzzle_description = puzzle_data.get("description", "")
	win_condition = puzzle_data.get("win_condition", {"type": "capture_chief", "max_moves": 1})
	scripted_moves = puzzle_data.get("opponent_moves", [])

	var player_str: String = puzzle_data.get("player", "white")
	player_side = Types.Player.WHITE if player_str == "white" else Types.Player.BLACK
	opponent_side = Types.opponent(player_side)

	# Build board from data
	var board_array: Array = puzzle_data.get("board", [])
	board = StoryData.build_board(board_array)
	initial_board = board.clone()

	# Setup UI
	title_label.text = puzzle_title
	objective_label.text = PuzzleValidator.format_objective(win_condition, "")
	skip_btn.visible = false

	if hint_label:
		var hint: String = puzzle_data.get("hint", "")
		hint_label.text = hint
		hint_label.visible = false

## Called by MapWatcher when the map file changes on disk — hot-reloads the puzzle.
func _on_map_file_changed(new_puzzle_data: Dictionary) -> void:
	print("[PuzzleController] Hot-reloading map: %s" % new_puzzle_data.get("title", ""))
	puzzle_data = new_puzzle_data
	GameSettings.story_puzzle_data = new_puzzle_data
	_load_puzzle_data()
	_start_puzzle()

func _start_puzzle() -> void:
	turn = player_side
	winner = -1
	player_move_count = 0
	total_move_count = 0
	opponent_move_index = 0
	selected = Vector2i(-1, -1)
	valid_moves = []
	history = []

	board_view.clear_selection()
	board_view.last_move_from = Vector2i(-1, -1)
	board_view.last_move_to = Vector2i(-1, -1)
	board_view.update_display(board)
	_update_ui()

# ─── Animation Callback ─────────────────────────────────────────

func _on_animation_finished() -> void:
	if pending_after_anim.is_valid():
		var cb := pending_after_anim
		pending_after_anim = Callable()
		cb.call()

# ─── Input ───────────────────────────────────────────────────────

func _on_cell_clicked(row: int, col: int) -> void:
	if winner != -1:
		return
	if board_view.animating:
		return
	if turn != player_side:
		return

	var cell = board.get_cell(row, col)

	if cell != null and cell["player"] == player_side:
		if selected.x == row and selected.y == col:
			_deselect()
			return
		_select(row, col)
		return

	if selected.x >= 0:
		var move = _find_valid_move(row, col)
		if move != null:
			_execute_player_move(selected.x, selected.y, row, col, move["type"])
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

func _execute_player_move(fr: int, fc: int, tr: int, tc: int, move_type: Types.MoveType) -> void:
	history.append(board.clone())

	var result := board.do_move(fr, fc, tr, tc, move_type)
	var new_board: Board = result["board"]
	var piece: Dictionary = result["piece"]

	player_move_count += 1
	total_move_count += 1

	_deselect()
	board_view.set_last_move(fr, fc, tr, tc)

	# Animate
	if move_type == Types.MoveType.SWAP:
		board_view.animate_swap(Vector2i(fr, fc), Vector2i(tr, tc), new_board)
	else:
		var captured_pos := Vector2i(-1, -1)
		var captured_cell = null
		var target = board.get_cell(tr, tc)
		if target != null:
			captured_cell = target.duplicate()
			captured_pos = Vector2i(tr, tc)
		board_view.animate_move(Vector2i(fr, fc), Vector2i(tr, tc), captured_pos, captured_cell, new_board)

	# Post-animation: check puzzle state
	pending_after_anim = func():
		board = new_board
		var state := PuzzleValidator.check_puzzle_state(
			board, win_condition, player_side,
			player_move_count, piece, tr, move_type
		)
		match state:
			"win":
				_on_puzzle_solved()
			"fail":
				_on_puzzle_failed()
			"continue":
				# Opponent's turn — play scripted move
				if opponent_move_index < scripted_moves.size():
					turn = opponent_side
					_update_ui()
					await get_tree().create_timer(0.3).timeout
					_execute_opponent_move()
				else:
					_update_ui()

func _execute_opponent_move() -> void:
	if opponent_move_index >= scripted_moves.size():
		turn = player_side
		_update_ui()
		return

	var notation: String = scripted_moves[opponent_move_index]
	var move = StoryData.parse_move_notation(notation, board, opponent_side)

	if move == null:
		push_warning("PuzzleController: Invalid scripted move: %s" % notation)
		turn = player_side
		_update_ui()
		return

	opponent_move_index += 1
	total_move_count += 1

	var fr: int = move["fr"]
	var fc: int = move["fc"]
	var tr: int = move["tr"]
	var tc: int = move["tc"]
	var mt: Types.MoveType = move["mt"]

	var result := board.do_move(fr, fc, tr, tc, mt)
	var new_board: Board = result["board"]

	board_view.set_last_move(fr, fc, tr, tc)

	if mt == Types.MoveType.SWAP:
		board_view.animate_swap(Vector2i(fr, fc), Vector2i(tr, tc), new_board)
	else:
		var captured_pos := Vector2i(-1, -1)
		var captured_cell = null
		var target = board.get_cell(tr, tc)
		if target != null:
			captured_cell = target.duplicate()
			captured_pos = Vector2i(tr, tc)
		board_view.animate_move(Vector2i(fr, fc), Vector2i(tr, tc), captured_pos, captured_cell, new_board)

	pending_after_anim = func():
		board = new_board
		turn = player_side
		_update_ui()

# ─── Puzzle Resolution ──────────────────────────────────────────

func _on_puzzle_solved() -> void:
	winner = player_side
	status_label.text = "Puzzle Complete!"
	status_label.add_theme_color_override("font_color", Color("#7fa650"))
	StoryProgress.mark_completed(puzzle_id)
	board_view.trigger_win_effect(player_side)

	# Auto-advance after a brief delay
	await get_tree().create_timer(1.5).timeout
	SceneManager.advance_story()

func _on_puzzle_failed() -> void:
	winner = -2  # Sentinel for "failed"
	failed_attempts += 1
	status_label.text = "Not quite... Try again!"
	status_label.add_theme_color_override("font_color", Color("#c85555"))
	retry_btn.grab_focus()

	if failed_attempts >= 3:
		skip_btn.visible = true

# ─── Undo ────────────────────────────────────────────────────────

func _on_undo() -> void:
	if history.is_empty() or winner != -1:
		return
	if board_view.animating:
		return
	# Reset to initial state (simpler than tracking opponent undo)
	_on_retry()

func _on_retry() -> void:
	board = initial_board.clone()
	winner = -1
	_start_puzzle()

func _on_skip() -> void:
	# Skip without marking as completed
	SceneManager.advance_story()

func _on_menu() -> void:
	SceneManager.stop_story()

# ─── UI Updates ──────────────────────────────────────────────────

func _update_ui() -> void:
	if winner == -1:
		var max_moves: int = win_condition.get("max_moves", 1)
		move_counter.text = "Move %d / %d" % [player_move_count, max_moves]
		if turn == player_side:
			status_label.text = "Your move"
			status_label.remove_theme_color_override("font_color")
		else:
			status_label.text = "Opponent responds..."
			status_label.remove_theme_color_override("font_color")

	undo_btn.disabled = history.is_empty() or winner != -1

	if hint_label and puzzle_data.has("hint"):
		hint_label.visible = failed_attempts >= 2
