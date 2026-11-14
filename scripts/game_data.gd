extends RefCounted
## Data statis: hidangan, area, dan parameter level. Konten ditambah lewat data di sini.

const LEVELS_PER_AREA := 5

const DISHES := {
	"es_teh": {"name": "Es Teh Manis", "station": "Dispenser", "cook": 3.0, "price": 15, "color": "c98b3c"},
	"nasi_goreng": {"name": "Nasi Goreng", "station": "Wajan", "cook": 6.0, "price": 30, "color": "d98c33"},
	"sate_ayam": {"name": "Sate Ayam", "station": "Panggangan", "cook": 8.0, "price": 40, "color": "a0522d"},
	"soto_ayam": {"name": "Soto Ayam", "station": "Panci", "cook": 10.0, "price": 50, "color": "e0b341"},
	"ikan_bakar": {"name": "Ikan Bakar", "station": "Panggangan", "cook": 9.0, "price": 60, "color": "8fa3ad"},

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
		"dishes": ["es_teh", "nasi_goreng", "sate_ayam", "soto_ayam", "ikan_bakar"]},
	{"id": "meksiko", "name": "Cantina Fiesta", "place": "Meksiko", "color": "d35400", "stars_needed": 6,
		"dishes": ["limonada", "taco", "burrito", "quesadilla"]},
	{"id": "jepang", "name": "Kedai Sakura", "place": "Jepang", "color": "c2185b", "stars_needed": 14,
		"dishes": ["teh_hijau", "onigiri", "tempura", "ramen"]},
	{"id": "prancis", "name": "Bistro Menara", "place": "Prancis", "color": "2e5eaa", "stars_needed": 24,
		"dishes": ["kopi_susu", "crepe", "croissant", "sup_bawang"]},
]


# Ekspresi pelanggan menurut sisa kesabaran (0..1).
const MOOD_HAPPY_ABOVE := 0.55
const MOOD_ANGRY_BELOW := 0.25

# Resep gaya Cooking Madness: bahan (rak bawah) -> alat masak -> wadah saji -> pelanggan.
# "serve" kosong = disajikan langsung dari alatnya (gelas es teh). "burns": false = tidak gosong.
const RECIPES := {
	"es_teh": {"ingredient": "es", "appliance": "dispenser", "serve": "", "burns": false, "refill": true},
	"nasi_goreng": {"ingredient": "nasi", "appliance": "wok", "serve": "plate"},
	"sate_ayam": {"ingredient": "tusuk_ayam", "appliance": "grill", "serve": "plate"},
	"soto_ayam": {"ingredient": "ayam", "appliance": "pot", "serve": "bowl"},
	"ikan_bakar": {"ingredient": "ikan", "appliance": "grill", "serve": "plate"},
}

# Dispenser: ketuk es mengisi penuh (JAR_FILL_TIME detik), tiap gelas mengurangi 1 porsi.
const JAR_CAPACITY := 4
const JAR_FILL_TIME := 3.0

const APPLIANCE_NAMES := {
	"dispenser": "Gelas", "grill": "Panggangan", "wok": "Wajan", "pot": "Panci",
	"plate": "Piring", "bowl": "Mangkuk",
}

# Latar per area + titik ketuk (koordinat piksel gambar latar 1672x941).
const SCENES := {
	"indonesia": {
		"image": "res://assets/scene_indonesia.jpg",
		"size": Vector2(1672, 941),
		# Pelanggan berdiri di celah antar alat masak (kaki = garis konter), kepala + bahu terlihat.
		"customer_spots": [Vector2(505, 402), Vector2(800, 402), Vector2(1190, 402), Vector2(1466, 402)],
		"customer_art": {
			"senang": "res://assets/customers/pria_batik_senang.png",
			"biasa": "res://assets/customers/pria_batik_biasa.png",
			"marah": "res://assets/customers/pria_batik_marah.png",
			"height": 168.0,      # tinggi gambar di latar (piksel gambar latar)
		},
		"appliances": {
			"dispenser": {"r": 30.0, "points": [Vector2(66, 556), Vector2(120, 556), Vector2(176, 556)]},
			"grill": {"r": 36.0, "points": [Vector2(283, 472), Vector2(370, 472), Vector2(452, 472),
				Vector2(272, 548), Vector2(364, 548), Vector2(455, 548)]},
			"plate": {"r": 38.0, "points": [Vector2(568, 484), Vector2(655, 484), Vector2(735, 484),
				Vector2(568, 557), Vector2(655, 557), Vector2(738, 557)]},
			"bowl": {"r": 36.0, "points": [Vector2(855, 481), Vector2(943, 481), Vector2(1030, 481),
				Vector2(860, 553), Vector2(950, 553), Vector2(1045, 553)]},
			"wok": {"r": 52.0, "points": [Vector2(1170, 442), Vector2(1305, 445), Vector2(1185, 523), Vector2(1325, 525)]},
			"pot": {"r": 48.0, "points": [Vector2(1445, 440), Vector2(1555, 438), Vector2(1470, 515), Vector2(1580, 518)]},
		},
		"dispenser": {
			"hot": Rect2(62, 372, 148, 152),      # area ketuk dispenser
			"timer": Vector2(130, 452),            # pusat timer jam pasir di dispenser
			"full_image": "res://assets/scene/indo_dispenser_penuh.png",
			"full_pos": Vector2(34, 360),
			"glass_images": ["res://assets/scene/indo_gelas_0.png", "res://assets/scene/indo_gelas_1.png", "res://assets/scene/indo_gelas_2.png"],
			"glass_pos": [Vector2(24, 510), Vector2(79, 510), Vector2(135, 510)],
		},
		"ingredients": {
			"es": {"name": "Es Batu", "rect": Rect2(105, 735, 225, 150)},
			"nasi": {"name": "Nasi", "rect": Rect2(355, 740, 205, 145)},
			"tusuk_ayam": {"name": "Tusuk Sate Ayam", "rect": Rect2(815, 740, 135, 140)},
			"ayam": {"name": "Ayam", "rect": Rect2(975, 735, 280, 145)},
			"ikan": {"name": "Ikan", "rect": Rect2(1285, 735, 285, 145)},
		},
	},
}


static func level_params(area_idx: int, level: int) -> Dictionary:
	var area: Dictionary = AREAS[area_idx]
	var g: int = area_idx * LEVELS_PER_AREA + level
	var all_dishes: Array = area["dishes"]
	var n: int = clampi(2 + level / 2, 2, all_dishes.size())
	if all_dishes.size() >= 5 and level >= LEVELS_PER_AREA - 1:
		n = all_dishes.size()  # menu kelima dibuka di level terakhir
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
