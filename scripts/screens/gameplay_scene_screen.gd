extends "res://scripts/screens/gameplay_screen.gd"
## Layar Main gaya Cooking Madness: satu latar penuh, area ketuk tak terlihat di atas
## bahan, alat masak, dan wadah saji. Alur: bahan -> alat masak -> piring/mangkuk -> pelanggan.
## Logika pelanggan, bayar, jeda, dan bintang dipakai ulang dari gameplay_screen.gd.
## Gambar masakan sementara berupa lingkaran berwarna sampai aset ikon asli tersedia.

var scene: Dictionary = {}
var bg: TextureRect
var fx: Control
var appliances: Dictionary = {}      # nama alat -> Array slot
var hotspots: Array = []             # {"rect": Rect2 (piksel gambar), "btn": Button}
var font: Font
var bubble_style: StyleBoxFlat
var body_style: StyleBoxFlat
var title_label: Label
var time_panel: PanelContainer
var hud_panel: PanelContainer
var pause_btn: Control
var scale_f: float = 1.0
var offset: Vector2 = Vector2.ZERO
var pulse: float = 0.0
const FOCUS_Y := 540.0   # titik gambar yang dijaga di tengah layar
const TOAST_Y := 692.0   # pita batik di antara alat masak dan rak bahan


func _ready() -> void:
	rng.randomize()
	area = GameData.AREAS[area_idx]
	params = GameData.level_params(area_idx, level)
	dishes = params["dishes"]
	time_left = float(params["duration"])
	scene = GameData.SCENES[area["id"]]
	font = load("res://assets/fonts/game_font.tres")
	UI.fill(self)
	UI.background(self, Color(0.1, 0.04, 0.03))
	bg = TextureRect.new()
	bg.texture = load(scene["image"])
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	fx = Control.new()
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.draw.connect(_on_fx_draw)
	add_child(fx)
	bubble_style = _round_box(Color(1, 0.96, 0.85, 0.95), 14, 14)
	body_style = _round_box(Color.WHITE, 0, 0)
	body_style.corner_radius_top_left = 40
	body_style.corner_radius_top_right = 40
	for spot in scene["customer_spots"]:
		customer_panels.append({"spot": spot})
	_build_appliances()
	_build_hotspots()
	_build_hud()
	toast_label = UI.label("", 34, Color(1, 0.88, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.02))
	toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_label)
	resized.connect(_layout)
	_layout()
	_refresh_ui()


func _round_box(c: Color, r: int, pad: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(r)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	return sb


# ---------- membangun ----------
func _build_appliances() -> void:
	# Jumlah slot aktif naik lewat upgrade "slot"; sisanya terkunci (diredupkan).
	var usable: int = GameState.slots_per_station() + 1
	for aname in scene["appliances"]:
		var def: Dictionary = scene["appliances"][aname]
		var slots: Array = []
		var pts: Array = def["points"]
		for i in pts.size():
			slots.append({
				"kind": aname, "pos": pts[i], "r": float(def["r"]),
				"state": "empty" if i < usable else "locked",
				"dish": "", "t": 0.0, "dur": 0.0,
			})
		appliances[aname] = slots


func _make_hot(rect: Rect2, cb: Callable) -> void:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(cb)
	add_child(b)
	hotspots.append({"rect": rect, "btn": b})


func _build_hotspots() -> void:
	for aname in appliances:
		var slots: Array = appliances[aname]
		for i in slots.size():
			var r: float = slots[i]["r"]
			var c: Vector2 = slots[i]["pos"]
			_make_hot(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), _on_slot.bind(aname, i))
	for id in scene["ingredients"]:
		_make_hot(scene["ingredients"][id]["rect"], _on_ingredient.bind(id))


