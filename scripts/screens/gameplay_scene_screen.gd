extends "res://scripts/screens/gameplay_screen.gd"
## Layar Main gaya Cooking Madness: satu latar penuh, area ketuk tak terlihat di atas
## bahan, alat masak, dan wadah saji. Alur: bahan -> alat masak -> piring/mangkuk -> pelanggan.
## Logika pelanggan, bayar, jeda, dan bintang dipakai ulang dari gameplay_screen.gd.
## Gambar masakan sementara berupa lingkaran berwarna sampai aset ikon asli tersedia.

var scene: Dictionary = {}
var bg: TextureRect
var side_strips: Array = []   # tepi gambar diregangkan untuk sisi layar yang lebih lebar dari 16:9
var fx: Control
var bubble_tex: Texture2D            # bingkai gelembung pesanan (ada slot bar kesabaran vertikal di kanan)
var ting_player: AudioStreamPlayer   # bel "ting" saat masakan matang
var ting_count: int = 0
var art_tex: Dictionary = {}         # dish -> state -> Array[Texture2D] (potongan tahap masakan)
var icon_tex: Dictionary = {}        # id hidangan -> Texture2D ikon (di-cache, jangan load tiap frame)
var cust_fx: Control                 # lapisan pelanggan (di belakang konter)
var counter: Polygon2D               # siluet konter dari latar, menimpa pelanggan
var appliances: Dictionary = {}      # nama alat -> Array slot
var hotspots: Array = []             # {"rect": Rect2 (piksel gambar), "btn": Button}
var font: Font
var bubble_style: StyleBoxFlat
var body_style: StyleBoxFlat
var title_label: Label               # penampung nilai HUD (tidak masuk pohon; digambar di fx)
var pause_btn: Control
var scale_f: float = 1.0
var offset: Vector2 = Vector2.ZERO
var pulse: float = 0.0
const BUBBLE_WINDOW := 2   # ikon yang terlihat sekaligus di gelembung; sisanya tergulir naik
var jar: Dictionary = {"state": "empty", "t": 0.0, "dur": 0.0, "uses": 0}
var jar_tex: Texture2D
var glass_tex: Array = []
var customer_tex: Dictionary = {}
const TOAST_Y := 692.0   # pita batik di antara alat masak dan rak bahan


func _ready() -> void:
	max_order_items = 5
	rng.randomize()
	area = GameData.AREAS[area_idx]
	params = GameData.level_params(area_idx, level)
	dishes = params["dishes"]
	time_left = float(params["duration"])
	scene = GameData.SCENES[area["id"]]
	font = load("res://assets/fonts/game_font.tres")
	UI.fill(self)
	UI.background(self, Color(0.1, 0.04, 0.03))
	var src_tex: Texture2D = load(scene["image"])
	var isz: Vector2 = scene["size"]
	for side in 2:
		var strip := TextureRect.new()
		var at := AtlasTexture.new()
		at.atlas = src_tex
		at.region = Rect2(0 if side == 0 else isz.x - 4.0, 0, 4.0, isz.y)
		strip.texture = at
		strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		strip.stretch_mode = TextureRect.STRETCH_SCALE
		strip.modulate = Color(0.55, 0.5, 0.45)
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(strip)
		side_strips.append(strip)
	bg = TextureRect.new()
	bg.texture = load(scene["image"])
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	for id in GameData.DISHES:
		if GameData.DISHES[id].has("icon"):
			icon_tex[id] = load(GameData.DISHES[id]["icon"])
	if scene.has("stage_art"):
		for dish in scene["stage_art"]:
			if dish == "rects":
				continue
			art_tex[dish] = {}
			for st in scene["stage_art"][dish]:
				if st == "rects":
					continue
				var arr: Array = []
				for path in scene["stage_art"][dish][st]:
					arr.append(load(path))
				art_tex[dish][st] = arr
	bubble_tex = load("res://assets/ui/bubble_pesanan.png")
	ting_player = AudioStreamPlayer.new()
	ting_player.stream = load("res://assets/audio/ting.wav")
	ting_player.volume_db = -4.0
	add_child(ting_player)
	cust_fx = Control.new()
	cust_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cust_fx.draw.connect(_on_cust_draw)
	add_child(cust_fx)
	counter = Polygon2D.new()
	counter.texture = bg.texture
	counter.polygon = PackedVector2Array(scene["counter_mask"])
	counter.uv = counter.polygon
	add_child(counter)
	fx = Control.new()
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.draw.connect(_on_fx_draw)
	add_child(fx)
	bubble_style = _round_box(Color(1, 0.96, 0.85, 0.95), 14, 14)
	body_style = _round_box(Color.WHITE, 0, 0)
	body_style.corner_radius_top_left = 40
	body_style.corner_radius_top_right = 40
	if scene.has("dispenser"):
		var dd: Dictionary = scene["dispenser"]
		jar_tex = load(dd["full_image"])
		for gp in dd["glass_images"]:
			glass_tex.append(load(gp))
	if scene.has("customer_art"):
		for mood in ["senang", "biasa", "marah"]:
			customer_tex[mood] = load(scene["customer_art"][mood])
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
				"kind": aname, "idx": i, "pos": pts[i], "r": float(def["r"]),
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
	if scene.has("dispenser"):
		_make_hot(scene["dispenser"]["hot"], _on_dispenser)
	for id in scene["ingredients"]:
		_make_hot(scene["ingredients"][id]["rect"], _on_ingredient.bind(id))


