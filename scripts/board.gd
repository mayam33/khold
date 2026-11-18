class_name DigBoard
extends Control

## Turn-based digging board. The player, rocks and items live on a small grid;
## every action is resolved instantly and rocks apply gravity afterwards.

signal stats_changed(stats: Dictionary)
signal won
signal died
signal message_requested(text: String)
signal swipe(dir: Vector2i)

const SWIPE_MIN := 34.0
const MAX_UNDO := 60

var level: Dictionary = {}
var level_id := ""
var level_name := ""
var w := 12
var h := 16
var grid: Array = []
var px := 1
var py := 1
var exit_pos := Vector2i(-1, -1)
var fruits_total := 0
var fruits_left := 0
var moves := 0
var par := 0
var facing := Vector2i(0, 1)
var dead := false
var finished := false
var cooldown := 0.0
var time := 0.0

var player_vis := Vector2.ZERO:
	set(value):
		player_vis = value
		queue_redraw()

var _cell := 40.0
var _origin := Vector2.ZERO
var _particles: Array = []
var _undo_stack: Array = []
var _shake := 0.0
var _exit_warn := 0.0
var beaver_animation := "idle"
var _animation_clock := 0.0
var _animation_duration := 0.0
var _ptween: Tween
var _touch_start := Vector2.ZERO
var _touch_index := -1
var _tracking := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(_layout)
	_layout()

func load_level(data: Dictionary) -> bool:
	var built := LevelData.build(data)
	if not bool(built.get("ok", false)):
		push_warning("Bad level: " + String(built.get("error", "")))
		return false
	level = data.duplicate(true)
	level_id = String(built.get("id", ""))
	level_name = String(built.get("name", "مرحلة"))
	w = int(built.get("w", 12))
	h = int(built.get("h", 16))
	grid = (built.get("grid", []) as Array).duplicate(true)
	px = (built.get("player", Vector2i(1, 1)) as Vector2i).x
	py = (built.get("player", Vector2i(1, 1)) as Vector2i).y
	exit_pos = built.get("exit", Vector2i(-1, -1))
	fruits_total = int(built.get("total_fruits", 0))
	fruits_left = fruits_total
	moves = 0
	par = int(built.get("par", 0))
	facing = Vector2i(0, 1)
	dead = false
	finished = false
	cooldown = 0.0
	_undo_stack.clear()
	_particles.clear()
	_shake = 0.0
	_exit_warn = 0.0
	_set_animation("idle")
	if _ptween and _ptween.is_valid():
		_ptween.kill()
	player_vis = Vector2(px, py)
	queue_redraw()
	stats_changed.emit(stats())
	return true

func restart() -> void:
	load_level(level)

func stats() -> Dictionary:
	return {
		"moves": moves,
		"fruits_left": fruits_left,
		"fruits_total": fruits_total,
		"par": par,
		"dead": dead,
		"finished": finished,
		"can_undo": not _undo_stack.is_empty(),
	}

# ---------------------------------------------------------------- actions

func try_move(dir: Vector2i) -> bool:
	if dead or finished or cooldown > 0.0:
		return false
	if dir == Vector2i.ZERO:
		return false
	dir = Vector2i(signi(dir.x), signi(dir.y))
	if absi(dir.x) + absi(dir.y) != 1:
		return false
	facing = dir

	var tx := px + dir.x
	var ty := py + dir.y
	if tx < 0 or ty < 0 or tx >= w or ty >= h:
		_bump()
		return false

	var tile := int(grid[ty][tx])
	if dir.y < 0 and tile == LevelData.T_EMPTY:
		_bump()
		message_requested.emit("لا يستطيع القندس الصعود إلى فراغ.")
		return false
	var snap := _snapshot()

	match tile:
		LevelData.T_STEEL:
			_bump()
			return false
		LevelData.T_ROCK:
			if dir.y != 0:
				_bump()
				return false
			var bx := tx + dir.x
			if bx < 0 or bx >= w or int(grid[ty][bx]) != LevelData.T_EMPTY:
				_bump()
				return false
			grid[ty][bx] = LevelData.T_ROCK
			grid[ty][tx] = LevelData.T_EMPTY
			_make_move(tx, ty, snap, 0.16)
			_set_animation("walk", 0.28)
			Sfx.play("push", randf_range(0.95, 1.05))
			Sfx.haptic(8)
			_spawn_burst(tx, ty, Color("7b8791"), 5, 0.8)
		LevelData.T_DIRT:
			grid[ty][tx] = LevelData.T_EMPTY
			_make_move(tx, ty, snap, 0.15)
			_set_animation("dig", 0.38)
			Sfx.play("dig", randf_range(0.9, 1.12))
			Sfx.haptic(6)
			_spawn_burst(tx, ty, Color("8a6039"), 7, 1.0)
		LevelData.T_FRUIT:
			grid[ty][tx] = LevelData.T_EMPTY
			fruits_left = maxi(0, fruits_left - 1)
			_make_move(tx, ty, snap, 0.16)
			_set_animation("walk", 0.28)
			Sfx.play("collect", randf_range(0.96, 1.06))
			Sfx.haptic(10)
			_spawn_burst(tx, ty, Color("e8524a"), 10, 1.2)
			_spawn_burst(tx, ty, Color("ffd166"), 5, 0.9)
			if fruits_left == 0 and not dead:
				_unlock_exit()
		LevelData.T_EXIT:
			if fruits_left > 0:
				_exit_warn = 1.0
				_shake = maxf(_shake, 0.3)
				cooldown = 0.3
				Sfx.play("bump")
				Sfx.haptic(12)
				message_requested.emit("المخرج مقفل — اجمع كل الثمار أولًا.")
				return false
			_make_move(tx, ty, snap, 0.2)
			if dead:
				return false
			finished = true
			_set_animation("celebrate")
			facing = Vector2i(0, 1)
			Sfx.play("win")
			Sfx.haptic(35)
			stats_changed.emit(stats())
			won.emit()
			return true
		_:
			_make_move(tx, ty, snap, 0.13)
			_set_animation("fall" if dir.y > 0 else "walk", 0.32)
			Sfx.play("step", randf_range(0.94, 1.06))
	return true