func _build_hud() -> void:
	pause_btn = UI.icon_button("res://assets/ui/btn_jeda.png", Vector2(72, 72))
	pause_btn.name = "BtnJeda"
	pause_btn.get_meta("button").pressed.connect(_toggle_pause)
	add_child(pause_btn)
	hud_panel = UI.panel(Color(0.12, 0.04, 0.02, 0.62), 14)
	var v := UI.vbox(4)
	hud_panel.add_child(v)
	title_label = UI.label("%s - Level %d" % [area["name"], level + 1], 22, Color.WHITE)
	v.add_child(title_label)
	var row := UI.hbox(10)
	v.add_child(row)
	goal_bar = ProgressBar.new()
	goal_bar.custom_minimum_size = Vector2(180, 18)
	goal_bar.max_value = float(params["target"])
	goal_bar.show_percentage = false
	goal_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bar_bg := _round_box(Color(0, 0, 0, 0.55), 8, 0)
	var bar_fill := _round_box(Color(0.35, 0.8, 0.3), 8, 0)
	goal_bar.add_theme_stylebox_override("background", bar_bg)
	goal_bar.add_theme_stylebox_override("fill", bar_fill)
	row.add_child(goal_bar)
	coins_label = UI.label("", 22, Color(1, 0.88, 0.45))
	row.add_child(coins_label)
	add_child(hud_panel)
	time_panel = UI.panel(Color(0.12, 0.04, 0.02, 0.62), 14)
	time_label = UI.label("", 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	time_label.custom_minimum_size = Vector2(96, 0)
	time_panel.add_child(time_label)
	add_child(time_panel)


# ---------- tata letak (mode cover, seperti layar lain) ----------
func _m(p: Vector2) -> Vector2:
	return offset + p * scale_f


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var img: Vector2 = scene["size"]
	scale_f = maxf(size.x / img.x, size.y / img.y)
	offset = (size - img * scale_f) * 0.5
	# Layar lebih lebar dari 16:9 memotong atas/bawah: pusatkan pada area main
	# (pelanggan sampai rak bahan), bukan pada tengah gambar.
	offset.y = clampf(size.y * 0.5 - FOCUS_Y * scale_f, size.y - img.y * scale_f, 0.0)
	bg.position = offset
	bg.size = img * scale_f
	fx.position = Vector2.ZERO
	fx.size = size
	for h in hotspots:
		var r: Rect2 = h["rect"]
		var b: Button = h["btn"]
		b.position = _m(r.position)
		b.size = r.size * scale_f
	var u: float = size.y / 720.0
	pause_btn.position = Vector2(14, 10) * u
	pause_btn.size = Vector2(72, 72) * u
	hud_panel.position = Vector2(96, 12) * u
	toast_label.size = Vector2(size.x, 40.0 * u)
	toast_label.position = Vector2(0, _m(Vector2(0, TOAST_Y)).y - toast_label.size.y * 0.5)
	toast_label.add_theme_font_size_override("font_size", int(30.0 * u))
	title_label.add_theme_font_size_override("font_size", int(22.0 * u))
	coins_label.add_theme_font_size_override("font_size", int(22.0 * u))
	time_label.add_theme_font_size_override("font_size", int(32.0 * u))
	time_label.custom_minimum_size = Vector2(96.0 * u, 0)
	goal_bar.custom_minimum_size = Vector2(180.0 * u, 18.0 * u)
	hud_panel.reset_size()
	time_panel.reset_size()
	time_panel.position = Vector2(size.x - time_panel.size.x - 14.0 * u, 12.0 * u)
	fx.queue_redraw()


# ---------- interaksi ----------
func _free_slot(kind: String) -> Dictionary:
	for slot in appliances[kind]:
		if slot["state"] == "empty":
			return slot
	return {}


func _reset(slot: Dictionary) -> void:
	slot["state"] = "empty"
	slot["dish"] = ""
	slot["t"] = 0.0
	slot["dur"] = 0.0


func _on_ingredient(id: String) -> void:
	if not running or paused:
		return
	var dish := ""
	for d in dishes:
		if GameData.RECIPES.has(d) and GameData.RECIPES[d]["ingredient"] == id:
			dish = d
	if dish == "":
		_toast("%s belum dipakai di level ini" % scene["ingredients"][id]["name"])
		return
	var kind: String = GameData.RECIPES[dish]["appliance"]
	var slot := _free_slot(kind)
	if slot.is_empty():
		_toast("%s penuh" % GameData.APPLIANCE_NAMES[kind])
		return
	slot["state"] = "cooking"
	slot["dish"] = dish
	slot["t"] = 0.0
	slot["dur"] = float(GameData.DISHES[dish]["cook"]) * GameState.cook_mult()


func _on_slot(kind: String, i: int) -> void:
	if not running or paused:
		return
	var slot: Dictionary = appliances[kind][i]
	match slot["state"]:
		"empty":
			if kind != "plate" and kind != "bowl":
				_toast("Ketuk bahan di rak bawah")
		"cooking":
			_toast("Masih memasak...")
		"burnt":
			_reset(slot)
			_toast("Masakan gosong dibuang")
		"ready":
			var rec: Dictionary = GameData.RECIPES[slot["dish"]]
			if rec["serve"] == "":
				_serve_from(slot)
			else:
				var ware := _free_slot(rec["serve"])
				if ware.is_empty():
					_toast("%s penuh" % GameData.APPLIANCE_NAMES[rec["serve"]])
					return
				ware["state"] = "full"
				ware["dish"] = slot["dish"]
				_reset(slot)
		"full":
			_serve_from(slot)


func _serve_from(slot: Dictionary) -> void:
	if _serve(slot["dish"]):
		_reset(slot)
	else:
		_toast("Belum ada yang memesan ini")


# ---------- loop ----------
func _update_slots(delta: float) -> void:
	pulse += delta
	for kind in appliances:
		for slot in appliances[kind]:
			match slot["state"]:
				"cooking":
					slot["t"] = float(slot["t"]) + delta
					if float(slot["t"]) >= float(slot["dur"]):
						slot["state"] = "ready"
						slot["t"] = 0.0
				"ready":
					if GameData.RECIPES[slot["dish"]].get("burns", true):
						slot["t"] = float(slot["t"]) + delta
						if float(slot["t"]) >= BURN_WINDOW:
							slot["state"] = "burnt"


func _refresh_ui() -> void:
	coins_label.text = "%d / %d" % [earned, int(params["target"])]
	goal_bar.value = minf(float(earned), goal_bar.max_value)
	var t: int = int(ceil(time_left))
	time_label.text = "%d:%02d" % [t / 60, t % 60]
	fx.queue_redraw()


# ---------- gambar sementara (lingkaran masakan, pelanggan, gelembung pesanan) ----------
func _text(pos: Vector2, txt: String, fs: int, col: Color) -> void:
	var ts: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var p := Vector2(pos.x - ts.x * 0.5, pos.y + fs * 0.35)
	fx.draw_string_outline(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, int(fs * 0.18)), Color(0.1, 0.04, 0.02))
	fx.draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _on_fx_draw() -> void:
	if scale_f <= 0.0:
		return
	var s: float = scale_f
	for kind in appliances:
		for slot in appliances[kind]:
			_draw_slot(slot, s)
	for k in customer_panels.size():
		for c in customers:
			if c["slot"] == k:
				_draw_customer(c, customer_panels[k]["spot"], s)


