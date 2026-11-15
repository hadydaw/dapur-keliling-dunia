extends Control
## Panel Pengaturan suara: volume Musik dan Efek (geser 0-100%, 0 = bisu). Tersimpan otomatis.
## Dipakai dari menu utama dan menu Jeda. Panggil `closed` saat ditutup.

const UI = preload("res://scripts/ui_kit.gd")

signal closed

var sliders: Dictionary = {}   # "music"/"sfx" -> HSlider
var value_labels: Dictionary = {}
var _preview_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("settings_panel")
	UI.fill(self)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	add_child(dim)
	UI.fill(dim)
	var center := CenterContainer.new()
	add_child(center)
	UI.fill(center)
	var p := UI.panel(Color(0.17, 0.13, 0.2), 24)
	center.add_child(p)
	var v := UI.vbox(18)
	v.custom_minimum_size = Vector2(620, 0)
	p.add_child(v)
	v.add_child(UI.label("Pengaturan Suara", 40, Color(1, 0.82, 0.4), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_row("music", "Musik", GameState.music_vol))
	v.add_child(_row("sfx", "Efek Suara", GameState.sfx_vol))
	var info := UI.label("Versi %s | layar %dx%d | %s" % [ProjectSettings.get_setting("application/config/version", "?"), get_window().size.x, get_window().size.y, RenderingServer.get_video_adapter_name()], 18, Color(0.7, 0.68, 0.78), HORIZONTAL_ALIGNMENT_CENTER)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	var btn := UI.button("Tutup", Vector2(360, 68), Color(0.42, 0.36, 0.9), 28)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.name = "BtnTutup"
	btn.pressed.connect(close)
	v.add_child(btn)


func _row(key: String, title: String, value: float) -> Control:
	var box := UI.vbox(4)
	var head := UI.hbox(8)
	head.add_child(UI.label(title, 28))
	head.add_child(UI.spacer())
	var pct := UI.label("", 28, Color(1, 0.9, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)
	pct.custom_minimum_size = Vector2(110, 0)
	head.add_child(pct)
	value_labels[key] = pct
	box.add_child(head)
	var s := HSlider.new()
	s.name = "Slider_" + key
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(0, 56)   # area sentuh tinggi (>= 44 px)
	s.focus_mode = Control.FOCUS_NONE
	_style_slider(s)
	s.value_changed.connect(_on_changed.bind(key))
	box.add_child(s)
	sliders[key] = s
	_update_label(key, value)
	return box


func _style_slider(s: HSlider) -> void:
	s.add_theme_stylebox_override("slider", _bar(Color(0.3, 0.26, 0.36)))
	s.add_theme_stylebox_override("grabber_area", _bar(Color(0.91, 0.64, 0.24)))
	s.add_theme_stylebox_override("grabber_area_highlight", _bar(Color(1.0, 0.75, 0.3)))
	var g := _knob(44, Color(1, 0.95, 0.85))
	s.add_theme_icon_override("grabber", g)
	s.add_theme_icon_override("grabber_highlight", _knob(44, Color(1, 1, 1)))
	s.add_theme_icon_override("grabber_disabled", g)


func _bar(c: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_corner_radius_all(8)
	b.content_margin_top = 8
	b.content_margin_bottom = 8
	return b


## Gagang bulat (lingkaran dengan tepi) dibuat dari Image, jadi tidak perlu aset.
func _knob(d: int, c: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d * 0.5
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - dist, 0.0, 1.0)
			var col := c
			if dist > r - 4.0:
				col = Color(0.55, 0.32, 0.1)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)


func _update_label(key: String, v: float) -> void:
	value_labels[key].text = "Bisu" if v <= 0.001 else "%d%%" % int(round(v * 100.0))


func _on_changed(v: float, key: String) -> void:
	if key == "music":
		GameState.music_vol = v
	else:
		GameState.sfx_vol = v
	_update_label(key, v)
	Music.apply_volumes()
	if key == "sfx":
		_preview()


## Bunyi "ting" singkat saat menggeser Efek, supaya terdengar hasilnya.
func _preview() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _preview_t < 0.25:
		return
	_preview_t = now
	var p := AudioStreamPlayer.new()
	p.stream = load("res://assets/audio/ting.wav")
	p.bus = "Efek"
	p.volume_db = -4.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func close() -> void:
	GameState.save_game()
	closed.emit()
	queue_free()
