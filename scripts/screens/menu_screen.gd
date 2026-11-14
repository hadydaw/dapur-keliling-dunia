extends Control
## Menu Utama: gambar penuh + tombol sentuh transparan di atas tiap tombol pada gambar.

const UI = preload("res://scripts/ui_kit.gd")
const AnimatedBg = preload("res://scripts/ui/animated_bg.gd")

signal navigate(screen: String, params: Dictionary)

# Area tombol pada gambar menu_ui.jpg (piksel, gambar 1672x941)
const IMG := Vector2(1672.0, 941.0)
const HOTSPOTS := [
	{"id": "lanjutkan", "rect": Rect2(560, 540, 570, 115)},
	{"id": "mulai_baru", "rect": Rect2(565, 685, 560, 115)},
	{"id": "petualangan", "rect": Rect2(80, 780, 190, 132)},
	{"id": "resep", "rect": Rect2(310, 780, 150, 132)},
	{"id": "toko", "rect": Rect2(1235, 780, 150, 132)},
	{"id": "inventaris", "rect": Rect2(1430, 780, 170, 132)},
	{"id": "piala", "rect": Rect2(1345, 15, 90, 92)},
	{"id": "surat", "rect": Rect2(1455, 15, 90, 92)},
	{"id": "setelan", "rect": Rect2(1555, 15, 92, 92)},
	{"id": "tambah_koin", "rect": Rect2(240, 33, 52, 50)},
	{"id": "tambah_bintang", "rect": Rect2(493, 33, 56, 50)},
]
const COIN_NUM := Rect2(135, 36, 85, 40)
const STAR_NUM := Rect2(392, 36, 85, 40)
const BAR_COLOR := Color(0.227, 0.09, 0.063)

var bg: Control
var buttons: Dictionary = {}
var coin_cover: ColorRect
var star_cover: ColorRect
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

	var flat := StyleBoxEmpty.new()
	var press := StyleBoxFlat.new()
	press.bg_color = Color(1, 1, 1, 0.2)
	press.set_corner_radius_all(24)
	for h in HOTSPOTS:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", flat)
		b.add_theme_stylebox_override("hover", flat)
		b.add_theme_stylebox_override("pressed", press)
		b.add_theme_stylebox_override("focus", flat)
		b.pressed.connect(_on_hotspot.bind(h["id"]))
		add_child(b)
		buttons[h["id"]] = b

	coin_cover = _make_cover()
	star_cover = _make_cover()
	coin_label = _make_num()
	star_label = _make_num()
	toast_label = UI.label("", 30, Color(1, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.03))
	toast_label.add_theme_constant_override("outline_size", 8)
	add_child(toast_label)

	resized.connect(_layout)
	bg.resized.connect(_layout)
	_layout()


func _make_cover() -> ColorRect:
	var c := ColorRect.new()
	c.color = BAR_COLOR
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _make_num() -> Label:
	var l := UI.label("0", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color(0.2, 0.08, 0.04))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _norm(r: Rect2) -> Rect2:
	return Rect2(r.position / IMG, r.size / IMG)


func _layout() -> void:
	for h in HOTSPOTS:
		var r: Rect2 = bg.rect_to_screen(_norm(h["rect"]))
		var b: Button = buttons[h["id"]]
		b.position = r.position
		b.size = r.size
	var s: float = bg.image_scale()
	for pair in [[coin_cover, coin_label, COIN_NUM, GameState.coins], [star_cover, star_label, STAR_NUM, GameState.total_stars()]]:
		var r2: Rect2 = bg.rect_to_screen(_norm(pair[2]))
		var cover: ColorRect = pair[0]
		var lab: Label = pair[1]
		cover.position = r2.position
		cover.size = r2.size
		lab.position = r2.position
		lab.size = r2.size
		lab.text = str(pair[3])
		lab.add_theme_font_size_override("font_size", int(40.0 * s))
	toast_label.position = Vector2(0, size.y * 0.5)
	toast_label.size = Vector2(size.x, 50)


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
