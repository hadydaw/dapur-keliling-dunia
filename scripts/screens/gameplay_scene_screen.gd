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
var burn_player: AudioStreamPlayer   # bunyi gosong (beda dari "ting")
var burn_count: int = 0
var pour_players: Array = []         # suara menuang es teh ke gelas (satu pemain per gelas)
var pour_count: int = 0
var fill_player: AudioStreamPlayer   # suara es + air mengisi dispenser
var fill_count: int = 0
var sizzle_players: Array = []       # desis sate di panggangan (satu pemain per slot)
var sizzle_count: int = 0
const SIZZLE_LENGTH := 6.0    # panjang sate_desis.wav (detik)
var stirfry_players: Array = []      # suara nasi goreng di wajan (satu pemain per slot)
var stirfry_count: int = 0
const STIRFRY_LENGTH := 5.0   # panjang nasi_goreng_wajan.wav (detik)
var fish_players: Array = []         # desis ikan bakar di panggangan (satu pemain per slot)
var fish_count: int = 0
const FISH_LENGTH := 7.0      # panjang ikan_bakar.wav (detik)
var soup_players: Array = []         # kuah soto mendidih di panci (satu pemain per slot)
var soup_count: int = 0
const SOUP_LENGTH := 8.0      # panjang soto_mendidih.wav (detik)
var serve_players: Array = []        # bunyi piring/mangkuk diletakkan ke pelanggan (bergantian)
var serve_count: int = 0
var _serve_next: int = 0
const FILL_LENGTH := 3.0      # panjang isi_dispenser.wav (detik)
const POUR_LENGTH := 2.6      # panjang tuang_es.wav (detik)
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
var ing_tap: Dictionary = {}        # id bahan -> detik sejak diketuk (efek ketuk 0..ING_TAP_LEN)
const ING_TAP_LEN := 0.5
var flame_fx: Control               # api kompor (di atas latar, di bawah wadah masakan)
var coal_heat: Array = []           # kekuatan bara tiap petak panggangan 0..1
var burner_heat: Array = []         # kekuatan api tiap tungku 0..1 (halus mengikuti keadaan)
const HEAT_IDLE := 0.28             # api kecil saat kompor menganggur
const HEAT_RISE := 5.0              # kecepatan api membesar/mengecil
const ALARM_H := 36.0        # tinggi ikon timer (piksel inti)
const FIRE_H := 18.0         # tinggi maksimum api (lebih kecil dari gembok)
const ALARM_STEPS := 64
const DING_SHAKE := 0.8      # lama goyang + memudar setelah "ting" (detik); ting.wav = 1.1 dtk
const BUBBLE_WINDOW := 2   # ikon yang terlihat sekaligus di gelembung; sisanya tergulir naik
var jar: Dictionary = {"state": "empty", "t": 0.0, "dur": 0.0, "uses": 0}
var jar_tex: Texture2D
var alarm_tex: Texture2D             # ikon jam alarm timer memasak
var fire_tex: Texture2D              # api: fase "akan gosong" dan gosong
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
	fire_tex = load("res://assets/ui/api.png")
	ting_player = AudioStreamPlayer.new()
	ting_player.stream = load("res://assets/audio/ting.wav")
	ting_player.volume_db = -4.0
	add_child(ting_player)
	for i in 3:
		var pp := AudioStreamPlayer.new()
		pp.stream = load("res://assets/audio/tuang_es.wav")
		pp.volume_db = -5.0
		add_child(pp)
		pour_players.append(pp)
	for i in 6:
		var sp := AudioStreamPlayer.new()
		sp.stream = load("res://assets/audio/sate_desis.wav")
		sp.volume_db = -6.0
		add_child(sp)
		sizzle_players.append(sp)
	for i in 4:
		var wp := AudioStreamPlayer.new()
		wp.stream = load("res://assets/audio/nasi_goreng_wajan.wav")
		wp.volume_db = -6.0
		add_child(wp)
		stirfry_players.append(wp)
	for i in 6:
		var fp := AudioStreamPlayer.new()
		fp.stream = load("res://assets/audio/ikan_bakar.wav")
		fp.volume_db = -6.0
		add_child(fp)
		fish_players.append(fp)
	for i in 4:
		var cp := AudioStreamPlayer.new()
		cp.stream = load("res://assets/audio/soto_mendidih.wav")
		cp.volume_db = -6.0
		add_child(cp)
		soup_players.append(cp)
	for i in 3:
		var vp := AudioStreamPlayer.new()
		vp.stream = load("res://assets/audio/sajikan_piring.wav")
		vp.volume_db = -4.0
		add_child(vp)
		serve_players.append(vp)
	fill_player = AudioStreamPlayer.new()
	fill_player.stream = load("res://assets/audio/isi_dispenser.wav")
	fill_player.volume_db = -4.0
	add_child(fill_player)
	burn_player = AudioStreamPlayer.new()
	burn_player.stream = load("res://assets/audio/gosong.wav")
	burn_player.volume_db = -3.0
	add_child(burn_player)
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
	flame_fx = Control.new()
	flame_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flame_fx.draw.connect(_on_flame_draw)
	add_child(flame_fx)
	for b in scene.get("burners", []):
		burner_heat.append(HEAT_IDLE)
	if scene.has("coals"):
		for i in scene["appliances"][scene["coals"]["kind"]]["points"].size():
			coal_heat.append(HEAT_IDLE)
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
	flame_fx.queue_redraw()
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
	slot.erase("ring")
	slot.erase("bring")


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
	ing_tap[id] = 0.0
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
	if dish == "sate_ayam":
		_sizzle_sound(int(slot["idx"]), float(slot["dur"]))
	elif dish == "nasi_goreng":
		_stirfry_sound(int(slot["idx"]), float(slot["dur"]))
	elif dish == "ikan_bakar":
		_fish_sound(int(slot["idx"]), float(slot["dur"]))
	elif dish == "soto_ayam":
		_soup_sound(int(slot["idx"]), float(slot["dur"]))


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
			fill_count += 1
			fill_player.pitch_scale = clampf(FILL_LENGTH / maxf(float(jar["dur"]), 0.1), 0.7, 1.6)
			fill_player.play()


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
			_pour_sound(int(slot["idx"]), float(slot["dur"]))
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
	var kind: String = slot["kind"]
	if _serve(slot["dish"]):
		if kind == "plate" or kind == "bowl":
			_serve_sound()
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
	_step_burners(delta)
	for id in ing_tap.keys():
		ing_tap[id] = float(ing_tap[id]) + delta
		if float(ing_tap[id]) > ING_TAP_LEN:
			ing_tap.erase(id)
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
							slot.erase("ring")
							slot["bring"] = 0.0
							_burn_sound()
				"burnt":
					if slot.has("bring"):
						slot["bring"] = float(slot["bring"]) + delta
						if float(slot["bring"]) > DING_SHAKE:
							slot.erase("bring")


