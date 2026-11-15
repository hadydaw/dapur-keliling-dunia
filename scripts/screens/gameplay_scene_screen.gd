extends "res://scripts/screens/gameplay_screen.gd"
## Layar Main gaya Cooking Madness: satu latar penuh, area ketuk tak terlihat di atas
## bahan, alat masak, dan wadah saji. Alur: bahan -> alat masak -> piring/mangkuk -> pelanggan.
## Logika pelanggan, bayar, jeda, dan bintang dipakai ulang dari gameplay_screen.gd.
## Gambar masakan sementara berupa lingkaran berwarna sampai aset ikon asli tersedia.

var scene: Dictionary = {}
var bg: TextureRect
var hud_shift := Vector2.ZERO   # geser HUD kiri (<=0) dan kanan (>=0) ke tepi area aman
var hud_tex: Dictionary = {}     # nama sprite HUD -> Texture2D (di-cache di _ready)
var hud_r: Dictionary = {}       # nama elemen HUD -> Rect2 layar (dihitung di _layout)
var hud_hot: Dictionary = {}     # area ketuk HUD -> Rect2 layar
var hud_u: float = 1.0           # piksel layar per piksel inti untuk HUD (skala k*f)
var hud_safe := Rect2()
var safe_insets_override := Vector4(-1, 0, 0, 0)   # untuk uji; x<0 = pakai area aman perangkat
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
var force_wide := -1   # uji: 1 = paksa latar lebar, 0 = paksa latar 16:9, -1 = menurut rasio layar
const CROP_TOP_MAX := 60.0   # latar cover: potongan atas/bawah maksimum (piksel inti) bila layar lebih lebar dari gambar
var offset: Vector2 = Vector2.ZERO
var pulse: float = 0.0
const ALARM_H := 36.0        # tinggi ikon timer (piksel inti)
const ALARM_STEPS := 64
const DING_SHAKE := 0.8      # lama goyang + memudar setelah "ting" (detik); ting.wav = 1.1 dtk
const BUBBLE_WINDOW := 2   # ikon yang terlihat sekaligus di gelembung; sisanya tergulir naik
var jar: Dictionary = {"state": "empty", "t": 0.0, "dur": 0.0, "uses": 0}
var jar_tex: Texture2D
var alarm_tex: Texture2D             # ikon jam alarm timer memasak
var alarm_ring_tex: Texture2D        # sprite sheet 8x8: cincin progres (64 langkah, putih, diwarnai saat digambar)
var lock_tex: Texture2D              # ikon gembok slot terkunci (di-cache)
var glass_tex: Array = []
var customer_tex: Dictionary = {}
const TOAST_Y := 692.0   # pita batik di antara alat masak dan rak bahan (bisa ditimpa scene["toast_y"])


func _ready() -> void:
	max_order_items = 5
	rng.randomize()
	area = GameData.AREAS[area_idx]
	params = GameData.level_params(area_idx, level)
	dishes = params["dishes"]
	time_left = float(params["duration"])
	var aspect: float = get_viewport_rect().size.x / maxf(get_viewport_rect().size.y, 1.0)
	if force_wide == 1:
		aspect = 9.0
	elif force_wide == 0:
		aspect = 1.0
	scene = GameData.scene_for(area["id"], aspect)
	font = load("res://assets/fonts/game_font.tres")
	UI.fill(self)
	UI.background(self, Color(0.1, 0.04, 0.03))
	# sisi layar yang lebih lebar dari 16:9: wash warna blur dari latar (bukan bar hitam)
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
	lock_tex = load("res://assets/ui/gembok.png")
	alarm_tex = load("res://assets/ui/alarm.png")
	alarm_ring_tex = load("res://assets/ui/alarm_ring.png")
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
	var pad_x: float = float(scene.get("pad", 0.0))
	var uv := PackedVector2Array()
	for pt in counter.polygon:
		uv.append(pt + Vector2(pad_x, 0.0))
	counter.uv = uv
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


