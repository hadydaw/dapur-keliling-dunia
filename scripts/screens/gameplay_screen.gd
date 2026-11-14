extends Control
## Level masak: pelanggan datang, pemain memasak di alat, ketuk matang untuk melayani.

const UI = preload("res://scripts/ui_kit.gd")
const GameData = preload("res://scripts/game_data.gd")

signal navigate(screen: String, params: Dictionary)

const BURN_WINDOW := 8.0
const CUSTOMER_NAMES := ["Budi", "Sari", "Andi", "Maya", "Tono", "Rina", "Joko", "Lia", "Dewi", "Rudi", "Nina", "Eko"]

var area_idx: int = 0
var level: int = 0
var area: Dictionary = {}
var params: Dictionary = {}
var dishes: Array = []
var time_left: float = 0.0
var earned: int = 0
var spawn_timer: float = 0.5
var running: bool = true
var paused: bool = false
var customers: Array = []
var customer_panels: Array = []
var stations: Dictionary = {}
var rng := RandomNumberGenerator.new()
var coins_label: Label
var time_label: Label
var goal_bar: ProgressBar
var toast_label: Label
var toast_time: float = 0.0
var overlay: Control = null
var slot_colors := {
	"empty": Color(0.18, 0.2, 0.21),
	"cooking": Color(0.85, 0.5, 0.1),
	"ready": Color(0.15, 0.65, 0.3),
	"burnt": Color(0.6, 0.12, 0.12),
}


func setup(p: Dictionary) -> void:
	area_idx = int(p.get("area", 0))
	level = int(p.get("level", 0))