## Suara menuang es teh ke gelas; kecepatan diatur agar panjangnya sama dengan waktu isi gelas.
func _pour_sound(idx: int, dur: float) -> void:
	pour_count += 1
	var pp: AudioStreamPlayer = pour_players[clampi(idx, 0, pour_players.size() - 1)]
	pp.pitch_scale = clampf(POUR_LENGTH / maxf(dur, 0.1), 0.7, 1.6)
	pp.play()


## Desis sate di panggangan; panjangnya disesuaikan dengan waktu masak.
func _sizzle_sound(idx: int, dur: float) -> void:
	sizzle_count += 1
	var sp: AudioStreamPlayer = sizzle_players[clampi(idx, 0, sizzle_players.size() - 1)]
	sp.pitch_scale = clampf(SIZZLE_LENGTH / maxf(dur, 0.1), 0.7, 1.6)
	sp.play()


## Suara nasi goreng ditumis di wajan; panjangnya disesuaikan dengan waktu masak.
func _stirfry_sound(idx: int, dur: float) -> void:
	stirfry_count += 1
	var wp: AudioStreamPlayer = stirfry_players[clampi(idx, 0, stirfry_players.size() - 1)]
	wp.pitch_scale = clampf(STIRFRY_LENGTH / maxf(dur, 0.1), 0.7, 1.6)
	wp.play()


## Suara ikan dibakar di panggangan; panjangnya disesuaikan dengan waktu masak.
func _fish_sound(idx: int, dur: float) -> void:
	fish_count += 1
	var fp: AudioStreamPlayer = fish_players[clampi(idx, 0, fish_players.size() - 1)]
	fp.pitch_scale = clampf(FISH_LENGTH / maxf(dur, 0.1), 0.7, 1.6)
	fp.play()


## Suara kuah soto mendidih di panci; panjangnya disesuaikan dengan waktu masak.
func _soup_sound(idx: int, dur: float) -> void:
	soup_count += 1
	var cp: AudioStreamPlayer = soup_players[clampi(idx, 0, soup_players.size() - 1)]
	cp.pitch_scale = clampf(SOUP_LENGTH / maxf(dur, 0.1), 0.7, 1.6)
	cp.play()


## Bunyi piring/mangkuk diletakkan di depan pelanggan (3 pemain bergantian agar bisa tumpang tindih).
func _serve_sound() -> void:
	serve_count += 1
	var vp: AudioStreamPlayer = serve_players[_serve_next]
	_serve_next = (_serve_next + 1) % serve_players.size()
	vp.play()


func _burn_sound() -> void:
	burn_count += 1
	burn_player.play()


func _ding() -> void:
	ting_count += 1
	ting_player.play()


