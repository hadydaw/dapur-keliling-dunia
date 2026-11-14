extends RefCounted
## Data statis: hidangan, area, dan parameter level. Konten ditambah lewat data di sini.

const LEVELS_PER_AREA := 5

const DISHES := {
	"es_teh": {"name": "Es Teh Manis", "station": "Dispenser", "cook": 3.0, "price": 15, "color": "c98b3c"},
	"nasi_goreng": {"name": "Nasi Goreng", "station": "Wajan", "cook": 6.0, "price": 30, "color": "d98c33"},
	"sate_ayam": {"name": "Sate Ayam", "station": "Panggangan", "cook": 8.0, "price": 40, "color": "a0522d"},
	"soto_ayam": {"name": "Soto Ayam", "station": "Panci", "cook": 10.0, "price": 50, "color": "e0b341"},

	"limonada": {"name": "Limonada", "station": "Dispenser", "cook": 3.0, "price": 20, "color": "8bc34a"},
	"taco": {"name": "Taco Pedas", "station": "Plancha", "cook": 6.0, "price": 45, "color": "e67e22"},
	"burrito": {"name": "Burrito", "station": "Panggangan", "cook": 8.0, "price": 60, "color": "b9770e"},
	"quesadilla": {"name": "Quesadilla", "station": "Plancha", "cook": 9.0, "price": 70, "color": "f1c40f"},

	"teh_hijau": {"name": "Teh Hijau", "station": "Dispenser", "cook": 3.0, "price": 25, "color": "7dbb6a"},
	"onigiri": {"name": "Onigiri", "station": "Kukusan", "cook": 5.0, "price": 50, "color": "ecf0f1"},
	"tempura": {"name": "Tempura", "station": "Penggorengan", "cook": 8.0, "price": 65, "color": "e59866"},
	"ramen": {"name": "Ramen", "station": "Panci", "cook": 11.0, "price": 85, "color": "d4ac0d"},

	"kopi_susu": {"name": "Kopi Susu", "station": "Mesin Kopi", "cook": 4.0, "price": 35, "color": "8e5b3a"},
	"crepe": {"name": "Crepe", "station": "Plancha", "cook": 6.0, "price": 70, "color": "f5cba7"},
	"croissant": {"name": "Croissant", "station": "Oven", "cook": 9.0, "price": 80, "color": "dc7633"},
	"sup_bawang": {"name": "Sup Bawang", "station": "Panci", "cook": 11.0, "price": 100, "color": "cba36b"},
}

const AREAS := [
	{"id": "indonesia", "name": "Warung Nusantara", "place": "Indonesia", "color": "c0392b", "stars_needed": 0,
		"dishes": ["es_teh", "nasi_goreng", "sate_ayam", "soto_ayam"]},
	{"id": "meksiko", "name": "Cantina Fiesta", "place": "Meksiko", "color": "d35400", "stars_needed": 6,
		"dishes": ["limonada", "taco", "burrito", "quesadilla"]},
	{"id": "jepang", "name": "Kedai Sakura", "place": "Jepang", "color": "c2185b", "stars_needed": 14,
		"dishes": ["teh_hijau", "onigiri", "tempura", "ramen"]},
	{"id": "prancis", "name": "Bistro Menara", "place": "Prancis", "color": "2e5eaa", "stars_needed": 24,
		"dishes": ["kopi_susu", "crepe", "croissant", "sup_bawang"]},
]


static func level_params(area_idx: int, level: int) -> Dictionary:
	var area: Dictionary = AREAS[area_idx]
	var g: int = area_idx * LEVELS_PER_AREA + level
	var all_dishes: Array = area["dishes"]
	var n: int = clampi(2 + level / 2, 2, all_dishes.size())
	var ids: Array = all_dishes.slice(0, n)
	var total_price := 0.0
	for id in ids:
		total_price += float(DISHES[id]["price"])
	var avg: float = total_price / float(n)
	var duration: float = 75.0 + level * 5.0
	var interval: float = maxf(4.5, 9.0 - g * 0.2)
	var expected: float = duration / interval
	var target: int = int(round(avg * 1.4 * expected * 0.55 / 10.0)) * 10
	return {
		"dishes": ids,
		"duration": duration,
		"spawn_interval": interval,
		"target": target,
		"patience": maxf(22.0, 42.0 - g * 0.9),
		"max_customers": 3 if g < 8 else 4,
	}
