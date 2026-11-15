extends Control
## Peta Dunia: latar peta penuh layar, tiap pulau = satu area. Ketuk pulau untuk masuk.
## Posisi dihitung dari koordinat gambar (0..1) lalu dipetakan ke layar (mode cover).

const UI = preload("res://scripts/ui_kit.gd")
const GameData = preload("res://scripts/game_data.gd")
const BG := preload("res://assets/world_map_bg.jpg")
const ASSET_DIR := "res://assets/ui/"

signal navigate(screen: String, params: Dictionary)

# Pusat tiap pulau (x) pada gambar; papan nama berada di bidang pasir di bawahnya.
const ISLAND_X := [0.14, 0.385, 0.625, 0.865]
const COLUMN_W := 0.215
const COLUMN_Y := [0.06, 0.90]
const PLATE_Y := 0.615
const PLATE_W := 0.23
# Porsi kelebihan tinggi yang dipotong dari ATAS saat layar lebih lebar dari 16:9
const CROP_TOP := 0.25
# Area teks di dalam papan nama (pecahan lebar/tinggi papan)
const NAME_RECT := Rect2(0.098, 0.394, 0.806, 0.231)   # pita kayu bersih (tanpa hiasan emas)
const NUM_RECT_COIN := Rect2(0.264, 0.317, 0.532, 0.433)
const NUM_RECT_STAR := Rect2(0.271, 0.303, 0.526, 0.427)

var bg_rect: TextureRect
var plates: Array = []
var columns: Array = []
var shades: Array = []
var top_items: Array = []
var coin_label: Label
var star_label: Label
var toast_label: Label
var toast_time: float = 0.0
var glow_tex: GradientTexture2D
var locks: Array = []


func setup(_p: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.fill(self)
	clip_contents = true
	bg_rect = TextureRect.new()
	bg_rect.texture = BG
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_rect)

	glow_tex = GradientTexture2D.new()
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	glow_tex.width = 128
	glow_tex.height = 128
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.02, 0.03, 0.08, 0.82), Color(0.02, 0.03, 0.08, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	glow_tex.gradient = g

	for i in GameData.AREAS.size():
		_build_area(i)
	_build_top()
	toast_label = UI.label("", 30, Color(1, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.03))
	toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_label)
	resized.connect(_layout)
	_layout()


