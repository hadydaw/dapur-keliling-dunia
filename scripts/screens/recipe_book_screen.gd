extends Control

const UI = preload("res://scripts/ui_kit.gd")
const GameData = preload("res://scripts/game_data.gd")

signal navigate(screen: String, params: Dictionary)


func setup(_p: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.fill(self)
	UI.background(self, Color(0.14, 0.12, 0.1))
	var mc := UI.margin_root(self, 24)
	var root := UI.vbox(12)
	mc.add_child(root)

	var top := UI.hbox(16)
	var back := UI.button("Peta", Vector2(130, 60), Color(0.42, 0.36, 0.9), 26)
	back.pressed.connect(on_back)
	top.add_child(back)
	top.add_child(UI.label("Buku Resep", 40, Color(1, 0.82, 0.4)))
	root.add_child(top)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := UI.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var found := 0
	var total := 0
	for a in GameData.AREAS:
		list.add_child(UI.label("%s - %s" % [a["name"], a["place"]], 30, Color.html(a["color"]).lightened(0.35)))
		for id in a["dishes"]:
			total += 1
			var d: Dictionary = GameData.DISHES[id]
			var n: int = int(GameState.served_count.get(id, 0))
			var row := UI.panel(Color(1, 1, 1, 0.08), 14)
			var h := UI.hbox(12)
			row.add_child(h)
			if n > 0:
				found += 1
				h.add_child(UI.label(d["name"], 26))
				h.add_child(UI.spacer())
				h.add_child(UI.label("%s | %d koin | %d detik | disajikan %dx" % [d["station"], d["price"], int(d["cook"]), n], 22, Color(1, 1, 1, 0.8)))
			else:
				h.add_child(UI.label("???", 26, Color(1, 1, 1, 0.5)))
				h.add_child(UI.spacer())
				h.add_child(UI.label("Sajikan sekali untuk membuka", 22, Color(1, 1, 1, 0.5)))
			list.add_child(row)
	top.add_child(UI.spacer())
	top.add_child(UI.label("Resep terbuka: %d / %d" % [found, total], 28))


func on_back() -> void:
	navigate.emit("world_map", {})
