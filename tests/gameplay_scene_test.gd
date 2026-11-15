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
	_check(g.fill_count == 1 and g.fill_player.playing, "suara isi dispenser berbunyi sekali saat mulai terisi")
	_check(g.ing_tap.has("es") and not g.ing_tap.has("nasi"), "ketuk termos es: efek ketuk hanya di bahan es")
	g._update_slots(0.6)
	_check(not g.ing_tap.has("es"), "efek ketuk bahan berakhir setelah 0,5 detik")
	_check(g.scene["ingredients"].size() == 5, "rak bahan: 5 bahan beranimasi (es, nasi, sate, ayam, ikan)")
	_check(g.appliances["dispenser"][0]["state"] == "empty", "gelas tetap kosong saat dispenser diisi")
	await _tap_dispenser(g)
	_check(g.appliances["dispenser"][0]["state"] == "empty", "dispenser belum penuh: gelas tidak terisi")
	g._update_slots(1.5)
	_check(g.jar["state"] == "filling", "dispenser masih terisi setelah 1,5 detik")
	g._update_slots(2.0)
	_check(g.jar["state"] == "full" and g.jar["uses"] == GameData.JAR_CAPACITY, "dispenser penuh setelah waktu isi")
	await _tap_ingredient(g, "es")
	_check(g.jar["state"] == "full", "ketuk es saat penuh: tidak mengulang")
	var pour_before: int = g.pour_count
	await _tap_dispenser(g)
	_check(g.appliances["dispenser"][0]["state"] == "cooking", "ketuk dispenser sekali: gelas pertama terisi (timer)")
	_check(g.pour_count == pour_before + 1 and g.pour_players[0].playing, "suara menuang es teh berbunyi sekali saat gelas mulai terisi")
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
	_check(g.stirfry_count == 1 and g.stirfry_players[0].playing, "suara nasi goreng di wajan berbunyi sekali saat mulai memasak")
	_check(g._cook_fx_enabled(g.appliances["wok"][0]), "nasi goreng memasak: animasi aduk/uap aktif")
	_check(not g._cook_fx_enabled(g.appliances["grill"][0]), "slot panggangan tidak memakai animasi wajan/panci")
	_check(g.burner_heat.size() == 6, "latar 16:9: 6 tungku wajan/panci punya api (%d)" % g.burner_heat.size())
	_check(is_equal_approx(float(g.burner_heat[0]), g.HEAT_IDLE), "tungku wajan 1 menganggur: api kecil")
	g._update_slots(0.5)
	_check(float(g.burner_heat[0]) > 0.99, "wajan 1 memasak: api tungku membesar penuh")
	_check(g.coal_heat.size() == 6, "6 petak panggangan punya bara (%d)" % g.coal_heat.size())
	_check(is_equal_approx(float(g.coal_heat[0]), g.HEAT_IDLE), "petak panggangan kosong: bara kecil")
	_check(is_equal_approx(float(g.burner_heat[3]), g.HEAT_IDLE), "tungku wajan lain yang kosong tetap kecil")
	var ting_before: int = g.ting_count
	g._update_slots(7.0)
	_check(g.ting_count == ting_before + 1, "bel ting berbunyi sekali saat nasi goreng matang")
	_check(not g._cook_fx_enabled(g.appliances["wok"][0]), "nasi goreng matang: animasi memasak berhenti")
	await _tap_slot(g, "wok", 0)
	_check(g.appliances["plate"][0]["state"] == "full" and g.appliances["wok"][0]["state"] == "empty", "ketuk wajan matang: pindah ke piring")
	var serve_before: int = g.serve_count
	await _tap_slot(g, "plate", 0)
	_check(g.earned > 0 and g.customers.is_empty(), "ketuk piring: pelanggan membayar")
	_check(g.serve_count == serve_before + 1 and g.serve_players[0].playing, "bunyi piring berbunyi sekali saat disajikan ke pelanggan")

	# --- piring tanpa pesanan tidak hilang ---
	g.appliances["plate"][0]["state"] = "full"
	g.appliances["plate"][0]["dish"] = "nasi_goreng"
	await _tap_slot(g, "plate", 0)
	_check(g.appliances["plate"][0]["state"] == "full", "tanpa pesanan: piring tetap terisi")
	g._reset(g.appliances["plate"][0])

	# --- gosong dan dibuang ---
	await _tap_ingredient(g, "nasi")
	g._update_slots(7.0)
	_check(g.appliances["wok"][0].has("ring"), "matang: jam alarm goyang (ring aktif)")
	var burn_before: int = g.burn_count
	var ting_mid: int = g.ting_count
	g._update_slots(g.BURN_WINDOW + 0.5)
	_check(g.appliances["wok"][0]["state"] == "burnt", "terlambat diambil: gosong")
	_check(g.burn_count == burn_before + 1 and g.ting_count == ting_mid, "bunyi gosong berbeda dari ting, berbunyi sekali")
	_check(g.appliances["wok"][0].has("bring"), "gosong: jam alarm goyang (bring aktif)")
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
	g = await _open(35)
	_check(not g.dishes.has("ikan_bakar") and g.dishes.size() == 4, "level 36 masih 4 menu (ikan bakar belum dibuka)")
	g = await _open(36)
	_check(g.dishes.has("ikan_bakar") and g.dishes.size() == 5, "level 37 membuka 5 menu termasuk ikan bakar")
	await _tap_ingredient(g, "ikan")
	_check(g.appliances["grill"][0]["state"] == "cooking" and g.appliances["grill"][0]["dish"] == "ikan_bakar", "ikan masuk panggangan")
	g._update_slots(0.5)
	_check(float(g.coal_heat[0]) > 0.99 and is_equal_approx(float(g.coal_heat[3]), g.HEAT_IDLE), "petak yang memasak: bara menyala penuh, petak lain tetap kecil")
	_check(g._oil_enabled(g.appliances["grill"][0]), "ikan bakar yang sedang dibakar: letupan minyak aktif")
	_check(not g._oil_enabled(g.appliances["grill"][1]), "petak panggangan kosong: tanpa letupan minyak")
	g._update_slots(20.0)
	_check(not g._oil_enabled(g.appliances["grill"][0]), "ikan sudah matang: letupan minyak berhenti")
	_check(g.sizzle_count == 0, "ikan bakar tidak memakai suara desis sate")
	_check(g.fish_count == 1 and g.fish_players[0].playing, "suara ikan bakar berbunyi sekali saat ikan masuk panggangan")
	_check(g.soup_count == 0, "soto belum dimasak: suara kuah belum berbunyi")
	await _tap_ingredient(g, "ayam")
	_check(g.soup_count == 1 and g.soup_players[0].playing, "suara soto mendidih berbunyi sekali saat ayam masuk panci")
	_check(g._cook_fx_enabled(g.appliances["pot"][0]), "soto memasak: animasi gelembung/uap aktif")
	await _tap_ingredient(g, "tusuk_ayam")
	_check(g.sizzle_count == 1 and g.sizzle_players[1].playing, "suara desis sate berbunyi sekali saat sate masuk panggangan")

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