# ---------- pembangunan ----------
func _build_area(i: int) -> void:
	var a: Dictionary = GameData.AREAS[i]
	var unlocked: bool = GameState.area_unlocked(i)
	# peredup pulau terkunci
	var shade := TextureRect.new()
	shade.texture = glow_tex
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.visible = not unlocked
	add_child(shade)
	shades.append(shade)

	# papan nama (aset) + nama + bintang
	var plate := _asset("plate_nama")
	plate.modulate = Color.WHITE if unlocked else Color(0.6, 0.6, 0.62)
	var name_l := UI.label(a["name"] if unlocked else "Terkunci", 24, Color(1, 0.93, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	name_l.name = "Nama"
	var count_text: String = "%d / %d" % [GameState.area_stars(i), GameData.LEVELS_PER_AREA * 3] if unlocked else "Terkunci"
	var count_l := UI.label(count_text, 22, Color(1, 0.88, 0.4) if unlocked else Color(0.85, 0.85, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	for l in [name_l, count_l]:
		l.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.02))
		l.add_theme_constant_override("outline_size", 5)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.clip_text = true
		plate.add_child(l)
	var star := TextureRect.new()
	star.texture = load(ASSET_DIR + ("star_full.png" if unlocked else "star_empty.png"))
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(star)
	plates.append({"root": plate, "name": name_l, "count": count_l, "star": star})
	# gembok di tengah pulau terkunci
	var lock := _asset("ic_gembok")
	lock.visible = not unlocked
	locks.append(lock)

	# kolom ketuk: seluruh pulau + papan namanya
	var b := TextureButton.new()
	b.ignore_texture_size = true
	b.focus_mode = Control.FOCUS_NONE
	b.button_down.connect(_press_anim.bind(plate, true))
	b.button_up.connect(_press_anim.bind(plate, false))
	b.pressed.connect(_on_area.bind(i))
	add_child(b)
	columns.append(b)


func _build_top() -> void:
	for it in [["bar_koin", 16, 230, "l"], ["bar_bintang", 258, 230, "l"]]:
		var tr := _asset(it[0])
		top_items.append({"node": tr, "x": it[1], "y": 16, "w": it[2], "a": it[3], "id": it[0]})
	coin_label = _num()
	star_label = _num()
	# tombol kanan atas: Resep, Toko, Menu
	for it in [["ic_resep", "recipes", 150], ["ic_toko", "shop", 82], ["btn_back", "menu", 14]]:
		var tr: TextureRect = _asset(it[0])
		var b := TextureButton.new()
		b.ignore_texture_size = true
		b.focus_mode = Control.FOCUS_NONE
		b.button_down.connect(_press_anim.bind(tr, true))
		b.button_up.connect(_press_anim.bind(tr, false))
		b.pressed.connect(func() -> void: navigate.emit(it[1], {}))
		add_child(b)
		top_items.append({"node": tr, "x": it[2], "y": 12, "w": 64, "a": "r", "btn": b, "id": it[1]})


func _asset(name: String) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load(ASSET_DIR + name + ".png")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	return tr


func _num() -> Label:
	var l := UI.label("0", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.04))
	l.add_theme_constant_override("outline_size", 6)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


# ---------- tata letak ----------
func _bg_geometry() -> Rect2:
	var s: float = maxf(size.x / BG.get_width(), size.y / BG.get_height())
	var d := Vector2(BG.get_width(), BG.get_height()) * s
	return Rect2(Vector2((size.x - d.x) * 0.5, -(d.y - size.y) * CROP_TOP), d)


func _to_screen(p: Vector2) -> Vector2:
	var r := _bg_geometry()
	return r.position + p * r.size


func _layout() -> void:
	var r := _bg_geometry()
	bg_rect.position = r.position
	bg_rect.size = r.size
	var u: float = size.y / 720.0
	for i in GameData.AREAS.size():
		var cx: float = ISLAND_X[i]
		var col_tl := _to_screen(Vector2(cx - COLUMN_W * 0.5, COLUMN_Y[0]))
		var col_br := _to_screen(Vector2(cx + COLUMN_W * 0.5, COLUMN_Y[1]))
		col_tl.y = maxf(col_tl.y, 0.0)
		col_br.y = minf(col_br.y, size.y)
		columns[i].position = col_tl
		columns[i].size = col_br - col_tl
		var pw: float = PLATE_W * r.size.x
		var plate: TextureRect = plates[i]["root"]
		var ph: float = pw * plate.texture.get_height() / plate.texture.get_width()
		var pc := _to_screen(Vector2(cx, PLATE_Y))
		plate.position = Vector2(pc.x - pw * 0.5, pc.y)
		plate.size = Vector2(pw, ph)
		plate.pivot_offset = plate.size * 0.5
		var nl: Label = plates[i]["name"]
		UI.fit_label(nl, nl.text, Rect2(NAME_RECT.position * plate.size, NAME_RECT.size * plate.size), 0.92)
		# baris bintang di bawah papan: ikon + teks, dipusatkan sebagai satu kelompok
		var cl: Label = plates[i]["count"]
		var st: TextureRect = plates[i]["star"]
		var row_h: float = ph * 0.36
		var fs: int = int(row_h * 0.85)
		cl.add_theme_font_size_override("font_size", fs)
		var tw: float = cl.get_theme_font("font").get_string_size(cl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var group_w: float = row_h + 6.0 + tw
		var gx: float = (pw - group_w) * 0.5
		var gy: float = ph * 0.97
		st.size = Vector2(row_h, row_h)
		st.position = Vector2(gx, gy)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cl.position = Vector2(gx + row_h + 6.0, gy)
		cl.size = Vector2(tw + 4.0, row_h)
		var lk: TextureRect = locks[i]
		var lw: float = 0.075 * r.size.x
		var lc := _to_screen(Vector2(cx, 0.36))
		lk.position = lc - Vector2(lw, lw) * 0.5
		lk.size = Vector2(lw, lw * lk.texture.get_height() / lk.texture.get_width())
		var sh: TextureRect = shades[i]
		var ic := _to_screen(Vector2(cx, 0.36))
		var rad: float = 0.2 * r.size.x
		sh.position = ic - Vector2(rad, rad * 0.9)
		sh.size = Vector2(rad * 2.0, rad * 1.8)
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
			var b: TextureButton = it["btn"]
			b.position = tr.position
			b.size = tr.size
			if b.size.x < 44.0:
				b.size = Vector2(44, 44)
	var bar_c: TextureRect = _top("bar_koin")
	var bar_s: TextureRect = _top("bar_bintang")
	_place_num(coin_label, bar_c, str(GameState.coins), NUM_RECT_COIN)
	_place_num(star_label, bar_s, str(GameState.total_stars()), NUM_RECT_STAR)
	toast_label.position = Vector2(0, size.y * 0.5)
	toast_label.size = Vector2(size.x, 50)


func _top(id: String) -> TextureRect:
	for it in top_items:
		if it["id"] == id:
			return it["node"]
	return null


func _place_num(lab: Label, bar: Control, txt: String, rel: Rect2) -> void:
	UI.fit_label(lab, txt, Rect2(bar.position + rel.position * bar.size, rel.size * bar.size), 0.85)


# ---------- interaksi ----------
func _press_anim(target: Control, down: bool) -> void:
	target.pivot_offset = target.size * 0.5
	var tw := create_tween()
	if down:
		target.modulate = Color(0.85, 0.85, 0.85)
		tw.tween_property(target, "scale", Vector2(0.94, 0.94), 0.07)
	else:
		target.modulate = Color.WHITE
		tw.tween_property(target, "scale", Vector2(1.05, 1.05), 0.09)
		tw.tween_property(target, "scale", Vector2.ONE, 0.09)


func _on_area(i: int) -> void:
	if GameState.area_unlocked(i):
		navigate.emit("level_select", {"area": i})
	else:
		_toast("Selesaikan Level %d di %s dulu" % [GameData.LEVELS_PER_AREA, GameData.AREAS[i - 1]["name"]])


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
	navigate.emit("menu", {})
