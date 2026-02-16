## Animated procedural background with nature themes.
## Draws everything via _draw() — no textures, pure vector art.
## Themes: forest, river, sky, dark (for dark force encounters).
extends Control

enum BGTheme {
	FOREST,
	RIVER,
	SKY,
	DARK,
}

const THEME_NAMES: Dictionary = {
	"forest": BGTheme.FOREST,
	"river": BGTheme.RIVER,
	"sky": BGTheme.SKY,
	"dark": BGTheme.DARK,
}

var current_theme: BGTheme = BGTheme.FOREST
var time: float = 0.0

# ─── Element pools (generated once per theme) ───────────────────

var _particles: Array = []   # Fireflies, leaves, stars, bubbles
var _layers: Array = []      # Background landscape layers (parallax-ish)
var _initialized: bool = false

# ─── Configuration ───────────────────────────────────────────────

const MAX_PARTICLES := 50
const MAX_LAYERS := 4

# ─── Theme Colors ────────────────────────────────────────────────

const THEME_COLORS: Dictionary = {
	BGTheme.FOREST: {
		"bg_top":     Color("#1c3c1c"),
		"bg_bottom":  Color("#0e1e0e"),
		"layer1":     Color("#2a5030"),
		"layer2":     Color("#224428"),
		"layer3":     Color("#1a3820"),
		"layer4":     Color("#142c18"),
		"particle":   Color("#b0e870"),
		"particle2":  Color("#70d850"),
		"accent":     Color("#ffe860"),
	},
	BGTheme.RIVER: {
		"bg_top":     Color("#14283e"),
		"bg_bottom":  Color("#0a1828"),
		"layer1":     Color("#204060"),
		"layer2":     Color("#1a3450"),
		"layer3":     Color("#142a42"),
		"layer4":     Color("#102036"),
		"particle":   Color("#90d0f0"),
		"particle2":  Color("#70b8e8"),
		"accent":     Color("#e8f4ff"),
	},
	BGTheme.SKY: {
		"bg_top":     Color("#0a1428"),
		"bg_bottom":  Color("#162040"),
		"layer1":     Color("#1e2c50"),
		"layer2":     Color("#182444"),
		"layer3":     Color("#121c38"),
		"layer4":     Color("#0e1830"),
		"particle":   Color("#f8f0d8"),
		"particle2":  Color("#e0d8c0"),
		"accent":     Color("#fffce8"),
	},
	BGTheme.DARK: {
		"bg_top":     Color("#1e1020"),
		"bg_bottom":  Color("#0c060e"),
		"layer1":     Color("#2c1830"),
		"layer2":     Color("#241428"),
		"layer3":     Color("#1c0e20"),
		"layer4":     Color("#140a18"),
		"particle":   Color("#a050c0"),
		"particle2":  Color("#7838d0"),
		"accent":     Color("#d070f0"),
	},
}

# ─── Board Color Palettes ────────────────────────────────────────

