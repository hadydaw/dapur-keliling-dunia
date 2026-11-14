extends Control
## Uji layar Main bergaya Cooking Madness (latar penuh + area ketuk).
## Jalankan: godot --headless --path . res://tests/gameplay_scene_test.tscn

const GameData = preload("res://scripts/game_data.gd")

var fails := 0
var main: Node


func _check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
	print("%s %s" % ["OK  " if cond else "GAGAL", label])


func _frames(n: int = 2) -> void:
	for i in n:
		await get_tree().process_frame


func _open(level: int) -> Node:
	main._go("gameplay", {"area": 0, "level": level})
	await _frames(4)
	var g: Node = main.current
	g.set_process(false)
	g.customers.clear()
	g.spawn_timer = 9999.0
	return g


func _tap(pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = pos
		e.global_position = pos
		e.pressed = pressed
		get_viewport().push_input(e)


func _tap_ingredient(g: Node, id: String) -> void:
	var r: Rect2 = g.scene["ingredients"][id]["rect"]
	_tap(g.offset + (r.position + r.size * 0.5) * g.scale_f)
	await _frames()


func _tap_slot(g: Node, kind: String, i: int) -> void:
	_tap(g.offset + g.appliances[kind][i]["pos"] * g.scale_f)
	await _frames()


func _tap_dispenser(g: Node) -> void:
	var r: Rect2 = g.scene["dispenser"]["hot"]
	_tap(g.offset + (r.position + r.size * 0.5) * g.scale_f)
	await _frames()


func _order(g: Node, items: Array) -> void:
	var served: Array = []
	for i in items:
		served.append(false)
	g.customers.append({"name": "Uji", "slot": 0, "items": items, "served": served, "patience": 40.0, "max": 40.0})


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await _frames()
	GameState.reset_all()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)

	var g: Node = await _open(0)
	_check(g.get_script().resource_path.get_file() == "gameplay_scene_screen.gd", "Indonesia memakai layar Main baru")
	_check(g.dishes == ["es_teh", "nasi_goreng"], "level 1 Indonesia: es teh + nasi goreng")

	# semua area ketuk >= 44 px di 1280x720
	var small := 0
	for h in g.hotspots:
		var b: Control = h["btn"]
		if b.size.x < 44.0 or b.size.y < 44.0:
			small += 1
	_check(small == 0, "semua area ketuk minimal 44px (%d terlalu kecil dari %d)" % [small, g.hotspots.size()])

	# --- es teh: termos es -> dispenser penuh -> ketuk dispenser -> gelas -> pelanggan ---
	_order(g, ["es_teh"])
	await _tap_dispenser(g)
	_check(g.jar["state"] == "empty" and g.appliances["dispenser"][0]["state"] == "empty", "dispenser kosong: ketuk dispenser tidak mengisi gelas")
	await _tap_ingredient(g, "es")
	_check(g.jar["state"] == "filling", "ketuk termos es: dispenser mulai terisi (timer)")
	_check(g.appliances["dispenser"][0]["state"] == "empty", "gelas tetap kosong saat dispenser diisi")
	await _tap_dispenser(g)
	_check(g.appliances["dispenser"][0]["state"] == "empty", "dispenser belum penuh: gelas tidak terisi")
	g._update_slots(1.5)
	_check(g.jar["state"] == "filling", "dispenser masih terisi setelah 1,5 detik")
	g._update_slots(2.0)
	_check(g.jar["state"] == "full" and g.jar["uses"] == GameData.JAR_CAPACITY, "dispenser penuh setelah waktu isi")
	await _tap_ingredient(g, "es")
	_check(g.jar["state"] == "full", "ketuk es saat penuh: tidak mengulang")
	await _tap_dispenser(g)
	_check(g.appliances["dispenser"][0]["state"] == "cooking", "ketuk dispenser sekali: gelas pertama terisi (timer)")
	_check(g.appliances["dispenser"][1]["state"] == "empty", "gelas kedua tetap kosong")
	_check(g.jar["uses"] == GameData.JAR_CAPACITY - 1, "satu porsi terpakai")
	g._update_slots(3.5)
	_check(g.appliances["dispenser"][0]["state"] == "ready", "gelas es teh matang setelah 3 detik")
	g._update_slots(30.0)
	_check(g.appliances["dispenser"][0]["state"] == "ready", "es teh tidak gosong")
	_check(g.ting_count >= 1, "bel ting berbunyi saat es teh matang")
	await _tap_slot(g, "dispenser", 0)
	_check(g.earned > 0 and g.customers.is_empty(), "ketuk gelas matang: pelanggan membayar")
	_check(g.appliances["dispenser"][0]["state"] == "empty", "gelas kosong lagi setelah disajikan")
	# habis setelah JAR_CAPACITY gelas -> perlu isi ulang
	g.jar["uses"] = 1
	await _tap_dispenser(g)
	_check(g.jar["state"] == "empty", "porsi terakhir diambil: dispenser kosong lagi")
	g._reset(g.appliances["dispenser"][0])
	g._reset(g.appliances["dispenser"][1])

	# --- nasi goreng: nasi -> wajan -> piring -> pelanggan ---
	g.earned = 0
	_order(g, ["nasi_goreng"])
	await _tap_ingredient(g, "nasi")
	_check(g.appliances["wok"][0]["state"] == "cooking", "ketuk penanak nasi: wajan mulai memasak")
	var ting_before: int = g.ting_count
	g._update_slots(7.0)
	_check(g.ting_count == ting_before + 1, "bel ting berbunyi sekali saat nasi goreng matang")
	await _tap_slot(g, "wok", 0)
	_check(g.appliances["plate"][0]["state"] == "full" and g.appliances["wok"][0]["state"] == "empty", "ketuk wajan matang: pindah ke piring")
	await _tap_slot(g, "plate", 0)
	_check(g.earned > 0 and g.customers.is_empty(), "ketuk piring: pelanggan membayar")

	# --- piring tanpa pesanan tidak hilang ---
	g.appliances["plate"][0]["state"] = "full"
	g.appliances["plate"][0]["dish"] = "nasi_goreng"
	await _tap_slot(g, "plate", 0)
	_check(g.appliances["plate"][0]["state"] == "full", "tanpa pesanan: piring tetap terisi")
	g._reset(g.appliances["plate"][0])

	# --- gosong dan dibuang ---
	await _tap_ingredient(g, "nasi")
	g._update_slots(7.0)
	g._update_slots(g.BURN_WINDOW + 0.5)
	_check(g.appliances["wok"][0]["state"] == "burnt", "terlambat diambil: gosong")
	await _tap_slot(g, "wok", 0)
	_check(g.appliances["wok"][0]["state"] == "empty", "ketuk gosong: dibuang")

	# --- alat penuh & slot terkunci ---
	GameState.upgrades["slots"] = 0
	g = await _open(0)
	_check(g.appliances["wok"][2]["state"] == "locked", "slot ke-3 wajan terkunci tanpa upgrade")
	await _tap_ingredient(g, "nasi")
	await _tap_ingredient(g, "nasi")
	await _tap_ingredient(g, "nasi")
	var cooking := 0
	for s in g.appliances["wok"]:
		if s["state"] == "cooking":
			cooking += 1
	_check(cooking == 2, "3 ketukan nasi: hanya 2 wajan aktif terisi (%d)" % cooking)

	# --- bahan yang belum dibuka di level ini ---
	await _tap_ingredient(g, "ikan")
	_check(g.appliances["grill"][0]["state"] == "empty", "ikan belum dibuka di level 1: tidak memasak")

	# --- level terakhir membuka ikan bakar ---
	g = await _open(4)
	_check(g.dishes.has("ikan_bakar") and g.dishes.size() == 5, "level 5 membuka 5 menu termasuk ikan bakar")
	await _tap_ingredient(g, "ikan")
	_check(g.appliances["grill"][0]["state"] == "cooking" and g.appliances["grill"][0]["dish"] == "ikan_bakar", "ikan masuk panggangan")

	# --- ekspresi pelanggan mengikuti kesabaran ---
	g.customers.clear()
	_order(g, ["es_teh"])
	var cu: Dictionary = g.customers[0]
	cu["patience"] = 38.0
	_check(g._customer_mood(cu) == "senang", "kesabaran tinggi: pelanggan senang")
	cu["patience"] = 20.0
	_check(g._customer_mood(cu) == "biasa", "kesabaran sedang: ekspresi biasa")
	cu["patience"] = 5.0
	_check(g._customer_mood(cu) == "marah", "kesabaran rendah: pelanggan marah")
	_check(g.customer_tex.size() == 3 and g.customer_tex["marah"] != null, "tiga gambar ekspresi termuat")
	g.customers.clear()

	# --- tombol Jeda ---
	var jeda: Control = g.find_child("BtnJeda", true, false)
	_tap(jeda.get_global_rect().get_center())
	await _frames()
	_check(g.paused, "tombol Jeda membuka menu jeda")
	g._close_overlay()

	print("TOTAL GAGAL: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
