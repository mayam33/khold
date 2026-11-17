extends Control

## Screen router and global toast overlay.

const MenuScreenScript := preload("res://scripts/menu_screen.gd")
const LevelSelectScript := preload("res://scripts/level_select.gd")
const GameScreenScript := preload("res://scripts/game_screen.gd")
const EditorScreenScript := preload("res://scripts/editor_screen.gd")
const OnlineScreenScript := preload("res://scripts/online_screen.gd")
const SettingsScreenScript := preload("res://scripts/settings_screen.gd")

var current: Control
var _return_to := "levels"
var _campaign: Array = []
var _campaign_index := -1
var _test_overlay: Control

var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	theme = UITheme.shared()
	TranslationServer.set_locale("ar")
	get_window().title = "خُلد — مغامرة الحفر"
	get_window().min_size = Vector2i(360, 640)
	_add_background()
	_add_toast()
	show_menu()

func _add_background() -> void:
	var bg := preload("res://scripts/background.gd").new()
	add_child(bg)
	UI.full(bg)

func _add_toast() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var margin := MarginContainer.new()
	UI.full(margin)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 34)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(margin)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_END
	# This full-screen toast container sits on a high CanvasLayer. Keep it from
	# intercepting clicks intended for the active screen underneath.
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(v)
	_toast_panel = UI.panel(14, Color("30243d"))
	_toast_panel.custom_minimum_size = Vector2(0, 0)
	_toast_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.modulate.a = 0.0
	_toast_panel.visible = false
	v.add_child(_toast_panel)
	_toast_label = UI.label("", 21, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.custom_minimum_size.x = 460
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_child(_toast_label)

func toast(text: String, duration := 2.6) -> void:
	if _toast_panel == null:
		return
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.text = text
	_toast_panel.visible = true
	_toast_panel.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.14)
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.28)
	_toast_tween.tween_callback(func(): _toast_panel.visible = false)

# ---------------------------------------------------------------- navigation

func _swap(screen: Control) -> void:
	if is_instance_valid(current):
		remove_child(current)
		current.queue_free()
	current = screen
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func show_menu() -> void:
	var s := MenuScreenScript.new()
	s.play_requested.connect(show_levels)
	s.editor_requested.connect(func(): show_editor({}))
	s.online_requested.connect(show_online)
	s.settings_requested.connect(show_settings)
	_swap(s)

func show_levels() -> void:
	var s := LevelSelectScript.new()
	s.back_requested.connect(show_menu)
	s.play_campaign.connect(_on_play_campaign)
	s.play_user.connect(_play_user)
	s.edit_user.connect(_edit_user)
	s.new_level.connect(func(): show_editor({}))
	_swap(s)

func show_editor(level: Dictionary = {}) -> void:
	var s := EditorScreenScript.new()
	s.editing_level = level
	s.back_requested.connect(show_levels)
	s.test_requested.connect(_on_test_requested)
	_swap(s)

func show_online() -> void:
	var s := OnlineScreenScript.new()
	s.back_requested.connect(show_menu)
	s.play_level.connect(_play_online)
	_swap(s)

func show_settings() -> void:
	var s := SettingsScreenScript.new()
	s.back_requested.connect(show_menu)
	_swap(s)

# ---------------------------------------------------------------- play

func _on_play_campaign(index: int) -> void:
	var levels := BuiltinLevels.all()
	if index < 0 or index >= levels.size():
		return
	_return_to = "levels"
	_start_game(levels[index], levels, index)

func _play_user(level: Dictionary) -> void:
	_return_to = "levels"
	_start_game(level, [], -1)

func _play_online(level: Dictionary) -> void:
	_return_to = "online"
	_start_game(level, [], -1)

func _edit_user(level: Dictionary) -> void:
	show_editor(level)

func _start_game(level: Dictionary, campaign: Array, index: int) -> void:
	_campaign = campaign
	_campaign_index = index
	var g := GameScreenScript.new()
	g.level = level
	g.campaign = campaign
	g.campaign_index = index
	g.test_mode = false
	g.exit_requested.connect(_on_game_exit)
	g.next_requested.connect(_on_game_next)
	_swap(g)

func _on_game_exit() -> void:
	if _return_to == "online":
		show_online()
	else:
		show_levels()

func _on_game_next() -> void:
	if _campaign.is_empty():
		show_levels()
		return
	var next := _campaign_index + 1
	if next < 0 or next >= _campaign.size():
		show_levels()
		return
	_start_game(_campaign[next], _campaign, next)

func _on_test_requested(level: Dictionary) -> void:
	if is_instance_valid(_test_overlay):
		remove_child(_test_overlay)
		_test_overlay.queue_free()
	var g := GameScreenScript.new()
	g.level = level
	g.test_mode = true
	g.exit_requested.connect(_close_test)
	if is_instance_valid(current):
		current.visible = false
	add_child(g)
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_test_overlay = g

func _close_test() -> void:
	if is_instance_valid(_test_overlay):
		remove_child(_test_overlay)
		_test_overlay.queue_free()
	_test_overlay = null
	if is_instance_valid(current):
		current.visible = true