func _build_hud() -> void:
	# Bingkai HUD sudah ada di gambar latar; di sini hanya area ketuk + penampung nilai.
	var hud: Dictionary = scene["hud"]
	_make_hot(hud["gear"], _toggle_pause)
	pause_btn = hotspots[hotspots.size() - 1]["btn"]
	pause_btn.name = "BtnJeda"
	_make_hot(hud["squares"][0], _toast.bind("Misi segera hadir"))
	_make_hot(hud["squares"][1], _toast.bind("Toko dibuka dari menu utama"))
	title_label = UI.label("", 22)
	coins_label = UI.label("", 22)
	time_label = UI.label("", 32)
	goal_bar = ProgressBar.new()
	goal_bar.max_value = float(params["target"])


# ---------- tata letak (mode cover, seperti layar lain) ----------
func _m(p: Vector2) -> Vector2:
	return offset + p * scale_f


func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var img: Vector2 = scene["size"]
	# Seluruh gambar harus terlihat (HUD ada di tepi atas/bawah): muat ke layar, tanpa dipotong.
	# Layar yang lebih lebar dari 16:9 mendapat sisi kiri-kanan yang diisi gambar latar buram.
	scale_f = minf(size.x / img.x, size.y / img.y)
	offset = (size - img * scale_f) * 0.5
	var side_w: float = maxf(offset.x, 0.0)
	side_strips[0].position = Vector2.ZERO
	side_strips[0].size = Vector2(side_w + 1.0, size.y)
	side_strips[1].position = Vector2(size.x - side_w - 1.0, 0)
	side_strips[1].size = Vector2(side_w + 1.0, size.y)
	bg.position = offset
	bg.size = img * scale_f
	cust_fx.position = Vector2.ZERO
	cust_fx.size = size
	counter.position = offset
	counter.scale = Vector2(scale_f, scale_f)
	fx.position = Vector2.ZERO
	fx.size = size
	for h in hotspots:
		var r: Rect2 = h["rect"]
		var b: Button = h["btn"]
		b.position = _m(r.position)
		b.size = r.size * scale_f
	var u: float = size.y / 720.0
	toast_label.size = Vector2(size.x, 40.0 * u)
	toast_label.position = Vector2(0, _m(Vector2(0, TOAST_Y)).y - toast_label.size.y * 0.5)
	toast_label.add_theme_font_size_override("font_size", int(30.0 * u))
	fx.queue_redraw()
	cust_fx.queue_redraw()


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
	if GameData.RECIPES[dish].get("refill", false):
		_refill_jar()
		return
	var slot := _free_slot(kind)
	if slot.is_empty():
		_toast("%s penuh" % GameData.APPLIANCE_NAMES[kind])
		return
	slot["state"] = "cooking"
	slot["dish"] = dish
	slot["t"] = 0.0
	slot["dur"] = float(GameData.DISHES[dish]["cook"]) * GameState.cook_mult()


func _refill_jar() -> void:
	match jar["state"]:
		"filling":
			_toast("Dispenser sedang diisi...")
		"full":
			_toast("Dispenser masih penuh")
		_:
			jar["state"] = "filling"
			jar["t"] = 0.0
			jar["dur"] = GameData.JAR_FILL_TIME * GameState.cook_mult()


