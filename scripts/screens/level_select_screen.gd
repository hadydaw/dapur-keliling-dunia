extends Control
## Pilih Level: latar pemandangan area, 50 medali level (5 per baris) yang digeser ke bawah, papan nama area.
## Geser dengan jari/mouse (atau roda mouse); ketuk medali tanpa menggeser untuk masuk level.

const UI = preload("res://scripts/ui_kit.gd")
const GameData = preload("res://scripts/game_data.gd")
const LevelMedal = preload("res://scripts/ui/level_medal.gd")
const ASSET_DIR := "res://assets/ui/"

signal navigate(screen: String, params: Dictionary)

# Grid medali: 5 per baris, lengkung ringan agar terasa seperti jalur (ukuran pada basis tinggi layar 720)
const COLS := 5
const WAVE := [0.0, -22.0, 10.0, -22.0, 0.0]
const MEDAL := 100.0   # diameter medali
const STEP_X := 196.0  # jarak antar kolom
const ROW_H := 196.0   # tinggi satu baris (medali + bintang + target)
const TAP_SLOP := 14.0 # geseran maksimum (px layar) yang masih dianggap ketukan

var area_idx: int = 0
var bg_rect: TextureRect
var bg_tex: Texture2D
var title_plate: TextureRect
var title_label: Label
var medals: Array = []      # {medal, button (area ketuk), stars:[3], target, unlocked}
var list: Control           # lapisan daftar medali (terpotong di bawah papan nama)
var scroll: float = 0.0     # geseran vertikal (px layar)
var scroll_max: float = 0.0
var scroll_vel: float = 0.0
var press_pos := Vector2.ZERO
var drag_dist: float = 0.0
var pressing: bool = false
var top_items: Array = []
var coin_label: Label
var toast_label: Label
var toast_time: float = 0.0


func setup(p: Dictionary) -> void:
	area_idx = int(p.get("area", 0))


func _ready() -> void:
	var area: Dictionary = GameData.AREAS[area_idx]
	UI.fill(self)
	clip_contents = true
	bg_tex = load("res://assets/level_bg_%s.jpg" % area["id"])
	bg_rect = TextureRect.new()
	bg_rect.texture = bg_tex
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_rect)

	title_plate = _asset("plate_nama")
	title_label = UI.label(area["name"], 30, Color(1, 0.93, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	title_label.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.02))
	title_label.add_theme_constant_override("outline_size", 6)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_plate.add_child(title_label)

	list = Control.new()
	list.clip_contents = true
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(list)
	for l in GameData.LEVELS_PER_AREA:
		_build_level(l)
	title_plate.z_index = 5

	var bar := _asset("bar_koin")
	bar.z_index = 5
	top_items.append({"node": bar, "x": 16, "y": 16, "w": 230, "a": "l", "id": "bar_koin"})
	coin_label = UI.label("0", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	coin_label.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.04))
	coin_label.add_theme_constant_override("outline_size", 6)
	coin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coin_label)
	coin_label.z_index = 6

	var back := _asset("btn_back")
	var bb := TextureButton.new()
	bb.ignore_texture_size = true
	bb.focus_mode = Control.FOCUS_NONE
	bb.button_down.connect(_press_anim.bind(back, true))
	bb.button_up.connect(_press_anim.bind(back, false))
	bb.pressed.connect(on_back)
	add_child(bb)
	back.z_index = 5
	bb.z_index = 6
	top_items.append({"node": back, "x": 14, "y": 12, "w": 64, "a": "r", "btn": bb, "id": "back"})

	toast_label = UI.label("", 30, Color(1, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.03))
	toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_label)
	resized.connect(_layout)
	_layout()
	_scroll_to_current()


func _asset(name: String) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load(ASSET_DIR + name + ".png")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	return tr