const BOARD_PALETTES: Dictionary = {
	BGTheme.FOREST: {
		"cell_light":        Color("#4a6a3a"),
		"cell_dark":         Color("#2e4a22"),
		"selected_light":    Color("#6a9848"),
		"selected_dark":     Color("#4a7830"),
		"last_move_light":   Color("#7aaa50"),
		"last_move_dark":    Color("#5a8a38"),
		"valid_light":       Color("#68b848"),
		"valid_dark":        Color("#489830"),
		"capture_light":     Color("#a85838"),
		"capture_dark":      Color("#884028"),
		"swap_light":        Color("#488868"),
		"swap_dark":         Color("#306848"),
		"move_dot":          Color(0.85, 1.0, 0.6, 0.3),
		"capture_corner":    Color(0.85, 0.3, 0.2, 0.6),
		"border":            Color("#1a3010"),
		"shadow":            Color(0, 0, 0, 0.4),
		"white_piece":       Color("#e8f0d0"),
		"white_outline":     Color("#1a2810"),
		"black_piece":       Color("#1a2810"),
		"black_outline":     Color("#c0d8a0"),
		"piece_glow":        Color("#b0e870"),
		"label":             Color(0.7, 0.9, 0.5, 0.4),
		"cell_shimmer":      Color("#b0e870"),
	},
	BGTheme.RIVER: {
		"cell_light":        Color("#3a5a78"),
		"cell_dark":         Color("#243a58"),
		"selected_light":    Color("#4878a8"),
		"selected_dark":     Color("#305888"),
		"last_move_light":   Color("#5090b0"),
		"last_move_dark":    Color("#387098"),
		"valid_light":       Color("#4898c0"),
		"valid_dark":        Color("#3078a0"),
		"capture_light":     Color("#a05848"),
		"capture_dark":      Color("#804030"),
		"swap_light":        Color("#3880a0"),
		"swap_dark":         Color("#286880"),
		"move_dot":          Color(0.6, 0.85, 1.0, 0.3),
		"capture_corner":    Color(0.85, 0.3, 0.2, 0.6),
		"border":            Color("#102030"),
		"shadow":            Color(0, 0, 0, 0.4),
		"white_piece":       Color("#d8e8f8"),
		"white_outline":     Color("#102838"),
		"black_piece":       Color("#102838"),
		"black_outline":     Color("#a0c8e8"),
		"piece_glow":        Color("#90d0f0"),
		"label":             Color(0.5, 0.75, 1.0, 0.4),
		"cell_shimmer":      Color("#90d0f0"),
	},
	BGTheme.SKY: {
		"cell_light":        Color("#384870"),
		"cell_dark":         Color("#242e50"),
		"selected_light":    Color("#4860a0"),
		"selected_dark":     Color("#304880"),
		"last_move_light":   Color("#5068a8"),
		"last_move_dark":    Color("#384890"),
		"valid_light":       Color("#5878b8"),
		"valid_dark":        Color("#405898"),
		"capture_light":     Color("#985848"),
		"capture_dark":      Color("#784030"),
		"swap_light":        Color("#485898"),
		"swap_dark":         Color("#304078"),
		"move_dot":          Color(0.8, 0.8, 1.0, 0.3),
		"capture_corner":    Color(0.85, 0.3, 0.2, 0.6),
		"border":            Color("#0e1428"),
		"shadow":            Color(0, 0, 0, 0.5),
		"white_piece":       Color("#e0e0f0"),
		"white_outline":     Color("#181830"),
		"black_piece":       Color("#181830"),
		"black_outline":     Color("#b0b0d8"),
		"piece_glow":        Color("#f8f0d8"),
		"label":             Color(0.7, 0.7, 1.0, 0.4),
		"cell_shimmer":      Color("#f8f0d8"),
	},
	BGTheme.DARK: {
		"cell_light":        Color("#48304a"),
		"cell_dark":         Color("#2e1a30"),
		"selected_light":    Color("#684870"),
		"selected_dark":     Color("#503058"),
		"last_move_light":   Color("#604068"),
		"last_move_dark":    Color("#483050"),
		"valid_light":       Color("#705080"),
		"valid_dark":        Color("#583868"),
		"capture_light":     Color("#904040"),
		"capture_dark":      Color("#702828"),
		"swap_light":        Color("#504068"),
		"swap_dark":         Color("#382850"),
		"move_dot":          Color(0.7, 0.4, 0.9, 0.3),
		"capture_corner":    Color(0.85, 0.2, 0.3, 0.6),
		"border":            Color("#140a18"),
		"shadow":            Color(0, 0, 0, 0.5),
		"white_piece":       Color("#d8c8e0"),
		"white_outline":     Color("#1a0e20"),
		"black_piece":       Color("#1a0e20"),
		"black_outline":     Color("#a888b8"),
		"piece_glow":        Color("#a050c0"),
		"label":             Color(0.7, 0.4, 0.9, 0.4),
		"cell_shimmer":      Color("#d070f0"),
	},
}

## Returns the board color palette for the active theme.
func get_board_palette() -> Dictionary:
	return BOARD_PALETTES[current_theme]