func _on_dispenser() -> void:
	if not running or paused:
		return
	match jar["state"]:
		"empty":
			_toast("Dispenser kosong. Ketuk es di rak bawah")
		"filling":
			_toast("Dispenser sedang diisi...")
		"full":
			var slot := _free_slot("dispenser")
			if slot.is_empty():
				_toast("Gelas penuh")
				return
			slot["state"] = "cooking"
			slot["dish"] = "es_teh"
			slot["t"] = 0.0
			slot["dur"] = float(GameData.DISHES["es_teh"]["cook"]) * GameState.cook_mult()
			jar["uses"] = int(jar["uses"]) - 1
			if int(jar["uses"]) <= 0:
				jar["state"] = "empty"


func _on_slot(kind: String, i: int) -> void:
	if not running or paused:
		return
	var slot: Dictionary = appliances[kind][i]
	match slot["state"]:
		"empty":
			if kind == "dispenser":
				_toast("Ketuk dispenser untuk mengisi gelas")
			elif kind != "plate" and kind != "bowl":
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
# Animasi gelembung: item yang sudah diberikan memudar & mengecil, sisanya bergulir naik.
func _anim_bubbles(delta: float) -> void:
	for c in customers:
		_step_vis(c, delta)


func _step_vis(c: Dictionary, delta: float) -> void:
	var n: int = c["items"].size()
	if not c.has("vis"):
		c["vis"] = []
	var vis: Array = c["vis"]
	while vis.size() < n:
		vis.append({"y": float(vis.size()), "a": 1.0})
	var pos := 0
	for k in n:
		var v: Dictionary = vis[k]
		if c["served"][k]:
			v["a"] = move_toward(float(v["a"]), 0.0, delta * 3.5)
		else:
			v["y"] = move_toward(float(v["y"]), float(pos), delta * 6.0)
			pos += 1


func _update_slots(delta: float) -> void:
	pulse += delta
	_anim_bubbles(delta)
	if jar["state"] == "filling":
		jar["t"] = float(jar["t"]) + delta
		if float(jar["t"]) >= float(jar["dur"]):
			jar["state"] = "full"
			jar["uses"] = GameData.JAR_CAPACITY
	for kind in appliances:
		for slot in appliances[kind]:
			match slot["state"]:
				"cooking":
					slot["t"] = float(slot["t"]) + delta
					if float(slot["t"]) >= float(slot["dur"]):
						slot["state"] = "ready"
						slot["t"] = 0.0
						_ding()
				"ready":
					if GameData.RECIPES[slot["dish"]].get("burns", true):
						slot["t"] = float(slot["t"]) + delta
						if float(slot["t"]) >= BURN_WINDOW:
							slot["state"] = "burnt"


func _ding() -> void:
	ting_count += 1
	ting_player.play()


func _refresh_ui() -> void:
	coins_label.text = "%d / %d" % [earned, int(params["target"])]
	goal_bar.value = minf(float(earned), goal_bar.max_value)
	var t: int = int(ceil(time_left))
	time_label.text = "%d:%02d" % [t / 60, t % 60]
	fx.queue_redraw()
	cust_fx.queue_redraw()


# ---------- gambar sementara (lingkaran masakan, pelanggan, gelembung pesanan) ----------
func _text(pos: Vector2, txt: String, fs: int, col: Color) -> void:
	var ts: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var p := Vector2(pos.x - ts.x * 0.5, pos.y + fs * 0.35)
	fx.draw_string_outline(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, int(fs * 0.18)), Color(0.1, 0.04, 0.02))
	fx.draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_tex_clipped(tex: Texture2D, pos: Vector2, frac: float, s: float) -> void:
	# Gambar lapisan dari bawah ke atas sebanyak `frac` (cairan naik).
	var sz: Vector2 = tex.get_size()
	var h: float = sz.y * clampf(frac, 0.0, 1.0)
	if h <= 0.5:
		return
	var src := Rect2(0, sz.y - h, sz.x, h)
	var dst := Rect2(_m(pos + Vector2(0, sz.y - h)), Vector2(sz.x, h) * s)
	fx.draw_texture_rect_region(tex, dst, src)


