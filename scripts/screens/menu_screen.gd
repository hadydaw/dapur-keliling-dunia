extends Control
## Menu Utama: latar dapur beranimasi + logo, tombol, ikon, dan bar mata uang (aset terpisah).
## Tata letak dihitung dari tinggi layar (basis 720) dan dipusatkan, jadi aman di 16:9 sampai 20:9.

const UI = preload("res://scripts/ui_kit.gd")
const AnimatedBg = preload("res://scripts/ui/animated_bg.gd")

signal navigate(screen: String, params: Dictionary)

const ASSET_DIR := "res://assets/ui/"
# anchor: "c" = tengah layar, "l" = kiri, "r" = kanan (x dihitung dari tepi tsb)
# rect: posisi x, y dan lebar w pada basis tinggi 720 (tinggi mengikuti rasio gambar)
const ITEMS := [
	{"id": "logo", "tex": "logo", "a": "c", "x": 0, "y": 10, "w": 470, "touch": false},
	{"id": "lanjutkan", "tex": "btn_lanjutkan", "a": "c", "x": 0, "y": 326, "w": 380, "touch": true},
	{"id": "mulai_baru", "tex": "btn_mulai_baru", "a": "c", "x": 0, "y": 468, "w": 380, "touch": true},
	{"id": "petualangan", "tex": "ic_petualangan", "a": "l", "x": 24, "y": 590, "w": 112, "touch": true},
	{"id": "resep", "tex": "ic_resep", "a": "l", "x": 152, "y": 590, "w": 112, "touch": true},
	{"id": "toko", "tex": "ic_toko", "a": "r", "x": 152, "y": 590, "w": 112, "touch": true},
	{"id": "inventaris", "tex": "ic_inventaris", "a": "r", "x": 24, "y": 590, "w": 112, "touch": true},
	{"id": "piala", "tex": "ic_piala", "a": "r", "x": 170, "y": 14, "w": 60, "touch": true},
	{"id": "surat", "tex": "ic_surat", "a": "r", "x": 98, "y": 14, "w": 60, "touch": true},
	{"id": "setelan", "tex": "ic_setelan", "a": "r", "x": 26, "y": 14, "w": 60, "touch": true},
	{"id": "bar_koin", "tex": "bar_koin", "a": "l", "x": 16, "y": 16, "w": 230, "touch": false},
	{"id": "bar_bintang", "tex": "bar_bintang", "a": "l", "x": 258, "y": 16, "w": 230, "touch": false},
]
# Area kayu kosong di dalam bar (pecahan lebar/tinggi bar), diukur dari gambar
const NUM_RECT_COIN := Rect2(0.264, 0.317, 0.532, 0.433)
const NUM_RECT_STAR := Rect2(0.271, 0.303, 0.526, 0.427)
# Tombol + pada bar (pecahan), jadi area ketuk menuju Toko
const PLUS_RECT := Rect2(0.80, 0.10, 0.20, 0.80)

var bg: Control
var nodes: Dictionary = {}
var buttons: Dictionary = {}
var coin_label: Label
var star_label: Label
var toast_label: Label
var toast_time: float = 0.0
var overlay: Control = null


func setup(_p: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.fill(self)
	bg = AnimatedBg.new()
	add_child(bg)
	for it in ITEMS:
		var tr := TextureRect.new()
		tr.texture = load(ASSET_DIR + it["tex"] + ".png")
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
		nodes[it["id"]] = tr
		if it["touch"]:
			_make_button(it["id"], tr)
	_make_button("tambah_koin", nodes["bar_koin"])
	_make_button("tambah_bintang", nodes["bar_bintang"])
	coin_label = _make_num()
	star_label = _make_num()
	toast_label = UI.label("", 30, Color(1, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.03))
	toast_label.add_theme_constant_override("outline_size", 8)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_label)
	resized.connect(_layout)
	_layout()


