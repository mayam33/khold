extends SceneTree

## Headless level checker. Run with:
##   godot --headless --path . --script res://tools/solve.gd
## It plans a route fruit by fruit and then to the exit, printing the move count.
## Pars are not required to be mathematically optimal, only reachable.

const LevelDataScript := preload("res://scripts/level_data.gd")
const BuiltinLevelsScript := preload("res://scripts/builtin_levels.gd")
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const MAX_STATES := 300000
const TIME_BUDGET_MS := 30000

func _initialize() -> void:
	print("== Khold level solver ==")
	var levels: Array = BuiltinLevelsScript.all()
	for lv in levels:
		var start := Time.get_ticks_msec()
		var result := _solve(lv)
		var elapsed := Time.get_ticks_msec() - start
		var par: Variant = result.get("moves", -1)
		print("%s | %s | par=%s | states=%d | %d ms" % [
			String(lv.get("id", "")), String(lv.get("name", "")), str(par),
			int(result.get("states", 0)), elapsed,
		])
	quit()

func _solve(lv: Dictionary) -> Dictionary:
	var built := LevelDataScript.build(lv)
	if not bool(built.get("ok", false)):
		print("  build error: " + String(built.get("error", "")))
		return {"moves": -1, "states": 0}
	var w := int(built["w"])
	var h := int(built["h"])
	var grid2: Array = built["grid"]
	var start := PackedByteArray()
	start.resize(w * h)
	for y in h:
		for x in w:
			start[y * w + x] = int(grid2[y][x])
	var player: Vector2i = built["player"]
	var st := {
		"px": player.x, "py": player.y,
		"grid": start,
		"fruits": int(built["total_fruits"]),
	}
	var total := 0
	var states := 0
	var guard := 0
	while guard < 200:
		guard += 1
		var dists := _dist_map(st, w, h)
		var target := Vector2i(-1, -1)
		var want_exit := int(st["fruits"]) == 0
		if want_exit:
			for i in (st["grid"] as PackedByteArray).size():
				if int(st["grid"][i]) == LevelDataScript.T_EXIT:
					target = Vector2i(i % w, i / w)
					break
			if int(dists[target.y * w + target.x]) < 0:
				return {"moves": -1, "states": states}
		else:
			var best := 1 << 30
			for i in (st["grid"] as PackedByteArray).size():
				if int(st["grid"][i]) != LevelDataScript.T_FRUIT:
					continue
				var d := int(dists[i])
				if d >= 0 and d < best:
					best = d
					target = Vector2i(i % w, i / w)
			if target.x < 0:
				return {"moves": -1, "states": states}
		var leg := _goto(st, target, want_exit, w, h)
		states += int(leg.get("states", 0))
		if not bool(leg.get("ok", false)):
			print("  stuck going to %s (exit=%s) from (%d,%d), fruits=%d, states=%d" % [
				str(target), str(want_exit), int(st["px"]), int(st["py"]),
				int(st["fruits"]), int(leg.get("states", 0))])
			return {"moves": -1, "states": states}
		st = leg["st"]
		total += int(leg.get("moves", 0))
		if bool(leg.get("win", false)):
			return {"moves": total, "states": states}
	return {"moves": -1, "states": states}

## Best-first walk to one target. Stops as soon as the target is reached.
func _goto(st: Dictionary, target: Vector2i, want_exit: bool, w: int, h: int) -> Dictionary:
	var started := Time.get_ticks_msec()
	var open: Array = []
	var best: Dictionary = {}
	var g0 := 0
	best[_key(int(st["px"]), int(st["py"]), int(st["fruits"]), st["grid"])] = g0
	_heap_push(open, {"f": 0.0, "st": st, "g": 0})
	var expanded := 0
	while not open.is_empty() and expanded < MAX_STATES:
		if (Time.get_ticks_msec() - started) > TIME_BUDGET_MS:
			break
		var node: Dictionary = _heap_pop(open)
		var cur: Dictionary = node["st"]
		var g := int(node["g"])
		var key := _key(int(cur["px"]), int(cur["py"]), int(cur["fruits"]), cur["grid"])
		if g > int(best.get(key, 1 << 30)):
			continue
		expanded += 1
		for d in DIRS:
			var step := _step(cur, d, w, h)
			if step.is_empty():
				continue
			if bool(step.get("win", false)):
				var win_state := {
					"px": target.x, "py": target.y,
					"grid": step.get("grid", cur["grid"]),
					"fruits": int(step.get("fruits", cur["fruits"])),
				}
				return {"ok": true, "win": true, "st": win_state, "moves": g + 1, "states": expanded}
			if bool(step.get("dead", false)):
				continue
			var child := {
				"px": step["px"], "py": step["py"],
				"grid": step["grid"],
				"fruits": step["fruits"],
			}
			var cg := g + 1
			var ck := _key(int(child["px"]), int(child["py"]), int(child["fruits"]), child["grid"])
			if cg >= int(best.get(ck, 1 << 30)):
				continue
			best[ck] = cg
			if not want_exit and int(child["px"]) == target.x and int(child["py"]) == target.y:
				return {"ok": true, "win": false, "st": child, "moves": cg, "states": expanded}
			var dist := _cell_distance(child, target, w, h)
			if dist < 0:
				dist = 800
			_heap_push(open, {"f": float(dist) * 1000.0 + float(cg), "st": child, "g": cg})
	return {"ok": false, "states": expanded}