func _draw_dispenser(s: float) -> void:
	var dd: Dictionary = scene["dispenser"]
	match jar["state"]:
		"filling":
			var f: float = float(jar["t"]) / maxf(float(jar["dur"]), 0.01)
			# dispenser perlahan terisi (memudar)
			fx.draw_texture_rect(jar_tex, Rect2(_m(dd["full_pos"]), jar_tex.get_size() * s), false, Color(1, 1, 1, smoothstep(0.0, 1.0, f)))
		"full":
			fx.draw_texture_rect(jar_tex, Rect2(_m(dd["full_pos"]), jar_tex.get_size() * s), false)
	# gelas: terisi bertahap (cairan naik) saat memasak, penuh saat matang
	var slots: Array = appliances["dispenser"]
	for i in slots.size():
		var slot: Dictionary = slots[i]
		var gp: Vector2 = dd["glass_pos"][i]
		if slot["state"] == "cooking":
			var f: float = float(slot["t"]) / maxf(float(slot["dur"]), 0.01)
			_draw_tex_clipped(glass_tex[i], gp, f, s)
		elif slot["state"] == "ready":
			fx.draw_texture_rect(glass_tex[i], Rect2(_m(gp), glass_tex[i].get_size() * s), false)


func _on_fx_draw() -> void:
	if scale_f <= 0.0:
		return
	var s: float = scale_f
	if scene.has("dispenser"):
		_draw_dispenser(s)
	for kind in appliances:
		if kind == "dispenser" and scene.has("dispenser"):
			for slot in appliances[kind]:
				if slot["state"] == "locked":
					_draw_slot(slot, s)
			continue
		for slot in appliances[kind]:
			_draw_slot(slot, s)
	for k in customer_panels.size():
		for c in customers:
			if c["slot"] == k:
				_draw_bubble(c, customer_panels[k]["spot"], s)
	_draw_hud(s)


# Teks HUD di atas bingkai kosong pada latar. Hanya data yang benar-benar ada di game.
func _text_at(pos: Vector2, txt: String, fs: int, col: Color, align: int = 0) -> void:
	# align: 0 kiri, 1 tengah, 2 kanan; pos = titik awal/tengah/akhir teks (layar)
	var ts: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var x: float = pos.x - (0.0 if align == 0 else (ts.x * 0.5 if align == 1 else ts.x))
	var p := Vector2(x, pos.y + fs * 0.35)
	fx.draw_string_outline(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, int(fs * 0.18)), Color(0.1, 0.04, 0.02))
	fx.draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_hud(s: float) -> void:
	var hud: Dictionary = scene["hud"]
	var gold := Color(1, 0.88, 0.45)
	var target: int = int(params["target"])
	var t: int = int(ceil(time_left))
	# avatar: nomor level
	var av: Rect2 = hud["avatar"]
	_text_at(_m(av.get_center()), str(level + 1), int(40.0 * s), Color.WHITE, 1)
	# strip 1: nama area singkat; strip 2: bar target + angka
	var s1: Rect2 = hud["strip1"]
	var short_name: String = String(area["name"]).split(" ")[-1]
	_text_at(_m(s1.get_center()), short_name, int(19.0 * s), gold, 1)
	var s2: Rect2 = hud["strip2"]
	var frac: float = clampf(float(earned) / maxf(float(target), 1.0), 0.0, 1.0)
	var inner := Rect2(s2.position + Vector2(4, 5), s2.size - Vector2(8, 10))
	if frac > 0.0:
		fx.draw_rect(Rect2(_m(inner.position), Vector2(inner.size.x * frac, inner.size.y) * s), Color(0.35, 0.82, 0.3))
	_text_at(_m(s2.get_center()), "%d/%d" % [earned, target], int(16.0 * s), Color.WHITE, 1)
	# pil: waktu, target, hasil level, koin total
	var pills: Array = hud["pills"]
	var vals: Array = [
		["Waktu", "%d:%02d" % [t / 60, t % 60]],
		["Target", str(target)],
		["Hasil", str(earned)],
		["Koin", str(GameState.coins)],
	]
	for i in 4:
		var pr: Rect2 = pills[i]
		var c: Vector2 = _m(pr.get_center())
		_text_at(Vector2(_m(pr.position).x + 14.0 * s, c.y), vals[i][0], int(17.0 * s), Color(0.95, 0.75, 0.45), 0)
		_text_at(Vector2(_m(pr.position + Vector2(pr.size.x - 14.0, 0)).x, c.y), vals[i][1], int(24.0 * s), Color.WHITE, 2)
	# tombol gir: simbol jeda (dua batang)
	var gr: Rect2 = hud["gear"]
	var gc: Vector2 = gr.get_center()
	for dx in [-8.0, 8.0]:
		fx.draw_rect(Rect2(_m(gc + Vector2(dx - 5.0, -14.0)), Vector2(10.0, 28.0) * s), Color(1, 0.93, 0.7))
	# tombol samping
	var names := ["Misi", "Toko"]
	for i in 2:
		var sq: Rect2 = hud["squares"][i]
		_text_at(_m(sq.get_center()), names[i], int(21.0 * s), gold, 1)
	# panel menu: daftar hidangan level ini
	var ph: Rect2 = hud["panel_head"]
	_text_at(_m(ph.get_center()), "Menu Level", int(22.0 * s), gold, 1)
	var pb: Rect2 = hud["panel_body"]
	var n: int = mini(dishes.size(), 5)
	var row_h: float = pb.size.y / 5.0
	for k in n:
		var id: String = dishes[k]
		var cy: float = pb.position.y + row_h * (k + 0.5)
		var d: Dictionary = GameData.DISHES[id]
		if icon_tex.has(id):
			fx.draw_texture_rect(icon_tex[id], Rect2(_m(Vector2(pb.position.x + 8.0, cy - 13.0)), Vector2(26, 26) * s), false)
		_text_at(_m(Vector2(pb.position.x + 40.0, cy)), String(d["name"]), int(17.0 * s), Color(0.28, 0.12, 0.05), 0)
		_text_at(_m(Vector2(pb.position.x + pb.size.x - 10.0, cy)), str(int(d["price"])), int(17.0 * s), Color(0.55, 0.25, 0.05), 2)


