extends Control
## Medali level bulat. Memakai gambar assets/ui/lvl_open.png bila ada; kalau belum, digambar kode.

const TEX_PATH := "res://assets/ui/lvl_open.png"

var number: int = 1
var tex: Texture2D = null


func _ready() -> void:
	if ResourceLoader.exists(TEX_PATH):
		tex = load(TEX_PATH)


func _draw() -> void:
	var c := size * 0.5
	var r: float = minf(size.x, size.y) * 0.5
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	else:
		draw_circle(c + Vector2(0, r * 0.05), r, Color(0, 0, 0, 0.35))
		draw_circle(c, r, Color(0.62, 0.38, 0.05))
		draw_circle(c, r * 0.95, Color(1.0, 0.78, 0.2))
		draw_circle(c, r * 0.8, Color(0.85, 0.55, 0.1))
		draw_circle(c, r * 0.74, Color(0.23, 0.09, 0.063))
		draw_arc(c, r * 0.88, PI * 1.1, PI * 1.6, 24, Color(1, 0.95, 0.6, 0.8), maxf(2.0, r * 0.05))
	var font: Font = load("res://assets/fonts/game_font.tres")
	var fs: int = int(r * (0.85 if number >= 10 else 1.05))   # dua angka sedikit lebih kecil agar muat
	var txt := str(number)
	var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	# angka lurus (tinggi huruf besar ~0,7 em): pusat visual = garis dasar - 0,35 em
	var pos := Vector2(c.x - ts.x * 0.5, c.y + fs * 0.35)
	draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(maxf(4.0, r * 0.12)), Color(0.15, 0.05, 0.02))
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.95, 0.75))
