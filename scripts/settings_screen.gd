extends Control

signal back_requested

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
	var title := UI.heading("الإعدادات", 34, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var pad := Control.new()
	pad.custom_minimum_size.x = 100
	top.add_child(pad)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12
	col.add_child(scroll)
	var v := UI.vbox(12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	v.add_child(_language_card())
	v.add_child(_toggle_card("إظهار أسهم التحكم", "يمكنك إخفاؤها واستخدام السحب أو لوحة المفاتيح.", bool(Store.settings.get("show_arrows", true)), _on_show_arrows))
	v.add_child(_display_scale_card())
	v.add_child(_toggle_card("المؤثرات الصوتية", "نغمات الحفر والجمع والنجاح", bool(Store.settings.get("sound", true)), _on_sound))
	v.add_child(_toggle_card("الاهتزاز", "لمسات خفيفة على الجوال", bool(Store.settings.get("haptics", true)), _on_haptics))

	# Player name
	var name_card := UI.card()
	var nv := UI.vbox(8)
	name_card.add_child(nv)
	nv.add_child(UI.heading("اسم اللاعب", 24))
	nv.add_child(UI.label("يظهر مع المراحل التي تنشرها.", 19, UITheme.MUTED))
	var name_row := UI.hbox(8)
	nv.add_child(name_row)
	var name_edit := LineEdit.new()
	name_edit.text = String(Store.settings.get("author", "لاعب"))
	name_edit.custom_minimum_size = Vector2(0, 48)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_edit)
	var name_save := UI.button("حفظ", 48, true)
	name_save.custom_minimum_size.x = 90
	name_save.pressed.connect(func():
		var n := name_edit.text.strip_edges()
		if n == "":
			n = "لاعب"
		Store.set_setting("author", n)
		name_edit.text = n
		_toast("حُفظ الاسم.")
	)
	name_row.add_child(name_save)
	v.add_child(name_card)

	# Server
	var server_card := UI.card()
	var sv := UI.vbox(8)
	server_card.add_child(sv)
	sv.add_child(UI.heading("خادم المراحل", 24))
	sv.add_child(UI.wrap_label("الخادم السحابي جاهز افتراضيًا.\nللتجربة محليًا استخدم http://127.0.0.1:8787 أو عنوان الكمبيوتر على شبكة Wi-Fi.", 19, UITheme.MUTED))
	var server_row := UI.hbox(8)
	sv.add_child(server_row)
	var server_edit := LineEdit.new()
	server_edit.text = String(Store.settings.get("server_url", "https://khold-levels.mayam33.workers.dev"))
	server_edit.custom_minimum_size = Vector2(0, 48)
	server_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	server_row.add_child(server_edit)
	var server_save := UI.button("حفظ", 48, true)
	server_save.custom_minimum_size.x = 90
	server_save.pressed.connect(func():
		var u := server_edit.text.strip_edges().trim_suffix("/")
		if u == "":
			u = "https://khold-levels.mayam33.workers.dev"
		if not u.begins_with("http://") and not u.begins_with("https://"):
			u = "http://" + u
		Store.set_setting("server_url", u)
		server_edit.text = u
		_toast("حُفظ عنوان الخادم.")
	)
	server_row.add_child(server_save)
	v.add_child(server_card)

	# About
	var about := UI.card()
	var av := UI.vbox(8)
	about.add_child(av)
	av.add_child(UI.heading("عن اللعبة", 24))
	av.add_child(UI.wrap_label("Beaver Explorer مغامرة قندس استكشف فيها الأنفاق تحت الأرض. رسوم الشخصية مبنية على ورقة الرسوم التي زودنا بها اللاعب.", 20, UITheme.MUTED))
	av.add_child(UI.wrap_label("صُنعت بـ Godot 4. أسلوب اللعب يستلهم ألعاب الحفر الكلاسيكية مع مراحل ومحتوى أصليين.", 19, UITheme.MUTED))
	var links := UI.hbox(14)
	links.add_child(_link("ترخيص Godot", "https://godotengine.org/license/"))
	links.add_child(_link("رخصة الخط", "https://scripts.sil.org/OFL"))
	av.add_child(links)
	v.add_child(about)

	var reset := UI.ghost_button("مسح التقدم", 54)
	reset.add_theme_color_override("font_color", UITheme.RED)
	reset.pressed.connect(_confirm_reset)
	v.add_child(reset)
	v.add_child(UI.label("الإصدار 1.1.0", 18, Color("7c6f84"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.spacer_h(20))

func _toggle_card(title: String, subtitle: String, value: bool, handler: Callable) -> Control:
	var card := UI.card()
	var row := UI.hbox(12)
	card.add_child(row)
	var info := UI.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(UI.heading(title, 23))
	info.add_child(UI.label(subtitle, 19, UITheme.MUTED))
	var check := CheckButton.new()
	check.button_pressed = value
	check.focus_mode = Control.FOCUS_NONE
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	check.toggled.connect(handler)
	row.add_child(check)
	return card

func _language_card() -> Control:
	var card := UI.card()
	var row := UI.hbox(12)
	card.add_child(row)
	var title := UI.heading("اللغة", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var choice := OptionButton.new()
	choice.custom_minimum_size = Vector2(160, 48)
	choice.focus_mode = Control.FOCUS_NONE
	choice.add_item("English", 0)
	choice.add_item("العربية", 1)
	choice.select(0 if I18n.language == "en" else 1)
	choice.item_selected.connect(_on_language_selected)
	row.add_child(choice)
	return card

func _display_scale_card() -> Control:
	var card := UI.card()
	var col := UI.vbox(8)
	card.add_child(col)
	var row := UI.hbox(8)
	var label := UI.heading("حجم العرض", 23)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value_label := UI.label("%d%%" % roundi(float(Store.settings.get("display_scale", 1.0)) * 100.0), 20, UITheme.ACCENT)
	value_label.name = "DisplayScaleValue"
	value_label.custom_minimum_size.x = 68
	row.add_child(value_label)
	col.add_child(row)
	col.add_child(UI.label("كبّر أو صغّر واجهة اللعبة.", 18, UITheme.MUTED))
	var slider := HSlider.new()
	slider.min_value = 0.8
	slider.max_value = 1.2
	slider.step = 0.1
	slider.value = float(Store.settings.get("display_scale", 1.0))
	slider.custom_minimum_size.y = 32
	slider.value_changed.connect(_on_display_scale_changed.bind(value_label))
	col.add_child(slider)
	return card

func _on_language_selected(index: int) -> void:
	I18n.set_language("en" if index == 0 else "ar")

func _on_show_arrows(enabled: bool) -> void:
	Store.set_setting("show_arrows", enabled)

func _on_display_scale_changed(value: float, value_label: Label) -> void:
	Store.set_setting("display_scale", value)
	value_label.text = "%d%%" % roundi(value * 100.0)
	var main := get_tree().current_scene
	if main and main.has_method("apply_display_scale"):
		main.call("apply_display_scale")

func _link(text: String, uri: String) -> LinkButton:
	var b := LinkButton.new()
	b.text = text
	b.uri = uri
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", UITheme.ACCENT)
	b.add_theme_color_override("font_hover_color", Color("ffd166"))
	b.focus_mode = Control.FOCUS_NONE
	return b

func _on_sound(on: bool) -> void:
	Store.set_setting("sound", on)
	if on:
		Sfx.play("click")

func _on_haptics(on: bool) -> void:
	Store.set_setting("haptics", on)
	if on:
		Sfx.haptic(20)

func _confirm_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "مسح التقدم"
	dialog.dialog_text = "سيُمسح أفضل نتيجة ونجوم كل المراحل الأساسية. المراحل التي صنعتها لن تُحذف."
	dialog.ok_button_text = "امسح"
	dialog.theme = UITheme.shared()
	add_child(dialog)
	I18n.translate_tree(dialog)
	dialog.confirmed.connect(func():
		Store.reset_progress()
		_toast("تم مسح التقدم.")
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(540, 250))

func _toast(text: String) -> void:
	var main := get_tree().current_scene
	if main and main.has_method("toast"):
		main.call("toast", text)