func _make_hot(rect: Rect2, cb: Callable, hud_key: String = "") -> void:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(cb)
	add_child(b)
	hotspots.append({"rect": rect, "btn": b, "hud_key": hud_key})


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
	# Bingkai HUD digambar di fx (lihat _draw_hud_frames); di sini area ketuk + penampung nilai.
	for nm in scene["hud"]["sprites"]:
		hud_tex[nm] = load(String(scene["hud"]["sprites"][nm]["img"]))
	_make_hot(Rect2(), _toggle_pause, "gear")
	pause_btn = hotspots[hotspots.size() - 1]["btn"]
	pause_btn.name = "BtnJeda"
	_make_hot(Rect2(), _toast.bind("Misi segera hadir"), "tile0")
	_make_hot(Rect2(), _toast.bind("Toko dibuka dari menu utama"), "tile1")
	title_label = UI.label("", 22)
	coins_label = UI.label("", 22)
	time_label = UI.label("", 32)
	goal_bar = ProgressBar.new()
	goal_bar.max_value = float(params["target"])


# ---------- tata letak (mode cover, seperti layar lain) ----------
func _m(p: Vector2) -> Vector2:
	return offset + p * scale_f


func _sprite_size(name: String) -> Vector2:
	var tex: Texture2D = hud_tex[name]
	var w: float = float(scene["hud"]["sprites"][name]["w"])
	return Vector2(w, w * tex.get_height() / float(tex.get_width()))


## Area isi sprite (pecahan `inner`) dalam koordinat layar.
func _inr(sprite_rect: Rect2, key: String) -> Rect2:
	var f: Rect2 = scene["hud"]["inner"][key]
	return Rect2(sprite_rect.position + f.position * sprite_rect.size, f.size * sprite_rect.size)


## Susun HUD secara responsif. Kelompok kiri menempel ke tepi kiri area aman, kelompok kanan
## ke tepi kanan. Bila lebar sempit (16:9) HUD diperkecil (faktor f <= 1) agar tidak menabrak
## emblem tengah-atas; makin lebar layar, HUD makin menjauh ke tepi dan kembali ke ukuran penuh.
func _compute_hud() -> void:
	var hud: Dictionary = scene["hud"]
	var k: float = scale_f
	var img: Vector2 = scene["size"]
	var banner: Vector2 = hud["banner"]
	var m: float = float(hud["margin"])
	var gap: float = float(hud["gap"])
	var cl: Vector2 = _sprite_size("cluster")
	var pl: Vector2 = _sprite_size("pill")
	var pg: Vector2 = _sprite_size("pillgear")
	var tl: Vector2 = _sprite_size("tile")
	var pn: Vector2 = _sprite_size("panel")
	var l_ext: float = m + _sprite_size("cluster").x + gap + _sprite_size("pill").x + gap + _sprite_size("pill").x
	var r_ext: float = m + _sprite_size("pillgear").x + gap + _sprite_size("pill").x
	var lo: float = maxf(offset.x + hud_shift.x, hud_safe.position.x)                       # tepi kiri HUD (layar)
	var ro: float = minf(offset.x + img.x * k + hud_shift.y, hud_safe.end.x)                # tepi kanan HUD (layar)
	var bl: float = offset.x + banner.x * k
	var br: float = offset.x + banner.y * k
	var f: float = minf(1.0, minf((bl - lo - 8.0) / (l_ext * k), (ro - br - 8.0) / (r_ext * k)))
	f = maxf(f, 0.6)
	var u: float = k * f
	hud_u = u
	var y0: float = maxf(offset.y, hud_safe.position.y)
	hud_r.clear()
	hud_r["cluster"] = Rect2(Vector2(lo + m * u, y0 + 8.0 * u), cl * u)
	var pill_y: float = y0 + (8.0 + cl.y * 0.5 - pl.y * 0.5 - 16.0) * u
	hud_r["pill0"] = Rect2(Vector2(lo + (m + cl.x + gap) * u, pill_y), pl * u)
	hud_r["pill1"] = Rect2(Vector2(lo + (m + cl.x + gap + pl.x + gap) * u, pill_y), pl * u)
	var tx: float = m + cl.x * 0.169 - tl.x * 0.5 + 4.0
	hud_r["tile0"] = Rect2(Vector2(lo + tx * u, y0 + (8.0 + cl.y + 14.0) * u), tl * u)
	hud_r["tile1"] = Rect2(Vector2(lo + tx * u, y0 + (8.0 + cl.y + 14.0 + tl.y + 10.0) * u), tl * u)
	hud_r["pillgear"] = Rect2(Vector2(ro - (m + pg.x) * u, y0 + 8.0 * u), pg * u)
	hud_r["pill2"] = Rect2(Vector2(ro - (m + pg.x + gap + pl.x) * u, y0 + (8.0 + pg.y * 0.5 - pl.y * 0.5) * u), pl * u)
	hud_r["panel"] = Rect2(Vector2(ro - (m + pn.x) * u, y0 + (8.0 + pg.y + 12.0) * u), pn * u)
	# area ketuk (minimal 44 px, diperluas dari tengah bila lebih kecil)
	hud_hot.clear()
	hud_hot["gear"] = _min_touch(_inr(hud_r["pillgear"], "pillgear_ring"))
	hud_hot["tile0"] = _min_touch(hud_r["tile0"])
	hud_hot["tile1"] = _min_touch(hud_r["tile1"])


