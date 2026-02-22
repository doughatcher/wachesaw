#!/usr/bin/env python3
"""
Wachesaw Level Editor — GTK4 visual editor for story chapter JSON files.

Usage:
    python3 tools/level_editor.py [path/to/chapter_N.json]
    just level-editor               (opens file chooser)
    just edit-chapter 1             (opens chapter 1)

    # macOS native mode — Play button launches Godot directly:
    python3 tools/level_editor.py --native --godot-path=/path/to/godot [chapter.json]
    just mac-level-editor           (uses brew Python + Godot)
    just mac-edit-chapter 1         (opens chapter 1 natively)

Dependencies (Ubuntu/Debian):
    sudo apt-get install python3-gi gir1.2-gtk-4.0

Dependencies (macOS via Homebrew):
    brew install gtk4 pygobject3 gobject-introspection adwaita-icon-theme
    brew install --cask godot       (for native Play mode)
    # Or run: just mac-setup
"""

import os
import signal
import subprocess
import sys
import copy
import json
import webbrowser
from pathlib import Path

try:
    import gi
    gi.require_version("Gtk", "4.0")
    from gi.repository import Gtk, Gio, GLib, Gdk, Pango
except (ImportError, ValueError) as _err:
    print(f"Error: GTK4 Python bindings not available: {_err}")
    if sys.platform == "darwin":
        print("Install with:  brew install gtk4 pygobject3 gobject-introspection adwaita-icon-theme")
        print("Then run with: $(brew --prefix)/bin/python3 tools/level_editor.py")
        print("Or just run:   just mac-setup && just mac-level-editor")
    else:
        print("Install with:  sudo apt-get install python3-gi gir1.2-gtk-4.0")
    sys.exit(1)

# ── Constants ──────────────────────────────────────────────────────────────────

PROJECT_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_DIR / "data"

PIECE_TYPES = ["CHIEF", "HUNTER", "KEEPER", "RIVER_RUNNER", "TRADER"]
PLAYERS = ["white", "black"]
WIN_CONDITIONS = ["capture_chief", "cross_piece"]
BOARD_SIZE = 5

# Unicode chess symbols (white = outline, black = filled)
PIECE_SYMBOLS = {
    "white": {
        "CHIEF":        "♔",
        "HUNTER":       "♖",
        "KEEPER":       "♕",
        "RIVER_RUNNER": "♗",
        "TRADER":       "♘",
    },
    "black": {
        "CHIEF":        "♚",
        "HUNTER":       "♜",
        "KEEPER":       "♛",
        "RIVER_RUNNER": "♝",
        "TRADER":       "♞",
    },
}

PIECE_LABELS = {
    "CHIEF":        "Chief",
    "HUNTER":       "Hunter",
    "KEEPER":       "Keeper",
    "RIVER_RUNNER": "River Runner",
    "TRADER":       "Trader",
}


def piece_symbol(cell) -> str:
    if cell is None:
        return ""
    return PIECE_SYMBOLS.get(cell["player"], {}).get(cell["type"], "?")


def piece_tooltip(cell) -> str:
    if cell is None:
        return "Empty — click to place a piece"
    player = cell["player"].capitalize()
    label = PIECE_LABELS.get(cell["type"], cell["type"])
    return f"{player} {label} — click to change"


def empty_board():
    return [[None] * BOARD_SIZE for _ in range(BOARD_SIZE)]


# ── CSS ────────────────────────────────────────────────────────────────────────

EDITOR_CSS = b"""
.board-cell-light { background-color: #f0d9b5; }
.board-cell-dark  { background-color: #b58863; }
.board-cell       { border-radius: 0; border: 1px solid #888; min-width: 54px; min-height: 54px; }
.board-cell label { font-size: 26px; }
.piece-white      { color: #222222; }
.piece-black      { color: #222222; }
.step-row         { padding: 4px 8px; }
"""


# ── Cell Popover ───────────────────────────────────────────────────────────────

class CellPopover(Gtk.Popover):
    """Popover for selecting a piece to place in a board cell."""

    def __init__(self, on_select):
        super().__init__()
        self._on_select = on_select
        self.set_has_arrow(True)

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        outer.set_margin_start(10)
        outer.set_margin_end(10)
        outer.set_margin_top(10)
        outer.set_margin_bottom(10)
        self.set_child(outer)

        # Clear button
        clear_btn = Gtk.Button(label="✕  Clear cell")
        clear_btn.connect("clicked", lambda _b: self._pick(None))
        outer.append(clear_btn)

        outer.append(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL))

        # Grid: columns = players, rows = piece types
        grid = Gtk.Grid(row_spacing=4, column_spacing=6)
        outer.append(grid)

        for col, player in enumerate(PLAYERS):
            lbl = Gtk.Label(label=player.capitalize())
            lbl.add_css_class("caption")
            grid.attach(lbl, col + 1, 0, 1, 1)

        for row, ptype in enumerate(PIECE_TYPES):
            lbl = Gtk.Label(label=PIECE_LABELS[ptype], xalign=1.0)
            lbl.set_margin_end(4)
            grid.attach(lbl, 0, row + 1, 1, 1)

            for col, player in enumerate(PLAYERS):
                sym = PIECE_SYMBOLS[player][ptype]
                btn = Gtk.Button(label=sym)
                btn.set_tooltip_text(f"{player.capitalize()} {PIECE_LABELS[ptype]}")
                btn.connect(
                    "clicked",
                    lambda _b, pt=ptype, pl=player: self._pick({"type": pt, "player": pl}),
                )
                grid.attach(btn, col + 1, row + 1, 1, 1)

    def _pick(self, piece):
        self.popdown()
        self._on_select(piece)


