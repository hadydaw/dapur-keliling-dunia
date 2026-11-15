extends Control
## Uji musik latar: lagu menu di layar non-game, lagu Indonesia di level Indonesia, lagu berbeda di area lain.
## Jalankan: godot --headless --path . res://tests/music_test.tscn

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
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames()
	_check(Music.track == "menu", "layar menu memutar lagu menu")
	var menu_stream: AudioStream = Music._active.stream
	_check(Music._active.playing, "lagu menu sedang diputar")
	for path in Music.TRACKS.values():
		var st: AudioStreamWAV = load(path)
		var secs: float = float(st.data.size()) / 2.0 / float(st.mix_rate)
		_check(secs > 30.0 and secs < 34.0, "%s: panjang %.1f dtk" % [path.get_file(), secs])
	_check(Music._active.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "lagu menu diatur berulang")
	main._go("world_map", {})
	await _frames()
	_check(Music.track == "menu" and Music._active.stream == menu_stream, "peta dunia: lagu menu berlanjut tanpa mulai ulang")
	main._go("gameplay", {"area": 0, "level": 0})
	await _frames()
	_check(Music.track == "indonesia", "level Indonesia memutar lagu gamelan Indonesia")
	_check(Music._active.stream != menu_stream and Music._active.playing, "lagu permainan berbeda dari lagu menu")
	_check(Music._active.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "lagu Indonesia diatur berulang")
	main._go("gameplay", {"area": 1, "level": 0})
	await _frames()
	_check(Music.track == "umum", "level area lain memutar lagu umum")
	_check(Music.track_for("gameplay", {"area": 0}) != Music.track_for("menu", {}), "lagu menu dan lagu permainan Indonesia berbeda")
	main._go("menu", {})
	await _frames()
	_check(Music.track == "menu", "kembali ke menu: lagu menu kembali")
	print("TOTAL GAGAL: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
