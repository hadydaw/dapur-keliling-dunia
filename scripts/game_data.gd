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

# Latar per area + titik ketuk (koordinat piksel area inti 1672x941; gambar latar diperlebar `pad` px tiap sisi).
const SCENES := {
	"indonesia": {
		"image": "res://assets/scene_indonesia.jpg",
		"size": Vector2(1672, 941),   # area inti (piksel koordinat data)
		"pad": 230.0,                  # perluasan latar di kiri & kanan inti (gambar lebar 2132 px)
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
		# HUD: bingkai = aset di assets/hud/ (dari desain HUD user); teks/angka digambar game.
		# "w" = lebar sprite (piksel area inti) pada skala penuh; tinggi mengikuti rasio gambar.
		# "inner" = area isi (cokelat/krem) sebagai pecahan dari ukuran sprite.
		# "banner" = rentang x emblem tengah-atas (bagian latar) yang tidak boleh ditabrak HUD.
		"hud": {
			"banner": Vector2(655, 1015),
			"margin": 10.0,
			"gap": 10.0,
			"sprites": {
				"cluster": {"img": "res://assets/hud/cluster.png", "w": 300.0},
				"pill": {"img": "res://assets/hud/pill.png", "w": 220.0},
				"pillgear": {"img": "res://assets/hud/pillgear.png", "w": 300.0},
				"tile": {"img": "res://assets/hud/tile.png", "w": 92.0},
				"panel": {"img": "res://assets/hud/panel.png", "w": 310.0},
			},
			"inner": {
				"cluster_circle": Rect2(0.038, 0.172, 0.262, 0.714),
				"cluster_s1": Rect2(0.309, 0.231, 0.606, 0.258),
				"cluster_s2": Rect2(0.312, 0.588, 0.606, 0.205),
				"pill": Rect2(0.11, 0.2, 0.78, 0.6),
				"pillgear_bar": Rect2(0.07, 0.27, 0.68, 0.46),
				"pillgear_ring": Rect2(0.775, 0.05, 0.22, 0.9),
				"tile": Rect2(0.1, 0.2, 0.8, 0.6),
				"panel_head": Rect2(0.06, 0.085, 0.88, 0.16),
				"panel_body": Rect2(0.06, 0.31, 0.88, 0.62),
			},
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


# Latar versi lebar (20:9, gambar 1870x841) untuk layar >= WIDE_MIN_ASPECT. Bagian yang tidak
# disebut di sini diwarisi dari SCENES[id]. Koordinat = piksel gambar lebar.
const WIDE_MIN_ASPECT := 2.14
const SCENES_WIDE := {
	"indonesia": {
		"image": "res://assets/scene_indonesia_wide.jpg",
		"size": Vector2(1870, 841),
		"pad": 0.0,
		"cover": true,          # latar memenuhi layar (potongan sangat kecil bila rasio sedikit berbeda)
		"ui_k": 0.894,           # skala elemen UI (gelembung, HUD) agar ukuran di layar sama dengan versi 16:9
		"toast_y": 618.0,
		"customer_spots": [Vector2(340, 372), Vector2(650, 372), Vector2(960, 372), Vector2(1270, 372)],
		"customer_height": 205.0,
		"counter_mask": [
			Vector2(250, 322), Vector2(268, 340), Vector2(287, 366), Vector2(298, 376), Vector2(305, 368), Vector2(585, 367),
			Vector2(588, 384), Vector2(590, 335), Vector2(600, 324), Vector2(606, 312), Vector2(612, 324), Vector2(624, 335), Vector2(627, 362),
			Vector2(645, 350), Vector2(675, 330), Vector2(691, 310), Vector2(710, 300), Vector2(730, 297), Vector2(760, 300), Vector2(785, 320),
			Vector2(795, 330), Vector2(810, 337), Vector2(832, 347), Vector2(847, 362),
			Vector2(853, 378), Vector2(857, 335), Vector2(866, 324), Vector2(872, 312), Vector2(879, 324), Vector2(890, 335), Vector2(894, 380),
			Vector2(900, 384), Vector2(903, 380), Vector2(906, 336), Vector2(916, 325), Vector2(922, 314), Vector2(929, 325), Vector2(940, 336), Vector2(944, 370),
			Vector2(947, 367), Vector2(975, 350), Vector2(1000, 330), Vector2(1020, 310), Vector2(1045, 300), Vector2(1070, 297), Vector2(1100, 305),
			Vector2(1120, 320), Vector2(1135, 332), Vector2(1160, 342), Vector2(1178, 340), Vector2(1186, 330), Vector2(1194, 320), Vector2(1202, 312),
			Vector2(1210, 320), Vector2(1220, 330), Vector2(1226, 372), Vector2(1230, 372), Vector2(1525, 370), Vector2(1775, 372),
			Vector2(1830, 500), Vector2(1870, 841), Vector2(250, 841)],
		"rect_k": {"grill": 0.95, "plate": 0.9, "wok": 1.12, "pot": 1.0, "bowl": 0.95},
		"hud": {
			"banner": Vector2(757, 1112),
			"margin": 9.0,
			"gap": 9.0,
			"sprite_w": {"cluster": 268.0, "pill": 197.0, "pillgear": 268.0, "tile": 82.0, "panel": 277.0},
		},
		"appliances": {
			"dispenser": {"r": 30.0, "points": [Vector2(133, 468), Vector2(188, 468), Vector2(245, 468)]},
			"grill": {"r": 38.0, "points": [Vector2(352, 402), Vector2(447, 402), Vector2(533, 402),
				Vector2(345, 467), Vector2(440, 467), Vector2(530, 467)]},
			"plate": {"r": 38.0, "points": [Vector2(657, 411), Vector2(744, 411), Vector2(830, 411),
				Vector2(654, 473), Vector2(745, 473), Vector2(836, 473)]},
			"bowl": {"r": 38.0, "points": [Vector2(967, 407), Vector2(1060, 407), Vector2(1147, 407),
				Vector2(970, 470), Vector2(1069, 470), Vector2(1157, 470)]},
			"wok": {"r": 58.0, "points": [Vector2(1307, 388), Vector2(1450, 388), Vector2(1320, 443), Vector2(1468, 445)]},
			"pot": {"r": 52.0, "points": [Vector2(1595, 372), Vector2(1712, 370), Vector2(1625, 440), Vector2(1745, 442)]},
		},
		"dispenser": {
			"hot": Rect2(120, 325, 150, 112),
			"timer": Vector2(198, 390),
			"full_image": "res://assets/scene/indo_dispenser_penuh.png",
			"full_pos": Vector2(102, 272),
			"glass_images": ["res://assets/scene/indo_gelas_0.png", "res://assets/scene/indo_gelas_1.png", "res://assets/scene/indo_gelas_2.png"],
			"glass_pos": [Vector2(93, 420), Vector2(148, 420), Vector2(205, 420)],
		},
		"ingredients": {
			"es": {"name": "Es Batu", "rect": Rect2(155, 625, 235, 140)},
			"nasi": {"name": "Nasi", "rect": Rect2(420, 625, 200, 135)},
			"tusuk_ayam": {"name": "Tusuk Sate Ayam", "rect": Rect2(905, 630, 155, 140)},
			"ayam": {"name": "Ayam", "rect": Rect2(1090, 630, 305, 140)},
			"ikan": {"name": "Ikan", "rect": Rect2(1420, 630, 320, 140)},
		},
	},
}


## Pilih definisi scene menurut rasio layar (lebar/tinggi). Layar >= WIDE_MIN_ASPECT memakai
## latar lebar bila tersedia; selain itu latar 16:9 (diperlebar `pad`).
static func scene_for(area_id: String, aspect: float) -> Dictionary:
	var base: Dictionary = SCENES[area_id]
	if aspect < WIDE_MIN_ASPECT or not SCENES_WIDE.has(area_id):
		return base
	var s: Dictionary = base.duplicate(true)
	var w: Dictionary = SCENES_WIDE[area_id]
	for k in w:
		if k == "hud" or k == "customer_height":
			continue
		s[k] = w[k]
	s["customer_art"]["height"] = float(w["customer_height"])
	for k in w["hud"]:
		if k == "sprite_w":
			for nm in w["hud"]["sprite_w"]:
				s["hud"]["sprites"][nm]["w"] = w["hud"]["sprite_w"][nm]
		else:
			s["hud"][k] = w["hud"][k]
	s["wide"] = true
	return s


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