func _min_touch(r: Rect2) -> Rect2:
	var c: Vector2 = r.get_center()
	var sz := Vector2(maxf(r.size.x, 44.0), maxf(r.size.y, 44.0))
	return Rect2(c - sz * 0.5, sz)


## Inset area aman (notch/lekuk layar) dalam satuan piksel viewport game: [kiri, atas, kanan, bawah].
func _safe_insets() -> Vector4:
	var win: Vector2 = Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		return Vector4.ZERO
	var sa: Rect2i = DisplayServer.get_display_safe_area()
	var scr: Vector2i = DisplayServer.screen_get_size()
	if sa.size.x <= 0 or scr.x <= 0:
		return Vector4.ZERO
	var f: float = size.x / win.x
	var l: float = maxf(0.0, float(sa.position.x)) * f
	var r: float = maxf(0.0, float(scr.x - sa.position.x - sa.size.x)) * f
	var tp: float = maxf(0.0, float(sa.position.y)) * f
	var bt: float = maxf(0.0, float(scr.y - sa.position.y - sa.size.y)) * f
	return Vector4(l, tp, r, bt)


## Tata letak responsif (landscape 16:9 s.d. 20:9 dan lebih lebar):
## skala ditentukan tinggi layar, sehingga seluruh area inti (termasuk HUD yang menyatu
## dengan gambar) selalu terlihat utuh dan proporsi aset tidak berubah. Lebar ekstra
## diisi perluasan latar (pad); ukuran aset TIDAK diregangkan. Bila area aman layar
## (notch) lebih sempit daripada area inti, skala diturunkan agar HUD tetap di dalamnya.
func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var img: Vector2 = scene["size"]
	var pad_x: float = float(scene.get("pad", 0.0))
	var ins: Vector4 = safe_insets_override if safe_insets_override.x >= 0.0 else _safe_insets()
	var safe := Rect2(Vector2(ins.x, ins.y), size - Vector2(ins.x + ins.z, ins.y + ins.w))
	if bool(scene.get("cover", false)):
		# latar lebar: memenuhi layar; hanya potongan kecil di tepi (kiri-kanan) atau atap/lantai
		var s_cover: float = maxf(size.x / img.x, size.y / img.y)
		var s_max: float = size.y / (img.y - CROP_TOP_MAX)
		scale_f = minf(s_cover, maxf(s_max, size.y / img.y))
		offset.x = (size.x - img.x * scale_f) * 0.5
		offset.y = (size.y - img.y * scale_f) * 0.5
		hud_shift = Vector2.ZERO
	else:
		scale_f = minf(safe.size.x / img.x, safe.size.y / img.y)
		offset = safe.position + (safe.size - img * scale_f) * 0.5
		hud_shift = Vector2(-maxf(0.0, offset.x - safe.position.x), maxf(0.0, safe.end.x - (offset.x + img.x * scale_f)))
	bg.position = offset - Vector2(pad_x, 0.0) * scale_f
	hud_safe = safe
	if not hud_tex.is_empty():
		_compute_hud()
	bg.size = Vector2(img.x + 2.0 * pad_x, img.y) * scale_f
	cust_fx.position = Vector2.ZERO
	cust_fx.size = size
	counter.position = offset
	counter.scale = Vector2(scale_f, scale_f)
	fx.position = Vector2.ZERO
	fx.size = size
	for h in hotspots:
		var r: Rect2 = h["rect"]
		var b: Button = h["btn"]
		var hk: String = String(h.get("hud_key", ""))
		if hk != "" and hud_hot.has(hk):
			b.position = hud_hot[hk].position
			b.size = hud_hot[hk].size
		elif hk == "":
			b.position = _m(r.position)
			b.size = r.size * scale_f
	var u: float = size.y / 720.0
	toast_label.size = Vector2(size.x, 40.0 * u)
	toast_label.position = Vector2(0, _m(Vector2(0, float(scene.get("toast_y", TOAST_Y)))).y - toast_label.size.y * 0.5)
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
						slot["ring"] = 0.0
						_ding()
				"ready":
					if slot.has("ring"):
						slot["ring"] = float(slot["ring"]) + delta
						if float(slot["ring"]) > DING_SHAKE:
							slot.erase("ring")
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
	_draw_hud_frames(s)
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
	_draw_timers(s)
	for k in customer_panels.size():
		for c in customers:
			if c["slot"] == k:
				_draw_bubble(c, customer_panels[k]["spot"], s)
	_draw_hud(s)


