class_name PixelArt
extends RefCounted

## Procedural cave tiles and pickups; the beaver uses the supplied sprite sheet.

const FRUIT := [
	"...ll...",
	"..lggl..",
	".rrrrrr.",
	"rrhrrrrr",
	"rhrrrrrr",
	"rrrrrrrr",
	".rrrrrr.",
	"..rrrr..",
]

static func draw_tile(ci: CanvasItem, type: int, rect: Rect2, cell: Vector2i, time: float, exit_open := false) -> void:
	match type:
		LevelData.T_EMPTY:
			draw_floor(ci, rect, cell)
		LevelData.T_DIRT:
			draw_dirt(ci, rect, cell)
		LevelData.T_ROCK:
			draw_floor(ci, rect, cell)
			draw_rock(ci, rect)
		LevelData.T_STEEL:
			draw_floor(ci, rect, cell)
			draw_steel(ci, rect)
		LevelData.T_FRUIT:
			draw_floor(ci, rect, cell)
			draw_fruit(ci, rect, time, cell)
		LevelData.T_EXIT:
			draw_floor(ci, rect, cell)
			draw_exit(ci, rect, exit_open, time, cell)
		_:
			draw_floor(ci, rect, cell)

static func draw_floor(ci: CanvasItem, rect: Rect2, cell: Vector2i) -> void:
	ci.draw_rect(rect, Color("211a1f"))
	var u := rect.size.x / 16.0
	# A soft radial vignette makes tunnels look carved instead of flat.
	var cx := rect.position.x + rect.size.x * 0.5
	var cy := rect.position.y + rect.size.y * 0.5
	ci.draw_circle(Vector2(cx, cy), rect.size.x * 0.46, Color(0.16, 0.11, 0.13, 0.22))
	ci.draw_circle(Vector2(cx, cy), rect.size.x * 0.30, Color(0.20, 0.14, 0.16, 0.18))
	var h := _h(cell.x, cell.y, 1)
	if h < 0.55:
		var px := rect.position.x + (2.0 + _h(cell.x, cell.y, 2) * 12.0) * u
		var py := rect.position.y + (2.0 + _h(cell.x, cell.y, 3) * 12.0) * u
		ci.draw_rect(Rect2(px, py, u, u), Color(0.34, 0.26, 0.24, 0.30))
	if h > 0.25 and h < 0.42:
		var px2 := rect.position.x + (3.0 + _h(cell.x, cell.y, 4) * 10.0) * u
		var py2 := rect.position.y + (4.0 + _h(cell.x, cell.y, 5) * 9.0) * u
		ci.draw_rect(Rect2(px2, py2, u * 2.0, u), Color(0.10, 0.07, 0.08, 0.55))
	# Chiseled rim: bright on top, deep shadow on the bottom edge.
	ci.draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, u), Color(0.38, 0.28, 0.22, 0.35))
	ci.draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y - u, rect.size.x, u), Color(0.02, 0.01, 0.02, 0.35))

static func draw_dirt(ci: CanvasItem, rect: Rect2, cell: Vector2i) -> void:
	ci.draw_rect(rect, Color("6c4a2f"))
	var u := rect.size.x / 16.0
	# Layered strata give the soil depth; warm top-left light, cool bottom-right.
	ci.draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, u * 2.0), Color("835b38"))
	ci.draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y - u * 2.0, rect.size.x, u * 2.0), Color("563822"))
	ci.draw_rect(Rect2(rect.position.x + rect.size.x - u, rect.position.y, u, rect.size.y), Color(0.12, 0.07, 0.03, 0.30))
	ci.draw_rect(Rect2(rect.position.x, rect.position.y, u, rect.size.y), Color(0.95, 0.72, 0.42, 0.10))
	# A wavy seam separates two soil layers.
	var seam := 6.0 + floorf(_h(cell.x, cell.y, 8) * 3.0)
	ci.draw_rect(Rect2(rect.position.x, rect.position.y + seam * u, rect.size.x, u), Color("5a3c25"))
	ci.draw_rect(Rect2(rect.position.x, rect.position.y + (seam + 1.0) * u, rect.size.x, u), Color("7c5535"))

	for i in 4:
		var hx := _h(cell.x, cell.y, 10 + i)
		var hy := _h(cell.x, cell.y, 20 + i)
		var s := u * (1.0 + floorf(hx * 2.0))
		var px := rect.position.x + (1.0 + floorf(hy * 13.0)) * u
		var py := rect.position.y + (2.0 + floorf(hx * 12.0)) * u
		var c := Color("52371f") if i % 2 == 0 else Color("966c43")
		ci.draw_rect(Rect2(px, py, s, s), c)
		ci.draw_rect(Rect2(px, py, maxf(u * 0.5, s * 0.35), u * 0.5), Color(0.98, 0.80, 0.55, 0.16))

	# buried pebble
	if _h(cell.x, cell.y, 31) < 0.30:
		var px3 := rect.position.x + (7.0 + _h(cell.x, cell.y, 32) * 5.0) * u
		var py3 := rect.position.y + (6.0 + _h(cell.x, cell.y, 33) * 6.0) * u
		ci.draw_rect(Rect2(px3, py3, u * 2.0, u * 1.5), Color("4b3220"))
		ci.draw_rect(Rect2(px3, py3, u, u * 0.5), Color("a37c55"))
	# a thin root thread
	if _h(cell.x, cell.y, 41) > 0.72:
		var rx := rect.position.x + (3.0 + _h(cell.x, cell.y, 42) * 8.0) * u
		ci.draw_rect(Rect2(rx, rect.position.y + u, u * 0.5, rect.size.y - u * 2.0), Color(0.36, 0.24, 0.13, 0.45))