func _on_cust_draw() -> void:
	if scale_f <= 0.0:
		return
	for k in customer_panels.size():
		for c in customers:
			if c["slot"] == k:
				_draw_customer(c, customer_panels[k]["spot"], scale_f)


func _draw_slot(slot: Dictionary, s: float) -> void:
	var c: Vector2 = _m(slot["pos"])
	var r: float = float(slot["r"]) * s
	var st: String = slot["state"]
	if st == "locked":
		fx.draw_circle(c, r, Color(0, 0, 0, 0.5))
		return
	if st == "empty":
		return
	if _draw_stage_art(slot, st, c, r, s):
		return
	var col: Color = Color.html(GameData.DISHES[slot["dish"]]["color"]) if slot["dish"] != "" else Color.WHITE
	var letter: String = GameData.DISHES[slot["dish"]]["name"].substr(0, 1) if slot["dish"] != "" else ""
	match st:
		"cooking":
			fx.draw_circle(c, r * 0.68, col.darkened(0.25))
			_text(c, letter, int(r * 0.75), Color(1, 1, 1, 0.75))
		"ready":
			fx.draw_circle(c, r * 0.72, col)
			_text(c, letter, int(r * 0.8), Color.WHITE)
		"burnt":
			fx.draw_circle(c, r * 0.72, Color(0.1, 0.08, 0.08))
			_text(c, "X", int(r * 0.8), Color(1, 0.5, 0.4))
		"full":
			fx.draw_circle(c, r * 0.62, col)
			_text(c, letter, int(r * 0.7), Color.WHITE)


# Gambar tahap masakan dari latar (mentah/matang/gosong/di piring). true bila dipakai.
func _draw_stage_art(slot: Dictionary, st: String, _c: Vector2, _r: float, s: float) -> bool:
	var dish: String = slot["dish"]
	if not art_tex.has(dish) or not art_tex[dish].has(st):
		return false
	var rects: Dictionary = scene["stage_art"]["rects"]
	if scene["stage_art"][dish].has("rects"):
		rects = scene["stage_art"][dish]["rects"]   # ukuran potongan khusus hidangan
	if not rects.has(slot["kind"]):
		return false
	var texs: Array = art_tex[dish][st]
	var idx: int = int(slot["idx"])
	if idx >= texs.size():
		return false
	var rc: Rect2 = rects[slot["kind"]]
	fx.draw_texture_rect(texs[idx], Rect2(_m(slot["pos"] + rc.position), rc.size * s), false)
	return true


func _customer_mood(cust: Dictionary) -> String:
	var ratio: float = float(cust["patience"]) / float(cust["max"])
	if ratio > GameData.MOOD_HAPPY_ABOVE:
		return "senang"
	if ratio < GameData.MOOD_ANGRY_BELOW:
		return "marah"
	return "biasa"


func _top_y(spot: Vector2) -> float:
	if customer_tex.is_empty():
		return spot.y - 70.0
	return spot.y - float(scene["customer_art"]["height"])