## Returns the current theme name as a string.
func get_current_theme_name() -> String:
	for key in THEME_NAMES:
		if THEME_NAMES[key] == current_theme:
			return key
	return "forest"

# ─── Lifecycle ───────────────────────────────────────────────────

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_process(true)

func set_theme_by_name(theme_name: String) -> void:
	if THEME_NAMES.has(theme_name):
		current_theme = THEME_NAMES[theme_name]
	else:
		current_theme = BGTheme.FOREST
	_initialized = false
	_init_elements()

func set_random_theme() -> void:
	current_theme = [BGTheme.FOREST, BGTheme.RIVER, BGTheme.SKY].pick_random()
	_initialized = false
	_init_elements()

func _process(delta: float) -> void:
	if not _initialized:
		_init_elements()
	time += delta
	_update_particles(delta)
	queue_redraw()

# ─── Element Initialization ─────────────────────────────────────

func _init_elements() -> void:
	_initialized = true
	_particles.clear()
	_layers.clear()

	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		_initialized = false
		return

	# Generate landscape layers (hills/mountains from bottom)
	for i in range(MAX_LAYERS):
		var layer := {}
		layer["index"] = i
		var base_y: float = h * (0.50 + i * 0.13)
		layer["base_y"] = base_y
		# Generate hill points
		var points: Array = []
		var num_points: int = randi_range(5, 9)
		for p in range(num_points + 1):
			var px: float = (float(p) / float(num_points)) * (w + 40.0) - 20.0
			var py: float = base_y - randf_range(15.0, 70.0 - i * 10.0)
			points.append(Vector2(px, py))
		layer["points"] = points
		layer["speed"] = 0.3 + i * 0.15  # Subtle parallax sway
		_layers.append(layer)

	# Generate particles
	for j in range(MAX_PARTICLES):
		_particles.append(_make_particle(w, h, true))

func _make_particle(w: float, h: float, randomize_start: bool) -> Dictionary:
	var p := {}
	p["x"] = randf_range(0, w)
	p["y"] = randf_range(0, h)
	p["size"] = randf_range(2.0, 5.0)
	p["speed_x"] = randf_range(-10.0, 10.0)
	p["speed_y"] = randf_range(-15.0, -3.0)
	p["phase"] = randf_range(0.0, TAU)
	p["alpha"] = randf_range(0.3, 0.85)
	p["wobble"] = randf_range(0.5, 2.0)
	p["life"] = randf_range(3.0, 10.0)
	p["max_life"] = p["life"]
	p["color_idx"] = randi_range(0, 2)  # 0=particle, 1=particle2, 2=accent
	if randomize_start:
		p["life"] = randf_range(0.0, p["max_life"])

	match current_theme:
		BGTheme.FOREST:
			# Fireflies — mostly float upward, gentle wobble
			p["speed_y"] = randf_range(-18.0, -4.0)
			p["speed_x"] = randf_range(-6.0, 6.0)
			p["size"] = randf_range(2.5, 5.5)
			p["alpha"] = randf_range(0.4, 0.9)
		BGTheme.RIVER:
			# Water sparkles / mist — drift sideways
			p["speed_x"] = randf_range(5.0, 18.0)
			p["speed_y"] = randf_range(-6.0, 3.0)
			p["size"] = randf_range(2.0, 4.5)
			p["alpha"] = randf_range(0.3, 0.8)
		BGTheme.SKY:
			# Stars — twinkle in place, very slow drift
			p["speed_x"] = randf_range(-0.8, 0.8)
			p["speed_y"] = randf_range(-0.5, 0.5)
			p["size"] = randf_range(1.5, 4.0)
			p["alpha"] = randf_range(0.4, 1.0)
			p["y"] = randf_range(0, h * 0.65)  # Stars in upper portion
		BGTheme.DARK:
			# Shadow wisps — float upward, dark purple
			p["speed_y"] = randf_range(-25.0, -6.0)
			p["speed_x"] = randf_range(-8.0, 8.0)
			p["size"] = randf_range(3.0, 7.0)
			p["alpha"] = randf_range(0.25, 0.6)
	return p

