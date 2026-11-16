class_name UI
extends RefCounted

## Small builders that keep the screens short and consistent.

static func label(text: String, size := 24, color := UITheme.TEXT, align := HORIZONTAL_ALIGNMENT_RIGHT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func wrap_label(text: String, size := 23, color := UITheme.MUTED) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

static func heading(text: String, size := 36, color := UITheme.TEXT, align := HORIZONTAL_ALIGNMENT_RIGHT) -> Label:
	var l := label(text, size, color, align)
	l.add_theme_font_override("font", UITheme.FONT_BOLD)
	return l

static func button(text: String, height := 64, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if accent:
		b.add_theme_stylebox_override("normal", UITheme.box(UITheme.ACCENT, 16, UITheme.ACCENT_DARK, 2, 20, 12))
		b.add_theme_stylebox_override("hover", UITheme.box(Color("ffc75f"), 16, UITheme.ACCENT, 2, 20, 12))
		b.add_theme_stylebox_override("pressed", UITheme.box(Color("d79a28"), 16, UITheme.ACCENT_DARK, 2, 20, 12))
		b.add_theme_stylebox_override("focus", UITheme.box(Color(0, 0, 0, 0), 16, UITheme.ACCENT, 2, 20, 12))
		b.add_theme_color_override("font_color", UITheme.ACCENT_INK)
		b.add_theme_color_override("font_hover_color", UITheme.ACCENT_INK)
		b.add_theme_color_override("font_pressed_color", UITheme.ACCENT_INK)
	return b

static func ghost_button(text: String, height := 52) -> Button:
	var b := button(text, height, false)
	b.add_theme_stylebox_override("normal", UITheme.box(Color(0, 0, 0, 0), 14, Color("4a3b56"), 2, 16, 8))
	b.add_theme_stylebox_override("hover", UITheme.box(Color("2c2233"), 14, Color("5b4a68"), 2, 16, 8))
	b.add_theme_stylebox_override("pressed", UITheme.box(Color("1f1826"), 14, UITheme.ACCENT_DARK, 2, 16, 8))
	return b

static func panel(padding := 18, bg := UITheme.PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.box(bg, 20, UITheme.BORDER, 2, padding, padding))
	return p

static func card() -> PanelContainer:
	return panel(16, UITheme.PANEL)

static func vbox(sep := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func margin_control(all := 16) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", all)
	m.add_theme_constant_override("margin_right", all)
	m.add_theme_constant_override("margin_top", all)
	m.add_theme_constant_override("margin_bottom", all)
	return m

static func full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c

static func spacer_h(h := 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func chip(text: String, color := UITheme.TEXT) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UITheme.box(Color("1b1522"), 18, Color("40334a"), 2, 12, 5))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, 21, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.name = "Value"
	p.add_child(l)
	return p

static func set_chip(p: PanelContainer, text: String) -> void:
	var l := p.get_node_or_null("Value") as Label
	if l:
		l.text = text

static func section_title(text: String) -> Label:
	return heading(text, 28, UITheme.ACCENT)