# ── Board Grid Widget ──────────────────────────────────────────────────────────

class BoardGrid(Gtk.Box):
    """5×5 interactive board editor."""

    def __init__(self, on_change=None):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self._on_change = on_change
        self._board = empty_board()
        self._buttons: dict[tuple[int, int], Gtk.Button] = {}

        grid = Gtk.Grid()
        grid.set_row_homogeneous(True)
        grid.set_column_homogeneous(True)
        grid.set_row_spacing(2)
        grid.set_column_spacing(2)
        self.append(grid)

        # Column labels (a–e)
        for col in range(BOARD_SIZE):
            lbl = Gtk.Label(label=chr(ord("a") + col))
            lbl.add_css_class("caption")
            grid.attach(lbl, col + 1, 0, 1, 1)

        for row in range(BOARD_SIZE):
            # Row label
            lbl = Gtk.Label(label=str(row))
            lbl.add_css_class("caption")
            lbl.set_xalign(1.0)
            lbl.set_margin_end(4)
            grid.attach(lbl, 0, row + 1, 1, 1)

            for col in range(BOARD_SIZE):
                btn = Gtk.Button()
                btn.add_css_class("board-cell")
                if (row + col) % 2 == 0:
                    btn.add_css_class("board-cell-light")
                else:
                    btn.add_css_class("board-cell-dark")
                btn.connect("clicked", self._on_cell_clicked, row, col)
                self._buttons[(row, col)] = btn
                grid.attach(btn, col + 1, row + 1, 1, 1)

        self._refresh()

    def set_board(self, board):
        self._board = copy.deepcopy(board) if board else empty_board()
        self._refresh()

    def get_board(self):
        return copy.deepcopy(self._board)

    def _refresh(self):
        for (row, col), btn in self._buttons.items():
            cell = self._board[row][col]
            sym = piece_symbol(cell)

            child = btn.get_child()
            if not isinstance(child, Gtk.Label):
                child = Gtk.Label()
                btn.set_child(child)

            if sym:
                child.set_markup(f'<span font="26">{sym}</span>')
            else:
                child.set_markup('<span font="14" alpha="50%">·</span>')

            btn.set_tooltip_text(piece_tooltip(cell))

    def _on_cell_clicked(self, btn, row, col):
        popover = CellPopover(lambda piece: self._place(row, col, piece))
        popover.set_parent(btn)
        popover.popup()

    def _place(self, row, col, piece):
        self._board[row][col] = piece
        self._refresh()
        if self._on_change:
            self._on_change(self._board)


# ── Dialog Step Editor ─────────────────────────────────────────────────────────

class DialogEditor(Gtk.Box):
    """Editor for a 'dialog' step (list of speaker/portrait/text lines)."""

    def __init__(self, on_change=None):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self._on_change = on_change
        self._lines: list[dict] = []

        self.set_margin_start(12)
        self.set_margin_end(12)
        self.set_margin_top(12)
        self.set_margin_bottom(12)

        hdr = Gtk.Label(label="Dialog Lines")
        hdr.add_css_class("heading")
        hdr.set_xalign(0)
        self.append(hdr)

        scrolled = Gtk.ScrolledWindow()
        scrolled.set_vexpand(True)
        self._list_box = Gtk.ListBox()
        self._list_box.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self._list_box.add_css_class("boxed-list")
        scrolled.set_child(self._list_box)
        self.append(scrolled)

        btn_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        add_btn = Gtk.Button(label="+ Add Line")
        add_btn.connect("clicked", self._add_line)
        btn_bar.append(add_btn)
        del_btn = Gtk.Button(label="Delete Line")
        del_btn.add_css_class("destructive-action")
        del_btn.connect("clicked", self._delete_line)
        btn_bar.append(del_btn)
        self.append(btn_bar)

    def set_step(self, step):
        self._lines = copy.deepcopy(step.get("lines", []))
        self._rebuild()

    def get_step_data(self) -> dict:
        return {"type": "dialog", "lines": copy.deepcopy(self._lines)}

    # ── Private ──────────────────────────────────────────────────────

    def _rebuild(self):
        while True:
            row = self._list_box.get_row_at_index(0)
            if row is None:
                break
            self._list_box.remove(row)

        for i, line in enumerate(self._lines):
            self._list_box.append(self._make_row(i, line))

    def _make_row(self, idx: int, line: dict) -> Gtk.ListBoxRow:
        row = Gtk.ListBoxRow()
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        box.set_margin_start(8)
        box.set_margin_end(8)
        box.set_margin_top(8)
        box.set_margin_bottom(8)
        row.set_child(box)

        for key, placeholder in [("speaker", "(narrator)"), ("portrait", "(none)"), ("text", "")]:
            hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            lbl = Gtk.Label(label=f"{key.capitalize()}:")
            lbl.set_size_request(72, -1)
            lbl.set_xalign(1.0)
            entry = Gtk.Entry()
            entry.set_text(line.get(key) or "")
            entry.set_placeholder_text(placeholder)
            entry.set_hexpand(True)
            entry.connect("changed", self._on_field_changed, idx, key)
            hbox.append(lbl)
            hbox.append(entry)
            box.append(hbox)

        return row

    def _on_field_changed(self, entry, idx: int, key: str):
        if idx < len(self._lines):
            val = entry.get_text().strip() or None
            self._lines[idx][key] = val
            if self._on_change:
                self._on_change()

    def _add_line(self, _btn):
        self._lines.append({"speaker": None, "portrait": None, "text": ""})
        self._rebuild()
        if self._on_change:
            self._on_change()

    def _delete_line(self, _btn):
        row = self._list_box.get_selected_row()
        if row is None:
            return
        idx = row.get_index()
        if 0 <= idx < len(self._lines):
            del self._lines[idx]
            self._rebuild()
            if self._on_change:
                self._on_change()