func _refresh_ui() -> void:
	coins_label.text = "%d / %d" % [earned, int(params["target"])]
	goal_bar.value = minf(float(earned), goal_bar.max_value)
	var t: int = int(ceil(time_left))
	time_label.text = "%d:%02d" % [t / 60, t % 60]
	fx.queue_redraw()
	flame_fx.queue_redraw()
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


## Target api sebuah tungku: 1 bila ada masakan di slot yang terhubung (memasak/matang/gosong), selain itu api kecil.
func _burner_target(b: Dictionary) -> float:
	for lk in b["links"]:
		var slot: Dictionary = appliances[lk[0]][int(lk[1])]
		var st: String = slot["state"]
		if st == "cooking" or st == "ready" or st == "burnt":
			return 1.0
	return HEAT_IDLE


func _step_burners(delta: float) -> void:
	if scene.has("coals"):
		var slots: Array = appliances[scene["coals"]["kind"]]
		for i in coal_heat.size():
			var st: String = slots[i]["state"]
			var tgt: float = 1.0 if (st == "cooking" or st == "ready" or st == "burnt") else HEAT_IDLE
			coal_heat[i] = move_toward(float(coal_heat[i]), tgt, delta * HEAT_RISE)
	var bl: Array = scene.get("burners", [])
	for i in bl.size():
		burner_heat[i] = move_toward(float(burner_heat[i]), _burner_target(bl[i]), delta * HEAT_RISE)


func _on_flame_draw() -> void:
	if scale_f <= 0.0:
		return
	if scene.has("coals"):
		var cd: Dictionary = scene["coals"]
		var slots: Array = appliances[cd["kind"]]
		for i in coal_heat.size():
			if not _cell_active(slots[i]):
				_draw_coals(flame_fx, _m(slots[i]["pos"]), Vector2(cd["size"]) * scale_f, float(coal_heat[i]), float(i) * 2.3, false)
	if not scene.has("burners"):
		return
	var bl: Array = scene["burners"]
	for i in bl.size():
		var b: Dictionary = bl[i]
		_draw_flame(_m(b["pos"]), float(b["w"]) * scale_f, float(burner_heat[i]), float(i) * 1.7)


## Api kompor prosedural: cincin biru di dasar + lidah api oranye/kuning/putih yang meliuk.
## heat 0..1 mengatur tinggi dan terang; ph = fase agar tiap tungku bergoyang berbeda.
func _draw_flame(c: Vector2, w: float, heat: float, ph: float) -> void:
	var t: float = pulse
	# pendar hangat di sekitar tungku
	var glow_a: float = (0.10 + 0.14 * heat) * (0.85 + 0.15 * sin(t * 9.0 + ph))
	fx_ellipse(flame_fx, c + Vector2(0, -w * 0.12), Vector2(w * 0.62, w * 0.34), Color(1.0, 0.55, 0.15, glow_a))
	# cincin biru
	var ring_a: float = 0.55 + 0.35 * heat
	var pts := PackedVector2Array()
	for k in 25:
		var a: float = float(k) / 24.0 * TAU
		pts.append(c + Vector2(cos(a) * w * 0.40, sin(a) * w * 0.11) * (1.0 + 0.04 * sin(t * 14.0 + k * 1.3 + ph)))
	flame_fx.draw_polyline(pts, Color(0.35, 0.65, 1.0, ring_a), maxf(2.0, w * 0.045))
	# lidah api (belakang dulu, depan terakhir)
	var n := 7
	for k in n:
		var u: float = float(k) / float(n - 1)
		var xo: float = lerpf(-0.36, 0.36, u) * w
		var depth: float = absf(u - 0.5) * 2.0          # tepi lebih pendek dari tengah
		var fl: float = 0.80 + 0.20 * sin(t * (8.0 + k * 1.9) + ph + k * 2.1) + 0.10 * sin(t * 19.0 + k * 3.7 + ph)
		var hgt: float = w * (0.10 + 0.40 * heat) * (1.0 - 0.35 * depth) * fl
		var sway: float = sin(t * (5.0 + k * 0.8) + ph + k) * w * 0.045
		var base := c + Vector2(xo, w * 0.05 * (1.0 - depth) - w * 0.02)
		var hw: float = w * (0.080 + 0.040 * heat)
		_flame_tongue(base, hw, hgt, sway, Color(1.0, 0.42, 0.08, 0.80 * (0.55 + 0.45 * heat)))
		_flame_tongue(base, hw * 0.62, hgt * 0.72, sway * 0.8, Color(1.0, 0.80, 0.25, 0.90 * (0.55 + 0.45 * heat)))
		_flame_tongue(base, hw * 0.30, hgt * 0.40, sway * 0.5, Color(1.0, 0.97, 0.75, 0.90 * heat))