func _draw_customer(cust: Dictionary, spot: Vector2, s: float) -> void:
	var ratio: float = clampf(float(cust["patience"]) / float(cust["max"]), 0.0, 1.0)
	var top_y: float = spot.y - 40.0
	if customer_tex.is_empty():
		var col := Color.from_hsv(float(hash(cust["name"]) % 100) / 100.0, 0.45, 0.9)
		body_style.bg_color = col.darkened(0.2)
		cust_fx.draw_style_box(body_style, Rect2(_m(spot + Vector2(-44, -2)), Vector2(88, 52) * s))
		cust_fx.draw_circle(_m(spot + Vector2(0, -30)), 30.0 * s, col)
		top_y = spot.y - 70.0
	else:
		var tex: Texture2D = customer_tex[_customer_mood(cust)]
		var h: float = float(scene["customer_art"]["height"])
		var w: float = tex.get_size().x * h / tex.get_size().y
		top_y = spot.y - h
		cust_fx.draw_texture_rect(tex, Rect2(_m(Vector2(spot.x - w * 0.5, top_y)), Vector2(w, h) * s), false)


func _draw_bubble(cust: Dictionary, spot: Vector2, s: float) -> void:
	var ratio: float = clampf(float(cust["patience"]) / float(cust["max"]), 0.0, 1.0)
	var top_y: float = _top_y(spot)
	# gelembung pesanan vertikal di sebelah kanan pelanggan, hanya gambar menu (tanpa teks);
	# pindah ke kiri bila mepet tepi layar. Bila DISHES[id] punya "icon", gambar itu yang dipakai.
	var n: int = cust["items"].size()
	var bw: float = 96.0
	var bh: float = bw * 480.0 / 296.0   # rasio gambar bingkai
	var img_w: float = scene["size"].x
	var bx: float = spot.x + 92.0
	if bx + bw > img_w - 2.0:
		bx = spot.x - 92.0 - bw
	var btop: Vector2 = Vector2(bx, spot.y - 184.0)  # di bawah panel waktu
	fx.draw_texture_rect(bubble_tex, Rect2(_m(btop), Vector2(bw, bh) * s), false)
	# bar kesabaran: terisi dari bawah (penuh = senang di atas, kosong = marah di bawah)
	var bar_x: float = btop.x + bw * 0.818
	var bar_w: float = bw * 0.058
	var bar_top: float = btop.y + bh * 0.272
	var bar_h: float = bh * 0.462
	fx.draw_rect(Rect2(_m(Vector2(bar_x, bar_top + bar_h * (1.0 - ratio))), Vector2(bar_w, bar_h * ratio) * s),
		Color(1.0 - 0.6 * ratio, 0.45 + 0.55 * ratio, 0.25))
	# ikon pesanan di area kertas (kiri bar), dipusatkan secara vertikal
	var area_top: float = btop.y + bh * 0.21
	var area_h: float = bh * 0.66
	var icon: float = 52.0
	var cx: float = btop.x + bw * 0.43
	var slot_h: float = area_h / float(BUBBLE_WINDOW)
	if not cust.has("vis") or cust["vis"].size() < n:
		_step_vis(cust, 0.0)
	var left: int = 0
	for k in n:
		if not cust["served"][k]:
			left += 1
		var v: Dictionary = cust["vis"][k]
		var id: String = cust["items"][k]
		var win: float = clampf(float(BUBBLE_WINDOW) - float(v["y"]), 0.0, 1.0)
		var alpha: float = float(v["a"]) * win
		if alpha <= 0.01:
			continue
		var sc: float = 0.6 + 0.4 * float(v["a"])
		var c: Vector2 = Vector2(cx, area_top + slot_h * (float(v["y"]) + 0.5))
		var d: Dictionary = GameData.DISHES[id]
		var sz: float = icon * sc
		if icon_tex.has(id):
			fx.draw_texture_rect(icon_tex[id], Rect2(_m(c - Vector2(sz, sz) * 0.5), Vector2(sz, sz) * s), false, Color(1, 1, 1, alpha))
		else:
			var dc := Color.html(d["color"])
			fx.draw_circle(_m(c), sz * 0.42 * s, Color(dc.darkened(0.15), alpha))
			_text(_m(c), String(d["name"]).substr(0, 1), int(sz * 0.45 * s), Color(1, 1, 1, alpha))
	var hidden: int = left - BUBBLE_WINDOW
	if hidden > 0:
		_text(_m(Vector2(cx, btop.y + bh * 0.9)), "+%d" % hidden, int(18.0 * s), Color(1, 0.9, 0.5))
