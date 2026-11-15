extends Control
## Uji Pilih Level: ketuk level terbuka masuk gameplay, level terkunci tidak, bintang tampil, kembali ke peta.
## Jalankan: godot --headless --path . res://tests/level_select_test.tscn

const GameData = preload("res://scripts/game_data.gd")

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


func _open(area: int) -> void:
	main._go("level_select", {"area": area})
	await _frames()


func _center(c: Control) -> Vector2:
	return c.global_position + c.size * 0.5


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await _frames()
	GameState.reset_all()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames()
	for a in 4:
		await _open(a)
		_check(_scr() == "level_select_screen.gd" and main.current.medals.size() == 50, "area %d: 50 medali tampil" % a)
	await _open(0)
	var ls: Node = main.current
	for i in 10:
		_check((ls.medals[i]["button"] as Control).size.x >= 44.0 and (ls.medals[i]["button"] as Control).size.y >= 44.0, "level %d: area ketuk >= 44px" % (i + 1))
	# level 2 terkunci
	_tap(_center(ls.medals[1]["button"]))
	await _frames()
	_check(_scr() == "level_select_screen.gd" and ls.toast_label.text.begins_with("Selesaikan"), "level 2 terkunci: tidak masuk, pesan tampil")
	# level 1 -> gameplay level 1
	_tap(_center(ls.medals[0]["button"]))
	await _frames()
	_check(_scr() in ["gameplay_screen.gd", "gameplay_scene_screen.gd"] and main.current.level == 0 and main.current.area_idx == 0, "ketuk level 1 -> gameplay area 0 level 0")
	# selesaikan level 1 dengan 2 bintang -> level 2 terbuka
	GameState.finish_level("indonesia", 0, 2, 50)
	await _open(0)
	ls = main.current
	var shown := 0
	for s in ls.medals[0]["stars"]:
		if (s.texture as Texture2D).resource_path.ends_with("star_full.png"):
			shown += 1
	_check(shown == 2, "level 1: 2 bintang penuh tampil (dapat %d)" % shown)
	_check(ls.medals[1]["unlocked"], "level 2 terbuka setelah level 1 selesai")
	_tap(_center(ls.medals[1]["button"]))
	await _frames()
	_check(_scr() in ["gameplay_screen.gd", "gameplay_scene_screen.gd"] and main.current.level == 1, "ketuk level 2 -> gameplay level 1")
	# ---- 50 level: geser, bos, kunci ----
	await _open(0)
	ls = main.current
	var u: float = ls.size.y / 720.0
	_check(ls.scroll_max > 0.0, "daftar 50 level bisa digeser (scroll_max %.0f)" % ls.scroll_max)
	_check(ls.scroll <= 0.5 * ls.scroll_max, "level 3 terbuka: daftar mulai dekat atas")
	ls.scroll = 0.0
	ls._place_items()
	var vis_first: bool = ls.list.get_global_rect().encloses((ls.medals[0]["button"] as Control).get_global_rect())
	_check(vis_first, "level 1 terlihat penuh di awal")
	# roda mouse menggeser
	var w := InputEventMouseButton.new()
	w.button_index = MOUSE_BUTTON_WHEEL_DOWN
	w.pressed = true
	w.position = Vector2(640, 400)
	ls._gui_input(w)
	_check(ls.scroll > 0.0, "roda mouse menggeser daftar ke bawah")
	# geser dengan jari: tidak boleh dianggap ketukan
	ls.scroll = 0.0
	ls._place_items()
	var start: Vector2 = _center(ls.medals[0]["button"])
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = start
	ev.global_position = start
	ev.pressed = true
	ls._gui_input(ev)
	var mv := InputEventMouseMotion.new()
	mv.relative = Vector2(0, -120)
	mv.position = start + Vector2(0, -120)
	ls._gui_input(mv)
	ev = ev.duplicate()
	ev.pressed = false
	ev.position = start + Vector2(0, -120)
	ev.global_position = ev.position
	ls._gui_input(ev)
	await _frames()
	_check(ls.scroll > 100.0 and _scr() == "level_select_screen.gd", "menggeser jari menggulir daftar dan tidak masuk level")
	# level terakhir (50) terjangkau dan bertanda bos
	ls.scroll = ls.scroll_max
	ls._place_items()
	var last: Control = ls.medals[49]["button"]
	_check(ls.list.get_global_rect().encloses(last.get_global_rect()), "level 50 terlihat penuh di akhir daftar")
	_check(ls.medals[49]["unlocked"] == false, "level 50 terkunci di awal")
	for l in [9, 19, 29, 39, 49]:
		_check(GameData.level_params(0, l)["boss"] == true, "level %d adalah bos" % (l + 1))
	_check(GameData.level_params(0, 8)["boss"] == false, "level 9 bukan bos")
	# selesai sampai level 30 -> daftar dibuka di sekitar level 31
	for l in 30:
		GameState.finish_level("indonesia", l, 1, 0)
	await _open(0)
	ls = main.current
	_check(ls.medals[30]["unlocked"] and not ls.medals[31]["unlocked"], "level 31 terbuka, level 32 masih terkunci")
	_check(ls.scroll > 0.0 and ls.list.get_global_rect().encloses((ls.medals[30]["button"] as Control).get_global_rect()), "daftar otomatis menggulir ke level 31 yang sedang dikerjakan")
	_tap(_center(ls.medals[30]["button"]))
	await _frames()
	_check(_scr() in ["gameplay_screen.gd", "gameplay_scene_screen.gd"] and main.current.level == 30, "ketuk level 31 (setelah digulir) -> gameplay level 30")
	GameState.reset_all()
	# kembali
	await _open(2)
	main.current.on_back()
	await _frames()
	_check(_scr() == "world_map_screen.gd", "tombol kembali -> Peta Dunia")
	await _open(1)
	for it in main.current.top_items:
		if it["id"] == "back":
			_tap(_center(it["btn"]))
	await _frames()
	_check(_scr() == "world_map_screen.gd", "ketuk panah kembali -> Peta Dunia")
	print("TOTAL GAGAL: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
