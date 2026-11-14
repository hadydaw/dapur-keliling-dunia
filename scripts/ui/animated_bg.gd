extends Control
## Latar menu: gambar penuh (mode "contain", sisi sisa diisi versi gelap gambar yang sama)
## + efek kode (uap, kilau lentera/lampu/api). Koordinat efek dan tombol dalam koordinat gambar (0..1).

const TEX := preload("res://assets/menu_bg.jpg")
## Video latar (loop mulus, 4 detik). Bila ada, efek kode (uap/kilau) dimatikan agar tidak dobel.
const VIDEO_PATH := "res://assets/menu_bg.ogv"

const LANTERNS := [Vector2(0.142, 0.105), Vector2(0.187, 0.218)]
const BULBS := [Vector2(0.511, 0.040), Vector2(0.565, 0.069), Vector2(0.4575, 0.085),
	Vector2(0.681, 0.011), Vector2(0.743, 0.013), Vector2(0.622, 0.045), Vector2(0.43, 0.02)]
const FIRE := Vector2(0.095, 0.63)
const STEAM := [Vector2(0.066, 0.47), Vector2(0.251, 0.50), Vector2(0.7775, 0.53), Vector2(0.508, 0.45)]

var t: float = 0.0
var glow_tex: GradientTexture2D
var glow_layer: Control
var steam_nodes: Array = []
var video: VideoStreamPlayer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if ResourceLoader.exists(VIDEO_PATH):
		video = VideoStreamPlayer.new()
		video.stream = load(VIDEO_PATH)
		video.loop = true
		video.expand = true
		video.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(video)
		video.play()
		resized.connect(_layout_video)
		_layout_video()
		return
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
		p.amount = 12
		p.lifetime = 3.2
		p.preprocess = 3.0
		p.direction = Vector2(0, -1)
		p.spread = 22.0
		p.gravity = Vector2(6, -14)
		p.initial_velocity_min = 18.0
		p.initial_velocity_max = 36.0
		p.scale_amount_min = 0.4
		p.scale_amount_max = 0.9
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 0.97, 0.92, 0.2), Color(1, 1, 1, 0.0)])
		ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		p.color_ramp = ramp
		add_child(p)
		steam_nodes.append(p)
	resized.connect(_layout_steam)
	_layout_steam()


## Skala "contain": seluruh gambar terlihat, tidak ada yang terpotong.
func image_scale() -> float:
	return minf(size.x / TEX.get_width(), size.y / TEX.get_height())


func image_rect() -> Rect2:
	var draw_size := Vector2(TEX.get_width(), TEX.get_height()) * image_scale()
	return Rect2((size - draw_size) * 0.5, draw_size)


func to_screen(p: Vector2) -> Vector2:
	var r := image_rect()
	return r.position + p * r.size


func rect_to_screen(r: Rect2) -> Rect2:
	var a := to_screen(r.position)
	var b := to_screen(r.position + r.size)
	return Rect2(a, b - a)


func _layout_video() -> void:
	var r := image_rect()
	video.position = r.position
	video.size = r.size


func _layout_steam() -> void:
	for i in steam_nodes.size():
		steam_nodes[i].position = to_screen(STEAM[i])


func _process(delta: float) -> void:
	if video != null:
		return
	t += delta
	queue_redraw()
	glow_layer.queue_redraw()


func _draw() -> void:
	# isi sisi sisa dengan versi "cover" yang digelapkan
	var cover: float = maxf(size.x / TEX.get_width(), size.y / TEX.get_height())
	var cs := Vector2(TEX.get_width(), TEX.get_height()) * cover
	draw_texture_rect(TEX, Rect2((size - cs) * 0.5, cs), false, Color(0.4, 0.35, 0.45))
	draw_texture_rect(TEX, image_rect(), false)


func _glow(center: Vector2, radius: float, color: Color) -> void:
	glow_layer.draw_texture_rect(glow_tex, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


func _draw_glows() -> void:
	var k: float = image_scale() * 0.6
	for i in LANTERNS.size():
		var pulse: float = 0.5 + 0.5 * sin(t * 1.6 + i * 1.9)
		_glow(to_screen(LANTERNS[i]), 70.0 * k * (1.0 + 0.1 * pulse), Color(1.0, 0.45, 0.15, 0.2 + 0.14 * pulse))
	for i in BULBS.size():
		var tw: float = 0.5 + 0.5 * sin(t * (2.2 + i * 0.37) + i * 2.3)
		_glow(to_screen(BULBS[i]), 34.0 * k, Color(1.0, 0.85, 0.5, 0.12 + 0.35 * tw))
	var flick: float = 0.6 + 0.4 * sin(t * 11.0) * sin(t * 5.3 + 1.0)
	_glow(to_screen(FIRE), 90.0 * k, Color(1.0, 0.5, 0.1, 0.16 + 0.2 * flick))
