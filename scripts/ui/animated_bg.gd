extends Control
## Latar menu beranimasi: satu gambar + lapisan efek (uap, kilau lentera, lampu, api, gerak kamera).
## Titik efek ditulis dalam koordinat gambar (0..1) supaya tetap pas di rasio layar apa pun.

const TEX := preload("res://assets/menu_bg.jpg")

const LANTERNS := [Vector2(0.1465, 0.074), Vector2(0.1926, 0.218)]
const BULBS := [Vector2(0.511, 0.040), Vector2(0.565, 0.069), Vector2(0.4575, 0.085),
	Vector2(0.681, 0.011), Vector2(0.743, 0.013), Vector2(0.622, 0.045)]
const FIRE := Vector2(0.095, 0.63)
const SUN := Vector2(0.628, 0.377)
const STEAM := [Vector2(0.066, 0.47), Vector2(0.251, 0.50), Vector2(0.7775, 0.53)]

var t: float = 0.0
var glow_tex: GradientTexture2D
var glow_layer: Control
var steam_nodes: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	glow_tex = GradientTexture2D.new()
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	glow_tex.width = 128
	glow_tex.height = 128
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	glow_tex.gradient = g

	glow_layer = Control.new()
	glow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = mat
	add_child(glow_layer)
	glow_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow_layer.draw.connect(_draw_glows)

	for i in STEAM.size():
		var p := CPUParticles2D.new()
		p.texture = glow_tex
		p.amount = 14
		p.lifetime = 3.2
		p.preprocess = 3.0
		p.direction = Vector2(0, -1)
		p.spread = 22.0
		p.gravity = Vector2(6, -14)
		p.initial_velocity_min = 18.0
		p.initial_velocity_max = 36.0
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.1
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 0.97, 0.92, 0.22), Color(1, 1, 1, 0.0)])
		ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		p.color_ramp = ramp
		add_child(p)
		steam_nodes.append(p)
	resized.connect(_layout_steam)
	_layout_steam()


## Pemetaan koordinat gambar (0..1) -> piksel layar, mode "cover" + zoom pelan.
func _map() -> Dictionary:
	var iw: float = TEX.get_width()
	var ih: float = TEX.get_height()
	var s: float = maxf(size.x / iw, size.y / ih) * (1.04 + 0.012 * sin(t * 0.25))
	var draw_size := Vector2(iw, ih) * s
	var off := (size - draw_size) * 0.5 + Vector2(sin(t * 0.18) * 6.0, 0.0)
	return {"s": s, "off": off, "size": draw_size}


func _to_screen(p: Vector2) -> Vector2:
	var m := _map()
	return m["off"] + p * (m["size"] as Vector2)


func _layout_steam() -> void:
	for i in steam_nodes.size():
		steam_nodes[i].position = _to_screen(STEAM[i])


func _process(delta: float) -> void:
	t += delta
	_layout_steam()
	queue_redraw()
	glow_layer.queue_redraw()


func _draw() -> void:
	var m := _map()
	draw_texture_rect(TEX, Rect2(m["off"], m["size"]), false)


func _glow(center: Vector2, radius: float, color: Color) -> void:
	glow_layer.draw_texture_rect(glow_tex, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


func _draw_glows() -> void:
	var m := _map()
	var k: float = m["s"] * 0.6
	for i in LANTERNS.size():
		var pulse: float = 0.5 + 0.5 * sin(t * 1.6 + i * 1.9)
		_glow(_to_screen(LANTERNS[i]), 70.0 * k * (1.0 + 0.1 * pulse), Color(1.0, 0.45, 0.15, 0.22 + 0.16 * pulse))
	for i in BULBS.size():
		var tw: float = 0.5 + 0.5 * sin(t * (2.2 + i * 0.37) + i * 2.3)
		_glow(_to_screen(BULBS[i]), 34.0 * k, Color(1.0, 0.85, 0.5, 0.15 + 0.4 * tw))
	var flick: float = 0.6 + 0.4 * sin(t * 11.0) * sin(t * 5.3 + 1.0)
	_glow(_to_screen(FIRE), 90.0 * k, Color(1.0, 0.5, 0.1, 0.18 + 0.22 * flick))
	_glow(_to_screen(SUN), 120.0 * k, Color(1.0, 0.7, 0.4, 0.14 + 0.05 * sin(t * 0.7)))
