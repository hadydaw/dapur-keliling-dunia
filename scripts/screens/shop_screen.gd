extends Control

const UI = preload("res://scripts/ui_kit.gd")

signal navigate(screen: String, params: Dictionary)

var coins_label: Label
var rows: Dictionary = {}


func setup(_p: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.fill(self)
	UI.background(self, Color(0.17, 0.11, 0.07))
	var mc := UI.margin_root(self, 24)
	var root := UI.vbox(12)
	mc.add_child(root)

	var top := UI.hbox(16)
	var back := UI.button("Peta", Vector2(130, 60), Color(0.42, 0.36, 0.9), 26)
	back.pressed.connect(on_back)
	top.add_child(back)
	top.add_child(UI.label("Toko Upgrade", 40, Color(1, 0.82, 0.4)))
	top.add_child(UI.spacer())
	coins_label = UI.label("", 30, Color(1, 0.82, 0.4))
	top.add_child(coins_label)
	root.add_child(top)

	for key in GameState.UPGRADES:
		var u: Dictionary = GameState.UPGRADES[key]
		var p := UI.panel(Color(1, 1, 1, 0.1), 16)
		var h := UI.hbox(16)
		p.add_child(h)
		var info := UI.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UI.label(u["name"], 30))
		info.add_child(UI.label(u["desc"], 22, Color(1, 1, 1, 0.75)))
		h.add_child(info)
		var lvl := UI.label("", 26, Color(1, 0.82, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
		lvl.custom_minimum_size = Vector2(130, 0)
		h.add_child(lvl)
		var btn := UI.button("", Vector2(240, 68), Color(0.15, 0.65, 0.3), 26)
		btn.pressed.connect(_on_buy.bind(key))
		h.add_child(btn)
		root.add_child(p)
		rows[key] = {"lvl": lvl, "btn": btn}
	_refresh()


func _refresh() -> void:
	coins_label.text = "Koin: %d" % GameState.coins
	for key in rows:
		var u: Dictionary = GameState.UPGRADES[key]
		var lv: int = GameState.upgrade_level(key)
		var mx: int = int(u["max"])
		var r: Dictionary = rows[key]
		r["lvl"].text = "Lv %d / %d" % [lv, mx]
		var btn: Button = r["btn"]
		if lv >= mx:
			btn.text = "Maksimal"
			btn.disabled = true
		else:
			btn.text = "Beli %d" % GameState.upgrade_cost(key)
			btn.disabled = not GameState.can_buy(key)


func _on_buy(key: String) -> void:
	GameState.buy(key)
	_refresh()


func on_back() -> void:
	navigate.emit("world_map", {})
