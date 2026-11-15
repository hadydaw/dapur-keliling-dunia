extends Control
## Uji layout responsif landscape: 16:9, 18:9, 19.5:9, 20:9 (+ area aman / notch).
## Jalankan: godot --headless --path . res://tests/responsive_layout_test.tscn

const GameData = preload("res://scripts/game_data.gd")
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


func _make_screen(wide: bool) -> Node:
	if main.current != null:
		main.current.queue_free()
	var g: Node = load("res://scripts/screens/gameplay_scene_screen.gd").new()
	g.setup({"area": 0, "level": 4})
	g.force_wide = 1 if wide else 0
	main.add_child(g)
	main.current = g
	return g


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await _frames()
	GameState.reset_all()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var g: Node = null
	var k_ref := -1.0

	for name in RATIOS:
		var sz := Vector2(roundf(720.0 * RATIOS[name]), 720.0)
		g = _make_screen(RATIOS[name] >= GameData.WIDE_MIN_ASPECT)
		var img: Vector2 = g.scene["size"]
		g.size = sz
		g._layout()
		var view := Rect2(Vector2.ZERO, sz)
		if k_ref < 0.0:
			k_ref = g.scale_f
		var wide: bool = bool(g.scene.get("wide", false))
		var ess_img: Rect2 = Rect2(60, 295, 1780, 500) if wide else Rect2(200, 330, 1280, 581)   # meja + alat + bahan
		_check(g.scale_f >= 720.0 / img.y - 0.001 and g.scale_f <= 720.0 / img.y * 1.06, "%s (%s): skala seragam tanpa regang, k=%.3f" % [name, "lebar" if wide else "16:9", g.scale_f])
		var ess := Rect2(g._m(ess_img.position), ess_img.size * g.scale_f)
		_check(view.encloses(ess), "%s: meja + alat + bahan utuh di dalam layar" % name)
		var cut_x: float = maxf(0.0, -g.offset.x)
		var cut_y: float = maxf(0.0, -g.offset.y)
		_check(cut_x <= 0.035 * sz.x and cut_y <= 60.0 * g.scale_f, "%s: potongan latar hanya tepi (kiri-kanan %.0f px, atas-bawah %.0f px)" % [name, cut_x, cut_y])
		_check(g.bg.position.x <= 0.5 and g.bg.position.x + g.bg.size.x >= sz.x - 0.5, "%s: latar menutupi lebar layar (tanpa bar)" % name)
		_check(g.bg.position.y <= 0.5 and g.bg.position.y + g.bg.size.y >= sz.y - 0.5, "%s: latar menutupi tinggi layar" % name)
		var bad := 0
		for key in g.hud_r:
			if not view.grow(-4.0).encloses(g.hud_r[key]):
				bad += 1
		_check(bad == 0, "%s: semua elemen HUD di dalam layar (%d keluar)" % [name, bad])
		var keys: Array = g.hud_r.keys()
		var overlap := 0
		for i in keys.size():
			for j in range(i + 1, keys.size()):
				if g.hud_r[keys[i]].intersects(g.hud_r[keys[j]]):
					overlap += 1
		_check(overlap == 0, "%s: elemen HUD tidak saling bertumpuk (%d)" % [name, overlap])
		var bl: float = g._m(Vector2(g.scene["hud"]["banner"].x, 0)).x
		var bnr: float = g._m(Vector2(g.scene["hud"]["banner"].y, 0)).x
		_check(g.hud_r["pill1"].end.x <= bl and g.hud_r["pill2"].position.x >= bnr, "%s: HUD tidak menabrak emblem tengah (f=%.2f)" % [name, g.hud_u / g.scale_f])
		var uk: float = float(g.scene.get("ui_k", 1.0))
		var bub := Rect2(g._m(Vector2(g.scene["customer_spots"][3].x + 92.0 * uk, g.scene["customer_spots"][3].y - 184.0 * uk)), Vector2(96.0, 96.0 * 480.0 / 296.0) * uk * g.scale_f)
		_check(not g.hud_r["panel"].intersects(bub), "%s: panel menu tidak menutupi gelembung pelanggan ke-4" % name)
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
			var bx: float = sp.x + 92.0 * uk
			if bx + 96.0 * uk > img.x - 2.0:
				bx = sp.x - 92.0 * uk - 96.0 * uk
			var br := Rect2(g._m(Vector2(bx, sp.y - 184.0 * uk)), Vector2(96.0, 96.0 * 480.0 / 296.0) * uk * g.scale_f)
			if not view.encloses(br):
				cust_ok = false
		_check(cust_ok, "%s: gelembung pesanan semua pelanggan di dalam layar" % name)

	# area aman (notch): HUD tetap di dalam area aman, skala turun proporsional
	g.safe_insets_override = Vector4(50, 0, 50, 0)
	var sz2 := Vector2(roundf(720.0 * 20.0 / 9.0), 720.0)
	g.size = sz2
	g._layout()
	var safe := Rect2(Vector2(50, 0), Vector2(sz2.x - 100.0, sz2.y))
	var hot_out := 0
	for h in g.hotspots:
		var hb: Button = h["btn"]
		if not safe.encloses(Rect2(hb.position, hb.size)):
			hot_out += 1
			print("   di luar area aman: %s %s hk=%s" % [hb.name, Rect2(hb.position, hb.size), h.get("hud_key", "")])
	_check(hot_out == 0, "20:9 + notch 50 px: semua area ketuk (alat, bahan, HUD) di dalam area aman (%d keluar)" % hot_out)
	var bad2 := 0
	for key in g.hud_r:
		if not safe.encloses(g.hud_r[key]):
			bad2 += 1
	_check(bad2 == 0, "20:9 + notch: HUD di dalam area aman")
	g.safe_insets_override = Vector4(-1, 0, 0, 0)

	print("TOTAL GAGAL: %d" % fails)
	get_tree().quit()