## Letupan minyak hanya untuk sate dan ikan yang sedang dibakar di panggangan.
func _oil_enabled(slot: Dictionary) -> bool:
	return slot["kind"] == "grill" and slot["state"] == "cooking" and (slot["dish"] == "sate_ayam" or slot["dish"] == "ikan_bakar")


## Letupan minyak saat memasak: kilatan kecil di permukaan masakan lalu beberapa tetes minyak keemasan
## terlempar naik dan jatuh (parabola). Ikan lebih berminyak: lebih banyak dan lebih besar.
func _draw_oil_pops(s: float) -> void:
	if not scene.has("coals"):
		return
	var cd: Dictionary = scene["coals"]
	var sz: Vector2 = Vector2(cd["size"]) * s
	for slot in appliances[cd["kind"]]:
		if _oil_enabled(slot):
			var fish: bool = slot["dish"] == "ikan_bakar"
			_oil_pops(fx, _m(slot["pos"]), sz, float(slot["idx"]) * 2.9, 7 if fish else 5, 1.25 if fish else 1.0)


static func _hash01(x: float) -> float:
	return fposmod(sin(x) * 43758.5453, 1.0)


func _oil_pops(node: Control, c: Vector2, sz: Vector2, ph: float, n: int, big: float) -> void:
	for k in n:
		var period: float = 0.75 + 0.21 * k
		var local: float = pulse + ph * 0.37 + k * 0.61
		var cyc: float = floor(local / period)
		var tt: float = local - cyc * period
		var r1: float = _hash01(cyc * 12.9898 + k * 78.233 + ph * 3.1)
		var r2: float = _hash01(cyc * 39.346 + k * 11.135 + ph)
		var origin: Vector2 = c + Vector2(lerpf(-0.34, 0.34, r1) * sz.x, lerpf(-0.30, 0.12, r2) * sz.y)
		if tt < 0.14:
			var f: float = tt / 0.14
			node.draw_arc(origin, sz.x * (0.02 + 0.08 * f) * big, 0.0, TAU, 12, Color(1.0, 0.95, 0.65, (1.0 - f) * 0.9), maxf(1.2, sz.x * 0.016))
			node.draw_circle(origin, sz.x * 0.03 * big * (1.0 - f), Color(1.0, 1.0, 0.85, 1.0 - f))
		if tt < 0.7:
			var life: float = tt / 0.7
			for d in 3:
				var ang: float = -PI * 0.5 + (r1 + d * 0.37 - 0.5) * 1.9
				var v: float = sz.y * (1.7 + 0.8 * _hash01(r2 * 7.0 + d)) * big
				var g: float = sz.y * 5.0
				var pos: Vector2 = origin + Vector2(cos(ang) * v * tt * 0.6, sin(ang) * v * tt + 0.5 * g * tt * tt)
				var vel: Vector2 = Vector2(cos(ang) * v * 0.6, sin(ang) * v + g * tt)
				var a: float = 1.0 - life
				node.draw_line(pos, pos - vel.normalized() * sz.x * 0.05, Color(1.0, 0.85, 0.35, a * 0.6), maxf(1.0, sz.x * 0.012))
				node.draw_circle(pos, maxf(1.2, sz.x * 0.028 * big * (1.0 - 0.5 * life)), Color(1.0, 0.9, 0.5, a))


## Animasi memasak di wajan (nasi goreng) dan panci (soto ayam); hanya selama fase memasak.
func _cook_fx_enabled(slot: Dictionary) -> bool:
	if slot["state"] != "cooking":
		return false
	return (slot["kind"] == "wok" and slot["dish"] == "nasi_goreng") or (slot["kind"] == "pot" and slot["dish"] == "soto_ayam")


func _draw_cook_fx(s: float) -> void:
	for kind in ["wok", "pot"]:
		if not appliances.has(kind):
			continue
		for slot in appliances[kind]:
			if not _cook_fx_enabled(slot):
				continue
			var u: float = float(slot["r"]) * s
			var c: Vector2 = _m(slot["pos"])
			var ph: float = float(slot["idx"]) * 3.7 + (0.0 if kind == "wok" else 1.9)
			if kind == "wok":
				_wok_fx(fx, c + Vector2(0, -0.12 * u), u, ph)
			else:
				_pot_fx(fx, c + Vector2(0, -0.22 * u), u, ph)


