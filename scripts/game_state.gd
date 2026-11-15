extends Node
## Autoload "GameState": koin, bintang, upgrade, buku resep. Disimpan sebagai JSON.

const GameData = preload("res://scripts/game_data.gd")
const SAVE_PATH := "user://save.json"

const UPGRADES := {
	"slots": {"name": "Slot Masak Tambahan", "desc": "+1 slot di setiap alat masak", "max": 2, "base": 300},
	"speed": {"name": "Api Besar", "desc": "Masak 10% lebih cepat", "max": 3, "base": 200},
	"patience": {"name": "Kursi Empuk", "desc": "Pelanggan 15% lebih sabar", "max": 3, "base": 150},
	"price": {"name": "Menu Premium", "desc": "Harga jual naik 10%", "max": 3, "base": 250},
}

var coins: int = 0
var stars: Dictionary = {}
var upgrades: Dictionary = {"slots": 0, "speed": 0, "patience": 0, "price": 0}
var served_count: Dictionary = {}


func _ready() -> void:
	load_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# --- bintang & level ---
func get_stars(area_id: String, level: int) -> int:
	return int(stars.get("%s_%d" % [area_id, level], 0))


func area_stars(area_idx: int) -> int:
	var id: String = GameData.AREAS[area_idx]["id"]
	var total := 0
	for l in GameData.LEVELS_PER_AREA:
		total += get_stars(id, l)
	return total


func total_stars() -> int:
	var total := 0
	for i in GameData.AREAS.size():
		total += area_stars(i)
	return total


## Area pertama selalu terbuka; area berikutnya terbuka setelah level terakhir area sebelumnya selesai.
func area_unlocked(area_idx: int) -> bool:
	if area_idx <= 0:
		return true
	var prev: String = GameData.AREAS[area_idx - 1]["id"]
	return get_stars(prev, GameData.LEVELS_PER_AREA - 1) >= 1


func level_unlocked(area_idx: int, level: int) -> bool:
	if level == 0:
		return true
	var id: String = GameData.AREAS[area_idx]["id"]
	return get_stars(id, level - 1) >= 1


func finish_level(area_id: String, level: int, star_count: int, earned: int) -> void:
	var key := "%s_%d" % [area_id, level]
	stars[key] = maxi(int(stars.get(key, 0)), star_count)
	coins += earned
	save_game()


func record_served(dish_id: String) -> void:
	served_count[dish_id] = int(served_count.get(dish_id, 0)) + 1


# --- upgrade ---
func upgrade_level(key: String) -> int:
	return int(upgrades.get(key, 0))


func upgrade_cost(key: String) -> int:
	return int(UPGRADES[key]["base"]) * (upgrade_level(key) + 1)


func can_buy(key: String) -> bool:
	return upgrade_level(key) < int(UPGRADES[key]["max"]) and coins >= upgrade_cost(key)


func buy(key: String) -> bool:
	if not can_buy(key):
		return false
	coins -= upgrade_cost(key)
	upgrades[key] = upgrade_level(key) + 1
	save_game()
	return true


func slots_per_station() -> int:
	return 1 + upgrade_level("slots")


func cook_mult() -> float:
	return 1.0 - 0.1 * upgrade_level("speed")


func patience_mult() -> float:
	return 1.0 + 0.15 * upgrade_level("patience")


func price_mult() -> float:
	return 1.0 + 0.1 * upgrade_level("price")


# --- simpan & muat ---
func reset_all() -> void:
	coins = 0
	stars = {}
	upgrades = {"slots": 0, "speed": 0, "patience": 0, "price": 0}
	served_count = {}
	save_game()


func save_game() -> void:
	var data := {"v": 1, "coins": coins, "stars": stars, "upgrades": upgrades, "served": served_count}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Gagal menyimpan: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	coins = int(parsed.get("coins", 0))
	stars = {}
	var s: Dictionary = parsed.get("stars", {})
	for k in s:
		stars[k] = int(s[k])
	var u: Dictionary = parsed.get("upgrades", {})
	for k in upgrades:
		upgrades[k] = int(u.get(k, 0))
	served_count = {}
	var sc: Dictionary = parsed.get("served", {})
	for k in sc:
		served_count[k] = int(sc[k])
