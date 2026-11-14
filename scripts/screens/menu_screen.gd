extends Control

const UI = preload("res://scripts/ui_kit.gd")

signal navigate(screen: String, params: Dictionary)

var reset_btn: Button
var reset_armed := false


func setup(_p: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.fill(self)
	UI.background(self, Color(0.13, 0.09, 0.16))
	var mc := UI.margin_root(self, 24)
	var center := CenterContainer.new()
	mc.add_child(center)
	var v := UI.vbox(16)
	center.add_child(v)
	v.add_child(UI.label("DAPUR KELILING DUNIA", 64, Color(1, 0.82, 0.4), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("Masak, layani, dan jelajahi dunia", 28, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.spacer())
	var play := UI.button("Main", Vector2(380, 76), Color(0.15, 0.65, 0.3), 34)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func(): navigate.emit("world_map", {}))
	v.add_child(play)
	reset_btn = UI.button("Mulai Baru", Vector2(380, 64), Color(0.75, 0.22, 0.17), 28)
	reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset_btn.pressed.connect(_on_reset)
	v.add_child(reset_btn)
	v.add_child(UI.label("Koin: %d   Bintang: %d" % [GameState.coins, GameState.total_stars()], 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))


func on_back() -> void:
	get_tree().quit()


func _on_reset() -> void:
	if not reset_armed:
		reset_armed = true
		reset_btn.text = "Yakin? Ketuk lagi"
		return
	GameState.reset_all()
	navigate.emit("menu", {})
