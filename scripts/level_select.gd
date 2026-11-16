extends Control

signal back_requested
signal play_campaign(index: int)
signal play_user(level: Dictionary)
signal edit_user(level: Dictionary)
signal new_level

var _list: VBoxContainer
var _scroll: ScrollContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var margin := UI.margin_control(18)
	UI.full(margin)
	add_child(margin)
	var col := UI.vbox(12)
	margin.add_child(col)

	var top := UI.hbox(12)
	col.add_child(top)
	var back := UI.ghost_button("رجوع", 50)
	back.custom_minimum_size.x = 100
	back.pressed.connect(func(): back_requested.emit())
	top.add_child(back)
	var title := UI.heading("المراحل", 34, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var add := UI.button("مرحلة جديدة", 50, true)
	add.custom_minimum_size.x = 150
	add.add_theme_font_size_override("font_size", 21)
	add.pressed.connect(func(): new_level.emit())
	top.add_child(add)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 12
	col.add_child(_scroll)

	_list = UI.vbox(10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_refresh()

func _refresh() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	_list.add_child(UI.section_title("مراحل اللعبة"))
	var builtins := BuiltinLevels.all()
	for i in builtins.size():
		_list.add_child(_campaign_card(i, builtins[i]))

	_list.add_child(UI.spacer_h(8))
	var my_head := UI.hbox(10)
	my_head.add_child(UI.section_title("مراحلي"))
	var my_count := UI.label("", 19, UITheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	my_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	my_head.add_child(my_count)
	_list.add_child(my_head)

	var mine := Store.list_user_levels()
	my_count.text = "%d مرحلة محفوظة على الجهاز" % mine.size()
	if mine.is_empty():
		var empty := UI.panel(18, Color("1e1725"))
		var e := UI.wrap_label("لم تصنع مرحلة بعد. اضغط «مرحلة جديدة» وارسم فكرتك، ثم اختبرها واحفظها.", 21, UITheme.MUTED)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_child(e)
		_list.add_child(empty)
	else:
		for level in mine:
			_list.add_child(_user_card(level))

	_list.add_child(UI.spacer_h(12))

func _campaign_card(index: int, level: Dictionary) -> Control:
	var card := UI.card()
	var row := UI.hbox(12)
	card.add_child(row)
	var num := UI.chip("%02d" % (index + 1), UITheme.ACCENT)
	num.custom_minimum_size = Vector2(58, 54)
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(num)

	var info := UI.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(UI.heading(String(level.get("name", "")), 24))
	var best := Store.best_for(String(level.get("id", "")))
	var sub := "لم تُلعب بعد"
	if best > 0:
		sub = "أفضل نتيجة: %d حركة" % best
	var sub_label := UI.label(sub, 19, UITheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	info.add_child(sub_label)

	var stars := StarRating.new()
	stars.star_radius = 9.0
	stars.set_rating(Store.stars_for(level, best))
	stars.custom_minimum_size = Vector2(94, 30)
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stars)

	var play := UI.button("العب", 50, true)
	play.custom_minimum_size.x = 92
	play.pressed.connect(func(): play_campaign.emit(index))
	row.add_child(play)
	return card

func _user_card(level: Dictionary) -> Control:
	var card := UI.card()
	var row := UI.hbox(10)
	card.add_child(row)
	var info := UI.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_label := UI.heading(String(level.get("name", "مرحلة")), 23)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(name_label)
	var built := LevelData.build(level)
	var detail := "بقلم %s" % String(level.get("author", "لاعب"))
	if built.get("ok", false):
		detail += " • %d ثمار" % int(built.get("total_fruits", 0))
	var best := Store.best_for(String(level.get("id", "")))
	if best > 0:
		detail += " • أفضل %d" % best
	info.add_child(UI.label(detail, 18, UITheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT))

	var play := UI.button("لعب", 46, true)
	play.custom_minimum_size.x = 70
	play.add_theme_font_size_override("font_size", 20)
	play.pressed.connect(func(): play_user.emit(level))
	row.add_child(play)

	var edit := UI.ghost_button("تعديل", 46)
	edit.custom_minimum_size.x = 78
	edit.add_theme_font_size_override("font_size", 20)
	edit.pressed.connect(func(): edit_user.emit(level))
	row.add_child(edit)

	var del := UI.ghost_button("حذف", 46)
	del.custom_minimum_size.x = 70
	del.add_theme_font_size_override("font_size", 20)
	del.add_theme_color_override("font_color", UITheme.RED)
	del.pressed.connect(func(): _confirm_delete(level))
	row.add_child(del)
	return card

func _confirm_delete(level: Dictionary) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "حذف المرحلة"
	dialog.dialog_text = "هل تريد حذف «%s»؟\nلا يمكن التراجع عن هذا الإجراء." % String(level.get("name", "مرحلة"))
	dialog.ok_button_text = "حذف"
	dialog.theme = UITheme.shared()
	add_child(dialog)
	dialog.confirmed.connect(func():
		Store.delete_user_level(String(level.get("id", "")))
		_refresh()
		_toast("حُذفت المرحلة.")
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(520, 240))

func _toast(text: String) -> void:
	var main := get_tree().current_scene
	if main and main.has_method("toast"):
		main.call("toast", text)