# ── Puzzle Step Editor ─────────────────────────────────────────────────────────

class PuzzleEditor(Gtk.Box):
    """Editor for a 'puzzle' step."""

    def __init__(self, on_change=None):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
        self._on_change = on_change
        self._loading = False

        self.set_margin_start(12)
        self.set_margin_end(12)
        self.set_margin_top(12)
        self.set_margin_bottom(12)

        # ── Left column: board ───────────────────────────────────────
        board_col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        board_hdr = Gtk.Label(label="Board  (click a cell to place / change a piece)")
        board_hdr.add_css_class("heading")
        board_hdr.set_xalign(0)
        board_col.append(board_hdr)
        self._board_grid = BoardGrid(on_change=lambda _b: self._notify())
        board_col.append(self._board_grid)
        self.append(board_col)

        # ── Right column: metadata ───────────────────────────────────
        meta_col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        meta_col.set_hexpand(True)
        meta_col.set_vexpand(True)
        self.append(meta_col)

        meta_hdr = Gtk.Label(label="Puzzle Metadata")
        meta_hdr.add_css_class("heading")
        meta_hdr.set_xalign(0)
        meta_col.append(meta_hdr)

        def row(label_text, widget):
            box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
            lbl = Gtk.Label(label=label_text)
            lbl.set_size_request(110, -1)
            lbl.set_xalign(1.0)
            widget.set_hexpand(True)
            box.append(lbl)
            box.append(widget)
            return box

        self._id_entry = Gtk.Entry()
        self._id_entry.connect("changed", lambda _e: self._notify())
        meta_col.append(row("ID:", self._id_entry))

        self._title_entry = Gtk.Entry()
        self._title_entry.connect("changed", lambda _e: self._notify())
        meta_col.append(row("Title:", self._title_entry))

        self._desc_entry = Gtk.Entry()
        self._desc_entry.connect("changed", lambda _e: self._notify())
        meta_col.append(row("Description:", self._desc_entry))

        self._hint_entry = Gtk.Entry()
        self._hint_entry.connect("changed", lambda _e: self._notify())
        meta_col.append(row("Hint:", self._hint_entry))

        self._player_combo = Gtk.DropDown.new_from_strings(PLAYERS)
        self._player_combo.connect("notify::selected", lambda _dd, _p: self._notify())
        meta_col.append(row("Player:", self._player_combo))

        self._win_combo = Gtk.DropDown.new_from_strings(WIN_CONDITIONS)
        self._win_combo.connect("notify::selected", lambda _dd, _p: self._notify())
        meta_col.append(row("Win Condition:", self._win_combo))

        adj = Gtk.Adjustment(value=1, lower=1, upper=20, step_increment=1)
        self._max_moves_spin = Gtk.SpinButton(adjustment=adj)
        self._max_moves_spin.connect("value-changed", lambda _s: self._notify())
        meta_col.append(row("Max Moves:", self._max_moves_spin))

        self._opp_entry = Gtk.Entry()
        self._opp_entry.set_placeholder_text("e.g. Kd1, Kd2  (comma-separated)")
        self._opp_entry.connect("changed", lambda _e: self._notify())
        meta_col.append(row("Opp. Moves:", self._opp_entry))

    def set_step(self, step: dict):
        self._loading = True

        self._id_entry.set_text(step.get("id", ""))
        self._title_entry.set_text(step.get("title", ""))
        self._desc_entry.set_text(step.get("description", ""))
        self._hint_entry.set_text(step.get("hint", ""))

        player = step.get("player", "white")
        self._player_combo.set_selected(PLAYERS.index(player) if player in PLAYERS else 0)

        wc = step.get("win_condition", {})
        wc_type = wc.get("type", "capture_chief")
        self._win_combo.set_selected(
            WIN_CONDITIONS.index(wc_type) if wc_type in WIN_CONDITIONS else 0
        )
        self._max_moves_spin.set_value(wc.get("max_moves", 1))

        opp_moves = step.get("opponent_moves", [])
        self._opp_entry.set_text(", ".join(opp_moves))

        self._board_grid.set_board(step.get("board", empty_board()))

        self._loading = False

    def get_step_data(self) -> dict:
        wc_type = WIN_CONDITIONS[self._win_combo.get_selected()]
        opp_text = self._opp_entry.get_text().strip()
        opp_moves = [m.strip() for m in opp_text.split(",") if m.strip()] if opp_text else []
        return {
            "type": "puzzle",
            "id": self._id_entry.get_text().strip(),
            "title": self._title_entry.get_text().strip(),
            "description": self._desc_entry.get_text().strip(),
            "player": PLAYERS[self._player_combo.get_selected()],
            "hint": self._hint_entry.get_text().strip(),
            "board": self._board_grid.get_board(),
            "win_condition": {
                "type": wc_type,
                "max_moves": int(self._max_moves_spin.get_value()),
            },
            "opponent_moves": opp_moves,
        }

    def _notify(self):
        if not self._loading and self._on_change:
            self._on_change()


