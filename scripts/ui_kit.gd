extends RefCounted
## Helper pembuat UI lewat kode (tanpa file .tscn per layar).


static func style(bg: Color, radius: int = 14, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func label(text: String, size: int = 26, color: Color = Color.WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## Taruh teks tepat di tengah sebuah kotak. Ukuran font mengikuti tinggi kotak,
## lalu dikecilkan bila lebar tidak muat (angka panjang tidak keluar dari bar).
static func fit_label(l: Label, text: String, rect: Rect2, height_ratio: float = 0.8, min_size: int = 10) -> void:
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var font: Font = l.get_theme_font("font")
	var fs: int = int(rect.size.y * height_ratio)
	while fs > min_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > rect.size.x:
		fs -= 1
	l.add_theme_font_size_override("font_size", fs)
	# Pusat visual huruf (setengah tinggi huruf besar, ~0,7 em di atas garis dasar)
	# diletakkan tepat di tengah kotak, bukan pusat kotak baris teks.
	var asc: float = font.get_ascent(fs)
	var line_h: float = font.get_height(fs)
	l.position = Vector2(rect.position.x, rect.get_center().y - (asc - 0.35 * fs))
	l.size = Vector2(rect.size.x, line_h)


## Tombol bergambar (PNG transparan) dengan animasi ketuk: mengecil lalu membal.
static func icon_button(tex_path: String, box: Vector2) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = box
	var img := TextureRect.new()
	img.texture = load(tex_path)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill(img)
	holder.add_child(img)
	var b := TextureButton.new()
	b.ignore_texture_size = true
	b.focus_mode = Control.FOCUS_NONE
	fill(b)
	holder.add_child(b)
	b.button_down.connect(func(): _press(img, true))
	b.button_up.connect(func(): _press(img, false))
	holder.set_meta("button", b)
	return holder


static func _press(target: Control, down: bool) -> void:
	target.pivot_offset = target.size * 0.5
	var tw := target.create_tween()
	if down:
		target.modulate = Color(0.85, 0.85, 0.85)
		tw.tween_property(target, "scale", Vector2(0.92, 0.92), 0.07)
	else:
		target.modulate = Color.WHITE
		tw.tween_property(target, "scale", Vector2(1.06, 1.06), 0.09)
		tw.tween_property(target, "scale", Vector2.ONE, 0.09)


static func wrap_label(text: String, size: int = 22, color: Color = Color.WHITE) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func color_button(b: Button, color: Color) -> void:
	b.add_theme_stylebox_override("normal", style(color))
	b.add_theme_stylebox_override("hover", style(color.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", style(color.darkened(0.2)))
	b.add_theme_stylebox_override("disabled", style(Color(0.35, 0.35, 0.37)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func button(text: String, min_size: Vector2 = Vector2(180, 64), color: Color = Color(0.91, 0.64, 0.24), size: int = 26) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.75, 0.75, 0.75))
	color_button(b, color)
	return b


static func panel(color: Color, radius: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(color, radius))
	return p


static func fill(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func background(parent: Control, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	fill(r)
	return r


static func margin_root(parent: Control, m: int = 24) -> MarginContainer:
	var mc := MarginContainer.new()
	parent.add_child(mc)
	fill(mc)
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, m)
	return mc


static func vbox(sep: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## Overlay modal. buttons: Array of {"text", "color", "fn"}.
static func overlay(parent: Control, title: String, lines: Array, buttons: Array) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	parent.add_child(dim)
	fill(dim)
	var center := CenterContainer.new()
	dim.add_child(center)
	fill(center)
	var p := panel(Color(0.17, 0.13, 0.2), 24)
	center.add_child(p)
	var v := vbox(14)
	v.custom_minimum_size = Vector2(520, 0)
	p.add_child(v)
	v.add_child(label(title, 40, Color(1, 0.82, 0.4), HORIZONTAL_ALIGNMENT_CENTER))
	for line in lines:
		v.add_child(label(str(line), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	for b in buttons:
		var btn := button(b["text"], Vector2(360, 68), b["color"], 28)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(b["fn"])
		v.add_child(btn)
	return dim
