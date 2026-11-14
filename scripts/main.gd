extends Control
## Pengatur layar. Tiap layar punya setup(params) dan signal navigate(screen, params).

const MenuScreen = preload("res://scripts/screens/menu_screen.gd")
const WorldMapScreen = preload("res://scripts/screens/world_map_screen.gd")
const LevelSelectScreen = preload("res://scripts/screens/level_select_screen.gd")
const GameData = preload("res://scripts/game_data.gd")
const GameplayScreen = preload("res://scripts/screens/gameplay_screen.gd")
const GameplaySceneScreen = preload("res://scripts/screens/gameplay_scene_screen.gd")
const RecipeBookScreen = preload("res://scripts/screens/recipe_book_screen.gd")
const ShopScreen = preload("res://scripts/screens/shop_screen.gd")

var current: Control = null


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	# Opsi uji (hanya dipakai saat dijalankan dari terminal): -- --screen=NAMA --area=N --level=N
	var screen := "menu"
	var p := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screen="):
			screen = a.substr(9)
		elif a.begins_with("--area="):
			p["area"] = int(a.substr(7))
		elif a.begins_with("--level="):
			p["level"] = int(a.substr(8))
	_go(screen, p)


func _go(screen: String, params: Dictionary) -> void:
	var s
	match screen:
		"menu": s = MenuScreen.new()
		"world_map": s = WorldMapScreen.new()
		"level_select": s = LevelSelectScreen.new()
		"gameplay":
			var aid: String = GameData.AREAS[int(params.get("area", 0))]["id"]
			if GameData.SCENES.has(aid) and not bool(params.get("classic", false)):
				s = GameplaySceneScreen.new()
			else:
				s = GameplayScreen.new()
		"recipes": s = RecipeBookScreen.new()
		"shop": s = ShopScreen.new()
		_:
			push_error("Layar tidak dikenal: " + screen)
			return
	s.setup(params)
	s.navigate.connect(_go)
	if current != null:
		current.queue_free()
	add_child(s)
	current = s


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if current != null and current.has_method("on_back"):
			current.call("on_back")
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		GameState.save_game()
		get_tree().quit()
