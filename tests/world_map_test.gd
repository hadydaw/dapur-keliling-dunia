extends Control
## Uji Peta Dunia: ketuk tiap pulau, area terkunci tidak masuk, tombol atas bekerja.
## Jalankan: godot --headless --path . res://tests/world_map_test.tscn

var fails := 0
var main: Node


func _check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
	print("%s %s" % ["OK  " if cond else "GAGAL", label])


func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _tap(pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = pos
		e.global_position = pos
		e.pressed = pressed
		get_viewport().push_input(e)


func _scr() -> String:
	return main.current.get_script().resource_path.get_file()


func _open() -> void:
	main._go("world_map", {})
	await _frames()


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await _frames()
	GameState.reset_all()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames()
	await _open()
	var wm: Node = main.current
	_check(_scr() == "world_map_screen.gd", "Peta Dunia terbuka")
	# area 0 terbuka -> level_select
	var c0: Control = wm.columns[0]
	_tap(c0.global_position + c0.size * 0.5)
	await _frames()
	_check(_scr() == "level_select_screen.gd", "ketuk pulau Indonesia -> pilih level")
	# area terkunci (bintang 0)
	for i in [1, 2, 3]:
		await _open()
		var c: Control = main.current.columns[i]
		_tap(c.global_position + c.size * 0.5)
		await _frames()
		_check(_scr() == "world_map_screen.gd", "area %d terkunci: tidak masuk" % i)
		_check(main.current.toast_label.text.begins_with("Selesaikan Level 50"), "area %d terkunci: pesan syarat level 50 tampil" % i)
	# beri bintang -> terbuka
	for l in 49:
		GameState.finish_level("indonesia", l, 3, 0)
	_check(not GameState.area_unlocked(1), "level 1-49 selesai (147 bintang): Meksiko masih terkunci")
	GameState.finish_level("indonesia", 49, 1, 0)
	_check(GameState.area_unlocked(1) and not GameState.area_unlocked(2), "level 50 selesai: Meksiko terbuka, Jepang masih terkunci")
	for i in [1]:
		await _open()
		var c: Control = main.current.columns[i]
		_tap(c.global_position + c.size * 0.5)
		await _frames()
		_check(_scr() == "level_select_screen.gd", "setelah level 50 selesai, Meksiko terbuka -> pilih level")
	# tombol atas
	for pair in [["recipes", "recipe_book_screen.gd"], ["shop", "shop_screen.gd"], ["menu", "menu_screen.gd"]]:
		await _open()
		for it in main.current.top_items:
			if it["id"] == pair[0]:
				var b: Control = it["btn"]
				_check(b.size.x >= 44.0 and b.size.y >= 44.0, "tombol %s >= 44px" % pair[0])
				_tap(b.global_position + b.size * 0.5)
		await _frames()
		_check(_scr() == pair[1], "tombol %s -> %s" % [pair[0], pair[1]])
	# Android back
	await _open()
	main.current.on_back()
	await _frames()
	_check(_scr() == "menu_screen.gd", "tombol kembali -> menu")
	print("TOTAL GAGAL: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