func undo() -> bool:
	if _undo_stack.is_empty():
		return false
	var snap: Dictionary = _undo_stack.pop_back()
	grid = (snap["grid"] as Array).duplicate(true)
	px = int(snap["px"])
	py = int(snap["py"])
	fruits_left = int(snap["fruits"])
	moves = int(snap["moves"])
	dead = false
	finished = false
	cooldown = 0.1
	_set_animation("idle")
	if _ptween and _ptween.is_valid():
		_ptween.kill()
	player_vis = Vector2(px, py)
	Sfx.play("click", 0.8)
	stats_changed.emit(stats())
	queue_redraw()
	return true

func _make_move(tx: int, ty: int, snap: Dictionary, cd: float) -> void:
	_undo_stack.append(snap)
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.pop_front()
	px = tx
	py = ty
	moves += 1
	cooldown = cd
	_tween_player()
	_resolve_gravity()
	stats_changed.emit(stats())

func _bump() -> void:
	_set_animation("hurt", 0.24)
	cooldown = 0.1
	_shake = maxf(_shake, 0.18)
	Sfx.play("bump", randf_range(0.95, 1.08))
	Sfx.haptic(6)

func _unlock_exit() -> void:
	Sfx.play("unlock")
	Sfx.haptic(20)
	message_requested.emit("فُتح المخرج! الطريق إلى الأسفل جاهز.")
	_spawn_burst(exit_pos.x, exit_pos.y, Color("7bd88f"), 14, 1.3)

# ---------------------------------------------------------------- gravity

func _resolve_gravity() -> void:
	var moved_any := false
	var fall_distance: Array = []
	for y in range(h):
		var row: Array = []
		for x in range(w):
			row.append(0)
		fall_distance.append(row)
	var guard := 0
	while guard < h + 3:
		var changed := false
		for y in range(h - 2, -1, -1):
			for x in w:
				if int(grid[y][x]) != LevelData.T_ROCK:
					continue
				var ny := y + 1
				if ny >= h:
					continue
				if x == px and ny == py:
					var impact_distance := int(fall_distance[y][x]) + 1
					if impact_distance >= 2:
						dead = true
						_set_animation("die")
						_shake = 1.0
						Sfx.play("die")
						Sfx.haptic(140)
						stats_changed.emit(stats())
						died.emit()
						return
					# A one-cell drop stops above the beaver and blocks the tunnel.
					continue
				if int(grid[ny][x]) != LevelData.T_EMPTY:
					continue
				grid[y][x] = LevelData.T_EMPTY
				grid[ny][x] = LevelData.T_ROCK
				fall_distance[ny][x] = int(fall_distance[y][x]) + 1
				fall_distance[y][x] = 0
				_spawn_burst(x, ny, Color("8b98a2"), 3, 0.7)
				changed = true
				moved_any = true
		if not changed:
			break
		guard += 1
	if moved_any:
		_shake = maxf(_shake, 0.28)
		Sfx.play("rock", randf_range(0.9, 1.05))

# ---------------------------------------------------------------- animation