func _draw_slot(slot: Dictionary, s: float) -> void:
	var c: Vector2 = _m(slot["pos"])
	var r: float = float(slot["r"]) * s
	var st: String = slot["state"]
	if st == "locked":
		fx.draw_circle(c, r, Color(0, 0, 0, 0.5))
		return
	if st == "empty":
		return
	var col: Color = Color.html(GameData.DISHES[slot["dish"]]["color"]) if slot["dish"] != "" else Color.WHITE
	var letter: String = GameData.DISHES[slot["dish"]]["name"].substr(0, 1) if slot["dish"] != "" else ""
	match st:
		"cooking":
			fx.draw_circle(c, r * 0.68, col.darkened(0.25))
			var frac: float = float(slot["t"]) / maxf(float(slot["dur"]), 0.01)
			fx.draw_arc(c, r * 0.88, -PI * 0.5, -PI * 0.5 + TAU * frac, 40, Color(1, 0.7, 0.15), maxf(4.0, r * 0.14))
			_text(c, letter, int(r * 0.75), Color(1, 1, 1, 0.75))
		"ready":
			fx.draw_circle(c, r * 0.72, col)
			var a: float = 0.55 + 0.45 * sin(pulse * 6.0)
			fx.draw_arc(c, r * 0.9, 0.0, TAU, 40, Color(0.3, 1, 0.4, a), maxf(4.0, r * 0.16))
			_text(c, letter, int(r * 0.8), Color.WHITE)
		"burnt":
			fx.draw_circle(c, r * 0.72, Color(0.1, 0.08, 0.08))
			fx.draw_arc(c, r * 0.9, 0.0, TAU, 40, Color(0.85, 0.15, 0.1), maxf(4.0, r * 0.16))
			_text(c, "X", int(r * 0.8), Color(1, 0.5, 0.4))
		"full":
			fx.draw_circle(c, r * 0.62, col)
			fx.draw_arc(c, r * 0.72, 0.0, TAU, 40, Color(1, 1, 1, 0.9), maxf(3.0, r * 0.1))
			_text(c, letter, int(r * 0.7), Color.WHITE)