# --------------------------------------------------------------- distances

func _dist_map(st: Dictionary, w: int, h: int) -> PackedInt32Array:
	var px := int(st["px"])
	var py := int(st["py"])
	var fruits := int(st["fruits"])
	var grid: PackedByteArray = st["grid"]
	var dist := PackedInt32Array()
	dist.resize(grid.size())
	dist.fill(-1)
	var queue: Array = [py * w + px]
	dist[py * w + px] = 0
	var head := 0
	while head < queue.size():
		var idx: int = queue[head]
		head += 1
		var x: int = idx % w
		var y: int = idx / w
		for dir in DIRS:
			var nx: int = x + dir.x
			var ny: int = y + dir.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var ni: int = ny * w + nx
			if dist[ni] >= 0:
				continue
			var tile: int = grid[ni]
			if tile == LevelDataScript.T_STEEL:
				continue
			if tile == LevelDataScript.T_ROCK:
				if dir.y != 0:
					continue
				var bx: int = nx + dir.x
				if bx < 0 or bx >= w or grid[ny * w + bx] != LevelDataScript.T_EMPTY:
					continue
			if tile == LevelDataScript.T_EXIT and fruits > 0:
				continue
			dist[ni] = int(dist[idx]) + 1
			queue.append(ni)
	return dist

func _cell_distance(st: Dictionary, target: Vector2i, w: int, h: int) -> int:
	var dists := _dist_map(st, w, h)
	if target.x < 0 or target.y < 0 or target.x >= w or target.y >= h:
		return -1
	return int(dists[target.y * w + target.x])

# --------------------------------------------------------------- moves

func _step(st: Dictionary, dir: Vector2i, w: int, h: int) -> Dictionary:
	var px := int(st["px"])
	var py := int(st["py"])
	var tx := px + dir.x
	var ty := py + dir.y
	if tx < 0 or ty < 0 or tx >= w or ty >= h:
		return {}
	var grid: PackedByteArray = (st["grid"] as PackedByteArray).duplicate()
	var fruits := int(st["fruits"])
	var tile := grid[ty * w + tx]
	if tile == LevelDataScript.T_STEEL:
		return {}
	if tile == LevelDataScript.T_ROCK:
		if dir.y != 0:
			return {}
		var bx := tx + dir.x
		if bx < 0 or bx >= w or grid[ty * w + bx] != LevelDataScript.T_EMPTY:
			return {}
		grid[ty * w + bx] = LevelDataScript.T_ROCK
		grid[ty * w + tx] = LevelDataScript.T_EMPTY
	elif tile == LevelDataScript.T_EXIT:
		if fruits > 0:
			return {}
		return {"win": true, "grid": grid, "fruits": fruits, "px": tx, "py": ty}
	elif tile == LevelDataScript.T_DIRT:
		grid[ty * w + tx] = LevelDataScript.T_EMPTY
	elif tile == LevelDataScript.T_FRUIT:
		grid[ty * w + tx] = LevelDataScript.T_EMPTY
		fruits -= 1
	if _gravity(grid, tx, ty, w, h):
		return {"dead": true}
	return {"grid": grid, "px": tx, "py": ty, "fruits": fruits}

func _gravity(grid: PackedByteArray, px: int, py: int, w: int, h: int) -> bool:
	var guard := 0
	while guard < h + 3:
		var changed := false
		for y in range(h - 2, -1, -1):
			for x in w:
				var i := y * w + x
				if grid[i] != LevelDataScript.T_ROCK:
					continue
				var j := (y + 1) * w + x
				if grid[j] != LevelDataScript.T_EMPTY:
					continue
				grid[i] = LevelDataScript.T_EMPTY
				grid[j] = LevelDataScript.T_ROCK
				if x == px and y + 1 == py:
					return true
				changed = true
		if not changed:
			break
		guard += 1
	return false

func _key(px: int, py: int, fruits: int, grid: PackedByteArray) -> String:
	var b := PackedByteArray()
	b.resize(grid.size())
	for i in grid.size():
		b[i] = grid[i] + 48
	return "%d,%d,%d|%s" % [px, py, fruits, b.get_string_from_ascii()]

# --------------------------------------------------------------- binary heap

func _heap_push(heap: Array, item: Dictionary) -> void:
	heap.append(item)
	var index := heap.size() - 1
	while index > 0:
		var parent := (index - 1) / 2
		if float(heap[parent]["f"]) <= float(heap[index]["f"]):
			break
		var tmp: Dictionary = heap[parent]
		heap[parent] = heap[index]
		heap[index] = tmp
		index = parent

func _heap_pop(heap: Array) -> Dictionary:
	var top: Dictionary = heap[0]
	var last: Dictionary = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		_sift_down(heap, 0)
	return top

func _sift_down(heap: Array, index: int) -> void:
	var n := heap.size()
	while true:
		var left := index * 2 + 1
		if left >= n:
			return
		var right := left + 1
		var smallest := left
		if right < n and float(heap[right]["f"]) < float(heap[left]["f"]):
			smallest = right
		if float(heap[smallest]["f"]) >= float(heap[index]["f"]):
			return
		var tmp: Dictionary = heap[index]
		heap[index] = heap[smallest]
		heap[smallest] = tmp
		index = smallest