## Nasi goreng: butir nasi terlempar saat diaduk, percikan minyak kecil, uap tipis.
func _wok_fx(node: Control, c: Vector2, u: float, ph: float) -> void:
	for k in 9:
		var period: float = 0.62 + 0.13 * k
		var local: float = pulse + ph * 0.41 + k * 0.53
		var cyc: float = floor(local / period)
		var tt: float = local - cyc * period
		var r1: float = _hash01(cyc * 17.13 + k * 61.7 + ph * 2.3)
		var r2: float = _hash01(cyc * 29.77 + k * 9.31 + ph)
		var x0: float = lerpf(-0.55, 0.55, r1) * u
		var vy: float = u * (2.4 + 0.8 * r2)
		var g: float = u * 7.0
		var life: float = 2.0 * vy / g
		if tt < life:
			var pos: Vector2 = c + Vector2(x0 + (r2 - 0.5) * u * 0.5 * tt, -(vy * tt - 0.5 * g * tt * tt))
			var col: Color = Color(1.0, 0.93, 0.68)
			if k % 3 == 1:
				col = Color(0.92, 0.62, 0.30)   # nasi yang sudah kecokelatan
			elif k % 4 == 2:
				col = Color(0.45, 0.78, 0.30)   # irisan daun bawang
			node.draw_circle(pos, maxf(1.1, u * 0.055), col)
			node.draw_circle(pos + Vector2(u * 0.02, u * 0.012), maxf(0.8, u * 0.035), Color(col.r * 0.8, col.g * 0.8, col.b * 0.8, 0.9))
	_oil_pops(node, c + Vector2(0, -0.05 * u), Vector2(u * 1.5, u * 0.9), ph, 4, 0.7)
	_steam(node, c + Vector2(0, -0.35 * u), u, ph, 3, 0.55)


## Soto ayam: gelembung kuah muncul lalu pecah di permukaan, percikan kuah, uap lebih tebal.
func _pot_fx(node: Control, c: Vector2, u: float, ph: float) -> void:
	for k in 7:
		var period: float = 0.55 + 0.16 * k
		var local: float = pulse + ph * 0.37 + k * 0.47
		var cyc: float = floor(local / period)
		var tt: float = local - cyc * period
		var r1: float = _hash01(cyc * 23.17 + k * 51.3 + ph * 1.7)
		var r2: float = _hash01(cyc * 37.71 + k * 13.9 + ph)
		var o: Vector2 = c + Vector2(lerpf(-0.55, 0.55, r1) * u, lerpf(-0.16, 0.16, r2) * u * 0.8)
		if tt < 0.5:
			var f: float = tt / 0.5
			if f < 0.55:   # gelembung membesar
				var gr: float = f / 0.55
				node.draw_circle(o, maxf(1.2, u * 0.10 * gr), Color(1.0, 0.96, 0.8, 0.55))
				node.draw_arc(o, maxf(1.5, u * 0.10 * gr), 0.0, TAU, 12, Color(1.0, 1.0, 0.92, 0.9), maxf(1.0, u * 0.025))
			else:          # pecah: cincin melebar dan memudar + tetes kecil
				var pf: float = (f - 0.55) / 0.45
				node.draw_arc(o, u * (0.10 + 0.14 * pf), 0.0, TAU, 14, Color(1.0, 0.98, 0.85, 0.8 * (1.0 - pf)), maxf(1.0, u * 0.022))
				if k % 2 == 0:
					for d in 2:
						var dx: float = (float(d) - 0.5) * u * 0.28 * pf
						node.draw_circle(o + Vector2(dx, -u * 0.30 * sin(PI * pf)), maxf(0.9, u * 0.03), Color(1.0, 0.88, 0.5, 1.0 - pf))
	_steam(node, c + Vector2(0, -0.3 * u), u, ph, 5, 1.0)


## Uap: lingkaran putih transparan yang naik, melebar, bergoyang, lalu memudar.
func _steam(node: Control, c: Vector2, u: float, ph: float, n: int, strength: float) -> void:
	for k in n:
		var tt: float = fmod(pulse * 0.42 + float(k) / float(n) + ph * 0.17, 1.0)
		var bx: float = lerpf(-0.45, 0.45, _hash01(k * 7.7 + ph)) * u
		var p: Vector2 = c + Vector2(bx + sin(tt * 5.0 + k * 1.9 + ph) * 0.16 * u, -tt * 1.5 * u)
		var a: float = sin(PI * tt) * 0.15 * strength
		node.draw_circle(p, u * (0.12 + 0.26 * tt), Color(1.0, 1.0, 1.0, a))
		node.draw_circle(p + Vector2(u * 0.10, -u * 0.06), u * (0.08 + 0.18 * tt), Color(1.0, 1.0, 1.0, a * 0.8))