func _build_level(l: int) -> void:
	var area: Dictionary = GameData.AREAS[area_idx]
	var unlocked: bool = GameState.level_unlocked(area_idx, l)
	var got: int = GameState.get_stars(area["id"], l)
	var params: Dictionary = GameData.level_params(area_idx, l)
	var entry := {"unlocked": unlocked}
	var medal: Control
	if unlocked:
		var m := LevelMedal.new()
		m.number = l + 1
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		list.add_child(m)
		medal = m
	else:
		medal = _asset("ic_gembok")
		medal.reparent(list)
		medal.modulate = Color(0.75, 0.75, 0.78)
	entry["medal"] = medal
	var stars: Array = []
	for k in 3:
		var s := TextureRect.new()
		s.texture = load(ASSET_DIR + ("star_full.png" if k < got else "star_empty.png"))
		s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.visible = unlocked
		list.add_child(s)
		stars.append(s)
	entry["stars"] = stars
	var boss: bool = bool(params["boss"])
	if boss and unlocked:
		medal.modulate = Color(1.0, 0.72, 0.62)
	var t := UI.label(("Bos · Target %d" if boss else "Target %d") % int(params["target"]), 20, Color(1, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.02))
	t.add_theme_constant_override("outline_size", 6)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.visible = unlocked
	list.add_child(t)
	entry["target"] = t
	var b := Control.new()   # area ketuk (ditangani _gui_input agar bisa dibedakan dari geseran)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(b)
	entry["button"] = b
	medals.append(entry)


# ---------- tata letak ----------
func _bg_geometry() -> Rect2:
	var s: float = maxf(size.x / bg_tex.get_width(), size.y / bg_tex.get_height())
	var d := Vector2(bg_tex.get_width(), bg_tex.get_height()) * s
	return Rect2((size - d) * 0.5, d)


func _layout() -> void:
	var r := _bg_geometry()
	bg_rect.position = r.position
	bg_rect.size = r.size
	var u: float = size.y / 720.0
	# papan nama
	var pw: float = 460.0 * u
	var ph: float = pw * title_plate.texture.get_height() / title_plate.texture.get_width()
	title_plate.size = Vector2(pw, ph)
	title_plate.position = Vector2((size.x - pw) * 0.5, 6.0 * u)
	UI.fit_label(title_label, GameData.AREAS[area_idx]["name"], Rect2(Vector2(0.098, 0.394) * title_plate.size, Vector2(0.806, 0.231) * title_plate.size), 0.92)
	# daftar medali (di bawah papan nama)
	var top_y: float = title_plate.position.y + ph + 4.0 * u
	list.position = Vector2(0, top_y)
	list.size = Vector2(size.x, maxf(size.y - top_y, 100.0))
	var rows: int = ceili(float(medals.size()) / float(COLS))
	var content: float = rows * ROW_H * u + 40.0 * u
	scroll_max = maxf(0.0, content - list.size.y)
	scroll = clampf(scroll, 0.0, scroll_max)
	_place_items()
	# atas
	for it in top_items:
		var tr: TextureRect = it["node"]
		var w: float = it["w"] * u
		var h: float = w * tr.texture.get_height() / tr.texture.get_width()
		var x: float = it["x"] * u
		if it["a"] == "r":
			x = size.x - x - w
		tr.position = Vector2(x, it["y"] * u)
		tr.size = Vector2(w, h)
		if it.has("btn"):
			var bt: TextureButton = it["btn"]
			bt.position = tr.position
			bt.size = Vector2(maxf(tr.size.x, 44.0), maxf(tr.size.y, 44.0))
	var bar: TextureRect = top_items[0]["node"]
	UI.fit_label(coin_label, str(GameState.coins), Rect2(bar.position + Vector2(0.264, 0.317) * bar.size, Vector2(0.532, 0.433) * bar.size), 0.85)
	toast_label.position = Vector2(0, size.y * 0.82)
	toast_label.size = Vector2(size.x, 50)


func _item_center(i: int) -> Vector2:
	var u: float = size.y / 720.0
	var col: int = i % COLS
	var row: int = i / COLS
	var cx: float = size.x * 0.5 + (col - (COLS - 1) * 0.5) * STEP_X * u
	var cy: float = (row + 0.5) * ROW_H * u - 12.0 * u + WAVE[col] * u - scroll + 20.0 * u
	return Vector2(cx, cy)


