class_name EditorBoard
extends Control

## Painting surface for the level editor.

signal painted(cell: Vector2i)

var w := 12
var h := 16
var cells: Array = []
var player := Vector2i(1, 1)
var highlight := Vector2i(-1, -1)

var _cell := 40.0
var _origin := Vector2.ZERO
var _painting := false
var _touch_index := -1
var _last := Vector2i(-1, -1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	resized.connect(_layout)
	_layout()

func configure(p_cells: Array, p_w: int, p_h: int, p_player: Vector2i) -> void:
	cells = p_cells
	w = p_w
	h = p_h
	player = p_player
	_layout()
	queue_redraw()

func _layout() -> void:
	if w <= 0 or h <= 0:
		return
	var avail := size - Vector2(20, 20)
	_cell = floorf(minf(avail.x / float(w), avail.y / float(h)))
	if _cell < 6.0:
		_cell = 6.0
	_origin = ((size - Vector2(_cell * w, _cell * h)) * 0.5).floor()
	queue_redraw()

func _draw() -> void:
	if cells.is_empty():
		return
	draw_set_transform(_origin, 0.0, Vector2.ONE)
	var full := Rect2(0, 0, _cell * w, _cell * h)
	draw_rect(full.grow(7.0), Color("0b080e"))
	draw_rect(full.grow(4.0), Color("382a31"))
	for y in h:
		for x in w:
			var rect := Rect2(float(x) * _cell, float(y) * _cell, _cell, _cell)
			PixelArt.draw_tile(self, int(cells[y][x]), rect, Vector2i(x, y), 0.0, true)

	var prect := Rect2(float(player.x) * _cell, float(player.y) * _cell, _cell, _cell)
	PixelArt.draw_mole(self, prect, 0.0, false)

	if _cell >= 22.0:
		var line_color := Color(1.0, 1.0, 1.0, 0.055)
		for x in range(1, w):
			draw_line(Vector2(float(x) * _cell, 0), Vector2(float(x) * _cell, _cell * h), line_color, 1.0)
		for y in range(1, h):
			draw_line(Vector2(0, float(y) * _cell), Vector2(_cell * w, float(y) * _cell), line_color, 1.0)

	if highlight.x >= 0 and highlight.x < w and highlight.y >= 0 and highlight.y < h:
		var hr := Rect2(float(highlight.x) * _cell, float(highlight.y) * _cell, _cell, _cell)
		draw_rect(hr.grow(-1.0), UITheme.ACCENT, false, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func cell_at(pos: Vector2) -> Vector2i:
	var local := pos - _origin
	if local.x < 0.0 or local.y < 0.0:
		return Vector2i(-1, -1)
	var cx := int(local.x / _cell)
	var cy := int(local.y / _cell)
	if cx < 0 or cy < 0 or cx >= w or cy >= h:
		return Vector2i(-1, -1)
	return Vector2i(cx, cy)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _touch_index == -1:
				_touch_index = touch.index
				_painting = true
				_paint(touch.position)
		elif touch.index == _touch_index:
			_touch_index = -1
			_painting = false
			_last = Vector2i(-1, -1)
			highlight = Vector2i(-1, -1)
			queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _painting and drag.index == _touch_index:
			_paint(drag.position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_painting = true
				_paint(mb.position)
			else:
				_painting = false
				_last = Vector2i(-1, -1)
				highlight = Vector2i(-1, -1)
				queue_redraw()

func _paint(pos: Vector2) -> void:
	var cell := cell_at(pos)
	if cell.x < 0:
		return
	if cell != _last:
		_last = cell
		highlight = cell
		queue_redraw()
		painted.emit(cell)