## Timer memasak: jam alarm di kanan-atas alat. Cincin terisi searah jarum jam (hijau -> kuning -> merah).
## Saat matang jam goyang sekali searah irama "ting" (amplitudo meredam), lalu memudar.
func _draw_timers(s: float) -> void:
	var asz: Vector2 = alarm_tex.get_size()
	var h: float = ALARM_H * s
	var w: float = h * asz.x / asz.y
	for kind in appliances:
		if kind == "dispenser":
			continue
		for slot in appliances[kind]:
			var st: String = slot["state"]
			var p := 0.0
			var rot := 0.0
			var alpha := 1.0
			if st == "cooking":
				p = clampf(float(slot["t"]) / maxf(float(slot["dur"]), 0.01), 0.0, 1.0)
			elif st == "ready" and slot.has("ring"):
				var t: float = float(slot["ring"])
				p = 1.0
				rot = sin(t * TAU * 7.0) * deg_to_rad(20.0) * exp(-t * 4.5)   # goyang cepat, meredam bersama ting
				alpha = clampf((DING_SHAKE - t) / 0.25, 0.0, 1.0)
			else:
				continue
			var base: Vector2 = slot["pos"]
			var r: float = float(slot["r"])
			var c: Vector2 = _m(base + Vector2(r * 0.85, -r * 0.5))
			fx.draw_set_transform(c, rot, Vector2.ONE)
			var rect := Rect2(Vector2(-w, -h) * 0.5, Vector2(w, h))
			fx.draw_texture_rect(alarm_tex, rect, false, Color(1, 1, 1, alpha))
			var step: int = clampi(int(ceil(p * ALARM_STEPS)) - 1, 0, ALARM_STEPS - 1)
			var src := Rect2(Vector2(step % 8, step / 8) * asz, asz)
			var col: Color = Color(0.35, 0.85, 0.3).lerp(Color(1.0, 0.85, 0.2), smoothstep(0.0, 0.6, p))
			col = col.lerp(Color(1.0, 0.3, 0.2), smoothstep(0.6, 1.0, p))
			col.a = alpha
			if p > 0.0:
				fx.draw_texture_rect_region(alarm_ring_tex, rect, src, col)
			fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Teks HUD di atas bingkai kosong pada latar. Hanya data yang benar-benar ada di game.