# ── Main Window ────────────────────────────────────────────────────────────────

class LevelEditorWindow(Gtk.ApplicationWindow):

    def __init__(self, app: Gtk.Application):
        super().__init__(application=app, title="Wachesaw Level Editor")
        self.set_default_size(1280, 820)

        self._chapter: dict | None = None
        self._filepath: str | None = None
        self._current_idx: int = -1
        self._dirty: bool = False
        self._server_proc: subprocess.Popen | None = None
        self._server_port: int = 8001  # Use 8001 to avoid conflict with 'just serve' on 8000

        # Native Godot playback (macOS) — set via --native / --godot-path CLI flags
        self._native_mode: bool = getattr(app, "native_mode", False)
        self._godot_path: str = getattr(app, "godot_path", "")
        self._godot_proc: subprocess.Popen | None = None

        self._install_css()
        self._build_ui()
        self.connect("close-request", self._on_close_request)

    # ── CSS ───────────────────────────────────────────────────────────────────

    def _install_css(self):
        provider = Gtk.CssProvider()
        provider.load_from_data(EDITOR_CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

    # ── UI construction ───────────────────────────────────────────────────────

    def _build_ui(self):
        # Header bar
        header = Gtk.HeaderBar()
        self.set_titlebar(header)

        open_btn = Gtk.Button(label="Open…")
        open_btn.connect("clicked", self._open_file)
        header.pack_start(open_btn)

        self._play_btn = Gtk.Button(label="▶ Play")
        if self._native_mode:
            self._play_btn.set_tooltip_text("Save & play natively (launches Godot)")
            self._play_btn.connect("clicked", self._play_native)
        else:
            self._play_btn.set_tooltip_text("Save & play in browser (launches dev server)")
            self._play_btn.connect("clicked", self._play_in_browser)
        self._play_btn.set_sensitive(False)
        header.pack_start(self._play_btn)

        save_btn = Gtk.Button(label="Save")
        save_btn.add_css_class("suggested-action")
        save_btn.connect("clicked", self._save_file)
        header.pack_end(save_btn)

        self._header_title = Gtk.Label(label="No file open")
        header.set_title_widget(self._header_title)

        # Main paned layout
        paned = Gtk.Paned(orientation=Gtk.Orientation.HORIZONTAL)
        paned.set_position(290)
        self.set_child(paned)

        # ── Left: step list ──────────────────────────────────────────
        left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        left.set_size_request(270, -1)

        list_hdr = Gtk.Label(label="Steps")
        list_hdr.add_css_class("heading")
        list_hdr.set_margin_start(12)
        list_hdr.set_margin_top(12)
        list_hdr.set_margin_bottom(6)
        list_hdr.set_xalign(0)
        left.append(list_hdr)

        scrolled = Gtk.ScrolledWindow()
        scrolled.set_vexpand(True)
        self._step_list = Gtk.ListBox()
        self._step_list.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self._step_list.connect("row-selected", self._on_row_selected)
        scrolled.set_child(self._step_list)
        left.append(scrolled)

        # Action buttons
        btn_grid = Gtk.Grid(row_spacing=4, column_spacing=4)
        btn_grid.set_margin_start(8)
        btn_grid.set_margin_end(8)
        btn_grid.set_margin_top(8)
        btn_grid.set_margin_bottom(8)

        def _gbtn(label, callback, css_class=None):
            b = Gtk.Button(label=label)
            b.set_hexpand(True)
            if css_class:
                b.add_css_class(css_class)
            b.connect("clicked", callback)
            return b

        btn_grid.attach(_gbtn("+ Dialog",  lambda _b: self._add_step("dialog")),  0, 0, 1, 1)
        btn_grid.attach(_gbtn("+ Puzzle",  lambda _b: self._add_step("puzzle")),  1, 0, 1, 1)
        btn_grid.attach(_gbtn("↑ Move Up", lambda _b: self._move_step(-1)),        0, 1, 1, 1)
        btn_grid.attach(_gbtn("↓ Move Down",lambda _b: self._move_step(1)),        1, 1, 1, 1)
        btn_grid.attach(_gbtn("Delete Step", self._delete_step, "destructive-action"), 0, 2, 2, 1)

        left.append(btn_grid)
        paned.set_start_child(left)
        paned.set_shrink_start_child(False)
        paned.set_resize_start_child(False)

        # ── Right: editor stack ──────────────────────────────────────
        self._stack = Gtk.Stack()
        self._stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)

        placeholder = Gtk.Label(label="Open a chapter file to begin editing.")
        placeholder.add_css_class("dim-label")
        self._stack.add_named(placeholder, "placeholder")

        puzzle_scroll = Gtk.ScrolledWindow()
        self._puzzle_editor = PuzzleEditor(on_change=self._mark_dirty)
        puzzle_scroll.set_child(self._puzzle_editor)
        self._stack.add_named(puzzle_scroll, "puzzle")

        dialog_scroll = Gtk.ScrolledWindow()
        self._dialog_editor = DialogEditor(on_change=self._mark_dirty)
        dialog_scroll.set_child(self._dialog_editor)
        self._stack.add_named(dialog_scroll, "dialog")

        paned.set_end_child(self._stack)

    # ── Play in browser ────────────────────────────────────────────────────────

    def _play_in_browser(self, _btn=None):
        """Save the current file, launch dev server, and open the game in a browser."""
        if not self._chapter or not self._filepath:
            return

        # Save first so the browser sees the latest content
        self._save_file()
        if self._dirty:  # save failed
            return

        # Derive the watch path relative to data/ (e.g. "story/chapter_1.json")
        try:
            watch_rel = str(Path(self._filepath).resolve().relative_to(DATA_DIR.resolve()))
        except ValueError:
            self._error(
                f"File is not inside the data directory:\n"
                f"{self._filepath}\n\n"
                f"The Play button requires the file to be under:\n{DATA_DIR}"
            )
            return

        # Find the target puzzle ID from the current step selection
        puzzle_arg = ""
        if self._current_idx >= 0:
            steps = self._chapter.get("steps", [])
            if self._current_idx < len(steps):
                step = steps[self._current_idx]
                if step.get("type") == "puzzle":
                    puzzle_arg = step.get("id", "")
                else:
                    # For dialog steps, find the next puzzle step
                    for s in steps[self._current_idx + 1:]:
                        if s.get("type") == "puzzle":
                            puzzle_arg = s.get("id", "")
                            break

        # Kill any existing server (ours or anything else on the port)
        self._kill_server()
        self._kill_port(self._server_port)

        # Build the dev server command
        server_script = Path(__file__).resolve().parent / "dev_server.py"
        cmd = [
            sys.executable, str(server_script),
            str(self._server_port),
            f"--watch={watch_rel}",
        ]
        if puzzle_arg:
            cmd.append(f"--puzzle={puzzle_arg}")

        try:
            self._server_proc = subprocess.Popen(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
                preexec_fn=os.setsid,
            )
        except Exception as exc:
            self._error(f"Could not start dev server:\n{exc}")
            return

        # Update button state
        self._play_btn.set_label("▶ Playing…")
        self._play_btn.set_tooltip_text(
            f"Server running on port {self._server_port}\n"
            f"Watching: {watch_rel}"
            + (f"\nPuzzle: {puzzle_arg}" if puzzle_arg else "")
            + "\nClick to restart with current step"
        )

        # Give the server a moment to start, then open the browser
        url = f"http://localhost:{self._server_port}"
        GLib.timeout_add(600, self._open_browser, url)

    def _open_browser(self, url: str) -> bool:
        """Open the browser (called from GLib.timeout_add, returns False to not repeat)."""
        browser_env = os.environ.get("BROWSER")
        if browser_env:
            subprocess.Popen([browser_env, url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            webbrowser.open(url)
        return False  # don't repeat

    def _kill_server(self):
        """Kill the dev server subprocess if running."""
        if self._server_proc is not None:
            try:
                os.killpg(os.getpgid(self._server_proc.pid), signal.SIGTERM)
            except (ProcessLookupError, PermissionError):
                pass
            self._server_proc = None
            self._play_btn.set_label("▶ Play")

    @staticmethod
    def _kill_port(port: int):
        """Kill any process listening on the given TCP port."""
        try:
            out = subprocess.check_output(
                ["lsof", "-ti", f"TCP:{port}", "-sTCP:LISTEN"],
                stderr=subprocess.DEVNULL, text=True,
            )
            for pid_str in out.strip().split():
                try:
                    os.kill(int(pid_str), signal.SIGTERM)
                except (ProcessLookupError, PermissionError, ValueError):
                    pass
        except (subprocess.CalledProcessError, FileNotFoundError):
            pass  # lsof not found or no process on port — fine

    # ── Native Godot playback ──────────────────────────────────────────────────

    def _play_native(self, _btn=None):
        """Save the current file and play in native Godot.

        First click launches Godot with --map-watch. Subsequent clicks just
        save the file — MapWatcher's 0.5s polling picks up changes automatically.
        """
        if not self._chapter or not self._filepath:
            return

        # Always save so Godot sees the latest content
        self._save_file()
        if self._dirty:  # save failed
            return

        # If Godot is already running, just saving is enough (hot-reload)
        if self._godot_proc is not None and self._godot_proc.poll() is None:
            self._play_btn.set_label("▶ Saved")
            # Reset label after a moment
            GLib.timeout_add(800, self._reset_play_label_native)
            self._focus_godot()
            return

        # Derive the watch path relative to data/ (e.g. "story/chapter_1.json")
        try:
            watch_rel = str(Path(self._filepath).resolve().relative_to(DATA_DIR.resolve()))
        except ValueError:
            self._error(
                f"File is not inside the data directory:\n"
                f"{self._filepath}\n\n"
                f"The Play button requires the file to be under:\n{DATA_DIR}"
            )
            return

        # Find the target puzzle ID from the current step selection
        puzzle_arg = ""
        if self._current_idx >= 0:
            steps = self._chapter.get("steps", [])
            if self._current_idx < len(steps):
                step = steps[self._current_idx]
                if step.get("type") == "puzzle":
                    puzzle_arg = step.get("id", "")
                else:
                    # For dialog steps, find the next puzzle step
                    for s in steps[self._current_idx + 1:]:
                        if s.get("type") == "puzzle":
                            puzzle_arg = s.get("id", "")
                            break

        # Build the Godot command.
        # Don't specify a scene — let the main scene load normally so that
        # MapWatcher._autostart() can load the JSON data before navigating
        # to the puzzle scene. (Avoids race where PuzzleController._ready()
        # reads empty GameSettings.story_puzzle_data.)
        cmd = [
            self._godot_path,
            "--path", str(PROJECT_DIR),
            "--",
            f"--map-watch={watch_rel}",
        ]
        if puzzle_arg:
            cmd.append(f"--puzzle={puzzle_arg}")

        print(f"[LevelEditor] Launching Godot: {' '.join(cmd)}")

        try:
            self._godot_proc = subprocess.Popen(
                cmd,
                stdout=None,  # Inherit terminal for debug output
                stderr=None,
            )
        except FileNotFoundError:
            self._error(
                f"Could not find Godot binary:\n{self._godot_path}\n\n"
                "Install with: brew install --cask godot\n"
                "Or set GODOT_PATH to your Godot binary."
            )
            return
        except Exception as exc:
            self._error(f"Could not launch Godot:\n{exc}")
            return

        # Update button state
        self._play_btn.set_label("▶ Playing…")
        self._play_btn.set_tooltip_text(
            f"Godot running (PID {self._godot_proc.pid})\n"
            f"Watching: {watch_rel}"
            + (f"\nPuzzle: {puzzle_arg}" if puzzle_arg else "")
            + "\nClick to save & hot-reload"
        )

        # Give Godot a moment to create its window, then focus it
        GLib.timeout_add(800, self._focus_godot)

        # Poll for Godot exit so we can reset the button
        GLib.timeout_add(1000, self._poll_godot_proc)

    @staticmethod
    def _focus_godot() -> bool:
        """Bring the Godot window to the front (macOS). Returns False for GLib.timeout_add."""
        if sys.platform == "darwin":
            try:
                subprocess.Popen(
                    ["osascript", "-e",
                     'tell application "System Events" to set frontmost of '
                     'first process whose unix id is '
                     '(do shell script "pgrep -x Godot") to true'],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
            except Exception:
                pass
        return False  # don't repeat

    def _poll_godot_proc(self) -> bool:
        """Check if the Godot process is still running (GLib timeout callback)."""
        if self._godot_proc is None or self._godot_proc.poll() is not None:
            self._godot_proc = None
            self._play_btn.set_label("▶ Play")
            self._play_btn.set_tooltip_text("Save & play natively (launches Godot)")
            return False  # stop polling
        return True  # keep polling

    def _reset_play_label_native(self) -> bool:
        """Reset Play button label after a brief 'Saved' flash."""
        if self._godot_proc is not None and self._godot_proc.poll() is None:
            self._play_btn.set_label("▶ Playing…")
        else:
            self._play_btn.set_label("▶ Play")
        return False  # don't repeat

    def _kill_godot(self):
        """Kill the Godot subprocess if running."""
        if self._godot_proc is not None:
            try:
                self._godot_proc.terminate()
                self._godot_proc.wait(timeout=3)
            except (ProcessLookupError, PermissionError):
                pass
            except subprocess.TimeoutExpired:
                try:
                    self._godot_proc.kill()
                except (ProcessLookupError, PermissionError):
                    pass
            self._godot_proc = None
            self._play_btn.set_label("▶ Play")

    def _on_close_request(self, _window):
        """Clean up server/godot processes when the editor window closes."""
        self._kill_server()
        self._kill_godot()
        return False  # allow the window to close

    # ── Public API ────────────────────────────────────────────────────────────

    def load_file(self, path: str):
        """Load a chapter JSON file (public entry-point)."""
        self._load_file(path)

    # ── File operations ───────────────────────────────────────────────────────

    def _open_file(self, _btn=None):
        dialog = Gtk.FileChooserDialog(
            title="Open Chapter File",
            transient_for=self,
            action=Gtk.FileChooserAction.OPEN,
        )
        dialog.add_button("_Cancel", Gtk.ResponseType.CANCEL)
        dialog.add_button("_Open",   Gtk.ResponseType.ACCEPT)

        filt = Gtk.FileFilter()
        filt.set_name("JSON files (*.json)")
        filt.add_pattern("*.json")
        dialog.add_filter(filt)

        story_dir = DATA_DIR / "story"
        if story_dir.exists():
            dialog.set_current_folder(Gio.File.new_for_path(str(story_dir)))

        dialog.connect("response", self._on_open_response)
        dialog.present()

    def _on_open_response(self, dialog, response):
        if response == Gtk.ResponseType.ACCEPT:
            self._load_file(dialog.get_file().get_path())
        dialog.destroy()

    def _load_file(self, path: str):
        try:
            with open(path) as fh:
                self._chapter = json.load(fh)
        except Exception as exc:
            self._error(f"Could not open file:\n{exc}")
            return

        self._filepath = path
        self._dirty = False
        self._current_idx = -1
        self._play_btn.set_sensitive(True)
        self._update_title()
        self._rebuild_step_list()
        self._stack.set_visible_child_name("placeholder")

    def _save_file(self, _btn=None):
        if not self._chapter:
            return
        if not self._filepath:
            self._save_as()
            return
        self._flush()
        try:
            with open(self._filepath, "w") as fh:
                json.dump(self._chapter, fh, indent=2)
                fh.write("\n")
            self._dirty = False
            self._update_title()
        except Exception as exc:
            self._error(f"Could not save file:\n{exc}")

    def _save_as(self):
        dialog = Gtk.FileChooserDialog(
            title="Save Chapter File",
            transient_for=self,
            action=Gtk.FileChooserAction.SAVE,
        )
        dialog.add_button("_Cancel", Gtk.ResponseType.CANCEL)
        dialog.add_button("_Save",   Gtk.ResponseType.ACCEPT)

        filt = Gtk.FileFilter()
        filt.set_name("JSON files (*.json)")
        filt.add_pattern("*.json")
        dialog.add_filter(filt)

        if self._filepath:
            dialog.set_current_name(Path(self._filepath).name)

        def on_response(d, r):
            if r == Gtk.ResponseType.ACCEPT:
                self._filepath = d.get_file().get_path()
                self._save_file()
            d.destroy()

        dialog.connect("response", on_response)
        dialog.present()

    # ── Step list ─────────────────────────────────────────────────────────────

    def _rebuild_step_list(self, keep_selection: bool = False):
        while True:
            row = self._step_list.get_row_at_index(0)
            if row is None:
                break
            self._step_list.remove(row)

        if not self._chapter:
            return

        dialog_n = puzzle_n = 0
        for step in self._chapter.get("steps", []):
            stype = step.get("type")
            if stype == "dialog":
                dialog_n += 1
                lines = step.get("lines", [])
                if lines:
                    first = lines[0]
                    spkr = first.get("speaker") or "—"
                    txt = first.get("text", "")
                    short = txt[:35] + ("…" if len(txt) > 35 else "")
                    label = f"💬  {spkr}: {short}"
                else:
                    label = f"💬  Dialog {dialog_n}"
            elif stype == "puzzle":
                puzzle_n += 1
                pid = step.get("id", f"p{puzzle_n:02d}")
                title = step.get("title", "")
                label = f"♟  {pid}" + (f": {title}" if title else "")
            else:
                label = f"?  {stype}"

            list_row = Gtk.ListBoxRow()
            lbl = Gtk.Label(label=label, xalign=0)
            lbl.set_ellipsize(Pango.EllipsizeMode.END)
            lbl.set_margin_start(10)
            lbl.set_margin_end(10)
            lbl.set_margin_top(6)
            lbl.set_margin_bottom(6)
            list_row.set_child(lbl)
            self._step_list.append(list_row)

        if keep_selection and 0 <= self._current_idx:
            steps = self._chapter.get("steps", [])
            idx = min(self._current_idx, len(steps) - 1)
            row = self._step_list.get_row_at_index(idx)
            if row:
                self._step_list.select_row(row)

    def _on_row_selected(self, _listbox, row):
        if row is None:
            return
        self._flush()
        self._current_idx = row.get_index()
        steps = self._chapter.get("steps", [])
        if 0 <= self._current_idx < len(steps):
            self._show_step(steps[self._current_idx])

    def _show_step(self, step: dict):
        stype = step.get("type")
        if stype == "puzzle":
            self._puzzle_editor.set_step(step)
            self._stack.set_visible_child_name("puzzle")
        elif stype == "dialog":
            self._dialog_editor.set_step(step)
            self._stack.set_visible_child_name("dialog")
        else:
            self._stack.set_visible_child_name("placeholder")

    def _flush(self):
        """Flush the active editor back into self._chapter."""
        if self._current_idx < 0 or not self._chapter:
            return
        steps = self._chapter.get("steps", [])
        if self._current_idx >= len(steps):
            return
        stype = steps[self._current_idx].get("type")
        if stype == "puzzle":
            steps[self._current_idx] = self._puzzle_editor.get_step_data()
        elif stype == "dialog":
            steps[self._current_idx] = self._dialog_editor.get_step_data()

    # ── Step management ───────────────────────────────────────────────────────

    def _add_step(self, step_type: str):
        if not self._chapter:
            return
        self._flush()
        steps = self._chapter.setdefault("steps", [])
        insert_at = self._current_idx + 1 if self._current_idx >= 0 else len(steps)

        if step_type == "dialog":
            new_step: dict = {
                "type": "dialog",
                "lines": [{"speaker": None, "portrait": None, "text": ""}],
            }
        else:
            puzzle_count = sum(1 for s in steps if s.get("type") == "puzzle") + 1
            chapter_num = self._chapter.get("chapter", 1)
            new_step = {
                "type": "puzzle",
                "id": f"ch{chapter_num}_p{puzzle_count:02d}",
                "title": "New Puzzle",
                "description": "",
                "player": "white",
                "hint": "",
                "board": empty_board(),
                "win_condition": {"type": "capture_chief", "max_moves": 1},
                "opponent_moves": [],
            }

        steps.insert(insert_at, new_step)
        self._current_idx = insert_at
        self._rebuild_step_list(keep_selection=True)
        self._show_step(new_step)
        self._mark_dirty()

    def _delete_step(self, _btn):
        if not self._chapter or self._current_idx < 0:
            return
        steps = self._chapter.get("steps", [])
        if not steps or self._current_idx >= len(steps):
            return
        del steps[self._current_idx]
        self._current_idx = min(self._current_idx, len(steps) - 1)
        self._rebuild_step_list(keep_selection=True)
        if self._current_idx >= 0:
            self._show_step(steps[self._current_idx])
        else:
            self._stack.set_visible_child_name("placeholder")
        self._mark_dirty()

    def _move_step(self, direction: int):
        if not self._chapter or self._current_idx < 0:
            return
        self._flush()
        steps = self._chapter.get("steps", [])
        new_idx = self._current_idx + direction
        if not (0 <= new_idx < len(steps)):
            return
        steps[self._current_idx], steps[new_idx] = steps[new_idx], steps[self._current_idx]
        self._current_idx = new_idx
        self._rebuild_step_list(keep_selection=True)
        self._mark_dirty()

    # ── Helpers ───────────────────────────────────────────────────────────────

    def _mark_dirty(self):
        if not self._dirty:
            self._dirty = True
            self._update_title()

    def _update_title(self):
        if self._chapter and self._filepath:
            name = Path(self._filepath).name
            chapter_title = self._chapter.get("title", name)
            dirty_marker = " •" if self._dirty else ""
            self._header_title.set_label(f"{chapter_title}{dirty_marker}")
            self.set_title(
                f"Wachesaw Level Editor — {name}{dirty_marker}"
            )
        else:
            self._header_title.set_label("No file open")
            self.set_title("Wachesaw Level Editor")

    def _error(self, message: str):
        dialog = Gtk.MessageDialog(
            transient_for=self,
            modal=True,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text=message,
        )
        dialog.connect("response", lambda d, _r: d.destroy())
        dialog.present()


# ── Application ────────────────────────────────────────────────────────────────

class LevelEditorApp(Gtk.Application):

    def __init__(self):
        super().__init__(
            application_id="io.wachesaw.LevelEditor",
            flags=Gio.ApplicationFlags.FLAGS_NONE,
        )
        self.initial_file: str | None = None
        self.native_mode: bool = False
        self.godot_path: str = ""

    def do_activate(self):
        win = LevelEditorWindow(self)
        win.present()
        if self.initial_file:
            win.load_file(self.initial_file)

    def do_open(self, files, _n, _hint):
        self.initial_file = files[0].get_path()
        self.activate()


def _find_godot_binary() -> str:
    """Try to locate the Godot 4.4 binary on macOS."""
    candidates = [
        "/Applications/Godot_v4.4.app/Contents/MacOS/Godot",
        "/Applications/Godot.app/Contents/MacOS/Godot",
    ]
    for path in candidates:
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path
    # Fall back to PATH lookup
    import shutil
    found = shutil.which("godot")
    return found or ""


def main():
    app = LevelEditorApp()

    # Parse our custom flags before passing to GTK
    args = sys.argv[:]
    custom_flags = []
    for a in args[1:]:
        if a == "--native":
            app.native_mode = True
            custom_flags.append(a)
        elif a.startswith("--godot-path="):
            app.godot_path = a.split("=", 1)[1]
            custom_flags.append(a)

    # Auto-detect godot binary if --native but no --godot-path
    if app.native_mode and not app.godot_path:
        app.godot_path = _find_godot_binary()
        if not app.godot_path:
            print("Error: --native requires Godot. Install with: brew install --cask godot")
            print("Or pass --godot-path=/path/to/godot")
            sys.exit(1)

    # Strip custom flags so GTK doesn't see them
    args = [a for a in args if a not in custom_flags]

    # Accept an optional file path as the first non-flag argument
    # (strip it from argv so GTK doesn't stumble on it)
    non_flags = [a for a in args[1:] if not a.startswith("-")]
    if non_flags:
        candidate = Path(non_flags[0])
        app.initial_file = str(candidate.resolve())
        args = [a for a in args if a != non_flags[0]]

    sys.exit(app.run(args))


if __name__ == "__main__":
    main()
