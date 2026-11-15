extends Node
## Uji mandiri di perangkat: dijalankan dengan argumen `--selftest` (mis. lewat adb). Memakai sentuhan nyata
## (InputEvent) lalu mencetak penanda "SELFTEST|..." ke logcat. Tidak mengubah gameplay.

var main: Node
var fails := 0


func run(m: Node) -> void:
	main = m
	await _run()


func _log(tag: String, msg: String) -> void:
	print("SELFTEST|%s|%s" % [tag, msg])


func _check(cond: bool, tag: String, msg: String) -> void:
	if not cond:
		fails += 1
	_log(tag if cond else tag + "_GAGAL", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _mem(tag: String) -> void:
	_log("MEMORI", "%s: statis=%d MB, puncak=%d MB, tekstur+buffer video=%d MB, node=%d" % [tag, int(OS.get_static_memory_usage() / 1048576), int(OS.get_static_memory_peak_usage() / 1048576), int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])


func _tap(pos: Vector2) -> void:
	# Posisi kanvas diubah ke piksel jendela (skala tampilan di perangkat nyata tidak 1:1).
	var wp: Vector2 = get_viewport().get_final_transform() * pos
	var mv := InputEventMouseMotion.new()
	mv.position = wp
	mv.global_position = wp
	Input.parse_input_event(mv)
	await _frames(2)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = wp
		e.global_position = wp
		e.pressed = down
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		Input.parse_input_event(e)
		await _frames(2)


func _tap_ctl(c: Control) -> void:
	await _tap(c.get_global_rect().get_center())


func _screen_name() -> String:
	return String(main.current.get_script().resource_path.get_file()) if main.current != null else "-"


func _run() -> void:
	await _frames(10)
	var win := get_window().size
	_log("INFO", "os=%s %s | model=%s | cpu=%s | arsitektur=%s | gpu=%s | renderer=%s | jendela=%dx%d | dpi=%d | bahasa=%s" % [
		OS.get_name(), OS.get_version(), OS.get_model_name(), OS.get_processor_name(), Engine.get_architecture_name(),
		RenderingServer.get_video_adapter_name(), str(ProjectSettings.get_setting("rendering/renderer/rendering_method")), win.x, win.y, DisplayServer.screen_get_dpi(), OS.get_locale()])
	_check(_screen_name() == "menu_screen.gd", "MENU", "layar menu utama tampil, frame tergambar=%d" % Engine.get_frames_drawn())
	# Audio dan penyimpanan
	_check(AudioServer.get_bus_index("Musik") != -1 and AudioServer.get_bus_index("Efek") != -1, "AUDIO_BUS", "bus Musik dan Efek ada, mix rate=%d Hz, keluaran=%s" % [int(AudioServer.get_mix_rate()), AudioServer.output_device])
	_check(Music._active != null and Music._active.playing, "MUSIK", "lagu '%s' diputar" % Music.track)
	var coins_before: int = GameState.coins
	GameState.coins = coins_before + 7
	GameState.save_game()
	GameState.coins = -1
	GameState.load_game()
	_check(GameState.coins == coins_before + 7, "SIMPAN", "tulis dan baca save.json (%s)" % OS.get_user_data_dir())
	GameState.coins = coins_before
	GameState.save_game()
	# Sentuhan: menu -> peta dunia
	await _tap_ctl(main.current.buttons["lanjutkan"])
	await _frames(5)
	_check(_screen_name() == "world_map_screen.gd", "SENTUH_MENU", "ketuk Lanjutkan membuka peta dunia")
	main._go("level_select", {"area": 0})
	await _frames(5)
	_check(_screen_name() == "level_select_screen.gd", "PILIH_LEVEL", "layar pilih level 50 medali")
	_mem("menu/peta")
	# Gameplay
	main._go("gameplay", {"area": 0, "level": 0})
	await _frames(8)
	var g: Control = main.current
	_check(_screen_name() == "gameplay_scene_screen.gd" and g.running, "GAMEPLAY", "level 1 berjalan, jendela=%dx%d skala=%.3f" % [int(g.size.x), int(g.size.y), g.scale_f])
	var f0 := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_msec()
	var taps := 0
	for round in 6:
		for h in g.hotspots:
			var b: Control = h["btn"]
			if b != g.pause_btn and b.size.x >= 44.0 and b.get_global_rect().get_center().x > 0.0 and round % 2 == 0 and taps < 40:
				await _tap_ctl(b)
				taps += 1
		await _secs(0.8)
	var el := float(Time.get_ticks_msec() - t0) / 1000.0
	var fps := float(Engine.get_frames_drawn() - f0) / maxf(el, 0.01)
	_check(g.running and not g.paused, "MAIN", "%d ketukan nyata pada tombol, game masih berjalan, rata-rata %.1f FPS selama %.1f dtk" % [taps, fps, el])
	_mem("setelah bermain")
	await _tap_ctl(g.pause_btn)
	await _frames(4)
	_check(g.paused, "JEDA", "ketuk gear: menu Jeda terbuka")
	g._open_settings()
	await _frames(3)
	_check(get_tree().get_nodes_in_group("settings_panel").size() == 1, "PENGATURAN", "panel Pengaturan terbuka dari Jeda")
	get_tree().get_nodes_in_group("settings_panel")[0].close()
	await _frames(2)
	g._toggle_pause()
	await _frames(3)
	_check(not g.paused, "LANJUT", "Lanjut dari Jeda")
	main._go("menu", {})
	await _frames(5)
	_check(_screen_name() == "menu_screen.gd", "KEMBALI", "kembali ke menu utama")
	_log("SELESAI", "gagal=%d" % fails)