## Animasi rak bahan (selalu hidup pelan) + efek saat bahan diketuk.
func _draw_ingredient_fx(s: float) -> void:
	if not scene.has("ingredients"):
		return
	var k := 0
	for id in scene["ingredients"]:
		var rc: Rect2 = scene["ingredients"][id]["rect"]
		var r := Rect2(_m(rc.position), rc.size * s)
		var ph: float = float(k) * 1.7
		k += 1
		match id:
			"es":
				_mist(fx, r, ph, 5, Color(0.75, 0.9, 1.0))
				_glints(fx, r, ph, 5, Color(0.85, 0.95, 1.0))
			"nasi":
				_steam(fx, r.position + Vector2(r.size.x * 0.5, r.size.y * 0.30), r.size.y * 0.42, ph, 4, 0.85)
			"tusuk_ayam":
				_sweep(fx, r, ph, 3.2, Color(1.0, 1.0, 1.0))
				_glints(fx, r, ph, 5, Color(1.0, 0.95, 0.9))
			"ayam":
				_sweep(fx, r, ph, 3.8, Color(1.0, 1.0, 0.95))
				_glints(fx, r, ph, 3, Color(1.0, 0.97, 0.9))
			"ikan":
				_sweep(fx, r, ph, 3.0, Color(0.85, 0.95, 1.0))
				_glints(fx, r, ph, 5, Color(0.9, 0.97, 1.0))
				_mist(fx, r, ph, 3, Color(0.8, 0.92, 1.0))
		if ing_tap.has(id):
			_ing_tap_fx(fx, r, float(ing_tap[id]) / ING_TAP_LEN)


## Kabut dingin tipis yang turun pelan dari bagian atas bahan.
func _mist(node: Control, r: Rect2, ph: float, n: int, col: Color) -> void:
	for k in n:
		var tt: float = fmod(pulse * 0.28 + float(k) / float(n) + ph * 0.13, 1.0)
		var x: float = r.position.x + r.size.x * (0.12 + 0.76 * _hash01(k * 5.3 + ph))
		var y: float = r.position.y + r.size.y * (0.02 + 0.55 * tt)
		var rad: float = r.size.y * (0.09 + 0.13 * tt)
		node.draw_circle(Vector2(x + sin(tt * 4.0 + k) * r.size.x * 0.03, y), rad, Color(col.r, col.g, col.b, sin(PI * tt) * 0.13))


## Kilau bintang empat sudut yang berkedip di titik acak pada bahan.
func _glints(node: Control, r: Rect2, ph: float, n: int, col: Color) -> void:
	for k in n:
		var period: float = 1.3 + 0.37 * k
		var local: float = pulse + ph * 0.43 + k * 0.71
		var cyc: float = floor(local / period)
		var tt: float = (local - cyc * period) / 0.55
		if tt >= 1.0:
			continue
		var x: float = r.position.x + r.size.x * (0.12 + 0.76 * _hash01(cyc * 13.7 + k * 41.3 + ph))
		var y: float = r.position.y + r.size.y * (0.20 + 0.60 * _hash01(cyc * 27.1 + k * 17.9 + ph * 2.0))
		var sc: float = sin(PI * tt)
		var l: float = r.size.y * 0.085 * sc
		var w: float = l * 0.22
		var c := Vector2(x, y)
		var a: float = 0.95 * sc
		node.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -l), c + Vector2(w, 0), c + Vector2(0, l), c + Vector2(-w, 0)]), Color(col.r, col.g, col.b, a))
		node.draw_colored_polygon(PackedVector2Array([c + Vector2(-l, 0), c + Vector2(0, -w), c + Vector2(l, 0), c + Vector2(0, w)]), Color(col.r, col.g, col.b, a))


## Pita cahaya miring yang menyapu bahan secara berkala (kesan segar dan mengilap).
func _sweep(node: Control, r: Rect2, ph: float, period: float, col: Color) -> void:
	var prog: float = fmod(pulse / period + ph * 0.19, 1.0) / 0.4
	if prog >= 1.0:
		return
	var cx: float = lerpf(r.position.x - r.size.y * 0.3, r.end.x + r.size.y * 0.3, prog)
	var lean: float = -r.size.y * 0.35
	var rect_poly := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var a: float = sin(PI * prog)
	for band in [[r.size.x * 0.16, 0.07], [r.size.x * 0.06, 0.14]]:
		var bw: float = band[0]
		var y0: float = r.position.y
		var y1: float = r.end.y
		var poly := PackedVector2Array([Vector2(cx - bw, y0), Vector2(cx + bw, y0), Vector2(cx + bw + lean, y1), Vector2(cx - bw + lean, y1)])
		for piece in Geometry2D.intersect_polygons(poly, rect_poly):
			node.draw_colored_polygon(piece, Color(col.r, col.g, col.b, float(band[1]) * a * 1.4))


## Efek ketuk bahan: kilat lembut di seluruh area, cincin melebar, dan percikan keluar.
func _ing_tap_fx(node: Control, r: Rect2, f: float) -> void:
	var c: Vector2 = r.get_center()
	var a: float = 1.0 - f
	var rect_poly := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	node.draw_colored_polygon(rect_poly, Color(1.0, 0.95, 0.7, 0.22 * a))
	node.draw_arc(c, r.size.y * (0.15 + 0.45 * f), 0.0, TAU, 28, Color(1.0, 0.95, 0.7, 0.8 * a), maxf(2.0, r.size.y * 0.035 * a))
	for k in 8:
		var ang: float = float(k) / 8.0 * TAU + 0.4
		var d: float = r.size.y * (0.18 + 0.42 * f)
		node.draw_circle(c + Vector2(cos(ang), sin(ang)) * d, maxf(1.2, r.size.y * 0.035 * a), Color(1.0, 0.9, 0.5, a))