func _make_button(id: String, target: Control) -> void:
	var b := TextureButton.new()
	b.ignore_texture_size = true
	b.focus_mode = Control.FOCUS_NONE
	b.button_down.connect(_press_anim.bind(target, true))
	b.button_up.connect(_press_anim.bind(target, false))
	b.pressed.connect(_on_hotspot.bind(id))
	add_child(b)
	buttons[id] = b


## Animasi ketuk: mengecil saat ditekan, membal kembali saat dilepas.
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


func _make_num() -> Label:
	var l := UI.label("0", 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.04))
	l.add_theme_constant_override("outline_size", 6)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _layout() -> void:
	var u: float = size.y / 720.0
	for it in ITEMS:
		var tr: TextureRect = nodes[it["id"]]
		var w: float = it["w"] * u
		var h: float = w * tr.texture.get_height() / tr.texture.get_width()
		var x: float = it["x"] * u
		match it["a"]:
			"c":
				x = (size.x - w) * 0.5
			"r":
				x = size.x - x - w
		tr.position = Vector2(x, it["y"] * u)
		tr.size = Vector2(w, h)
		if buttons.has(it["id"]):
			var b: TextureButton = buttons[it["id"]]
			b.position = tr.position
			b.size = tr.size
	for id in ["tambah_koin", "tambah_bintang"]:
		var bar: Control = nodes["bar_koin" if id == "tambah_koin" else "bar_bintang"]
		var pb: TextureButton = buttons[id]
		pb.position = bar.position + PLUS_RECT.position * bar.size
		pb.size = PLUS_RECT.size * bar.size
		# area ketuk minimal 44px
		if pb.size.y < 44.0:
			var grow: float = 44.0 - pb.size.y
			pb.position.y -= grow * 0.5
			pb.size.y = 44.0
		if pb.size.x < 44.0:
			pb.position.x -= 44.0 - pb.size.x
			pb.size.x = 44.0
	_place_num(coin_label, nodes["bar_koin"], str(GameState.coins), NUM_RECT_COIN)
	_place_num(star_label, nodes["bar_bintang"], str(GameState.total_stars()), NUM_RECT_STAR)
	toast_label.position = Vector2(0, size.y * 0.5)
	toast_label.size = Vector2(size.x, 50)


func _place_num(lab: Label, bar: Control, txt: String, rel: Rect2) -> void:
	UI.fit_label(lab, txt, Rect2(bar.position + rel.position * bar.size, rel.size * bar.size), 0.85)


func _process(delta: float) -> void:
	if toast_time > 0.0:
		toast_time -= delta
		toast_label.modulate.a = clampf(toast_time / 0.5, 0.0, 1.0)
		if toast_time <= 0.0:
			toast_label.text = ""


func _toast(msg: String) -> void:
	toast_label.text = msg
	toast_label.modulate.a = 1.0
	toast_time = 1.8


func _on_hotspot(id: String) -> void:
	if overlay != null:
		return
	match id:
		"lanjutkan", "petualangan":
			navigate.emit("world_map", {})
		"mulai_baru":
			_confirm_reset()
		"resep":
			navigate.emit("recipes", {})
		"toko", "tambah_koin", "tambah_bintang":
			navigate.emit("shop", {})
		"inventaris":
			_toast("Inventaris segera hadir")
		"piala":
			_toast("Pencapaian segera hadir")
		"surat":
			_toast("Kotak surat segera hadir")
		"setelan":
			_toast("Pengaturan segera hadir")


func _confirm_reset() -> void:
	overlay = UI.overlay(self, "Mulai Baru?", ["Semua koin, bintang, dan upgrade akan dihapus."], [
		{"text": "Ya, hapus", "color": Color(0.75, 0.22, 0.17), "fn": _do_reset},
		{"text": "Batal", "color": Color(0.42, 0.36, 0.9), "fn": _close_overlay},
	])


func _close_overlay() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null


func _do_reset() -> void:
	GameState.reset_all()
	navigate.emit("menu", {})


func on_back() -> void:
	if overlay != null:
		_close_overlay()
	else:
		get_tree().quit()
