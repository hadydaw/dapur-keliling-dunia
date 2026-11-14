extends Control
## Ikon bintang bergaya game, digambar kode (emas bila penuh, redup bila kosong).

var filled: bool = true


func _draw() -> void:
	var c := size * 0.5
	var r: float = minf(size.x, size.y) * 0.5
	var pts := PackedVector2Array()
	for i in 10:
		var ang: float = -PI / 2.0 + i * PI / 5.0
		var rad: float = r if i % 2 == 0 else r * 0.46
		pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	var fill := Color(1.0, 0.82, 0.2) if filled else Color(0.28, 0.2, 0.16)
	var edge := Color(0.62, 0.38, 0.05) if filled else Color(0.15, 0.1, 0.08)
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, edge, maxf(2.0, r * 0.12), true)
	if filled:
		draw_circle(c + Vector2(-r * 0.15, -r * 0.2), r * 0.16, Color(1, 1, 0.8, 0.7))