func _cell_active(slot: Dictionary) -> bool:
	var st: String = slot["state"]
	return st == "cooking" or st == "ready" or st == "burnt"


## Bara petak yang sedang dipakai digambar DI ATAS gambar masakan (pendar lembut + percikan), supaya tetap terlihat.
func _draw_coals_over(s: float) -> void:
	if not scene.has("coals"):
		return
	var cd: Dictionary = scene["coals"]
	var slots: Array = appliances[cd["kind"]]
	for i in coal_heat.size():
		if _cell_active(slots[i]):
			_draw_coals(fx, _m(slots[i]["pos"]), Vector2(cd["size"]) * s, float(coal_heat[i]), float(i) * 2.3, true)


## Bara arang di satu petak panggangan: pendar merah-oranye yang berdenyut, titik bara berkedip, dan percikan naik.
## heat 0..1: kecil saat kosong, menyala penuh saat ada masakan. over = digambar di atas masakan (lebih lembut).
func _draw_coals(node: Control, c: Vector2, sz: Vector2, heat: float, ph: float, over: bool) -> void:
	var t: float = pulse
	if over:
		_draw_coals_strip(node, c, sz, heat, ph)
		return
	var glow: float = (0.07 + 0.17 * heat) * (0.8 + 0.2 * sin(t * 3.1 + ph) + 0.08 * sin(t * 7.3 + ph * 2.0))
	fx_ellipse(node, c, sz * Vector2(0.46, 0.40), Color(1.0, 0.30, 0.05, glow))
	# titik bara: posisi tetap per petak, berkedip sendiri-sendiri
	for k in 6:
		var rx: float = sin(ph * 1.7 + k * 2.399) * 0.36
		var ry: float = sin(ph * 2.3 + k * 1.618 + 1.0) * 0.28
		var pls: float = 0.5 + 0.5 * sin(t * (1.6 + k * 0.7) + ph + k * 2.0)
		pls *= pls
		var a: float = pls * (0.22 + 0.48 * heat)
		var col: Color = Color(1.0, 0.25, 0.05, a).lerp(Color(1.0, 0.75, 0.2, a), pls * heat)
		fx_ellipse(node, c + Vector2(rx * sz.x, ry * sz.y), Vector2(sz.x * 0.085, sz.y * 0.10) * (0.8 + 0.4 * pls), col)
	_draw_sparks(node, c, sz, heat, ph, -0.10, 0.55)


## Petak yang sedang memasak: gambar masakan menutupi arang, jadi hanya jalur bara di bawah masakan yang
## dikedipkan (titik-titik oranye/kuning) ditambah percikan yang naik di atas masakan.
func _draw_coals_strip(node: Control, c: Vector2, sz: Vector2, heat: float, ph: float) -> void:
	var t: float = pulse
	var n := 9
	for k in n:
		var u: float = float(k) / float(n - 1)
		var x: float = lerpf(-0.40, 0.40, u) + 0.03 * sin(ph + k * 1.9)
		var y: float = 0.48 + 0.05 * sin(ph * 2.0 + k * 1.3)
		var pls: float = 0.5 + 0.5 * sin(t * (2.2 + k * 0.9) + ph + k * 2.4)
		pls *= pls
		var a: float = pls * (0.55 + 0.40 * heat)
		var col: Color = Color(1.0, 0.35, 0.05, a).lerp(Color(1.0, 0.95, 0.55, a), pls)
		fx_ellipse(node, c + Vector2(x * sz.x, y * sz.y), Vector2(sz.x * 0.040, sz.y * 0.045) * (0.7 + 0.6 * pls), col)
	_draw_sparks(node, c, sz, heat, ph, 0.46, -0.05)


## Percikan bara naik dari y0 ke y1 (pecahan tinggi petak dari pusat); makin banyak saat panas.
func _draw_sparks(node: Control, c: Vector2, sz: Vector2, heat: float, ph: float, y0: float, y1: float) -> void:
	var n: int = 1 + int(round(3.0 * heat))
	for k in n:
		var tt: float = fmod(pulse * 0.7 + k * 0.37 + ph * 0.11, 1.4) / 1.4
		var sx: float = sin(ph * 3.1 + k * 4.2) * 0.30 * sz.x + sin(tt * 7.0 + k) * sz.x * 0.04
		var p := c + Vector2(sx, lerpf(y0, y1, tt) * sz.y)
		node.draw_circle(p, maxf(0.8, sz.x * 0.022 * (1.0 - 0.6 * tt)), Color(1.0, 0.72, 0.22, (1.0 - tt) * (0.45 + 0.45 * heat)))