func _draw_customer(cust: Dictionary, spot: Vector2, s: float) -> void:
	var col := Color.from_hsv(float(hash(cust["name"]) % 100) / 100.0, 0.45, 0.9)
	var head: Vector2 = _m(spot + Vector2(0, -30))
	body_style.bg_color = col.darkened(0.2)
	fx.draw_style_box(body_style, Rect2(_m(spot + Vector2(-44, -2)), Vector2(88, 52) * s))
	fx.draw_circle(head, 30.0 * s, col)
	_text(_m(spot + Vector2(0, 22)), cust["name"], int(17.0 * s), Color.WHITE)
	# bar kesabaran
	var ratio: float = clampf(float(cust["patience"]) / float(cust["max"]), 0.0, 1.0)
	var bp: Vector2 = _m(spot + Vector2(-40, -80))
	fx.draw_rect(Rect2(bp, Vector2(80, 10) * s), Color(0, 0, 0, 0.6))
	fx.draw_rect(Rect2(bp, Vector2(80.0 * ratio, 10) * s), Color(1.0 - 0.6 * ratio, 0.4 + 0.6 * ratio, 0.3))
	# gelembung pesanan
	var n: int = cust["items"].size()
	var bh: float = n * 34.0 + 12.0
	var btop: Vector2 = spot + Vector2(36, -34.0 - bh)  # di samping kanan pelanggan
	fx.draw_style_box(bubble_style, Rect2(_m(btop), Vector2(176, bh) * s))
	for k in n:
		var id: String = cust["items"][k]
		var done: bool = cust["served"][k]
		var rc: Vector2 = _m(btop + Vector2(22, 6.0 + 17.0 + k * 34.0))
		fx.draw_circle(rc, 13.0 * s, Color.html(GameData.DISHES[id]["color"]))
		var nm: String = GameData.DISHES[id]["name"]
		var tcol: Color = Color(0.3, 0.55, 0.3) if done else Color(0.25, 0.1, 0.05)
		fx.draw_string(font, _m(btop + Vector2(42, 6.0 + 17.0 + k * 34.0)) + Vector2(0, 7.0 * s), ("OK " if done else "") + nm,
			HORIZONTAL_ALIGNMENT_LEFT, int(128.0 * s), int(15.0 * s), tcol)
