class_name UITheme
extends RefCounted

## Central visual identity for Beaver Explorer, using warm cave colors from the beaver art.

const FONT_REGULAR: FontFile = preload("res://assets/fonts/Almarai-Regular.ttf")
const FONT_BOLD: FontFile = preload("res://assets/fonts/Almarai-Bold.ttf")

const BG := Color("17100d")
const BG_2 := Color("241713")
const PANEL := Color("2e201a")
const PANEL_2 := Color("3b281f")
const PANEL_3 := Color("4a3226")
const TEXT := Color("f5eadc")
const MUTED := Color("c4aa95")
const ACCENT := Color("f0a15c")
const ACCENT_DARK := Color("bb682f")
const ACCENT_INK := Color("2b160b")
const GREEN := Color("8bc77a")
const RED := Color("e46b52")
const BLUE := Color("8bb9c9")
const BORDER := Color("563d30")

static var _theme: Theme

static func shared() -> Theme:
	if _theme == null:
		_theme = build()
	return _theme

static func build() -> Theme:
	var t := Theme.new()
	t.default_font = FONT_REGULAR
	t.default_font_size = 26

	t.set_color("font_color", "Label", TEXT)
	t.set_font("font", "Button", FONT_BOLD)
	t.set_font_size("font_size", "Button", 26)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color("6d6274"))
	t.set_color("font_focus_color", "Button", TEXT)

	var normal := box(PANEL_2, 16, BORDER, 2, 20, 12)
	var hover := box(PANEL_3, 16, Color("57445f"), 2, 20, 12)
	var pressed := box(Color("1f1826"), 16, ACCENT_DARK, 2, 20, 12)
	var disabled := box(Color("1d1722"), 16, Color("2c2433"), 2, 20, 12)
	var focus := box(Color(0, 0, 0, 0), 16, ACCENT, 2, 20, 12)

	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", focus)

	t.set_stylebox("panel", "PanelContainer", box(PANEL, 20, BORDER, 2, 18, 18))
	t.set_stylebox("panel", "Panel", box(PANEL, 20, BORDER, 2, 18, 18))

	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color("8f8297"))
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", Color("6d5a2a"))
	t.set_font_size("font_size", "LineEdit", 24)
	var le := box(Color("17121c"), 12, Color("4a3a56"), 2, 14, 10)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", box(Color("17121c"), 12, ACCENT, 2, 14, 10))
	t.set_stylebox("read_only", "LineEdit", box(Color("141017"), 12, Color("332a3c"), 2, 14, 10))

	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_pressed_color", "CheckButton", ACCENT)
	t.set_color("font_hover_color", "CheckButton", TEXT)
	t.set_font_size("font_size", "CheckButton", 24)

	t.set_stylebox("panel", "PopupPanel", box(PANEL, 16, BORDER, 2, 14, 14))
	t.set_stylebox("panel", "AcceptDialog", box(PANEL, 16, BORDER, 2, 14, 14))
	t.set_color("font_color", "AcceptDialog", TEXT)
	t.set_font("title_font", "Window", FONT_BOLD)
	t.set_font_size("title_font_size", "Window", 26)

	t.set_stylebox("scroll", "ScrollContainer", box(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, 0, 0))
	return t

static func box(bg: Color, radius := 16, border_color := Color(0, 0, 0, 0), border := 0, margin_x := 0, margin_y := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.border_width_left = border
	sb.border_width_top = border
	sb.border_width_right = border
	sb.border_width_bottom = border
	sb.border_color = border_color
	sb.content_margin_left = margin_x
	sb.content_margin_right = margin_x
	sb.content_margin_top = margin_y
	sb.content_margin_bottom = margin_y
	sb.anti_aliasing = true
	return sb