func _flame_tongue(base: Vector2, hw: float, h: float, sway: float, col: Color) -> void:
	if h < 1.0:
		return
	var pts := PackedVector2Array()
	var steps := 8
	for k in range(steps + 1):
		var u: float = float(k) / float(steps)
		pts.append(base + Vector2(-hw * sin(PI * pow(u, 0.7)) * (1.0 - 0.55 * u) + sway * u * u, -h * u))
	for k in range(steps - 1, 0, -1):
		var u: float = float(k) / float(steps)
		pts.append(base + Vector2(hw * sin(PI * pow(u, 0.7)) * (1.0 - 0.55 * u) + sway * u * u, -h * u))
	flame_fx.draw_colored_polygon(pts, col)


func fx_ellipse(node: Control, c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		var a: float = float(k) / 24.0 * TAU
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	node.draw_colored_polygon(pts, col)


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
	_draw_coals_over(s)
	_draw_oil_pops(s)
	_draw_cook_fx(s)
	_draw_ingredient_fx(s)
	_draw_timers(s)
	for k in customer_panels.size():
		for c in customers:
			if c["slot"] == k:
				_draw_bubble(c, customer_panels[k]["spot"], s)
	_draw_hud(s)


## Timer memasak: jam alarm di kanan-atas alat. Cincin terisi searah jarum jam (hijau -> kuning -> merah).
## Saat matang jam goyang sekali searah irama "ting" (amplitudo meredam), lalu diganti api yang
## makin besar mendekati gosong; saat gosong api menyala penuh sampai masakan dibuang.
func _draw_timers(s: float) -> void:
	var asz: Vector2 = alarm_tex.get_size()
	var h: float = ALARM_H * s
	var w: float = h * asz.x / asz.y
	for kind in appliances:
		if kind == "dispenser":
			continue
		for slot in appliances[kind]:
			var st: String = slot["state"]
			var base: Vector2 = slot["pos"]
			var r: float = float(slot["r"])
			var c: Vector2 = _m(base + Vector2(r * 0.85, -r * 0.5))
			if st == "cooking" or (st == "ready" and slot.has("ring")):
				var p := 1.0
				var rot := 0.0
				var alpha := 1.0
				if st == "cooking":
					p = clampf(float(slot["t"]) / maxf(float(slot["dur"]), 0.01), 0.0, 1.0)
				else:
					var t: float = float(slot["ring"])
					rot = sin(t * TAU * 7.0) * deg_to_rad(20.0) * exp(-t * 4.5)   # goyang cepat, meredam bersama ting
					alpha = clampf((DING_SHAKE - t) / 0.25, 0.0, 1.0)
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
			elif (st == "ready" and GameData.RECIPES[slot["dish"]].get("burns", true)) or st == "burnt":
				_draw_fire(slot, c, s)


## Api animasi (kedip, meliuk): kecil lalu makin besar selama fase "akan gosong"; penuh + hentakan saat gosong.
func _draw_fire(slot: Dictionary, c: Vector2, s: float) -> void:
	var fsz: Vector2 = fire_tex.get_size()
	var ph: float = float(int(slot["idx"]) * 7 + String(slot["kind"]).length() * 3)
	var scl := 1.0
	var alpha := 1.0
	var speed := 1.0
	if slot["state"] == "ready":
		var p: float = clampf(float(slot["t"]) / BURN_WINDOW, 0.0, 1.0)
		scl = lerpf(0.5, 1.0, p)
		speed = lerpf(1.0, 1.8, p)
		alpha = clampf((float(slot["t"]) - DING_SHAKE) / 0.25, 0.0, 1.0)   # muncul setelah jam alarm selesai goyang
	else:
		scl = 1.0
		speed = 2.0
		if slot.has("bring"):
			scl *= 1.0 + 0.15 * exp(-float(slot["bring"]) * 5.0)   # hentakan saat baru gosong
	var tm: float = pulse * speed + ph
	var sy: float = 1.0 + 0.10 * sin(tm * 13.0) + 0.05 * sin(tm * 21.0)
	var sx: float = 1.0 - 0.06 * sin(tm * 11.0)
	var rot: float = deg_to_rad(5.0) * sin(tm * 7.0)
	var fh: float = FIRE_H * s * scl
	var fw: float = fh * fsz.x / fsz.y
	var anchor: Vector2 = c + Vector2(0.0, FIRE_H * 0.5 * s)   # pangkal api; pusat kotak api = titik timer
	fx.draw_set_transform(anchor, rot, Vector2(sx, sy))
	fx.draw_texture_rect(fire_tex, Rect2(Vector2(-fw * 0.5, -fh), Vector2(fw, fh)), false, Color(1, 1, 1, alpha))
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
