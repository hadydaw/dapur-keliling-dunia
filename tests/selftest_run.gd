extends Control
## Menjalankan scripts/selftest.gd secara headless. Jalankan: godot --headless --path . res://tests/selftest_run.tscn
func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var m = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	var st := Node.new()
	st.set_script(load("res://scripts/selftest.gd"))
	add_child(st)
	await st.run(m)
	get_tree().quit(1 if st.fails > 0 else 0)
