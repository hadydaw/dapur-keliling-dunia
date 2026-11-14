extends Control

const UI = preload("res://scripts/ui_kit.gd")
const GameData = preload("res://scripts/game_data.gd")

signal navigate(screen: String, params: Dictionary)

var area_idx: int = 0


func setup(p: Dictionary) -> void:
	area_idx = int(p.get("area", 0))


func _ready() -> void:
	var area: Dictionary = GameData.AREAS[area_idx]
	UI.fill(self)
	UI.background(self, Color.html(area["color"]).darkened(0.6))
	var mc := UI.margin_root(self, 24)
	var root := UI.vbox(16)
	mc.add_child(root)

	var top := UI.hbox(16)
	var back := UI.button("Peta", Vector2(130, 60), Color(0.42, 0.36, 0.9), 26)
	back.pressed.connect(on_back)
	top.add_child(back)
	top.add_child(UI.label("%s - %s" % [area["name"], area["place"]], 38, Color(1, 0.82, 0.4)))
	top.add_child(UI.spacer())
	top.add_child(UI.label("Koin: %d" % GameState.coins, 28))
	root.add_child(top)

	var row := UI.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for l in GameData.LEVELS_PER_AREA:
		row.add_child(_level_card(l))
	root.add_child(row)


func _level_card(l: int) -> Control:
	var area: Dictionary = GameData.AREAS[area_idx]
	var unlocked: bool = GameState.level_unlocked(area_idx, l)
	var params: Dictionary = GameData.level_params(area_idx, l)
	var p := UI.panel(Color(1, 1, 1, 0.14) if unlocked else Color(0, 0, 0, 0.35), 20)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(8)
	p.add_child(v)
	v.add_child(UI.label("Level %d" % (l + 1), 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("Bintang: %d / 3" % GameState.get_stars(area["id"], l), 22, Color(1, 0.82, 0.4), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("Target: %d" % int(params["target"]), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("Menu: %d hidangan" % (params["dishes"] as Array).size(), 20, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.spacer())
	var btn := UI.button("Main" if unlocked else "Terkunci", Vector2(0, 70), Color(0.15, 0.65, 0.3), 28)
	btn.disabled = not unlocked
	btn.pressed.connect(func(): navigate.emit("gameplay", {"area": area_idx, "level": l}))
	v.add_child(btn)
	return p


func on_back() -> void:
	navigate.emit("world_map", {})