static func draw_rock(ci: CanvasItem, rect: Rect2) -> void:
	var x := rect.position.x
	var y := rect.position.y
	var u := rect.size.x / 16.0
	var base := Color("64717b")
	var light := Color("8b98a2")
	var mid := Color("55616b")
	var dark := Color("3e4851")

	ci.draw_rect(Rect2(x + 2.0 * u, y + 13.0 * u, 12.0 * u, 2.0 * u), Color(0.0, 0.0, 0.0, 0.28))
	ci.draw_rect(Rect2(x + 3.0 * u, y + 2.0 * u, 10.0 * u, 11.0 * u), base)
	ci.draw_rect(Rect2(x + 2.0 * u, y + 4.0 * u, 12.0 * u, 7.0 * u), base)
	ci.draw_rect(Rect2(x + 4.0 * u, y + 1.0 * u, 8.0 * u, 1.0 * u), light)
	ci.draw_rect(Rect2(x + 3.0 * u, y + 2.0 * u, 4.0 * u, 2.0 * u), light)
	ci.draw_rect(Rect2(x + 2.0 * u, y + 4.0 * u, 2.0 * u, 5.0 * u), mid)
	ci.draw_rect(Rect2(x + 3.0 * u, y + 12.0 * u, 10.0 * u, 1.0 * u), dark)
	ci.draw_rect(Rect2(x + 12.0 * u, y + 4.0 * u, 2.0 * u, 8.0 * u), dark)
	ci.draw_rect(Rect2(x + 8.0 * u, y + 3.0 * u, 1.0 * u, 3.0 * u), dark)
	ci.draw_rect(Rect2(x + 9.0 * u, y + 6.0 * u, 1.0 * u, 2.0 * u), dark)
	ci.draw_rect(Rect2(x + 5.0 * u, y + 8.0 * u, 3.0 * u, 1.0 * u), dark)
	# Extra facet planes and a rim light make the rock read as a solid boulder.
	ci.draw_rect(Rect2(x + 6.0 * u, y + 2.0 * u, 6.0 * u, 3.0 * u), Color("74818b"))
	ci.draw_rect(Rect2(x + 5.0 * u, y + 5.0 * u, 4.0 * u, 4.0 * u), Color("6b7882"))
	ci.draw_rect(Rect2(x + 10.0 * u, y + 6.0 * u, 3.0 * u, 4.0 * u), Color("49555f"))
	ci.draw_rect(Rect2(x + 4.0 * u, y + 10.0 * u, 5.0 * u, 2.0 * u), Color("4d5963"))
	ci.draw_rect(Rect2(x + 4.0 * u, y + 2.0 * u, u, u), Color("c2ced6"))
	ci.draw_rect(Rect2(x + 5.0 * u, y + 3.0 * u, u, u), Color("aab7c0"))
	ci.draw_rect(Rect2(x + 11.0 * u, y + 11.0 * u, u, u), Color("9aa7b0"))
	# moss flecks
	ci.draw_rect(Rect2(x + 3.0 * u, y + 3.0 * u, u * 1.5, u), Color(0.36, 0.52, 0.30, 0.55))
	ci.draw_rect(Rect2(x + 12.0 * u, y + 9.0 * u, u, u), Color(0.32, 0.48, 0.28, 0.45))
	ci.draw_rect(Rect2(x + 2.0 * u, y + 1.0 * u, 12.0 * u, 13.0 * u), Color("2b1b14"), false, maxf(1.0, u))

