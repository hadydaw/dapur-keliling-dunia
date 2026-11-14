extends Control

const UI = preload("res://scripts/ui_kit.gd")
const GameData = preload("res://scripts/game_data.gd")

signal navigate(screen: String, params: Dictionary)


func setup(_p: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.fill(self)
	UI.background(self, Color(0.1, 0.17, 0.27))
	var mc := UI.margin_root(self, 24)
	var root := UI.vbox(14)
	mc.add_child(root)

	var top := UI.hbox(16)
	var back := UI.button("Menu", Vector2(130, 60), Color(0.42, 0.36, 0.9), 26)
	back.pressed.connect(on_back)
	top.add_child(back)
	top.add_child(UI.label("Peta Dunia", 40, Color(1, 0.82, 0.4)))
	top.add_child(UI.spacer())
	top.add_child(UI.label("Koin: %d   Bintang: %d" % [GameState.coins, GameState.total_stars()], 28))
	root.add_child(top)

	var row := UI.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in GameData.AREAS.size():
		row.add_child(_area_card(i))
	root.add_child(row)

	var bottom := UI.hbox(16)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	var shop := UI.button("Toko Upgrade", Vector2(280, 68), Color(0.9, 0.5, 0.13), 28)
	shop.pressed.connect(func(): navigate.emit("shop", {}))
	var book := UI.button("Buku Resep", Vector2(280, 68), Color(0.15, 0.55, 0.65), 28)
	book.pressed.connect(func(): navigate.emit("recipes", {}))
	bottom.add_child(shop)
	bottom.add_child(book)
	root.add_child(bottom)


func _area_card(i: int) -> Control:
	var a: Dictionary = GameData.AREAS[i]
	var unlocked: bool = GameState.area_unlocked(i)
	var p := UI.panel(Color.html(a["color"]) if unlocked else Color(0.25, 0.25, 0.28), 22)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(8)
	p.add_child(v)
	v.add_child(UI.wrap_label(a["name"] if unlocked else "Terkunci", 30))
	v.add_child(UI.label(a["place"], 22, Color(1, 1, 1, 0.8)))
	var names: Array = []
	for id in a["dishes"]:
		names.append(GameData.DISHES[id]["name"] if unlocked else "???")
	v.add_child(UI.wrap_label("Menu: " + ", ".join(names), 20, Color(1, 1, 1, 0.85)))
	v.add_child(UI.spacer())
	v.add_child(UI.label("Bintang: %d / %d" % [GameState.area_stars(i), GameData.LEVELS_PER_AREA * 3], 24))
	var btn: Button
	if unlocked:
		btn = UI.button("Masuk", Vector2(0, 64), Color(0, 0, 0, 0.35), 28)
		btn.pressed.connect(func(): navigate.emit("level_select", {"area": i}))
	else:
		btn = UI.button("Butuh %d bintang" % int(a["stars_needed"]), Vector2(0, 64), Color(0.3, 0.3, 0.3), 24)
		btn.disabled = true
	v.add_child(btn)
	return p


func on_back() -> void:
	navigate.emit("menu", {})
