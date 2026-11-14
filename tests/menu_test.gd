extends Control
## Uji menu: ketuk (klik sungguhan) di tengah tiap tombol gambar, cek layar tujuan.
## Jalankan: godot --headless --path . res://tests/menu_test.tscn

const EXPECT := {
	"lanjutkan": "world_map_screen.gd",
	"petualangan": "world_map_screen.gd",
	"resep": "recipe_book_screen.gd",
	"toko": "shop_screen.gd",
	"tambah_koin": "shop_screen.gd",
	"tambah_bintang": "shop_screen.gd",
	"inventaris": "menu_screen.gd",
	"piala": "menu_screen.gd",
	"surat": "menu_screen.gd",
	"setelan": "menu_screen.gd",
}

var fails := 0


func _tap(pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = pos
	down.global_position = pos
	down.pressed = true
	get_viewport().push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = pos
	up.global_position = pos
	up.pressed = false
	get_viewport().push_input(up)


func _screen_of(main: Node) -> String:
	return main.current.get_script().resource_path.get_file()


func _ready() -> void:
	# Mode headless tidak punya jendela nyata; paksa ukuran layar uji 1280x720
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	print("ukuran layar uji: ", get_viewport().get_visible_rect().size)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 3:
		await get_tree().process_frame
	for id in EXPECT:
		main._go("menu", {})
		for i in 3:
			await get_tree().process_frame
		var b: BaseButton = main.current.buttons[id]
		var center: Vector2 = b.global_position + b.size * 0.5
		_tap(center)
		for i in 3:
			await get_tree().process_frame
		var got := _screen_of(main)
		var ok: bool = got == EXPECT[id]
		if not ok:
			fails += 1
		print("%s %-15s ketuk (%d,%d) -> %s" % ["OK  " if ok else "GAGAL", id, center.x, center.y, got])
	# Mulai Baru membuka konfirmasi, Batal menutupnya, Ya menghapus progres
	main._go("menu", {})
	for i in 3:
		await get_tree().process_frame
	var gs: Node = GameState
	gs.coins = 123
	var mb: BaseButton = main.current.buttons["mulai_baru"]
	_tap(mb.global_position + mb.size * 0.5)
	for i in 3:
		await get_tree().process_frame
	var has_overlay: bool = main.current.overlay != null
	print("%s mulai_baru membuka konfirmasi" % ("OK  " if has_overlay else "GAGAL"))
	if not has_overlay:
		fails += 1
	main.current._do_reset()
	for i in 3:
		await get_tree().process_frame
	var reset_ok: bool = gs.coins == 0
	print("%s reset menghapus koin (coins=%d)" % ["OK  " if reset_ok else "GAGAL", gs.coins])
	if not reset_ok:
		fails += 1
	# Animasi ketuk: tombol mengecil saat ditekan, kembali normal saat dilepas
	main._go("menu", {})
	for i in 3:
		await get_tree().process_frame
	var lb: BaseButton = main.current.buttons["lanjutkan"]
	var tgt: Control = main.current.nodes["lanjutkan"]
	main.current.overlay = null
	lb.button_down.emit()
	for i in 12:
		await get_tree().process_frame
	var shrunk: bool = tgt.scale.x < 0.95
	lb.button_up.emit()
	for i in 30:
		await get_tree().process_frame
	var back: bool = absf(tgt.scale.x - 1.0) < 0.01
	print("%s animasi ketuk (mengecil=%s, kembali=%s)" % ["OK  " if shrunk and back else "GAGAL", shrunk, back])
	if not (shrunk and back):
		fails += 1

	print("TOTAL GAGAL: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
