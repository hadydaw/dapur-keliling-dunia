extends Control
## Pengatur layar. Tiap layar punya setup(params) dan signal navigate(screen, params).

const MenuScreen = preload("res://scripts/screens/menu_screen.gd")
const WorldMapScreen = preload("res://scripts/screens/world_map_screen.gd")
const LevelSelectScreen = preload("res://scripts/screens/level_select_screen.gd")
const GameplayScreen = preload("res://scripts/screens/gameplay_screen.gd")
const RecipeBookScreen = preload("res://scripts/screens/recipe_book_screen.gd")
const ShopScreen = preload("res://scripts/screens/shop_screen.gd")

var current: Control = null


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	_go("menu", {})


func _go(screen: String, params: Dictionary) -> void:
	var s
	match screen:
		"menu": s = MenuScreen.new()
		"world_map": s = WorldMapScreen.new()
		"level_select": s = LevelSelectScreen.new()
		"gameplay": s = GameplayScreen.new()
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