func _text_at(pos: Vector2, txt: String, fs: int, col: Color, align: int = 0) -> void:
	# align: 0 kiri, 1 tengah, 2 kanan; pos = titik awal/tengah/akhir teks (layar)
	var ts: Vector2 = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var x: float = pos.x - (0.0 if align == 0 else (ts.x * 0.5 if align == 1 else ts.x))
	var p := Vector2(x, pos.y + fs * 0.35)
	fx.draw_string_outline(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, int(fs * 0.18)), Color(0.1, 0.04, 0.02))
	fx.draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _frame_box(fill: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


func _draw_hud_frames(_s: float) -> void:
	for nm in ["cluster", "pill0", "pill1", "pill2", "pillgear", "tile0", "tile1", "panel"]:
		var key: String = nm.trim_suffix("0").trim_suffix("1").trim_suffix("2")
		fx.draw_texture_rect(hud_tex[key], hud_r[nm], false)


func _draw_hud(_s: float) -> void:
	var u: float = hud_u
	var gold := Color(1, 0.88, 0.45)
	var target: int = int(params["target"])
	var t: int = int(ceil(time_left))
	# lencana: nomor level; strip atas: nama area; strip bawah: bar target + angka
	var cr: Rect2 = hud_r["cluster"]
	_text_at(_inr(cr, "cluster_circle").get_center(), str(level + 1), int(44.0 * u), Color.WHITE, 1)
	var s1: Rect2 = _inr(cr, "cluster_s1")
	_text_at(s1.get_center(), String(area["name"]).split(" ")[-1], int(19.0 * u), gold, 1)
	var s2: Rect2 = _inr(cr, "cluster_s2")
	var frac: float = clampf(float(earned) / maxf(float(target), 1.0), 0.0, 1.0)
	if frac > 0.0:
		var bar := Rect2(s2.position + Vector2(2, 2), Vector2(maxf((s2.size.x - 4.0) * frac, s2.size.y * 0.6), s2.size.y - 4.0))
		fx.draw_style_box(_frame_box(Color(0.35, 0.82, 0.3), int(bar.size.y * 0.5)), bar)
	_text_at(s2.get_center(), "%d/%d" % [earned, target], int(16.0 * u), Color.WHITE, 1)
	# pil: label kiri + nilai kanan di area isi
	var rows := [
		["pill0", "pill", "Waktu", "%d:%02d" % [t / 60, t % 60]],
		["pill1", "pill", "Target", str(target)],
		["pill2", "pill", "Hasil", str(earned)],
		["pillgear", "pillgear_bar", "Koin", str(GameState.coins)],
	]
	for rw in rows:
		var ir: Rect2 = _inr(hud_r[rw[0]], rw[1])
		_text_at(Vector2(ir.position.x + ir.size.x * 0.04, ir.get_center().y), rw[2], int(15.0 * u), Color(0.95, 0.75, 0.45), 0)
		_text_at(Vector2(ir.end.x - ir.size.x * 0.04, ir.get_center().y), rw[3], int(21.0 * u), Color.WHITE, 2)
	# tombol jeda di cincin pillgear
	var ring: Rect2 = _inr(hud_r["pillgear"], "pillgear_ring")
	var rc: Vector2 = ring.get_center()
	for dx in [-0.17, 0.17]:
		fx.draw_rect(Rect2(rc + Vector2(dx * ring.size.x - 4.0 * u, -12.0 * u), Vector2(8.0 * u, 24.0 * u)), Color(1, 0.93, 0.7))
	# kotak samping
	var names := ["Misi", "Toko"]
	for i in 2:
		_text_at(_inr(hud_r["tile%d" % i], "tile").get_center(), names[i], int(21.0 * u), gold, 1)
	# panel menu: daftar hidangan level ini
	var pr: Rect2 = hud_r["panel"]
	_text_at(_inr(pr, "panel_head").get_center(), "Menu Level", int(22.0 * u), gold, 1)
	var pb: Rect2 = _inr(pr, "panel_body")
	var n: int = mini(dishes.size(), 5)
	var row_h: float = pb.size.y / 5.0
	for kk in n:
		var id: String = dishes[kk]
		var cy: float = pb.position.y + row_h * (kk + 0.5)
		var d: Dictionary = GameData.DISHES[id]
		var isz: float = minf(row_h * 0.85, 24.0 * u)
		if icon_tex.has(id):
			fx.draw_texture_rect(icon_tex[id], Rect2(Vector2(pb.position.x + 6.0 * u, cy - isz * 0.5), Vector2(isz, isz)), false)
		_text_at(Vector2(pb.position.x + 8.0 * u + isz, cy), String(d["name"]), int(15.0 * u), Color(0.28, 0.12, 0.05), 0)
		_text_at(Vector2(pb.end.x - 8.0 * u, cy), str(int(d["price"])), int(15.0 * u), Color(0.55, 0.25, 0.05), 2)


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
		var lh: float = 26.0 * s   # ukuran seragam di semua alat
		var lw: float = lh * lock_tex.get_size().x / lock_tex.get_size().y
		fx.draw_texture_rect(lock_tex, Rect2(c - Vector2(lw, lh) * 0.5, Vector2(lw, lh)), false)
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
	var rk: float = float(scene.get("rect_k", {}).get(slot["kind"], 1.0))
	if rk != 1.0:
		rc = Rect2(rc.position * rk, rc.size * rk)
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
	var uk: float = float(scene.get("ui_k", 1.0))
	var bw: float = 96.0 * uk
	var bh: float = bw * 480.0 / 296.0   # rasio gambar bingkai
	var img_w: float = scene["size"].x
	var bx: float = spot.x + 92.0 * uk
	if bx + bw > img_w - 2.0:
		bx = spot.x - 92.0 * uk - bw
	var btop: Vector2 = Vector2(bx, spot.y - 184.0 * uk)  # di bawah panel waktu
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
	var icon: float = 52.0 * uk
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
