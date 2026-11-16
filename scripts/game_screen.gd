extends Control

## Gameplay screen: HUD, touch controls and the result dialogs.

signal exit_requested
signal next_requested

var level: Dictionary = {}
var campaign: Array = []
var campaign_index := -1
var test_mode := false

var board: DigBoard
var dpad: DPad
var moves_chip: PanelContainer
var fruits_chip: PanelContainer
var par_chip: PanelContainer
var overlay: Control
var _held := Vector2i.ZERO
var _overlay_open := false
var _overlay_kind := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if level.is_empty():
		level = BuiltinLevels.all()[0]

	var bg := preload("res://scripts/background.gd").new()
	add_child(bg)

	var margin := UI.margin_control(16)
	UI.full(margin)
	add_child(margin)
	var col := UI.vbox(10)
	margin.add_child(col)

	# Top bar
	var top := UI.hbox(10)
	top.custom_minimum_size = Vector2(0, 48)
	col.add_child(top)
	var menu_btn := UI.ghost_button("القائمة", 48)
	menu_btn.custom_minimum_size.x = 112
	menu_btn.pressed.connect(_open_pause)
	top.add_child(menu_btn)
	var title := UI.heading(String(level.get("name", "مرحلة")), 26, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	top.add_child(title)
	var tag := UI.label("اختبار" if test_mode else "", 20, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	tag.custom_minimum_size.x = 112
	top.add_child(tag)

	# Stat chips
	var chips := UI.hbox(10)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(chips)
	moves_chip = UI.chip("الحركات 0")
	fruits_chip = UI.chip("الثمار 0/0")
	par_chip = UI.chip("الهدف —")
	chips.add_child(moves_chip)
	chips.add_child(fruits_chip)
	chips.add_child(par_chip)
	if int(level.get("par", 0)) <= 0:
		par_chip.visible = false

	if String(level.get("id", "")) == "b01" and not test_mode:
		var hint := UI.label("اسحب فوق الأرض للحفر، أو استخدم الأسهم.", 19, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		col.add_child(hint)

	# Board
	var host := Control.new()
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.custom_minimum_size = Vector2(0, 260)
	col.add_child(host)
	board = DigBoard.new()
	UI.full(board)
	host.add_child(board)

	# Controls
	var bottom := UI.hbox(18)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.custom_minimum_size = Vector2(0, 252)
	col.add_child(bottom)
	var undo_btn := UI.ghost_button("تراجع", 82)
	undo_btn.custom_minimum_size = Vector2(104, 82)
	undo_btn.add_theme_font_size_override("font_size", 22)
	undo_btn.pressed.connect(_undo)
	bottom.add_child(undo_btn)
	dpad = DPad.new()
	dpad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(dpad)
	var restart_btn := UI.ghost_button("إعادة", 82)
	restart_btn.custom_minimum_size = Vector2(104, 82)
	restart_btn.add_theme_font_size_override("font_size", 22)
	restart_btn.pressed.connect(_restart)
	bottom.add_child(restart_btn)

	# Overlay layer
	overlay = Control.new()
	UI.full(overlay)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)

	board.stats_changed.connect(_on_stats)
	board.won.connect(_on_won)
	board.died.connect(_on_died)
	board.message_requested.connect(_toast)
	board.swipe.connect(_on_swipe)
	dpad.dir_pressed.connect(_on_dpad_pressed)
	dpad.dir_released.connect(_on_dpad_released)

	if not board.load_level(level):
		call_deferred("_fail")

	_on_dpad_released()

func _process(_delta: float) -> void:
	if _overlay_open or board == null:
		return
	var dir := _held
	if dir == Vector2i.ZERO:
		dir = _read_keys()
	if dir == Vector2i.ZERO:
		return
	if board.cooldown <= 0.0:
		board.try_move(dir)

func _read_keys() -> Vector2i:
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		return Vector2i(0, -1)
	if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		return Vector2i(0, 1)
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		return Vector2i(-1, 0)
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		return Vector2i(1, 0)
	return Vector2i.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _overlay_open:
			if _overlay_kind == "pause":
				_close_modal()
		else:
			_open_pause()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _overlay_open:
			if _overlay_kind == "pause":
				_close_modal()
		else:
			_open_pause()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_inside_tree() and not _overlay_open and not board == null:
			_open_pause()

# ---------------------------------------------------------------- HUD

func _on_stats(stats: Dictionary) -> void:
	if moves_chip == null:
		return
	UI.set_chip(moves_chip, "الحركات %d" % int(stats.get("moves", 0)))
	UI.set_chip(fruits_chip, "الثمار %d/%d" % [
		int(stats.get("fruits_total", 0)) - int(stats.get("fruits_left", 0)),
		int(stats.get("fruits_total", 0)),
	])
	var p := int(stats.get("par", 0))
	par_chip.visible = p > 0
	if p > 0:
		UI.set_chip(par_chip, "الهدف %d" % p)
	var fl := fruits_chip.get_node_or_null("Value") as Label
	if fl:
		fl.add_theme_color_override("font_color", UITheme.GREEN if int(stats.get("fruits_left", 1)) == 0 else UITheme.TEXT)

func _on_swipe(dir: Vector2i) -> void:
	if not _overlay_open and board:
		board.try_move(dir)

func _on_dpad_pressed(dir: Vector2i) -> void:
	if _overlay_open:
		return
	_held = dir
	if board:
		board.try_move(dir)

func _on_dpad_released() -> void:
	_held = Vector2i.ZERO

func _toast(text: String) -> void:
	var main := get_tree().current_scene
	if main and main.has_method("toast"):
		main.call("toast", text)

func _fail() -> void:
	_toast("تعذر تحميل المرحلة.")
	exit_requested.emit()

# ---------------------------------------------------------------- actions

func _undo() -> void:
	if board == null:
		return
	if board.undo():
		if _overlay_open:
			_close_modal()
	else:
		_toast("لا يوجد ما يمكن التراجع عنه.")

func _restart() -> void:
	if board == null:
		return
	_close_modal()
	_held = Vector2i.ZERO
	board.restart()

func _open_pause() -> void:
	if _overlay_open or board == null:
		return
	_held = Vector2i.ZERO
	if dpad:
		dpad.active = Vector2i.ZERO
		dpad.queue_redraw()
	var body := UI.vbox(4)
	var l := UI.wrap_label("خذ نفسًا. الأرض لن تهرب.", 23, UITheme.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(l)
	if not test_mode:
		body.add_child(UI.label("مرحلة: %s" % String(level.get("name", "")), 20, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var resume := UI.button("متابعة", 58, true)
	resume.custom_minimum_size.x = 150
	resume.pressed.connect(_close_modal)
	var restart := UI.ghost_button("إعادة", 58)
	restart.custom_minimum_size.x = 130
	restart.pressed.connect(_restart)
	var quit := UI.ghost_button("خروج", 58)
	quit.custom_minimum_size.x = 120
	quit.pressed.connect(func(): exit_requested.emit())
	_show_modal("pause", "إيقاف مؤقت", body, [resume, restart, quit])

# ---------------------------------------------------------------- results

func _on_won() -> void:
	_held = Vector2i.ZERO
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree() or board == null:
		return
	var moves := board.moves
	var stars := 3
	if not test_mode:
		if String(level.get("id", "")) != "":
			Store.mark_complete(String(level.get("id", "")), moves)
		stars = Store.stars_for(level, moves)
	var content := UI.vbox(6)
	var star_row := StarRating.new()
	star_row.set_rating(stars)
	star_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	star_row.custom_minimum_size = Vector2(220, 54)
	content.add_child(star_row)
	if test_mode:
		content.add_child(UI.label("نجحت المرحلة في الاختبار!", 23, UITheme.GREEN, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		content.add_child(UI.label("الحركات: %d" % moves, 24, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		if int(level.get("par", 0)) > 0:
			content.add_child(UI.label("الهدف: %d حركة" % int(level.get("par", 0)), 21, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		var best := Store.best_for(String(level.get("id", "")))
		if best > 0:
			content.add_child(UI.label("أفضل نتيجة: %d" % best, 21, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	var buttons: Array = []
	if test_mode:
		var back := UI.button("العودة للمحرر", 58, true)
		back.custom_minimum_size.x = 200
		back.pressed.connect(func(): exit_requested.emit())
		buttons.append(back)
	elif campaign_index >= 0 and campaign_index + 1 < campaign.size():
		var nxt := UI.button("المرحلة التالية", 58, true)
		nxt.custom_minimum_size.x = 200
		nxt.pressed.connect(func(): next_requested.emit())
		buttons.append(nxt)
	else:
		var list_btn := UI.button("قائمة المراحل", 58, true)
		list_btn.custom_minimum_size.x = 190
		list_btn.pressed.connect(func(): exit_requested.emit())
		buttons.append(list_btn)
	var again := UI.ghost_button("إعادة", 58)
	again.custom_minimum_size.x = 120
	again.pressed.connect(_restart)
	buttons.append(again)
	_show_modal("win", "أحسنت!", content, buttons)

func _on_died() -> void:
	_held = Vector2i.ZERO
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree() or _overlay_open:
		return
	var content := UI.vbox(6)
	var l := UI.wrap_label("سقطت صخرة عليك. جرّب طريقًا آخر، أو تراجع خطوة.", 23, UITheme.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(l)
	var undo := UI.button("تراجع", 58, true)
	undo.custom_minimum_size.x = 130
	undo.pressed.connect(_undo)
	var again := UI.ghost_button("إعادة", 58)
	again.custom_minimum_size.x = 130
	again.pressed.connect(_restart)
	_show_modal("death", "سحقتك الصخرة!", content, [undo, again])

# ---------------------------------------------------------------- modal

func _show_modal(kind: String, title: String, content: Control, buttons: Array) -> void:
	_overlay_kind = kind
	_overlay_open = true
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	overlay.visible = true

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.04, 0.76)
	UI.full(dim)
	overlay.add_child(dim)

	var center := CenterContainer.new()
	UI.full(center)
	overlay.add_child(center)
	var panel := UI.panel(20)
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	var v := UI.vbox(14)
	panel.add_child(v)
	v.add_child(UI.heading(title, 32, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(content)
	var row := UI.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for b in buttons:
		row.add_child(b)
	v.add_child(row)

func _close_modal() -> void:
	_overlay_open = false
	_overlay_kind = ""
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	overlay.visible = false