static func draw_steel(ci: CanvasItem, rect: Rect2) -> void:
	var x := rect.position.x
	var y := rect.position.y
	var u := rect.size.x / 16.0
	ci.draw_rect(rect, Color("323b47"))
	ci.draw_rect(Rect2(x + u, y + u, 14.0 * u, 14.0 * u), Color("3b4552"))
	# Brushed-metal bands and a bright top-left bevel.
	for i in 5:
		var by := (3.0 + float(i) * 2.4) * u
		ci.draw_rect(Rect2(x + 2.0 * u, y + by, 12.0 * u, u * 0.5), Color(0.72, 0.78, 0.86, 0.05))
	ci.draw_rect(Rect2(x + u, y + u, 14.0 * u, 1.0 * u), Color("6d7a8c"))
	ci.draw_rect(Rect2(x + u, y + u, 1.0 * u, 14.0 * u), Color("5a6777"))
	ci.draw_rect(Rect2(x + u, y + 14.0 * u, 14.0 * u, 1.0 * u), Color("20262e"))
	ci.draw_rect(Rect2(x + 14.0 * u, y + u, 1.0 * u, 14.0 * u), Color("20262e"))
	for p in [Vector2(3.0, 3.0), Vector2(12.0, 3.0), Vector2(3.0, 12.0), Vector2(12.0, 12.0)]:
		ci.draw_rect(Rect2(x + p.x * u, y + p.y * u, 2.0 * u, 2.0 * u), Color("697585"))
		ci.draw_rect(Rect2(x + p.x * u, y + p.y * u, u, u), Color("a8b4c2"))
		ci.draw_rect(Rect2(x + (p.x + 1.0) * u, y + (p.y + 1.0) * u, u, u), Color("424d5a"))

static func draw_fruit(ci: CanvasItem, rect: Rect2, time: float, cell: Vector2i) -> void:
	var bob := sin(time * 2.6 + float(cell.x) * 0.7 + float(cell.y) * 0.4) * rect.size.y * 0.035
	var inner := Rect2(rect.position + Vector2(rect.size.x * 0.16, rect.size.y * 0.16 + bob), rect.size * 0.68)
	var u := inner.size.x / 8.0
	ci.draw_circle(inner.get_center(), rect.size.x * 0.36, Color(0.95, 0.35, 0.29, 0.10))
	ci.draw_circle(inner.get_center(), rect.size.x * 0.27, Color(0.95, 0.35, 0.29, 0.08))
	# Soft contact shadow under the floating fruit.
	ci.draw_circle(rect.get_center() + Vector2(0.0, inner.size.y * 0.52), inner.size.x * 0.28, Color(0.0, 0.0, 0.0, 0.18))
	draw_pattern(ci, FRUIT, {
		"r": Color("e8524a"),
		"h": Color("ffd166"),
		"l": Color("5fae4b"),
		"g": Color("7bd88f"),
	}, inner)
	# Pixel highlight and stem/leaf make the pickup read at a glance.
	ci.draw_rect(Rect2(inner.position.x + u * 2.0, inner.position.y + u * 3.0, u, u), Color(1.0, 0.82, 0.76, 0.85))
	ci.draw_rect(Rect2(inner.position.x + u * 5.0, inner.position.y + u * 0.5, u * 0.6, u * 1.6), Color("7b5334"))
	ci.draw_rect(Rect2(inner.position.x + u * 5.6, inner.position.y + u * 0.5, u * 1.6, u), Color("79c46b"))
	# Twinkling glint.
	var glint := 0.35 + 0.45 * maxf(0.0, sin(time * 3.4 + float(cell.x)))
	ci.draw_rect(Rect2(inner.position.x + u * 6.0, inner.position.y + u * 2.0, u * 0.7, u * 0.7), Color(1.0, 0.96, 0.72, glint))

