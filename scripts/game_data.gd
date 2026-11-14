extends RefCounted
## Data statis: hidangan, area, dan parameter level. Konten ditambah lewat data di sini.

const LEVELS_PER_AREA := 5

const DISHES := {
	"es_teh": {"name": "Es Teh Manis", "station": "Dispenser", "cook": 3.0, "price": 15, "color": "c98b3c", "icon": "res://assets/icons/es_teh.png"},
	"nasi_goreng": {"name": "Nasi Goreng", "station": "Wajan", "cook": 6.0, "price": 30, "color": "d98c33", "icon": "res://assets/icons/nasi_goreng.png"},
	"sate_ayam": {"name": "Sate Ayam", "station": "Panggangan", "cook": 8.0, "price": 40, "color": "a0522d", "icon": "res://assets/icons/sate_ayam.png"},
	"soto_ayam": {"name": "Soto Ayam", "station": "Panci", "cook": 10.0, "price": 50, "color": "e0b341", "icon": "res://assets/icons/soto_ayam.png"},
	"ikan_bakar": {"name": "Ikan Bakar", "station": "Panggangan", "cook": 9.0, "price": 60, "color": "8fa3ad", "icon": "res://assets/icons/ikan_bakar.png"},

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
		"customer_spots": [Vector2(316, 426), Vector2(611, 426), Vector2(906, 426), Vector2(1202, 426)],
		# siluet bagian atas konter (piksel gambar latar); menimpa pelanggan agar mereka
		# tampak berdiri di belakang konter, bukan terpotong.
		"counter_mask": [
			Vector2(215, 428), Vector2(380, 428), Vector2(500, 428), Vector2(502, 396), Vector2(512, 378), Vector2(523, 371), Vector2(535, 378), Vector2(545, 398),
			Vector2(562, 400), Vector2(600, 374), Vector2(650, 352), Vector2(700, 372), Vector2(745, 398), Vector2(755, 392),
			Vector2(762, 376), Vector2(770, 371), Vector2(780, 378), Vector2(790, 396), Vector2(797, 392), Vector2(806, 376),
			Vector2(815, 371), Vector2(825, 378), Vector2(832, 408), Vector2(880, 388), Vector2(950, 365), Vector2(1000, 385),
			Vector2(1040, 402), Vector2(1052, 395), Vector2(1060, 378), Vector2(1070, 372), Vector2(1080, 378), Vector2(1092, 400),
			Vector2(1100, 425), Vector2(1115, 412), Vector2(1380, 410), Vector2(1400, 405), Vector2(1600, 408), Vector2(1672, 412),
			Vector2(1672, 941), Vector2(380, 941)],
		# gambar tahap masakan per slot (potongan latar, satu per slot); tanpa gambar -> lingkaran berhuruf.
		# "rects": area potongan relatif terhadap pusat slot (piksel gambar latar).
		"stage_art": {
			"rects": {"grill": Rect2(-46, -46, 92, 98), "plate": Rect2(-50, -42, 104, 78), "wok": Rect2(-62, -34, 124, 68), "pot": Rect2(-58, -34, 116, 68), "bowl": Rect2(-50, -40, 100, 76)},
			"ikan_bakar": {
				"rects": {"grill": Rect2(-52, -36, 104, 76), "plate": Rect2(-52, -44, 108, 82)},   # lebih lebar dari sate
				"cooking": ["res://assets/scene/ikan/cooking_0.png", "res://assets/scene/ikan/cooking_1.png", "res://assets/scene/ikan/cooking_2.png", "res://assets/scene/ikan/cooking_3.png", "res://assets/scene/ikan/cooking_4.png", "res://assets/scene/ikan/cooking_5.png"],
				"ready": ["res://assets/scene/ikan/ready_0.png", "res://assets/scene/ikan/ready_1.png", "res://assets/scene/ikan/ready_2.png", "res://assets/scene/ikan/ready_3.png", "res://assets/scene/ikan/ready_4.png", "res://assets/scene/ikan/ready_5.png"],
				"burnt": ["res://assets/scene/ikan/burnt_0.png", "res://assets/scene/ikan/burnt_1.png", "res://assets/scene/ikan/burnt_2.png", "res://assets/scene/ikan/burnt_3.png", "res://assets/scene/ikan/burnt_4.png", "res://assets/scene/ikan/burnt_5.png"],
				"full": ["res://assets/scene/ikan/full_0.png", "res://assets/scene/ikan/full_1.png", "res://assets/scene/ikan/full_2.png", "res://assets/scene/ikan/full_3.png", "res://assets/scene/ikan/full_4.png", "res://assets/scene/ikan/full_5.png"],
			},
			"soto_ayam": {
				"cooking": ["res://assets/scene/soto/cooking_0.png", "res://assets/scene/soto/cooking_1.png", "res://assets/scene/soto/cooking_2.png", "res://assets/scene/soto/cooking_3.png"],
				"ready": ["res://assets/scene/soto/ready_0.png", "res://assets/scene/soto/ready_1.png", "res://assets/scene/soto/ready_2.png", "res://assets/scene/soto/ready_3.png"],
				"burnt": ["res://assets/scene/soto/burnt_0.png", "res://assets/scene/soto/burnt_1.png", "res://assets/scene/soto/burnt_2.png", "res://assets/scene/soto/burnt_3.png"],
				"full": ["res://assets/scene/soto/full_0.png", "res://assets/scene/soto/full_1.png", "res://assets/scene/soto/full_2.png", "res://assets/scene/soto/full_3.png", "res://assets/scene/soto/full_4.png", "res://assets/scene/soto/full_5.png"],
			},
			"nasi_goreng": {
				"cooking": ["res://assets/scene/nasi/cooking_0.png", "res://assets/scene/nasi/cooking_1.png", "res://assets/scene/nasi/cooking_2.png", "res://assets/scene/nasi/cooking_3.png"],
				"ready": ["res://assets/scene/nasi/ready_0.png", "res://assets/scene/nasi/ready_1.png", "res://assets/scene/nasi/ready_2.png", "res://assets/scene/nasi/ready_3.png"],
				"burnt": ["res://assets/scene/nasi/burnt_0.png", "res://assets/scene/nasi/burnt_1.png", "res://assets/scene/nasi/burnt_2.png", "res://assets/scene/nasi/burnt_3.png"],
				"full": ["res://assets/scene/nasi/full_0.png", "res://assets/scene/nasi/full_1.png", "res://assets/scene/nasi/full_2.png", "res://assets/scene/nasi/full_3.png", "res://assets/scene/nasi/full_4.png", "res://assets/scene/nasi/full_5.png"],
			},
			"sate_ayam": {
				"cooking": ["res://assets/scene/sate/cooking_0.png", "res://assets/scene/sate/cooking_1.png", "res://assets/scene/sate/cooking_2.png", "res://assets/scene/sate/cooking_3.png", "res://assets/scene/sate/cooking_4.png", "res://assets/scene/sate/cooking_5.png"],
				"ready": ["res://assets/scene/sate/ready_0.png", "res://assets/scene/sate/ready_1.png", "res://assets/scene/sate/ready_2.png", "res://assets/scene/sate/ready_3.png", "res://assets/scene/sate/ready_4.png", "res://assets/scene/sate/ready_5.png"],
				"burnt": ["res://assets/scene/sate/burnt_0.png", "res://assets/scene/sate/burnt_1.png", "res://assets/scene/sate/burnt_2.png", "res://assets/scene/sate/burnt_3.png", "res://assets/scene/sate/burnt_4.png", "res://assets/scene/sate/burnt_5.png"],
				"full": ["res://assets/scene/sate/full_0.png", "res://assets/scene/sate/full_1.png", "res://assets/scene/sate/full_2.png", "res://assets/scene/sate/full_3.png", "res://assets/scene/sate/full_4.png", "res://assets/scene/sate/full_5.png"],
			},
		},
		# Bingkai HUD ikut tergambar di latar (kosong); teks/angka digambar game di atasnya.
		# Semua dalam piksel gambar latar.
		"hud": {
			"avatar": Rect2(24, 20, 84, 84),
			"strip1": Rect2(124, 24, 114, 26),
			"strip2": Rect2(124, 68, 114, 26),
			"pills": [Rect2(268, 20, 182, 40), Rect2(470, 20, 170, 40), Rect2(1142, 20, 200, 40), Rect2(1376, 20, 190, 40)],
			"gear": Rect2(1588, 12, 68, 68),
			"squares": [Rect2(20, 134, 83, 86), Rect2(20, 234, 83, 82)],
			"panel_head": Rect2(1408, 110, 236, 36),
			"panel_body": Rect2(1408, 158, 236, 142),
		},
		"customer_art": {
			"senang": "res://assets/customers/pria_batik_senang.png",
			"biasa": "res://assets/customers/pria_batik_biasa.png",
			"marah": "res://assets/customers/pria_batik_marah.png",
			"height": 215.0,      # tinggi gambar di latar (piksel gambar latar)
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
