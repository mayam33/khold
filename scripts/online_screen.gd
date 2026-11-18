extends Control

## Online hub: browse, play, rate, report and publish levels.
## Talks to the bundled server/server.py over a small JSON API.

signal back_requested
signal play_level(level: Dictionary)

var _http: HTTPRequest
var _status: Label
var _list: VBoxContainer
var _url_edit: LineEdit
var _busy := false
var _online: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_http = HTTPRequest.new()
	_http.timeout = 12.0
	add_child(_http)

	var margin := UI.margin_control(18)
	UI.full(margin)
	add_child(margin)
	var col := UI.vbox(10)
	margin.add_child(col)

	var top := UI.hbox(10)
	col.add_child(top)
	var back := UI.ghost_button("رجوع", 50)
	back.custom_minimum_size.x = 100
	back.pressed.connect(func(): back_requested.emit())
	top.add_child(back)
	var title := UI.heading("مراحل الإنترنت", 32, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var refresh := UI.button("تحديث", 50, true)
	refresh.custom_minimum_size.x = 110
	refresh.pressed.connect(_refresh)
	top.add_child(refresh)

	var url_row := UI.card()
	col.add_child(url_row)
	var uv := UI.vbox(6)
	url_row.add_child(uv)
	uv.add_child(UI.label("عنوان الخادم", 19, UITheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT))
	var uh := UI.hbox(8)
	uv.add_child(uh)
	_url_edit = LineEdit.new()
	_url_edit.text = String(Store.settings.get("server_url", "https://khold-levels.mayam33.workers.dev"))
	_url_edit.custom_minimum_size = Vector2(0, 46)
	_url_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uh.add_child(_url_edit)
	var connect := UI.ghost_button("اتصال", 46)
	connect.custom_minimum_size.x = 92
	connect.pressed.connect(_refresh)
	uh.add_child(connect)

	_status = UI.wrap_label("جاهز.", 19, UITheme.MUTED)
	col.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12
	col.add_child(scroll)
	_list = UI.vbox(10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_refresh.call_deferred()

func _base_url() -> String:
	var u := _url_edit.text.strip_edges()
	if u == "":
		u = "https://khold-levels.mayam33.workers.dev"
	if not u.begins_with("http://") and not u.begins_with("https://"):
		u = "http://" + u
	return u.trim_suffix("/")

func _refresh() -> void:
	if _busy:
		return
	_busy = true
	var base := _base_url()
	Store.set_setting("server_url", base)
	_url_edit.text = base
	_set_status("جارٍ الاتصال بالخادم…")
	var res: Dictionary = await _request("GET", "/levels?limit=60")
	_busy = false
	if not is_inside_tree():
		return
	if bool(res.get("ok", false)):
		_online = res.get("data", {}).get("levels", [])
		if not (_online is Array):
			_online = []
		_set_status("تم الاتصال • %d مرحلة منشورة." % _online.size(), false)
	else:
		_online = []
		_set_status(String(res.get("error", "تعذر الاتصال.")) + " — يمكنك لعب المراحل المنزّلة أو نشر مراحلك عند عودة الاتصال.", true)
	_rebuild()

func _request(method: String, path: String, body: Variant = null) -> Dictionary:
	var m := HTTPClient.METHOD_GET
	if method == "POST":
		m = HTTPClient.METHOD_POST
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	var payload := ""
	if body != null:
		payload = JSON.stringify(body)
	var err := _http.request(_base_url() + path, headers, m, payload)
	if err != OK:
		_busy = false
		return {"ok": false, "error": "تعذر بدء الاتصال (رمز %d)." % err}
	var result: Array = await _http.request_completed
	if not is_inside_tree():
		return {"ok": false, "error": ""}
	var transport := int(result[0])
	var code := int(result[1])
	var raw: PackedByteArray = result[3]
	var text := raw.get_string_from_utf8()
	if transport != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "فشل الاتصال بالخادم. تأكد من تشغيله ومن العنوان."}
	var parsed: Variant = JSON.parse_string(text)
	if code < 200 or code >= 300:
		var msg := "خطأ من الخادم (%d)." % code
		if parsed is Dictionary and parsed.has("error"):
			msg = String(parsed["error"])
		return {"ok": false, "error": msg}
	if not (parsed is Dictionary):
		return {"ok": false, "error": "رد غير مفهوم من الخادم."}
	return {"ok": true, "data": parsed}

func _set_status(text: String, error := false) -> void:
	if _status == null:
		return
	I18n.set_node_text(_status, &"text", text)
	_status.add_theme_color_override("font_color", UITheme.RED if error else UITheme.MUTED)

func _rebuild() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	_list.add_child(UI.section_title("مراحل منشورة"))
	if _online.is_empty():
		var p := UI.panel(16, Color("1e1725"))
		p.add_child(UI.wrap_label("لا توجد مراحل من الخادم الآن. شغّل خادم المراحل ثم اضغط «تحديث».", 20, UITheme.MUTED))
		_list.add_child(p)
	else:
		for level in _online:
			_list.add_child(_online_card(level))

	_list.add_child(UI.spacer_h(6))
	_list.add_child(UI.section_title("مراحل نزّلتها"))
	var downloads := Store.list_downloads()
	if downloads.is_empty():
		var p2 := UI.panel(14, Color("1e1725"))
		p2.add_child(UI.wrap_label("كل مرحلة تنزّلها تُحفظ هنا للعب دون اتصال.", 19, UITheme.MUTED))
		_list.add_child(p2)
	else:
		for level in downloads:
			_list.add_child(_download_card(level))

	_list.add_child(UI.spacer_h(6))
	_list.add_child(UI.section_title("نشر مراحلي"))
	var mine := Store.list_user_levels()
	if mine.is_empty():
		var p3 := UI.panel(14, Color("1e1725"))
		p3.add_child(UI.wrap_label("اصنع مرحلة في المحرر أولًا، ثم عد إلى هنا لنشرها.", 19, UITheme.MUTED))
		_list.add_child(p3)
	else:
		for level in mine:
			_list.add_child(_publish_card(level))
	_list.add_child(UI.spacer_h(16))

func _online_card(level: Dictionary) -> Control:
	var card := UI.card()
	var v := UI.vbox(4)
	card.add_child(v)
	var head := UI.hbox(8)
	v.add_child(head)
	var name_label := UI.heading(String(level.get("name", "مرحلة")), 23)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(name_label)
	v.add_child(UI.label("بقلم %s" % String(level.get("author", "لاعب")), 18, UITheme.MUTED))
	var rating := float(level.get("rating", 0.0))
	var count := int(level.get("rating_count", 0))
	var plays := int(level.get("plays", 0))
	v.add_child(UI.label("التقييم %.1f/5 (%d) • %d لعبة" % [rating, count, plays], 18, UITheme.MUTED))

	var row := UI.hbox(8)
	v.add_child(row)
	var play := UI.button("لعب", 44, true)
	play.custom_minimum_size.x = 70
	play.add_theme_font_size_override("font_size", 19)
	var id := String(level.get("id", ""))
	play.pressed.connect(func(): _play_online(id))
	row.add_child(play)
	var rate := UI.ghost_button("تقييم", 44)
	rate.custom_minimum_size.x = 78
	rate.add_theme_font_size_override("font_size", 19)
	rate.pressed.connect(func(): _show_rating(level))
	row.add_child(rate)
	var report := UI.ghost_button("إبلاغ", 44)
	report.custom_minimum_size.x = 78
	report.add_theme_font_size_override("font_size", 19)
	report.add_theme_color_override("font_color", UITheme.RED)
	report.pressed.connect(func(): _confirm_report(level))
	row.add_child(report)
	return card

func _download_card(level: Dictionary) -> Control:
	var card := UI.card()
	var row := UI.hbox(8)
	card.add_child(row)
	var info := UI.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(UI.heading(String(level.get("name", "مرحلة")), 22))
	info.add_child(UI.label("بقلم %s • محفوظة على الجهاز" % String(level.get("author", "لاعب")), 18, UITheme.MUTED))
	var play := UI.button("لعب", 44, true)
	play.custom_minimum_size.x = 70
	play.add_theme_font_size_override("font_size", 19)
	play.pressed.connect(func(): play_level.emit(level))
	row.add_child(play)
	var del := UI.ghost_button("حذف", 44)
	del.custom_minimum_size.x = 70
	del.add_theme_font_size_override("font_size", 19)
	del.add_theme_color_override("font_color", UITheme.RED)
	del.pressed.connect(func(): _confirm_delete_download(level))
	row.add_child(del)
	return card

func _publish_card(level: Dictionary) -> Control:
	var card := UI.card()
	var row := UI.hbox(8)
	card.add_child(row)
	var info := UI.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(UI.heading(String(level.get("name", "مرحلة")), 22))
	var published := String(level.get("online_id", "")) != ""
	info.add_child(UI.label("منشورة مسبقًا" if published else "محفوظة على الجهاز", 18, UITheme.GREEN if published else UITheme.MUTED))
	var pub := UI.button("نشر" if not published else "نشر نسخة", 44, not published)
	pub.custom_minimum_size.x = 120
	pub.add_theme_font_size_override("font_size", 19)
	pub.pressed.connect(func(): _publish(level))
	row.add_child(pub)
	return card

# ---------------------------------------------------------------- actions

func _play_online(id: String) -> void:
	if _busy:
		return
	_busy = true
	_set_status("جارٍ تنزيل المرحلة…")
	var res: Dictionary = await _request("GET", "/levels/" + id)
	_busy = false
	if not is_inside_tree():
		return
	if not bool(res.get("ok", false)):
		_set_status(String(res.get("error", "تعذر التنزيل.")), true)
		return
	var payload: Dictionary = res.get("data", {})
	var data: Variant = payload.get("data", {})
	if not (data is Dictionary):
		_set_status("المرحلة المرسلة غير صالحة.", true)
		return
	var lv: Dictionary = (data as Dictionary).duplicate(true)
	lv["id"] = "on_" + id
	lv["online_id"] = id
	lv["name"] = String(payload.get("name", lv.get("name", "مرحلة")))
	lv["author"] = String(payload.get("author", "لاعب"))
	lv["source"] = "online"
	var built := LevelData.build(lv)
	if not bool(built.get("ok", false)):
		_set_status(String(built.get("error", "المرحلة غير صالحة.")), true)
		return
	# Play the same copy that is stored locally so best scores line up.
	var saved := Store.save_download(lv)
	_set_status("تم تنزيل «%s»." % String(saved.get("name", "")), false)
	play_level.emit(saved)

func _show_rating(level: Dictionary) -> void:
	var id := String(level.get("id", ""))
	var ov := Control.new()
	UI.full(ov)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ov)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.04, 0.76)
	UI.full(dim)
	ov.add_child(dim)
	var center := CenterContainer.new()
	UI.full(center)
	ov.add_child(center)
	var panel := UI.panel(20)
	panel.custom_minimum_size = Vector2(500, 0)
	center.add_child(panel)
	var v := UI.vbox(12)
	panel.add_child(v)
	v.add_child(UI.heading("قيّم المرحلة", 28, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(String(level.get("name", "")), 20, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var stars := UI.hbox(8)
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(stars)
	for i in 5:
		var b := UI.button(str(i + 1), 54, i >= 3)
		b.custom_minimum_size.x = 76
		b.add_theme_font_size_override("font_size", 24)
		var score := i + 1
		b.pressed.connect(func(): _submit_rating(id, score, ov))
		stars.add_child(b)
	var cancel := UI.ghost_button("إلغاء", 48)
	cancel.pressed.connect(func(): ov.queue_free())
	v.add_child(cancel)

func _submit_rating(id: String, score: int, ov: Control) -> void:
	_set_status("جارٍ إرسال التقييم…")
	var res: Dictionary = await _request("POST", "/levels/" + id + "/rate", {
		"score": score,
		"client": String(Store.settings.get("client_id", "")),
	})
	if is_instance_valid(ov):
		ov.queue_free()
	if not bool(res.get("ok", false)):
		_set_status(String(res.get("error", "تعذر إرسال التقييم.")), true)
		return
	_toast("شكرًا لتقييمك.")
	_refresh()

func _confirm_report(level: Dictionary) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "إبلاغ عن مرحلة"
	dialog.dialog_text = "هل تريد الإبلاغ عن «%s»؟\nتُراجع البلاغات وتُخفى المراحل المخالفة." % String(level.get("name", ""))
	dialog.ok_button_text = "إبلاغ"
	dialog.theme = UITheme.shared()
	add_child(dialog)
	I18n.translate_tree(dialog)
	dialog.confirmed.connect(func(): _report(String(level.get("id", ""))))
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(540, 250))

func _report(id: String) -> void:
	_set_status("جارٍ إرسال البلاغ…")
	var res: Dictionary = await _request("POST", "/levels/" + id + "/report", {
		"reason": "inappropriate",
		"client": String(Store.settings.get("client_id", "")),
	})
	if not bool(res.get("ok", false)):
		_set_status(String(res.get("error", "تعذر إرسال البلاغ.")), true)
		return
	_set_status("شكرًا، تم استلام البلاغ.", false)
	_refresh()

func _confirm_delete_download(level: Dictionary) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "حذف التنزيل"
	dialog.dialog_text = "حذف النسخة المحفوظة من «%s»؟" % String(level.get("name", ""))
	dialog.ok_button_text = "حذف"
	dialog.theme = UITheme.shared()
	add_child(dialog)
	I18n.translate_tree(dialog)
	dialog.confirmed.connect(func():
		Store.delete_download(String(level.get("id", "")))
		_rebuild()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(500, 220))

func _publish(level: Dictionary) -> void:
	if _busy:
		return
	var built := LevelData.build(level)
	if not bool(built.get("ok", false)):
		_toast(String(built.get("error", "المرحلة غير صالحة.")))
		return
	var payload := {
		"name": String(level.get("name", "مرحلة")),
		"author": String(Store.settings.get("author", level.get("author", "لاعب"))),
		"data": {
			"w": int(built.get("w", 12)),
			"h": int(built.get("h", 16)),
			"rows": level.get("rows", []),
			"par": int(level.get("par", 0)),
		},
	}
	_busy = true
	_set_status("جارٍ نشر «%s»…" % String(level.get("name", "")))
	var res: Dictionary = await _request("POST", "/levels", payload)
	_busy = false
	if not is_inside_tree():
		return
	if not bool(res.get("ok", false)):
		_set_status(String(res.get("error", "تعذر النشر.")), true)
		return
	var data: Dictionary = res.get("data", {})
	level["online_id"] = String(data.get("id", ""))
	Store.save_user_level(level)
	_set_status("نُشرت «%s» بنجاح." % String(level.get("name", "")), false)
	_toast("تم نشر المرحلة!")
	_refresh()

func _toast(text: String) -> void:
	var main := get_tree().current_scene
	if main and main.has_method("toast"):
		main.call("toast", text)
