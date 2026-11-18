extends Node

## Verifies the English-first UI, Arabic switching, and beaver art.
## Run with:
##   godot --headless --path . res://tools/test_localization.tscn

var failures: Array = []
var checks := 0
var _old_language := "en"

func _ready() -> void:
	await get_tree().process_frame
	await _run()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("FAIL: " + message)
	else:
		print("ok: " + message)

func _buttons(node: Node, out: Array) -> void:
	if node is Button:
		out.append(node)
	for child in node.get_children():
		_buttons(child, out)

func _button_with(node: Node, text: String) -> Button:
	var all: Array = []
	_buttons(node, all)
	for b in all:
		if String(b.text).strip_edges() == text:
			return b
	return null

func _texts(node: Node, out: Array) -> void:
	if node is Label:
		out.append(String((node as Label).text).strip_edges())
	elif node is Button:
		out.append(String((node as Button).text).strip_edges())
	for child in node.get_children():
		_texts(child, out)

func _run() -> void:
	_old_language = String(Store.settings.get("language", "en"))
	I18n.set_language("en")
	_check(I18n.language == "en", "default language is English")
	_check(I18n.translate_text("العب") == "Play", "Arabic source translates to English")

	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate() as Control
	add_child(main)
	await get_tree().process_frame
	_check(main != null, "main scene instantiates")
	_check(main.layout_direction == Control.LAYOUT_DIRECTION_LTR, "English uses LTR layout")
	_check(_button_with(main, "Play") != null, "menu shows the English Play button")
	_check(_button_with(main, "Level Editor") != null, "menu shows the English editor button")
	_check(_button_with(main, "Community Levels") != null, "menu shows the English online button")
	_check(_button_with(main, "Settings") != null, "menu shows the English settings button")
	# A long English story string used to push the menu to 788px and skew it.
	_check(main.current.get_combined_minimum_size().x <= 720.0, "English menu fits the 720px design width")

	# Beaver art must resolve to real textures.
	_check(BeaverArt.PORTRAIT != null, "beaver portrait loads")
	_check(BeaverArt.frames_for("idle").size() == 4, "idle animation has four frames")
	_check(BeaverArt.frames_for("dig").size() == 4, "dig animation has four frames")
	_check(BeaverArt.frames_for("shovel").size() == 4, "shovel animation has four frames")
	_check(BeaverArt.frames_for("die").size() == 3, "die animation has three frames")
	_check(BeaverArt.texture_for("walk", 0) != null, "walk frame resolves")

	# Pause dialogs are created after I18n.translate_tree(screen), so the
	# freshly built overlay must be translated separately.
	var game := load("res://scripts/game_screen.gd").new() as Control
	game.test_mode = true
	add_child(game)
	await get_tree().process_frame
	game._open_pause()
	await get_tree().process_frame
	var pause_texts: Array = []
	_texts(game.overlay, pause_texts)
	_check(pause_texts.has("Paused"), "pause dialog title is English while paused")
	_check(pause_texts.has("Resume"), "pause dialog resume button is English")
	_check(pause_texts.has("Restart"), "pause dialog restart button is English")
	_check(pause_texts.has("Exit"), "pause dialog exit button is English")
	game.queue_free()

	# Switch to Arabic: layout and labels must flip back.
	I18n.set_language("ar")
	await get_tree().process_frame
	_check(main.layout_direction == Control.LAYOUT_DIRECTION_RTL, "Arabic uses RTL layout")
	_check(_button_with(main, "العب") != null, "menu shows the Arabic Play button")
	_check(I18n.translate_text("العب") == "العب", "Arabic source is left untranslated")

	# Settings expose the new controls.
	var settings := load("res://scripts/settings_screen.gd").new() as Control
	add_child(settings)
	await get_tree().process_frame
	var all: Array = []
	_buttons(settings, all)
	var has_option := false
	var has_slider := false
	for child in settings.get_children():
		var stack: Array = [child]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is OptionButton:
				has_option = true
			if n is HSlider:
				has_slider = true
			for c in n.get_children():
				stack.append(c)
	_check(has_option, "settings expose the language selector")
	_check(has_slider, "settings expose the display-size slider")
	settings.queue_free()

	I18n.set_language(_old_language)
	main.queue_free()
	print("")
	print("Localization test: %d checks, %d failures" % [checks, failures.size()])
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
