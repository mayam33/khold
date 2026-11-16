class_name LevelData
extends RefCounted

## Level format shared by the campaign, the editor and online levels.
## Rows use these characters:
##   . dirt   (space) empty   R rock   S steel   F fruit   E exit   P player
## P is the player start and is stored inside the rows for easy sharing.

const T_EMPTY := 0
const T_DIRT := 1
const T_ROCK := 2
const T_STEEL := 3
const T_FRUIT := 4
const T_EXIT := 5

const MIN_W := 7
const MIN_H := 7
const MAX_W := 24
const MAX_H := 32

static func default_rows(w := 12, h := 16) -> Array:
	var rows: Array = []
	for y in h:
		var line := ""
		for x in w:
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				line += "S"
			else:
				line += "."
		rows.append(line)
	# Exit near the bottom-right and three fruits in the opening.
	rows[h - 2] = rows[h - 2].substr(0, w - 2) + "E" + "S"
	rows[1] = "S" + "P" + rows[1].substr(2, w - 2)
	for p in [Vector2i(4, 3), Vector2i(w - 4, 6), Vector2i(3, h - 5)]:
		if p.x > 0 and p.y > 0 and p.x < w - 1 and p.y < h - 1:
			rows[p.y] = rows[p.y].substr(0, p.x) + "F" + rows[p.y].substr(p.x + 1)
	return rows

static func empty_level() -> Dictionary:
	var rows := default_rows()
	return {
		"id": "",
		"name": "مرحلة جديدة",
		"author": "لاعب",
		"w": 12,
		"h": 16,
		"rows": rows,
		"par": 0,
		"source": "user",
	}

static func build(level: Dictionary) -> Dictionary:
	var rows_value: Variant = level.get("rows", level.get("tiles", []))
	if rows_value is PackedStringArray:
		rows_value = Array(rows_value)
	if not (rows_value is Array) or (rows_value as Array).size() < MIN_H:
		return {"ok": false, "error": "بيانات المرحلة غير مكتملة."}
	var rows: Array = rows_value

	var h: int = rows.size()
	var w: int = String(rows[0]).length()
	if w < MIN_W or h > MAX_H or w > MAX_W:
		return {"ok": false, "error": "أبعاد المرحلة غير مدعومة."}

	var grid: Array = []
	var player := Vector2i(-1, -1)
	var exit_pos := Vector2i(-1, -1)
	var total_fruits := 0
	for y in h:
		var row := String(rows[y])
		if row.length() != w:
			return {"ok": false, "error": "صفوف المرحلة غير متساوية الطول."}
		var line: Array = []
		for x in w:
			var ch := row[x]
			match ch:
				"P", "p":
					if player.x >= 0:
						return {"ok": false, "error": "المرحلة تحتوي على أكثر من نقطة بداية."}
					player = Vector2i(x, y)
					line.append(T_EMPTY)
				"E", "e":
					if exit_pos.x >= 0:
						return {"ok": false, "error": "المرحلة تحتوي على أكثر من مخرج."}
					exit_pos = Vector2i(x, y)
					line.append(T_EXIT)
				"F", "f", "*":
					total_fruits += 1
					line.append(T_FRUIT)
				"R", "r":
					line.append(T_ROCK)
				"S", "s", "#":
					line.append(T_STEEL)
				".":
					line.append(T_DIRT)
				" ":
					line.append(T_EMPTY)
				_:
					return {"ok": false, "error": "رمز غير معروف في المرحلة: %s" % ch}
		grid.append(line)

	if player.x < 0:
		return {"ok": false, "error": "أضف نقطة بداية للاعب."}
	if exit_pos.x < 0:
		return {"ok": false, "error": "أضف مخرجًا للمرحلة."}
	if total_fruits < 1:
		return {"ok": false, "error": "أضف ثمرة واحدة على الأقل."}

	return {
		"ok": true,
		"error": "",
		"w": w,
		"h": h,
		"grid": grid,
		"player": player,
		"exit": exit_pos,
		"total_fruits": total_fruits,
		"name": String(level.get("name", "مرحلة")),
		"author": String(level.get("author", "لاعب")),
		"id": String(level.get("id", "")),
		"par": int(level.get("par", 0)),
		"source": String(level.get("source", "")),
	}

static func rows_from_cells(cells: Array, player: Vector2i, w: int, h: int) -> Array:
	var rows: Array = []
	for y in h:
		var line := ""
		for x in w:
			if player.x == x and player.y == y:
				line += "P"
				continue
			var t: int = cells[y][x]
			match t:
				T_DIRT:
					line += "."
				T_ROCK:
					line += "R"
				T_STEEL:
					line += "S"
				T_FRUIT:
					line += "F"
				T_EXIT:
					line += "E"
				_:
					line += " "
		rows.append(line)
	return rows

static func cells_from_rows(rows: Array, w: int, h: int) -> Dictionary:
	var cells: Array = []
	var player := Vector2i(1, 1)
	for y in h:
		var line: Array = []
		var row := String(rows[y]) if y < rows.size() else ""
		for x in w:
			var ch := row[x] if x < row.length() else " "
			match ch:
				"P", "p":
					player = Vector2i(x, y)
					line.append(T_EMPTY)
				"R", "r":
					line.append(T_ROCK)
				"S", "s", "#":
					line.append(T_STEEL)
				"F", "f", "*":
					line.append(T_FRUIT)
				"E", "e":
					line.append(T_EXIT)
				".":
					line.append(T_DIRT)
				_:
					line.append(T_EMPTY)
		cells.append(line)
	return {"cells": cells, "player": player}