func _tween_player() -> void:
	if _ptween and _ptween.is_valid():
		_ptween.kill()
	_ptween = create_tween()
	_ptween.tween_property(self, "player_vis", Vector2(px, py), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _spawn_burst(cx: int, cy: int, color: Color, amount: int, power: float) -> void:
	if _particles.size() > 160:
		return
	var center := Vector2((float(cx) + 0.5) * _cell, (float(cy) + 0.5) * _cell)
	for i in amount:
		_particles.append({
			"pos": center + Vector2(randf_range(-0.22, 0.22), randf_range(-0.22, 0.22)) * _cell,
			"vel": Vector2(randf_range(-1.0, 1.0), randf_range(-1.3, 0.25)) * _cell * 2.0 * power,
			"life": randf_range(0.25, 0.55),
			"max": 0.55,
			"color": color,
			"size": _cell * randf_range(0.05, 0.12),
		})

func _process(delta: float) -> void:
	time += delta
	_animation_clock += delta
	if _animation_duration > 0.0:
		_animation_duration = maxf(0.0, _animation_duration - delta)
		if _animation_duration == 0.0 and not dead and not finished:
			_set_animation("idle")
	cooldown = maxf(0.0, cooldown - delta)
	_shake = maxf(0.0, _shake - delta * 2.6)
	_exit_warn = maxf(0.0, _exit_warn - delta * 2.0)
	if not _particles.is_empty():
		var alive: Array = []
		for p in _particles:
			p["life"] = float(p["life"]) - delta
			if float(p["life"]) <= 0.0:
				continue
			p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
			p["vel"] = (p["vel"] as Vector2) + Vector2(0.0, _cell * 11.0 * delta)
			alive.append(p)
		_particles = alive
	queue_redraw()

# ---------------------------------------------------------------- layout / draw

func _layout() -> void:
	if w <= 0 or h <= 0:
		return
	var pad := 10.0
	var available := size - Vector2(pad * 2.0, pad * 2.0)
	_cell = floorf(minf(available.x / float(w), available.y / float(h)))
	if _cell < 6.0:
		_cell = 6.0
	_origin = ((size - Vector2(_cell * w, _cell * h)) * 0.5).floor()
	queue_redraw()

func _draw() -> void:
	if grid.is_empty():
		return
	var jitter := Vector2.ZERO
	if _shake > 0.0:
		jitter = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * _cell * 0.22
	draw_set_transform(_origin + jitter, 0.0, Vector2.ONE)

	var full := Rect2(0.0, 0.0, _cell * w, _cell * h)
	draw_rect(full.grow(7.0), Color("0b080e"))
	draw_rect(full.grow(4.0), Color("382a31"))
	draw_rect(full, Color("211a1f"))

	var open := fruits_left == 0
	for y in h:
		for x in w:
			var rect := Rect2(float(x) * _cell, float(y) * _cell, _cell, _cell)
			PixelArt.draw_tile(self, int(grid[y][x]), rect, Vector2i(x, y), time, open)

	_draw_beaver(jitter)

	for p in _particles:
		var a: float = clampf(float(p["life"]) / float(p["max"]), 0.0, 1.0)
		var c: Color = p["color"]
		c.a = a * 0.9
		draw_rect(Rect2(p["pos"] as Vector2, Vector2(float(p["size"]), float(p["size"]))), c)

	if _exit_warn > 0.0:
		var ec := Vector2((exit_pos.x + 0.5) * _cell, (exit_pos.y + 0.5) * _cell)
		draw_circle(ec, _cell * 0.44, Color(0.95, 0.35, 0.3, 0.18 * _exit_warn))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_beaver(jitter: Vector2) -> void:
	var frames := BeaverArt.frames_for(beaver_animation)
	var rate := 3.2 if beaver_animation == "idle" else 8.0
	var frame_index := floori(_animation_clock * rate)
	if beaver_animation == "die":
		frame_index = mini(frame_index, frames.size() - 1)
	var texture := BeaverArt.texture_for(beaver_animation, frame_index)
	var target_size := Vector2(_cell * 1.18, _cell * 1.48)
	var target := Rect2(
		(player_vis.x + 0.5) * _cell - target_size.x * 0.5,
		(player_vis.y + 1.0) * _cell - target_size.y * 0.92,
		target_size.x,
		target_size.y
	)
	if facing.x < 0:
		draw_set_transform(_origin + jitter + Vector2(target.end.x, target.position.y), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect(texture, Rect2(Vector2.ZERO, target.size), false)
		draw_set_transform(_origin + jitter, 0.0, Vector2.ONE)
	else:
		draw_texture_rect(texture, target, false)

func _set_animation(animation: String, duration := 0.0) -> void:
	if dead and animation != "die":
		return
	beaver_animation = animation
	_animation_clock = 0.0
	_animation_duration = duration

# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not _tracking:
			_tracking = true
			_touch_index = touch.index
			_touch_start = touch.position
		elif not touch.pressed and touch.index == _touch_index:
			_tracking = false
			_touch_index = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not _tracking or drag.index != _touch_index:
			return
		var d := drag.position - _touch_start
		if d.length() < SWIPE_MIN:
			return
		if absf(d.x) > absf(d.y):
			swipe.emit(Vector2i(1 if d.x > 0.0 else -1, 0))
		else:
			swipe.emit(Vector2i(0, 1 if d.y > 0.0 else -1))
		_touch_start = drag.position

func _snapshot() -> Dictionary:
	return {
		"grid": grid.duplicate(true),
		"px": px,
		"py": py,
		"fruits": fruits_left,
		"moves": moves,
	}