func _place_items() -> void:
	var u: float = size.y / 720.0
	for i in medals.size():
		var e: Dictionary = medals[i]
		var c := _item_center(i)
		var d: float = MEDAL * u
		var medal: Control = e["medal"]
		medal.size = Vector2(d, d)
		medal.position = c - Vector2(d, d) * 0.5
		medal.queue_redraw()
		var sw: float = 30.0 * u
		var stars: Array = e["stars"]
		for k in 3:
			var s: TextureRect = stars[k]
			s.size = Vector2(sw, sw)
			s.position = Vector2(c.x + (k - 1) * (sw + 2.0 * u) - sw * 0.5, c.y + d * 0.5 + 4.0 * u)
		var tl: Label = e["target"]
		UI.fit_label(tl, tl.text, Rect2(c.x - (d + 70.0 * u) * 0.5, c.y + d * 0.5 + 4.0 * u + sw + 2.0 * u, d + 70.0 * u, 24.0 * u), 0.85)
		var b: Control = e["button"]
		b.position = medal.position - Vector2(8, 8) * u
		b.size = Vector2(d + 16.0 * u, d + 16.0 * u + (sw + 30.0 * u if e["unlocked"] else 0.0))


## Gulir agar baris level berikutnya yang belum selesai berada di tengah daftar.
func _scroll_to_current() -> void:
	var cur := 0
	for i in medals.size():
		if medals[i]["unlocked"]:
			cur = i
			if GameState.get_stars(GameData.AREAS[area_idx]["id"], i) == 0:
				break
	var u: float = size.y / 720.0
	var row_center: float = (cur / COLS + 0.5) * ROW_H * u
	scroll = clampf(row_center - list.size.y * 0.5, 0.0, scroll_max)
	_place_items()


func _scroll_by(dy: float) -> void:
	scroll = clampf(scroll + dy, 0.0, scroll_max)
	_place_items()


func _gui_input(event: InputEvent) -> void:
	var u: float = size.y / 720.0
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_scroll_by(-ROW_H * 0.6 * u)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_scroll_by(ROW_H * 0.6 * u)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				pressing = true
				press_pos = mb.position
				drag_dist = 0.0
				scroll_vel = 0.0
			elif pressing:
				pressing = false
				if drag_dist < TAP_SLOP * u:
					_tap_at(mb.global_position)
	elif event is InputEventMouseMotion and pressing:
		var mm := event as InputEventMouseMotion
		drag_dist += absf(mm.relative.y) + absf(mm.relative.x)
		if drag_dist >= TAP_SLOP * u:
			_scroll_by(-mm.relative.y)
			scroll_vel = -mm.relative.y


func _tap_at(gpos: Vector2) -> void:
	if not list.get_global_rect().has_point(gpos):
		return
	for i in medals.size():
		if (medals[i]["button"] as Control).get_global_rect().has_point(gpos):
			_press_anim(medals[i]["medal"], true)
			_press_anim(medals[i]["medal"], false)
			_on_level(i)
			return


# ---------- interaksi ----------
func _press_anim(target: Control, down: bool) -> void:
	target.pivot_offset = target.size * 0.5
	var tw := create_tween()
	if down:
		target.modulate = Color(0.85, 0.85, 0.85)
		tw.tween_property(target, "scale", Vector2(0.92, 0.92), 0.07)
	else:
		target.modulate = Color.WHITE
		tw.tween_property(target, "scale", Vector2(1.06, 1.06), 0.09)
		tw.tween_property(target, "scale", Vector2.ONE, 0.09)


func _on_level(l: int) -> void:
	if GameState.level_unlocked(area_idx, l):
		navigate.emit("gameplay", {"area": area_idx, "level": l})
	else:
		_toast("Selesaikan Level %d dulu" % l)


func _toast(msg: String) -> void:
	toast_label.text = msg
	toast_label.modulate.a = 1.0
	toast_time = 1.8


func _process(delta: float) -> void:
	if not pressing and absf(scroll_vel) > 0.5:
		_scroll_by(scroll_vel)
		scroll_vel *= pow(0.92, delta * 60.0)
	elif not pressing:
		scroll_vel = 0.0
	if toast_time > 0.0:
		toast_time -= delta
		toast_label.modulate.a = clampf(toast_time / 0.5, 0.0, 1.0)
		if toast_time <= 0.0:
			toast_label.text = ""


func on_back() -> void:
	navigate.emit("world_map", {})
