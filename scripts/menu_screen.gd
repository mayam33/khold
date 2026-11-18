extends Control

signal play_requested
signal editor_requested
signal online_requested
signal settings_requested

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

	var outer := UI.margin_control(24)
	UI.full(outer)
	add_child(outer)
	var center := CenterContainer.new()
	outer.add_child(center)

	var col := UI.vbox(14)
	# Fixed column width; long labels wrap instead of stretching the menu
	# past the 720px screen (English story text used to push it to 788px).
	col.custom_minimum_size = Vector2(520, 0)
	center.add_child(col)

	# Animated beaver holding its shovel, instead of a still portrait.
	var mascot := preload("res://scripts/animated_beaver.gd").new()
	mascot.custom_minimum_size = Vector2(230, 210)
	mascot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(mascot)

	var title := UI.heading("Beaver Explorer", 52, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	title.add_theme_constant_override("shadow_offset_y", 4)
	col.add_child(title)
	col.add_child(UI.label("مغامرة تحت الأرض", 27, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var story := UI.wrap_label("ملّ القندس من الحفر قرب النهر، فانطلق ليستكشف ما تحت الأرض.", 21, UITheme.MUTED)
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(story)
	col.add_child(UI.spacer_h(14))

	var play := UI.button("العب", 72, true)
	play.add_theme_font_size_override("font_size", 32)
	play.pressed.connect(func(): play_requested.emit())
	col.add_child(play)

	var editor := UI.button("محرر المراحل", 62)
	editor.pressed.connect(func(): editor_requested.emit())
	col.add_child(editor)

	var online := UI.button("مراحل الإنترنت", 62)
	online.pressed.connect(func(): online_requested.emit())
	col.add_child(online)

	var settings := UI.button("الإعدادات", 62)
	settings.pressed.connect(func(): settings_requested.emit())
	col.add_child(settings)

	col.add_child(UI.spacer_h(18))
	col.add_child(UI.label("مفتوح المصدر • رخصة MIT • Godot 4", 18, Color("8d7f95"), HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UI.label("الإصدار 1.1.0", 17, Color("6f6378"), HORIZONTAL_ALIGNMENT_CENTER))