func _update_particles(delta: float) -> void:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return

	for p in _particles:
		p["x"] += p["speed_x"] * delta
		p["y"] += p["speed_y"] * delta
		# Wobble
		p["x"] += sin(time * p["wobble"] + p["phase"]) * 0.3
		# Fade lifecycle
		p["life"] -= delta
		if p["life"] <= 0:
			# Respawn
			var new_p := _make_particle(w, h, false)
			# Reset position based on direction
			if current_theme == BGTheme.RIVER:
				new_p["x"] = -5.0
			else:
				new_p["y"] = h + 5.0
			p.merge(new_p, true)

# ─── Drawing ────────────────────────────────────────────────────

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return

	var colors: Dictionary = THEME_COLORS[current_theme]

	# Background gradient
	_draw_gradient(w, h, colors["bg_top"], colors["bg_bottom"])

	# Theme-specific background elements
	match current_theme:
		BGTheme.RIVER:
			_draw_water(w, h, colors)
		BGTheme.SKY:
			_draw_moon(w, h, colors)
		BGTheme.DARK:
			_draw_vortex(w, h, colors)

	# Landscape layers (back to front)
	var layer_colors: Array = [colors["layer4"], colors["layer3"], colors["layer2"], colors["layer1"]]
	for i in range(_layers.size()):
		var layer: Dictionary = _layers[i]
		var color_idx: int = clampi(i, 0, layer_colors.size() - 1)
		_draw_landscape_layer(w, h, layer, layer_colors[color_idx])

	# Trees (forest and dark themes)
	if current_theme == BGTheme.FOREST or current_theme == BGTheme.DARK:
		_draw_trees(w, h, colors)

	# Particles
	_draw_particles(colors)

func _draw_gradient(w: float, h: float, top: Color, bottom: Color) -> void:
	# Simple vertical gradient using strips
	var strips := 16
	for i in range(strips):
		var t0 := float(i) / float(strips)
		var t1 := float(i + 1) / float(strips)
		var c := top.lerp(bottom, (t0 + t1) / 2.0)
		draw_rect(Rect2(0, h * t0, w, h * (t1 - t0) + 1), c)

func _draw_landscape_layer(w: float, h: float, layer: Dictionary, color: Color) -> void:
	var points: Array = layer["points"]
	var sway_offset := sin(time * layer["speed"]) * 4.0

	var poly: PackedVector2Array = PackedVector2Array()
	for pt in points:
		poly.append(Vector2(pt.x + sway_offset, pt.y + sin(time * 0.4 + pt.x * 0.015) * 5.0))
	# Close polygon at bottom corners
	poly.append(Vector2(w + 20, h + 10))
	poly.append(Vector2(-20, h + 10))

	if poly.size() >= 3:
		draw_colored_polygon(poly, color)

func _draw_trees(w: float, h: float, colors: Dictionary) -> void:
	# Draw simple triangular trees along the bottom layers
	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # Deterministic tree placement

	var tree_color: Color = colors["layer1"].lightened(0.2)
	var trunk_color: Color = colors["layer2"]
	var num_trees: int = int(w / 35.0)

	for i in range(num_trees):
		var tx: float = rng.randf_range(0, w)
		var base_y: float = h * rng.randf_range(0.6, 0.92)
		var tree_h: float = rng.randf_range(25.0, 60.0)
		var tree_w: float = tree_h * rng.randf_range(0.35, 0.55)

		# Gentle sway
		var sway := sin(time * 0.6 + tx * 0.02) * 3.5

		# Trunk
		draw_rect(Rect2(tx - 2 + sway * 0.3, base_y - tree_h * 0.3, 4, tree_h * 0.35), trunk_color)

		# Canopy (layered triangles)
		for layer_i in range(3):
			var ly := base_y - tree_h * (0.3 + layer_i * 0.25)
			var lw := tree_w * (1.0 - layer_i * 0.2)
			var lh := tree_h * 0.35
			var tri := PackedVector2Array([
				Vector2(tx + sway, ly - lh),
				Vector2(tx - lw / 2.0 + sway * 0.5, ly),
				Vector2(tx + lw / 2.0 + sway * 0.5, ly),
			])
			var shade := tree_color.darkened(layer_i * 0.06)
			draw_colored_polygon(tri, shade)

