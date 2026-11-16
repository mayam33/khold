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
	av.add_child(UI.wrap_label("خُلد لعبة حفر بكسل أصلية، مفتوحة المصدر برخصة MIT. كل الرسومات والأصوات تُرسم وتُولّد بالكود داخل المشروع، ولا تحتوي اللعبة على أصول فنية منسوخة من أي لعبة أخرى.", 20, UITheme.MUTED))
	av.add_child(UI.wrap_label("صُنعت بـ Godot 4. الخط: Almarai برخصة SIL Open Font License. أسلوب اللعب مستلهم من ألعاب الحفر الكلاسيكية مع تصميم ومحتوى أصليين.", 19, UITheme.MUTED))
	var links := UI.hbox(14)
	links.add_child(_link("ترخيص Godot", "https://godotengine.org/license/"))
	links.add_child(_link("رخصة الخط", "https://scripts.sil.org/OFL"))
	av.add_child(links)
	v.add_child(about)

	var reset := UI.ghost_button("مسح التقدم", 54)
	reset.add_theme_color_override("font_color", UITheme.RED)
	reset.pressed.connect(_confirm_reset)
	v.add_child(reset)
	v.add_child(UI.label("الإصدار 1.0.0", 18, Color("7c6f84"), HORIZONTAL_ALIGNMENT_CENTER))
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