func _ready() -> void:
	rng.randomize()
	area = GameData.AREAS[area_idx]
	params = GameData.level_params(area_idx, level)
	dishes = params["dishes"]
	time_left = float(params["duration"])
	UI.fill(self)
	UI.background(self, Color.html(area["color"]).darkened(0.65))
	var mc := UI.margin_root(self, 20)
	var root := UI.vbox(10)
	mc.add_child(root)
	root.add_child(_build_top_bar())
	toast_label = UI.label("", 34, Color(1, 0.82, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.custom_minimum_size = Vector2(0, 44)
	root.add_child(toast_label)
	root.add_child(_build_customer_row())
	root.add_child(_build_station_row())
	_refresh_ui()


func on_back() -> void:
	_toggle_pause()


# ---------- UI ----------
func _build_top_bar() -> Control:
	var bar := UI.hbox(16)
	var pause := UI.button("Jeda", Vector2(130, 60), Color(0.42, 0.36, 0.9), 26)
	pause.pressed.connect(_toggle_pause)
	bar.add_child(pause)
	bar.add_child(UI.label("%s - Level %d" % [area["name"], level + 1], 28))
	bar.add_child(UI.spacer())
	goal_bar = ProgressBar.new()
	goal_bar.custom_minimum_size = Vector2(260, 32)
	goal_bar.max_value = float(params["target"])
	goal_bar.show_percentage = false
	goal_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(goal_bar)
	coins_label = UI.label("", 28, Color(1, 0.82, 0.4))
	bar.add_child(coins_label)
	time_label = UI.label("", 32)
	time_label.custom_minimum_size = Vector2(110, 0)
	bar.add_child(time_label)
	return bar


func _build_customer_row() -> Control:
	var row := UI.hbox(12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in int(params["max_customers"]):
		var p := UI.panel(Color(1, 1, 1, 0.1))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.custom_minimum_size = Vector2(200, 190)
		var v := UI.vbox(6)
		p.add_child(v)
		var name_l := UI.label("", 28, Color(1, 0.82, 0.4))
		var order_l := UI.label("", 24)
		order_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.custom_minimum_size = Vector2(0, 22)
		v.add_child(name_l)
		v.add_child(order_l)
		v.add_child(bar)
		row.add_child(p)
		customer_panels.append({"panel": p, "name": name_l, "order": order_l, "bar": bar})
	return row


func _build_station_row() -> Control:
	var row := UI.hbox(12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var n_slots: int = GameState.slots_per_station()
	for id in dishes:
		var d: Dictionary = GameData.DISHES[id]
		var p := UI.panel(Color.html(d["color"]).darkened(0.45))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UI.vbox(8)
		p.add_child(v)
		v.add_child(UI.label(d["name"], 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(UI.label("%s | %d koin" % [d["station"], d["price"]], 20, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER))
		var slots: Array = []
		for i in n_slots:
			var b := UI.button("", Vector2(0, 76), slot_colors["empty"], 24)
			b.size_flags_vertical = Control.SIZE_EXPAND_FILL
			b.pressed.connect(_on_slot_pressed.bind(id, i))
			v.add_child(b)
			slots.append({"state": "empty", "t": 0.0, "dur": 0.0, "btn": b, "shown": ""})
		stations[id] = slots
		row.add_child(p)
	return row


func _toast(msg: String) -> void:
	toast_label.text = msg
	toast_time = 1.6


# ---------- input ----------
func _on_slot_pressed(id: String, i: int) -> void:
	if not running or paused:
		return
	var slot: Dictionary = stations[id][i]
	match slot["state"]:
		"empty":
			slot["state"] = "cooking"
			slot["t"] = 0.0
			slot["dur"] = float(GameData.DISHES[id]["cook"]) * GameState.cook_mult()
		"ready":
			if _serve(id):
				slot["state"] = "empty"
			else:
				_toast("Belum ada yang memesan ini")
		"burnt":
			slot["state"] = "empty"
			_toast("Masakan gosong dibuang")


# ---------- loop ----------
func _process(delta: float) -> void:
	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0.0:
			toast_label.text = ""
	if not running or paused:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_refresh_ui()
		_finish()
		return
	_update_spawn(delta)
	_update_customers(delta)
	_update_slots(delta)
	_refresh_ui()


func _update_spawn(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	if customers.size() < int(params["max_customers"]):
		_spawn_customer()
		spawn_timer = float(params["spawn_interval"]) * rng.randf_range(0.8, 1.2)
	else:
		spawn_timer = 1.0


func _spawn_customer() -> void:
	var used: Array = []
	for c in customers:
		used.append(c["slot"])
	var slot_i := -1
	for i in customer_panels.size():
		if not used.has(i):
			slot_i = i
			break
	if slot_i < 0:
		return
	var count := 1
	if dishes.size() >= 2 and rng.randf() < 0.3 + level * 0.06:
		count = 2
	var items: Array = []
	var served: Array = []
	for k in count:
		items.append(dishes[rng.randi() % dishes.size()])
		served.append(false)
	var pat: float = float(params["patience"]) * GameState.patience_mult() * (1.0 + 0.25 * (count - 1))
	customers.append({
		"name": CUSTOMER_NAMES[rng.randi() % CUSTOMER_NAMES.size()],
		"slot": slot_i, "items": items, "served": served, "patience": pat, "max": pat,
	})


func _update_customers(delta: float) -> void:
	var i := customers.size() - 1
	while i >= 0:
		var c: Dictionary = customers[i]
		c["patience"] = float(c["patience"]) - delta
		if float(c["patience"]) <= 0.0:
			customers.remove_at(i)
			_toast("%s pergi dengan marah!" % c["name"])
		i -= 1


func _update_slots(delta: float) -> void:
	for id in stations:
		for slot in stations[id]:
			match slot["state"]:
				"cooking":
					slot["t"] = float(slot["t"]) + delta
					if float(slot["t"]) >= float(slot["dur"]):
						slot["state"] = "ready"
						slot["t"] = 0.0
				"ready":
					slot["t"] = float(slot["t"]) + delta
					if float(slot["t"]) >= BURN_WINDOW:
						slot["state"] = "burnt"


# ---------- melayani ----------
func _serve(id: String) -> bool:
	var best: Dictionary = {}
	var best_i := -1
	var best_ratio := 2.0
	for c in customers:
		var n: int = c["items"].size()
		for i in n:
			if c["items"][i] == id and not c["served"][i]:
				var ratio: float = float(c["patience"]) / float(c["max"])
				if ratio < best_ratio:
					best_ratio = ratio
					best = c
					best_i = i
	if best_i < 0:
		return false
	best["served"][best_i] = true
	GameState.record_served(id)
	if not best["served"].has(false):
		_pay(best)
	return true


func _pay(c: Dictionary) -> void:
	var total := 0.0
	for id in c["items"]:
		total += float(GameData.DISHES[id]["price"])
	total *= GameState.price_mult()
	var ratio: float = float(c["patience"]) / float(c["max"])
	var tip: bool = ratio > 0.5
	if tip:
		total *= 1.25
	var gain: int = int(round(total))
	earned += gain
	customers.erase(c)
	_toast("+%d koin%s" % [gain, " (bonus sabar!)" if tip else ""])


# ---------- tampilan per frame ----------
func _refresh_ui() -> void:
	coins_label.text = "%d / %d" % [earned, int(params["target"])]
	goal_bar.value = minf(float(earned), goal_bar.max_value)
	var t: int = int(ceil(time_left))
	time_label.text = "%d:%02d" % [t / 60, t % 60]
	for i in customer_panels.size():
		var cp: Dictionary = customer_panels[i]
		var cust: Dictionary = {}
		for c in customers:
			if c["slot"] == i:
				cust = c
		var panel: Control = cp["panel"]
		if cust.is_empty():
			panel.modulate = Color(1, 1, 1, 0.45)
			cp["name"].text = ""
			cp["order"].text = "Menunggu pelanggan..."
			cp["bar"].value = 0.0
			continue
		panel.modulate = Color(1, 1, 1, 1)
		cp["name"].text = cust["name"]
		var lines: Array = []
		var n: int = cust["items"].size()
		for k in n:
			var nm: String = GameData.DISHES[cust["items"][k]]["name"]
			lines.append(("[v] " if cust["served"][k] else "[ ] ") + nm)
		cp["order"].text = "\n".join(lines)
		var ratio: float = float(cust["patience"]) / float(cust["max"])
		cp["bar"].value = ratio
		cp["bar"].modulate = Color(1.0 - 0.6 * ratio, 0.4 + 0.6 * ratio, 0.4)
	for id in stations:
		for slot in stations[id]:
			var st: String = slot["state"]
			var btn: Button = slot["btn"]
			match st:
				"empty":
					btn.text = "Masak"
				"cooking":
					btn.text = "Memasak %d%%" % int(100.0 * float(slot["t"]) / maxf(float(slot["dur"]), 0.01))
				"ready":
					btn.text = "MATANG! Ketuk (%d)" % int(ceil(BURN_WINDOW - float(slot["t"])))
				"burnt":
					btn.text = "GOSONG! Buang"
			if slot["shown"] != st:
				slot["shown"] = st
				UI.color_button(btn, slot_colors[st])


# ---------- jeda & selesai ----------
func _toggle_pause() -> void:
	if not running:
		return
	if paused:
		_close_overlay()
		return
	paused = true
	overlay = UI.overlay(self, "Jeda", [], [
		{"text": "Lanjut", "color": Color(0.15, 0.65, 0.3), "fn": _toggle_pause},
		{"text": "Ulangi", "color": Color(0.9, 0.5, 0.13), "fn": _restart},
		{"text": "Keluar ke Peta", "color": Color(0.75, 0.22, 0.17), "fn": _exit_level},
	])


func _close_overlay() -> void:
	paused = false
	if overlay != null:
		overlay.queue_free()
		overlay = null


func _restart() -> void:
	navigate.emit("gameplay", {"area": area_idx, "level": level})


func _exit_level() -> void:
	navigate.emit("level_select", {"area": area_idx})


func _next_level() -> void:
	navigate.emit("gameplay", {"area": area_idx, "level": level + 1})


func _finish() -> void:
	running = false
	var target: int = int(params["target"])
	var s := 0
	if earned >= target:
		s = 1
	if earned >= int(target * 1.4):
		s = 2
	if earned >= int(target * 1.8):
		s = 3
	GameState.finish_level(area["id"], level, s, earned)
	var title := "Level Selesai!" if s > 0 else "Belum Berhasil"
	var lines := ["Pendapatan: %d koin" % earned, "Target: %d koin" % target, "Bintang: %d / 3" % s]
	var buttons: Array = []
	if s > 0 and level + 1 < GameData.LEVELS_PER_AREA:
		buttons.append({"text": "Level Berikutnya", "color": Color(0.15, 0.65, 0.3), "fn": _next_level})
	buttons.append({"text": "Ulangi", "color": Color(0.9, 0.5, 0.13), "fn": _restart})
	buttons.append({"text": "Pilih Level", "color": Color(0.42, 0.36, 0.9), "fn": _exit_level})
	overlay = UI.overlay(self, title, lines, buttons)