func _draw_water(w: float, h: float, colors: Dictionary) -> void:
	# Animated water waves in the lower portion
	var water_top: float = h * 0.7
	var water_color: Color = Color(colors["layer1"]).lerp(Color("#1a3a5a"), 0.3)

	for wave in range(5):
		var wave_y := water_top + wave * 12.0
		var poly := PackedVector2Array()
		var segments := 20
		for s in range(segments + 1):
			var sx := float(s) / float(segments) * w
			var sy_offset := sin(time * (0.8 + wave * 0.15) + sx * 0.025 + wave * 0.8) * (7.0 - wave * 0.8)
			poly.append(Vector2(sx, wave_y + sy_offset))
		poly.append(Vector2(w, h + 10))
		poly.append(Vector2(0, h + 10))
		var alpha := 0.65 - wave * 0.08
		var wc: Color = water_color.lightened(wave * 0.06)
		wc.a = alpha
		if poly.size() >= 3:
			draw_colored_polygon(poly, wc)

func _draw_moon(w: float, h: float, colors: Dictionary) -> void:
	# Draw a moon with a gentle glow
	var moon_x := w * 0.75
	var moon_y := h * 0.15
	var moon_r := 20.0

	# Glow rings
	for ring in range(6):
		var r := moon_r + ring * 10.0
		var a := 0.12 - ring * 0.018
		draw_circle(Vector2(moon_x, moon_y), r, Color(1, 1, 0.9, maxf(a, 0.01)))

	# Moon body
	draw_circle(Vector2(moon_x, moon_y), moon_r, Color("#e8e0c8"))

	# Crescent shadow
	draw_circle(Vector2(moon_x + 6, moon_y - 3), moon_r * 0.85, colors["bg_top"])

func _draw_vortex(w: float, h: float, colors: Dictionary) -> void:
	# Swirling dark vortex in the upper area
	var cx := w * 0.5
	var cy := h * 0.25
	var max_r := minf(w, h) * 0.3

	for ring in range(8):
		var r := max_r * (1.0 - ring * 0.1)
		var angle_offset := time * (0.3 + ring * 0.05) * (1 if ring % 2 == 0 else -1)
		var segments := 24
		var poly := PackedVector2Array()
		for s in range(segments):
			var angle := float(s) / float(segments) * TAU + angle_offset
			var wobble := sin(angle * 3 + time) * r * 0.08
			var px := cx + cos(angle) * (r + wobble)
			var py := cy + sin(angle) * (r * 0.6 + wobble)
			poly.append(Vector2(px, py))
		var alpha := 0.10 + ring * 0.02
		var vc: Color = Color(colors["accent"]).darkened(ring * 0.1)
		vc.a = alpha
		if poly.size() >= 3:
			draw_colored_polygon(poly, vc)

func _draw_particles(colors: Dictionary) -> void:
	for p in _particles:
		var life_ratio: float = p["life"] / p["max_life"]
		# Fade in at start, fade out at end
		var fade := 1.0
		if life_ratio > 0.85:
			fade = (1.0 - life_ratio) / 0.15
		elif life_ratio < 0.2:
			fade = life_ratio / 0.2

		var alpha: float = p["alpha"] * fade

		# Twinkle for stars
		if current_theme == BGTheme.SKY:
			alpha *= 0.5 + 0.5 * sin(time * 2.0 + p["phase"])

		if alpha < 0.01:
			continue

		var particle_color: Color
		match p["color_idx"]:
			0: particle_color = colors["particle"]
			1: particle_color = colors["particle2"]
			_: particle_color = colors["accent"]
		particle_color.a = alpha

		var pos := Vector2(p["x"], p["y"])
		var sz: float = p["size"]

		# Draw glow halo
		var glow := particle_color
		glow.a = alpha * 0.4
		draw_circle(pos, sz * 3.0, glow)

		# Draw particle core
		draw_circle(pos, sz, particle_color)