static func draw_exit(ci: CanvasItem, rect: Rect2, open: bool, time: float, cell: Vector2i) -> void:
	var x := rect.position.x
	var y := rect.position.y
	var u := rect.size.x / 16.0
	var pulse := 0.5 + 0.5 * sin(time * 3.0 + float(cell.x))
	if open:
		ci.draw_circle(rect.get_center(), rect.size.x * (0.55 + pulse * 0.12), Color(0.48, 0.85, 0.56, 0.08))
		ci.draw_circle(rect.get_center(), rect.size.x * 0.40, Color(0.48, 0.85, 0.56, 0.07))
	var frame := Color("6fbf7c") if open else Color("5a626d")
	var panel := Color("2c4a37") if open else Color("302a33")
	ci.draw_rect(Rect2(x + 3.0 * u, y + 2.0 * u, 10.0 * u, 12.0 * u), frame)
	ci.draw_rect(Rect2(x + 4.0 * u, y + 1.0 * u, 8.0 * u, 2.0 * u), frame)
	ci.draw_rect(Rect2(x + 5.0 * u, y + 3.0 * u, 6.0 * u, 11.0 * u), panel)
	ci.draw_rect(Rect2(x + 4.0 * u, y + 2.0 * u, 8.0 * u, 1.0 * u), Color(0.9, 0.95, 0.85, 0.35) if open else Color(0.7, 0.75, 0.8, 0.2))
	# Rivets and an arched lintel give the exit a carved-stone look.
	for p in [Vector2(3.5, 3.5), Vector2(12.0, 3.5), Vector2(3.5, 12.5), Vector2(12.0, 12.5)]:
		ci.draw_rect(Rect2(x + p.x * u, y + p.y * u, u, u), Color(0.92, 0.94, 0.88, 0.35) if open else Color("7f8891"))
	ci.draw_rect(Rect2(x + 5.0 * u, y + 3.0 * u, u, 11.0 * u), Color(0.0, 0.0, 0.0, 0.22))
	ci.draw_rect(Rect2(x + 10.0 * u, y + 4.0 * u, u, 10.0 * u), Color(0.0, 0.0, 0.0, 0.22))
	if open:
		var glow := Color(0.55, 0.95, 0.62, 0.55 + pulse * 0.35)
		ci.draw_rect(Rect2(x + 7.0 * u, y + 7.0 * u, 2.0 * u, 2.0 * u), glow)
		ci.draw_rect(Rect2(x + 7.0 * u, y + 10.0 * u, 2.0 * u, 1.0 * u), glow)
	else:
		ci.draw_rect(Rect2(x + 7.0 * u, y + 7.0 * u, 2.0 * u, 3.0 * u), Color("d8b25a"))
		ci.draw_rect(Rect2(x + 6.0 * u, y + 6.0 * u, u, u), Color("d8b25a"))
		ci.draw_rect(Rect2(x + 9.0 * u, y + 6.0 * u, u, u), Color("d8b25a"))
		ci.draw_rect(Rect2(x + 6.0 * u, y + 5.0 * u, 4.0 * u, u), Color("d8b25a"))

static func draw_pattern(ci: CanvasItem, pattern: Array, palette: Dictionary, rect: Rect2, flip := false) -> void:
	if pattern.is_empty():
		return
	var rows := pattern.size()
	var cols := String(pattern[0]).length()
	var sx := rect.size.x / float(cols)
	var sy := rect.size.y / float(rows)
	for y in rows:
		var line := String(pattern[y])
		for x in cols:
			var ch := line[x]
			if ch == ".":
				continue
			var c: Color = palette.get(ch, Color.MAGENTA)
			var dx := float(cols - 1 - x) if flip else float(x)
			var px := rect.position.x + dx * sx
			var py := rect.position.y + float(y) * sy
			ci.draw_rect(Rect2(px, py, sx + 0.6, sy + 0.6), c)

static func draw_star(ci: CanvasItem, center: Vector2, radius: float, color: Color, filled := true) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI * 0.5 + float(i) * PI / 5.0
		var rr := radius if i % 2 == 0 else radius * 0.44
		pts.append(center + Vector2(cos(ang), sin(ang)) * rr)
	if filled:
		ci.draw_colored_polygon(pts, color)
	else:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, color, maxf(1.5, radius * 0.12), true)

static func _h(x: int, y: int, s: int) -> float:
	var n := x * 374761393 + y * 668265263 + s * 1442695041
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0
