extends Control
## Uji gameplay: masak, matang, gosong, layani, bayar, tip, sabar habis, bintang, penyimpanan,
## lalu simulasi bot memainkan 20 level untuk memeriksa keseimbangan target.
## Jalankan: godot --headless --path . res://tests/gameplay_test.tscn

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


func _open(area: int, level: int) -> Node:
	main._go("gameplay", {"area": area, "level": level})
	await _frames()
	var g: Node = main.current
	g.set_process(false)  # waktu dikendalikan tes
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


func _add_customer(g: Node, items: Array, patience: float, maxp: float) -> Dictionary:
	var served: Array = []
	for i in items:
		served.append(false)
	var c := {"name": "Uji", "slot": 0, "items": items, "served": served, "patience": patience, "max": maxp}
	g.customers.append(c)
	return c


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await _frames()
	GameState.reset_all()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)

	# --- 1. masak -> matang (ketuk sungguhan di tombol slot) ---
	var g: Node = await _open(0, 0)
	var id: String = g.dishes[0]
	var slot: Dictionary = g.stations[id][0]
	var btn: Button = slot["btn"]
	_tap(btn.global_position + btn.size * 0.5)
	await _frames()
	_check(slot["state"] == "cooking", "ketuk slot kosong -> memasak")
	g._update_slots(float(slot["dur"]) - 0.1)
	_check(slot["state"] == "cooking", "belum matang sebelum waktunya")
	g._update_slots(0.2)
	_check(slot["state"] == "ready", "matang setelah waktu masak")

	# --- 2. gosong bila dibiarkan, ketuk membuang ---
	g._update_slots(g.BURN_WINDOW + 0.1)
	_check(slot["state"] == "burnt", "gosong setelah BURN_WINDOW")
	g._on_slot_pressed(id, 0)
	_check(slot["state"] == "empty", "ketuk gosong -> dibuang, slot kosong")

	# --- 3. matang tanpa pesanan: tidak melayani ---
	slot["state"] = "ready"
	g._on_slot_pressed(id, 0)
	_check(slot["state"] == "ready", "tanpa pesanan: masakan tetap di slot")

	# --- 4. layani + bayar + tip (sabar > 50%) ---
	var price: int = int(GameData.DISHES[id]["price"])
	_add_customer(g, [id], 40.0, 40.0)
	var before_served: int = int(GameState.served_count.get(id, 0)) if GameState.served_count is Dictionary else 0
	g.earned = 0
	g._on_slot_pressed(id, 0)
	var expect_tip: int = int(round(price * GameState.price_mult() * 1.25))
	_check(slot["state"] == "empty", "layani: slot kembali kosong")
	_check(g.customers.is_empty(), "pesanan selesai: pelanggan pergi")
	_check(g.earned == expect_tip, "bayar + tip 25%% (dapat %d, harapan %d)" % [g.earned, expect_tip])

	# --- 5. tanpa tip bila sabar <= 50% ---
	slot["state"] = "ready"
	_add_customer(g, [id], 10.0, 40.0)
	g.earned = 0
	g._on_slot_pressed(id, 0)
	var expect_plain: int = int(round(price * GameState.price_mult()))
	_check(g.earned == expect_plain, "tanpa tip saat sabar rendah (dapat %d, harapan %d)" % [g.earned, expect_plain])

	# --- 6. pesanan 2 menu: bayar hanya setelah keduanya ---
	var ids2: Array = [g.dishes[0], g.dishes[1]]
	_add_customer(g, ids2, 40.0, 40.0)
	g.earned = 0
	g.stations[ids2[0]][0]["state"] = "ready"
	g._on_slot_pressed(ids2[0], 0)
	_check(g.earned == 0 and g.customers.size() == 1, "pesanan ganda: belum bayar setelah menu pertama")
	g.stations[ids2[1]][0]["state"] = "ready"
	g._on_slot_pressed(ids2[1], 0)
	_check(g.earned > 0 and g.customers.is_empty(), "pesanan ganda: bayar setelah semua dilayani")

	# --- 7. pelanggan pergi bila sabar habis ---
	_add_customer(g, [id], 1.0, 40.0)
	g._update_customers(1.5)
	_check(g.customers.is_empty(), "sabar habis: pelanggan pergi")

	# --- 8. akhir level: ambang bintang + simpan progres ---
	for case in [[0, 0], [1.0, 1], [1.4, 2], [1.8, 3]]:
		GameState.reset_all()
		g = await _open(0, 0)
		var target: int = int(g.params["target"])
		g.earned = int(round(target * float(case[0]))) if float(case[0]) > 0 else target - 1
		if float(case[0]) == 1.0:
			g.earned = target
		g._finish()
		var got: int = GameState.get_stars("indonesia", 0) if GameState.has_method("get_stars") else -1
		_check(got == int(case[1]), "bintang %d untuk pendapatan %d dari target %d (dapat %d)" % [case[1], g.earned, target, got])
	_check(GameState.level_unlocked(0, 1) or GameState.coins > 0, "selesai level 1 membuka level 2 / menambah koin")

	# --- 9. simulasi bot: seimbangkah target 20 level? ---
	print("--- Simulasi bot (pemain ideal, jeda reaksi 0,6 dtk), 3 percobaan per level ---")
	for a in GameData.AREAS.size():
		for lv in GameData.LEVELS_PER_AREA:
			var res: Array = []
			for seed_i in 3:
				GameState.reset_all()
				res.append(await _bot_run(a, lv, 100 + seed_i))
			var avg := 0.0
			var tgt: int = int(res[0]["target"])
			for r in res:
				avg += float(r["earned"]) / 3.0
			print("%-9s L%d  target %4d | bot rata2 %4d (%3d%% target)" % [GameData.AREAS[a]["name"], lv + 1, tgt, int(avg), int(100.0 * avg / tgt)])
	print("TOTAL GAGAL: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


## Bot: tiap 0,6 dtk ketuk slot matang yang dipesan, lalu masak untuk pesanan yang belum tertutup.
func _bot_run(a: int, lv: int, seed_val: int) -> Dictionary:
	var g: Node = await _open(a, lv)
	g.rng.seed = seed_val
	g.spawn_timer = 0.5
	var step := 0.1
	var react := 0.0
	while g.running:
		g._update_spawn(step)
		g._update_customers(step)
		g._update_slots(step)
		g.time_left -= step
		react += step
		if react >= 0.6:
			react = 0.0
			_bot_act(g)
		if g.time_left <= 0.0:
			g._finish()
	return {"earned": g.earned, "target": g.params["target"]}


func _bot_act(g: Node) -> void:
	# butuh: jumlah menu yang dipesan tapi belum dilayani, per hidangan
	var need := {}
	for c in g.customers:
		for i in c["items"].size():
			if not c["served"][i]:
				need[c["items"][i]] = int(need.get(c["items"][i], 0)) + 1
	for id in g.stations:
		var slots: Array = g.stations[id]
		var pending := 0
		for s in slots:
			if s["state"] == "ready":
				if int(need.get(id, 0)) > 0:
					g._on_slot_pressed(id, slots.find(s))
					need[id] = int(need[id]) - 1
				else:
					pending += 1
			elif s["state"] == "cooking":
				pending += 1
			elif s["state"] == "burnt":
				g._on_slot_pressed(id, slots.find(s))
		var missing: int = int(need.get(id, 0)) - pending
		for i in slots.size():
			if missing <= 0:
				break
			if slots[i]["state"] == "empty":
				g._on_slot_pressed(id, i)
				missing -= 1
