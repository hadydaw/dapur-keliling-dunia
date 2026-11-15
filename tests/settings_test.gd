extends Control
## Uji Pengaturan suara: bus, volume tersimpan, panel dari menu dan menu Jeda, ukuran sentuh.
## Jalankan: godot --headless --path . res://tests/settings_test.tscn

var fails := 0
var main: Node


func _check(cond: bool, label: String) -> void:
	if not cond:
		fails += 1
	print("%s %s" % ["OK  " if cond else "GAGAL", label])


func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await _frames()
	GameState.reset_all()
	GameState.music_vol = 1.0
	GameState.sfx_vol = 1.0
	Music.apply_volumes()
	var mi := AudioServer.get_bus_index("Musik")
	var ei := AudioServer.get_bus_index("Efek")
	_check(mi != -1 and ei != -1, "bus Musik dan Efek ada")
	_check(Music._active.bus == "Musik", "pemutar musik memakai bus Musik")
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames()
	var menu = main.current
	menu._on_hotspot("setelan")
	await _frames()
	var panel = menu.overlay
	_check(panel != null and panel.has_method("close"), "tombol Setelan membuka panel Pengaturan")
	var sm: HSlider = panel.sliders["music"]
	var se: HSlider = panel.sliders["sfx"]
	_check(sm.size.y >= 44.0 and se.size.y >= 44.0, "slider tinggi >= 44 px (%d)" % int(sm.size.y))
	var tutup: Control = panel.find_child("BtnTutup", true, false)
	_check(tutup != null and tutup.size.y >= 44.0 and tutup.size.x >= 44.0, "tombol Tutup ada dan >= 44 px")
	sm.value = 0.5
	await _frames()
	_check(is_equal_approx(GameState.music_vol, 0.5), "geser Musik mengubah nilai tersimpan")
	_check(absf(AudioServer.get_bus_volume_db(mi) - linear_to_db(0.5)) < 0.01, "volume bus Musik mengikuti (%.1f dB)" % AudioServer.get_bus_volume_db(mi))
	_check(not AudioServer.is_bus_mute(mi), "Musik 50% tidak bisu")
	se.value = 0.0
	await _frames()
	_check(AudioServer.is_bus_mute(ei), "Efek 0% membisukan bus Efek")
	_check(panel.value_labels["sfx"].text == "Bisu", "label Efek 0 = Bisu")
	menu._close_overlay()
	await _frames()
	_check(menu.overlay == null, "panel tertutup")
	# simpan -> muat ulang
	GameState.music_vol = 1.0
	GameState.sfx_vol = 1.0
	GameState.load_game()
	_check(is_equal_approx(GameState.music_vol, 0.5) and is_equal_approx(GameState.sfx_vol, 0.0), "volume bertahan setelah muat ulang")
	# 'Mulai Baru' tidak menghapus pengaturan suara
	GameState.reset_all()
	GameState.load_game()
	_check(is_equal_approx(GameState.music_vol, 0.5), "reset progres tidak menghapus pengaturan suara")
	# dari menu Jeda
	GameState.music_vol = 1.0
	GameState.sfx_vol = 1.0
	Music.apply_volumes()
	main._go("gameplay", {"area": 0, "level": 0})
	await _frames(5)
	var g = main.current
	var sfx_players := 0
	var wrong := 0
	for c in g.get_children():
		if c is AudioStreamPlayer:
			sfx_players += 1
			if c.bus != "Efek":
				wrong += 1
	_check(sfx_players >= 10 and wrong == 0, "%d pemutar efek di level semuanya memakai bus Efek" % sfx_players)
	g._toggle_pause()
	await _frames()
	g._open_settings()
	await _frames()
	_check(get_tree().get_nodes_in_group("settings_panel").size() == 1, "Pengaturan terbuka dari menu Jeda")
	g.on_back()
	await _frames()
	_check(get_tree().get_nodes_in_group("settings_panel").size() == 0 and g.paused, "Kembali menutup Pengaturan, game tetap Jeda")
	g._toggle_pause()
	await _frames()
	_check(not g.paused, "Lanjut dari Jeda berfungsi")
	print("HASIL: %s (%d gagal)" % ["LULUS" if fails == 0 else "GAGAL", fails])
	get_tree().quit(1 if fails > 0 else 0)
