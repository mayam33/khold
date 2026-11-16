class_name DPad
extends Control

## Touch-first directional pad drawn entirely in code, with generous targets.

signal dir_pressed(dir: Vector2i)
signal dir_released

const DIRS := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]
const GAP := 7.0

var active := Vector2i.ZERO
var _touch_index := -1
var _normal: StyleBoxFlat
var _hot: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(252, 252)
	_normal = UITheme.box(Color("2b2134"), 22, Color("453650"), 2, 0, 0)
	_hot = UITheme.box(UITheme.ACCENT, 22, UITheme.ACCENT_DARK, 2, 0, 0)
	queue_redraw()

func _draw() -> void:
	var cell := _cell_size()
	var origin := ((size - Vector2(cell * 3.0 + GAP * 2.0, cell * 3.0 + GAP * 2.0)) * 0.5).floor()
	for dir in DIRS:
		var rect := _rect_for(dir, cell, origin)
		draw_style_box(_hot if dir == active else _normal, rect)
		var col := UITheme.ACCENT_INK if dir == active else UITheme.TEXT
		_draw_arrow(rect, dir, col)
	var center := rect_center(origin, cell)
	draw_circle(center, cell * 0.10, Color(0.45, 0.36, 0.51, 0.55))

func _cell_size() -> float:
	return maxf(20.0, (minf(size.x, size.y) - GAP * 2.0) / 3.0)

func _rect_for(dir: Vector2i, cell: float, origin: Vector2) -> Rect2:
	var pos := origin + Vector2(cell + GAP, cell + GAP)
	match dir:
		Vector2i(0, -1):
			pos = origin + Vector2(cell + GAP, 0.0)
		Vector2i(-1, 0):
			pos = origin + Vector2(0.0, cell + GAP)
		Vector2i(1, 0):
			pos = origin + Vector2((cell + GAP) * 2.0, cell + GAP)
		Vector2i(0, 1):
			pos = origin + Vector2(cell + GAP, (cell + GAP) * 2.0)
	return Rect2(pos, Vector2(cell, cell))

func rect_center(origin: Vector2, cell: float) -> Vector2:
	return origin + Vector2(cell * 1.5 + GAP, cell * 1.5 + GAP)

func _draw_arrow(rect: Rect2, dir: Vector2i, color: Color) -> void:
	var c := rect.get_center()
	var r := rect.size.x * 0.20
	var pts := PackedVector2Array()
	match dir:
		Vector2i(0, -1):
			pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(-r * 0.95, r * 0.7), c + Vector2(r * 0.95, r * 0.7)])
		Vector2i(0, 1):
			pts = PackedVector2Array([c + Vector2(0, r), c + Vector2(-r * 0.95, -r * 0.7), c + Vector2(r * 0.95, -r * 0.7)])
		Vector2i(-1, 0):
			pts = PackedVector2Array([c + Vector2(-r, 0), c + Vector2(r * 0.7, -r * 0.95), c + Vector2(r * 0.7, r * 0.95)])
		Vector2i(1, 0):
			pts = PackedVector2Array([c + Vector2(r, 0), c + Vector2(-r * 0.7, -r * 0.95), c + Vector2(-r * 0.7, r * 0.95)])
	draw_colored_polygon(pts, color)
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(0, 2))
	# A subtle lower bevel.
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.12))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _touch_index == -1:
				_touch_index = touch.index
				_pick(touch.position)
		elif touch.index == _touch_index:
			_touch_index = -1
			_release()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_pick(drag.position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pick(mb.position)
			else:
				_release()

func _pick(pos: Vector2) -> void:
	var cell := _cell_size()
	var origin := ((size - Vector2(cell * 3.0 + GAP * 2.0, cell * 3.0 + GAP * 2.0)) * 0.5).floor()
	for dir in DIRS:
		if _rect_for(dir, cell, origin).has_point(pos):
			if active != dir:
				active = dir
				dir_pressed.emit(dir)
				Sfx.haptic(7)
				queue_redraw()
			return

func _release() -> void:
	if active != Vector2i.ZERO:
		active = Vector2i.ZERO
		queue_redraw()
		dir_released.emit()
