## Game controller -- manages game flow, turn logic, AI, and UI.
## Responsive: adapts layout to viewport size.
## Handles animations, scene transitions, and win effects.
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
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var background: Control = %Background

# ---- Initialization ----

func _ready() -> void:
	mode = GameMode.AI if GameSettings.game_mode == 0 else GameMode.LOCAL
	difficulty = GameSettings.difficulty

	# Set random animated background
	if background and background.has_method("set_random_theme"):
		background.set_random_theme()
		if background.has_method("get_board_palette"):
			board_view.set_board_palette(background.get_board_palette())

	board_view.cell_clicked.connect(_on_cell_clicked)
	board_view.animation_finished.connect(_on_animation_finished)
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
	# Default info panel open on wide screens only
	info_visible = _is_wide()
	_apply_info_layout()

	# Fade in from black
	if fade_overlay:
		fade_overlay.color = Color(0, 0, 0, 1)
		var tween := create_tween()
		tween.tween_property(fade_overlay, "color:a", 0.0, 0.35)
		tween.tween_callback(func(): fade_overlay.visible = false)

	start_game()

var info_visible: bool = false

func _on_viewport_resized() -> void:
	_apply_info_layout()

func _toggle_info() -> void:
	info_visible = not info_visible
	_apply_info_layout()

func _is_wide() -> bool:
	return get_viewport_rect().size.x > 700

func _apply_info_layout() -> void:
	if not info_panel or not board_view:
		return
	info_panel.visible = info_visible
	var wide := _is_wide()
	if wide and info_visible:
		var panel_w := 240.0
		var right_inset := -panel_w - 8.0
		board_view.offset_right = right_inset
		info_panel.offset_left = -panel_w
		_set_bars_right(right_inset)
	else:
		board_view.offset_right = 0.0
		if not wide and info_visible:
			info_panel.anchor_left = 0.0
			info_panel.offset_left = 0.0
		else:
			info_panel.anchor_left = 1.0
			info_panel.offset_left = -240.0
		_set_bars_right(-8.0)

func _set_bars_right(r: float) -> void:
	var top_bar := $TopBar as Control
	var status_bar := $StatusBar as Control
	var bottom_bar := $BottomBar as Control
	var captured_bar := $CapturedBar as Control
	if top_bar:
		top_bar.offset_right = r
	if status_bar:
		status_bar.offset_right = r
	if bottom_bar:
		bottom_bar.offset_right = r
	if captured_bar:
		captured_bar.offset_right = r

func start_game() -> void:
	var old_board := board
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

	# Animate pieces back to starting positions if there was a previous game
	if old_board != null:
		board_view.animate_reset(old_board, board)
	else:
		board_view.update_display(board)
	_update_ui()

# ---- Animation Callback ----

var pending_after_anim: Callable = Callable()

func _on_animation_finished() -> void:
	if pending_after_anim.is_valid():
		var cb := pending_after_anim
		pending_after_anim = Callable()
		cb.call()

# ---- Input ----

func _on_cell_clicked(row: int, col: int) -> void:
	if winner != -1 or thinking:
		return
	if board_view.animating:
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

	# Capture info before move
	var captured_cell = null
	var captured_pos := Vector2i(-1, -1)
	if move_type == Types.MoveType.MOVE:
		var target = board.get_cell(tr, tc)
		if target != null:
			captured_cell = target.duplicate()
			captured_pos = Vector2i(tr, tc)

	var result := board.do_move(fr, fc, tr, tc, move_type)
	var new_board: Board = result["board"]
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

	# Animate the move instead of instant display
	if move_type == Types.MoveType.SWAP:
		board_view.animate_swap(Vector2i(fr, fc), Vector2i(tr, tc), new_board)
	else:
		board_view.animate_move(Vector2i(fr, fc), Vector2i(tr, tc), captured_pos, captured_cell, new_board)

	# Set up post-animation callback
	var win_result: int = WinChecker.check_win(new_board, turn, piece, tr, move_type)
	var next_player := Types.opponent(turn)
	var no_legal := not WinChecker.has_legal_moves(new_board, next_player)

	pending_after_anim = func():
		board = new_board
		if win_result != -1:
			winner = win_result
			board_view.trigger_win_effect(winner)
			_update_ui()
			return
		if no_legal:
			winner = turn
			board_view.trigger_win_effect(winner)
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
	if board_view.animating:
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

	# Captured pieces display using chess symbols
	if captured_white_label:
		var cap_w := ""
		for t in captured_white:
			cap_w += Types.get_symbol(t, Types.Player.BLACK) + " "
		captured_white_label.text = cap_w.strip_edges()
		captured_white_label.add_theme_font_size_override("font_size", 16)
		captured_white_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))

	if captured_black_label:
		var cap_b := ""
		for t in captured_black:
			cap_b += Types.get_symbol(t, Types.Player.WHITE) + " "
		captured_black_label.text = cap_b.strip_edges()
		captured_black_label.add_theme_font_size_override("font_size", 16)
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
	_fade_to_scene("res://scenes/main_menu.tscn")

func _on_difficulty_changed(index: int) -> void:
	difficulty = index + 1
	start_game()

# ---- Scene Transitions ----

func _fade_to_scene(scene_path: String) -> void:
	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.color = Color(0, 0, 0, 0)
		var tween := create_tween()
		tween.tween_property(fade_overlay, "color:a", 1.0, 0.3)
		tween.tween_callback(func(): get_tree().change_scene_to_file(scene_path))
	else:
		get_tree().change_scene_to_file(scene_path)
