extends Control

signal back_requested
signal test_requested(level: Dictionary)

const TOOL_PLAYER := 99

var editing_level: Dictionary = {}
var w := 12
var h := 16
var cells: Array = []
var player := Vector2i(1, 1)
var tool := LevelData.T_DIRT
var dirty := false

var board: EditorBoard
var name_edit: LineEdit
var hint_label: Label
var _tool_hint: Label
var _tool_buttons: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_load_initial()

	var margin := UI.margin_control(14)
	UI.full(margin)
	add_child(margin)
	var col := UI.vbox(8)
	margin.add_child(col)

	# Header
	var top := UI.hbox(8)
	col.add_child(top)
	var back := UI.ghost_button("رجوع", 48)
	back.custom_minimum_size.x = 92
	back.pressed.connect(_back)
	top.add_child(back)
	name_edit = LineEdit.new()
	name_edit.text = String(editing_level.get("name", "مرحلتي"))
	name_edit.placeholder_text = "اسم المرحلة"
	name_edit.custom_minimum_size = Vector2(0, 48)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(_t): dirty = true)
	top.add_child(name_edit)
	var save := UI.button("حفظ", 48, true)
	save.custom_minimum_size.x = 96
	save.pressed.connect(_save)
	top.add_child(save)

	# Info row
	var info := UI.hbox(8)
	col.add_child(info)
	hint_label = UI.label("", 19, UITheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(hint_label)
	_tool_hint = UI.label("", 19, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_LEFT)
	info.add_child(_tool_hint)

	# Canvas
	var host := Control.new()
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.custom_minimum_size = Vector2(0, 300)
	col.add_child(host)
	board = EditorBoard.new()
	UI.full(board)
	host.add_child(board)
	board.painted.connect(_paint_cell)
	board.configure(cells, w, h, player)

	# Palette
	var palette := UI.panel(10, Color("211a29"))
	col.add_child(palette)
	var pv := UI.vbox(6)
	palette.add_child(pv)
	pv.add_child(UI.label("الأدوات — ارسم بإصبعك على اللوحة", 18, UITheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT))
	var tools_row := UI.hbox(7)
	tools_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_child(tools_row)
	var group := ButtonGroup.new()
	var tools := [
		{"id": LevelData.T_DIRT, "label": "تراب"},
		{"id": LevelData.T_EMPTY, "label": "فراغ"},
		{"id": LevelData.T_ROCK, "label": "صخر"},
		{"id": LevelData.T_STEEL, "label": "فولاذ"},
		{"id": LevelData.T_FRUIT, "label": "فاكهة"},
		{"id": LevelData.T_EXIT, "label": "مخرج"},
		{"id": TOOL_PLAYER, "label": "لاعب"},
	]
	for t in tools:
		var b := Button.new()
		b.text = String(t["label"])
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(82, 48)
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_stylebox_override("pressed", UITheme.box(UITheme.ACCENT, 12, UITheme.ACCENT_DARK, 2, 8, 6))
		b.add_theme_stylebox_override("hover_pressed", UITheme.box(Color("ffc75f"), 12, UITheme.ACCENT, 2, 8, 6))
		b.add_theme_color_override("font_pressed_color", UITheme.ACCENT_INK)
		b.add_theme_color_override("font_hover_pressed_color", UITheme.ACCENT_INK)
		var tid: int = int(t["id"])
		b.button_pressed = tid == tool
		b.toggled.connect(func(on: bool):
			if on:
				_select_tool(tid)
		)
		tools_row.add_child(b)
		_tool_buttons.append(b)

	# Test / reset
	var actions := UI.hbox(10)
	col.add_child(actions)
	var test := UI.button("اختبار المرحلة", 56, true)
	test.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	test.pressed.connect(_test)
	actions.add_child(test)
	var reset := UI.ghost_button("لوحة جديدة", 56)
	reset.custom_minimum_size.x = 150
	reset.pressed.connect(_confirm_reset)
	actions.add_child(reset)

	_update_labels()

func _load_initial() -> void:
	var rows: Array = []
	if not editing_level.is_empty() and editing_level.has("rows"):
		var built := LevelData.build(editing_level)
		if bool(built.get("ok", false)):
			w = int(built.get("w", 12))
			h = int(built.get("h", 16))
			rows = editing_level.get("rows", [])
			player = built.get("player", Vector2i(1, 1))
	if rows.is_empty():
		rows = LevelData.default_rows()
		w = 12
		h = 16
		editing_level = {"name": "مرحلتي", "author": String(Store.settings.get("author", "لاعب"))}
	var parsed := LevelData.cells_from_rows(rows, w, h)
	cells = parsed["cells"]
	player = parsed["player"]
	dirty = false

func _paint_cell(cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= w or cell.y >= h:
		return
	if tool == TOOL_PLAYER:
		if int(cells[cell.y][cell.x]) == LevelData.T_STEEL:
			cells[cell.y][cell.x] = LevelData.T_EMPTY
		player = cell
	else:
		if cell == player:
			return
		if tool == LevelData.T_EXIT:
			for y in h:
				for x in w:
					if int(cells[y][x]) == LevelData.T_EXIT:
						cells[y][x] = LevelData.T_DIRT
		cells[cell.y][cell.x] = tool
	board.player = player
	board.queue_redraw()
	dirty = true
	_update_labels()

func _select_tool(id: int) -> void:
	tool = id
	var names := {
		LevelData.T_DIRT: "تراب",
		LevelData.T_EMPTY: "فراغ",
		LevelData.T_ROCK: "صخر",
		LevelData.T_STEEL: "فولاذ",
		LevelData.T_FRUIT: "فاكهة",
		LevelData.T_EXIT: "مخرج",
		TOOL_PLAYER: "لاعب",
	}
	I18n.set_node_text(_tool_hint, &"text", "الأداة: %s" % String(names.get(id, "")))
	Sfx.play("click", 1.2)

func _update_labels() -> void:
	var fruits := _count_fruits()
	I18n.set_node_text(hint_label, &"text", "ثمار: %d • المقاس %d×%d" % [fruits, w, h])
	if _tool_hint.text == "":
		I18n.set_node_text(_tool_hint, &"text", "الأداة: تراب")

func _count_fruits() -> int:
	var n := 0
	for y in h:
		for x in w:
			if int(cells[y][x]) == LevelData.T_FRUIT:
				n += 1
	return n

func _build_current() -> Dictionary:
	var level_name := name_edit.text.strip_edges()
	if level_name == "":
		level_name = "مرحلتي"
	return {
		"id": String(editing_level.get("id", "")),
		"name": level_name,
		"author": String(Store.settings.get("author", "لاعب")),
		"w": w,
		"h": h,
		"rows": LevelData.rows_from_cells(cells, player, w, h),
		"par": int(editing_level.get("par", 0)),
		"source": "user",
		"created_at": int(editing_level.get("created_at", Time.get_unix_time_from_system())),
	}

func _validated() -> Dictionary:
	var lv := _build_current()
	var built := LevelData.build(lv)
	if not bool(built.get("ok", false)):
		_toast(String(built.get("error", "المرحلة غير صالحة.")))
		return {}
	if not _reachable(built):
		_toast("المخرج أو إحدى الثمار غير قابلة للوصول. افتح طريقًا.")
		return {}
	return lv

func _reachable(built: Dictionary) -> bool:
	var grid: Array = built["grid"]
	var start: Vector2i = built["player"]
	var seen: Array = []
	for y in h:
		var row: Array = []
		for x in w:
			row.append(false)
		seen.append(row)
	var stack: Array = [start]
	seen[start.y][start.x] = true
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				continue
			if seen[n.y][n.x]:
				continue
			if int(grid[n.y][n.x]) == LevelData.T_STEEL:
				continue
			seen[n.y][n.x] = true
			stack.append(n)
	for y in h:
		for x in w:
			var t := int(grid[y][x])
			if (t == LevelData.T_FRUIT or t == LevelData.T_EXIT) and not seen[y][x]:
				return false
	return true

func _save() -> void:
	var lv := _validated()
	if lv.is_empty():
		return
	var saved := Store.save_user_level(lv)
	editing_level = saved
	dirty = false
	_toast("تم حفظ «%s»." % String(saved.get("name", "")))
	Sfx.play("collect", 1.0)

func _test() -> void:
	var lv := _validated()
	if lv.is_empty():
		return
	test_requested.emit(lv)

func _back() -> void:
	if not dirty:
		back_requested.emit()
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "خروج دون حفظ"
	dialog.dialog_text = "لديك تعديلات غير محفوظة. هل تريد الخروج؟"
	dialog.ok_button_text = "خروج"
	dialog.theme = UITheme.shared()
	add_child(dialog)
	I18n.translate_tree(dialog)
	dialog.confirmed.connect(func(): back_requested.emit())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(520, 240))

func _confirm_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "لوحة جديدة"
	dialog.dialog_text = "سيتم مسح كل ما رسمته. هل تريد المتابعة؟"
	dialog.ok_button_text = "امسح"
	dialog.theme = UITheme.shared()
	add_child(dialog)
	I18n.translate_tree(dialog)
	dialog.confirmed.connect(func():
		var rows := LevelData.default_rows()
		var parsed := LevelData.cells_from_rows(rows, 12, 16)
		w = 12
		h = 16
		cells = parsed["cells"]
		player = parsed["player"]
		board.configure(cells, w, h, player)
		dirty = true
		_update_labels()
		_toast("لوحة جديدة جاهزة.")
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(520, 240))

func _toast(text: String) -> void:
	var main := get_tree().current_scene
	if main and main.has_method("toast"):
		main.call("toast", text)
