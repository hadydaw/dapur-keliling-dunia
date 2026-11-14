extends Control
## Pilih Level: latar pemandangan area, 5 medali level (bintang + target), papan nama area.

const UI = preload("res://scripts/ui_kit.gd")
const GameData = preload("res://scripts/game_data.gd")
const LevelMedal = preload("res://scripts/ui/level_medal.gd")
const ASSET_DIR := "res://assets/ui/"

signal navigate(screen: String, params: Dictionary)

# Posisi medali (pecahan tinggi layar): lengkung ringan agar terasa seperti jalur
const ROW_Y := 0.58
const WAVE := [0.0, -0.045, 0.02, -0.045, 0.0]
const MEDAL := 128.0   # diameter pada basis tinggi 720
const GAP := 58.0

var area_idx: int = 0
var bg_rect: TextureRect
var bg_tex: Texture2D
var title_plate: TextureRect
var title_label: Label
var medals: Array = []      # {medal, button, stars:[3], target, lock}
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

	for l in GameData.LEVELS_PER_AREA:
		_build_level(l)

	var bar := _asset("bar_koin")
	top_items.append({"node": bar, "x": 16, "y": 16, "w": 230, "a": "l", "id": "bar_koin"})
	coin_label = UI.label("0", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	coin_label.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.04))
	coin_label.add_theme_constant_override("outline_size", 6)
	coin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coin_label)

	var back := _asset("btn_back")
	var bb := TextureButton.new()
	bb.ignore_texture_size = true
	bb.focus_mode = Control.FOCUS_NONE
	bb.button_down.connect(_press_anim.bind(back, true))
	bb.button_up.connect(_press_anim.bind(back, false))
	bb.pressed.connect(on_back)
	add_child(bb)
	top_items.append({"node": back, "x": 14, "y": 12, "w": 64, "a": "r", "btn": bb, "id": "back"})

	toast_label = UI.label("", 30, Color(1, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.03))
	toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_label)
	resized.connect(_layout)
	_layout()


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
		add_child(m)
		medal = m
	else:
		medal = _asset("ic_gembok")
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
		add_child(s)
		stars.append(s)
	entry["stars"] = stars
	var t := UI.label("Target %d" % int(params["target"]), 20, Color(1, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.02))
	t.add_theme_constant_override("outline_size", 6)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.visible = unlocked
	add_child(t)
	entry["target"] = t
	var b := TextureButton.new()
	b.ignore_texture_size = true
	b.focus_mode = Control.FOCUS_NONE
	b.button_down.connect(_press_anim.bind(medal, true))
	b.button_up.connect(_press_anim.bind(medal, false))
	b.pressed.connect(_on_level.bind(l))
	add_child(b)
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
	# medali
	var n: int = medals.size()
	var step: float = (MEDAL + GAP) * u
	var total: float = step * (n - 1)
	for i in n:
		var e: Dictionary = medals[i]
		var d: float = MEDAL * u
		var cx: float = size.x * 0.5 - total * 0.5 + step * i
		var cy: float = size.y * (ROW_Y + WAVE[i])
		var medal: Control = e["medal"]
		medal.size = Vector2(d, d)
		medal.position = Vector2(cx - d * 0.5, cy - d * 0.5)
		medal.queue_redraw()
		var sw: float = 34.0 * u
		var stars: Array = e["stars"]
		for k in 3:
			var s: TextureRect = stars[k]
			s.size = Vector2(sw, sw)
			s.position = Vector2(cx + (k - 1) * (sw + 2.0 * u) - sw * 0.5, cy + d * 0.5 + 6.0 * u + (0.0 if k == 1 else -0.0))
		var tl: Label = e["target"]
		UI.fit_label(tl, tl.text, Rect2(cx - (d + 40.0 * u) * 0.5, cy + d * 0.5 + 6.0 * u + sw + 2.0 * u, d + 40.0 * u, 26.0 * u), 0.85)
		var b: TextureButton = e["button"]
		b.position = medal.position - Vector2(10, 10) * u
		b.size = Vector2(d + 20.0 * u, d + 20.0 * u + (sw + 34.0 * u if e["unlocked"] else 0.0))
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
	if toast_time > 0.0:
		toast_time -= delta
		toast_label.modulate.a = clampf(toast_time / 0.5, 0.0, 1.0)
		if toast_time <= 0.0:
			toast_label.text = ""


func on_back() -> void:
	navigate.emit("world_map", {})
