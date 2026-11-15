extends Control
## Uji layout responsif landscape: 16:9, 18:9, 19.5:9, 20:9 (+ area aman / notch).
## Jalankan: godot --headless --path . res://tests/responsive_layout_test.tscn

var fails := 0
var main: Node

const RATIOS := {"16:9": 16.0 / 9.0, "18:9": 2.0, "19.5:9": 19.5 / 9.0, "20:9": 20.0 / 9.0}


func _check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
	print("%s %s" % ["OK  " if cond else "GAGAL", label])


func _frames(n: int = 2) -> void:
	for i in n:
		await get_tree().process_frame


func _hud_rects(g: Node) -> Array:
	var hud: Dictionary = g.scene["hud"]
	var out: Array = [hud["avatar"], hud["strip1"], hud["strip2"], hud["gear"], hud["panel_head"], hud["panel_body"]]
	out.append_array(hud["pills"])
	out.append_array(hud["squares"])
	return out


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await _frames()
	GameState.reset_all()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	main._go("gameplay", {"area": 0, "level": 4})
	await _frames(4)
	var g: Node = main.current
	g.set_process(false)
	g.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var k_ref := -1.0
	var img: Vector2 = g.scene["size"]

	for name in RATIOS:
		var sz := Vector2(roundf(720.0 * RATIOS[name]), 720.0)
		g.size = sz
		g._layout()
		var view := Rect2(Vector2.ZERO, sz)
		if k_ref < 0.0:
			k_ref = g.scale_f
		_check(absf(g.scale_f - 720.0 / img.y) < 0.001, "%s: skala aset sama (tidak diregangkan), k=%.3f" % [name, g.scale_f])
		var core := Rect2(g.offset, img * g.scale_f)
		_check(view.encloses(core), "%s: area inti (HUD + permainan) utuh di dalam layar" % name)
		_check(g.bg.position.x <= 0.5 and g.bg.position.x + g.bg.size.x >= sz.x - 0.5, "%s: latar menutupi lebar layar (tanpa bar)" % name)
		_check(g.bg.position.y <= 0.5 and g.bg.position.y + g.bg.size.y >= sz.y - 0.5, "%s: latar menutupi tinggi layar" % name)
		var bad := 0
		for r in _hud_rects(g):
			var rr := Rect2(g._m(r.position), r.size * g.scale_f)
			if not view.grow(-4.0).encloses(rr):
				bad += 1
		_check(bad == 0, "%s: semua elemen HUD di dalam layar (%d keluar)" % [name, bad])
		var small := 0
		var out := 0
		for h in g.hotspots:
			var b: Button = h["btn"]
			var r := Rect2(b.position, b.size)
			if r.size.x < 44.0 or r.size.y < 44.0:
				small += 1
			if not view.encloses(r):
				out += 1
		_check(small == 0 and out == 0, "%s: area ketuk >= 44 px dan di dalam layar (kecil %d, keluar %d)" % [name, small, out])
		# titik pelanggan + gelembung pesanan tidak keluar dari area inti
		var cust_ok := true
		for sp in g.scene["customer_spots"]:
			var bx: float = sp.x + 92.0
			if bx + 96.0 > img.x - 2.0:
				bx = sp.x - 92.0 - 96.0
			var br := Rect2(g._m(Vector2(bx, sp.y - 184.0)), Vector2(96.0, 96.0 * 480.0 / 296.0) * g.scale_f)
			if not view.encloses(br):
				cust_ok = false
		_check(cust_ok, "%s: gelembung pesanan semua pelanggan di dalam layar" % name)

	# area aman (notch): HUD tetap di dalam area aman, skala turun proporsional
	g.safe_insets_override = Vector4(90, 0, 90, 0)
	var sz2 := Vector2(roundf(720.0 * 20.0 / 9.0), 720.0)
	g.size = sz2
	g._layout()
	var safe := Rect2(Vector2(90, 0), Vector2(sz2.x - 180.0, sz2.y))
	_check(safe.encloses(Rect2(g.offset, img * g.scale_f)), "20:9 + notch 90 px: area inti di dalam area aman")
	var bad2 := 0
	for r in _hud_rects(g):
		if not safe.encloses(Rect2(g._m(r.position), r.size * g.scale_f)):
			bad2 += 1
	_check(bad2 == 0, "20:9 + notch: HUD di dalam area aman")
	g.safe_insets_override = Vector4(-1, 0, 0, 0)

	print("TOTAL GAGAL: %d" % fails)
	get_tree().quit()
