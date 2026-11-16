extends Node

## Automated smoke test for the real screens. Run with:
##   godot --headless --path . res://tools/test_ui.tscn
## It drives the menu, a campaign level, the editor and the online screen.

var failures: Array = []
var checks := 0
var _old_server := ""

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

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _run() -> void:
	# The UI suite must publish to the throwaway local server, never the cloud.
	_old_server = String(Store.settings.get("server_url", ""))
	Store.set_setting("server_url", "http://127.0.0.1:8787")

	var packed: PackedScene = load("res://scenes/main.tscn")
	_check(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return
	var main = packed.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var view: Vector2 = main.size
	_check(view.x >= 300.0 and view.y >= 500.0, "viewport has a portrait size (%s)" % str(view))

	# --- Menu -------------------------------------------------------------
	_check(main.current != null, "menu screen is shown")
	var play := _button_with(main, "العب")
	_check(play != null, "menu has a play button")
	if play == null:
		_finish()
		return
	play.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_button_with(main, "مرحلة جديدة") != null, "level select opens")

	# The first card belongs to b01.
	var all_buttons: Array = []
	_buttons(main, all_buttons)
	var first_play: Button = null
	for b in all_buttons:
		if String(b.text).strip_edges() == "العب":
			first_play = b
			break
	_check(first_play != null, "campaign card has a play button")
	if first_play == null:
		_finish()
		return
	first_play.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	# --- Gameplay ---------------------------------------------------------
	_check(is_instance_valid(main.current), "game screen is shown")
	var gs = main.current
	_check(gs.get("board") != null, "game screen owns a board")
	var board = gs.board
	_check(board.grid.size() == board.h, "board grid is built")
	_check(board.fruits_total >= 1, "level starts with fruit")
	_check(String(board.level_id) == "b01", "first campaign level is b01")
	_check(board.moves == 0, "moves start at zero")

	var start_px: int = board.px
	var start_py: int = board.py
	gs._on_dpad_pressed(Vector2i(0, 1))
	gs._on_dpad_released()
	await _wait(0.25)
	_check(board.moves == 1, "d-pad makes one move")
	_check(board.py == start_py + 1 or board.px != start_px, "player changed cell")

	gs._undo()
	await get_tree().process_frame
	_check(board.moves == 0, "undo restores the move counter")
	_check(board.px == start_px and board.py == start_py, "undo restores player position")

	gs._on_dpad_pressed(Vector2i(0, 1))
	gs._on_dpad_released()
	await _wait(0.25)
	gs._restart()
	await get_tree().process_frame
	_check(board.moves == 0, "restart resets moves")
	_check(board.px == start_px and board.py == start_py, "restart resets position")

	gs._open_pause()
	await get_tree().process_frame
	_check(bool(gs._overlay_open), "pause overlay opens")
	gs._close_modal()
	await get_tree().process_frame
	_check(not bool(gs._overlay_open), "pause overlay closes")

	# --- Editor -----------------------------------------------------------
	gs.exit_requested.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_button_with(main, "مرحلة جديدة") != null, "back to level select")
	var new_btn := _button_with(main, "مرحلة جديدة")
	if new_btn == null:
		_finish()
		return
	new_btn.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var ed = main.current
	_check(ed.get("board") != null, "editor opens with a canvas")
	var build: Dictionary = ed._validated()
	_check(not build.is_empty(), "default editor level validates")
	var before: int = Store.list_user_levels().size()
	ed._save()
	await get_tree().process_frame
	_check(Store.list_user_levels().size() == before + 1, "editor save persists a level")

	ed._test()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_instance_valid(main._test_overlay), "test mode opens the game overlay")
	if is_instance_valid(main._test_overlay):
		var test_board = main._test_overlay.board
		_check(test_board.fruits_total >= 1, "test overlay board is loaded")
		main._test_overlay.exit_requested.emit()
		await get_tree().process_frame
		_check(not is_instance_valid(main._test_overlay), "test overlay closes")

	var saved: Array = Store.list_user_levels()
	var saved_id := ""
	if not saved.is_empty():
		saved_id = String(saved[0].get("id", ""))
	_check(saved_id.begins_with("user_"), "saved level gets a user id")

	ed._back()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_button_with(main, "مرحلة جديدة") != null, "editor back returns to level select")

	# --- Online -----------------------------------------------------------
	var back_btn := _button_with(main, "رجوع")
	if back_btn:
		back_btn.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
	var online_btn := _button_with(main, "مراحل الإنترنت")
	_check(online_btn != null, "menu has an online button")
	if online_btn != null:
		online_btn.pressed.emit()
		await get_tree().process_frame
		await _wait(1.8)
		var os = main.current
		_check(os.get("_status") != null, "online screen has a status line")
		var status := String(os._status.text)
		_check(status.contains("تم الاتصال") or status.contains("مرحلة منشورة"), "online screen reaches the server (%s)" % status)
		_check(os.get("_online") is Array, "online level list is an array")
		var publish_btn := _button_with(os, "نشر")
		if publish_btn == null:
			publish_btn = _button_with(os, "نشر نسخة")
		_check(publish_btn != null, "publish button is available")
		if publish_btn != null:
			publish_btn.pressed.emit()
			await _wait(1.6)
			var status2 := String(os._status.text)
			_check(status2.contains("نُشرت") or status2.contains("بنجاح") or status2.contains("تم "), "publishing reports success (%s)" % status2)

	# --- Cleanup ----------------------------------------------------------
	if saved_id != "":
		Store.delete_user_level(saved_id)
	Store.set_setting("server_url", _old_server)
	Sfx.stop_all()
	print("")
	print("UI smoke test: %d checks, %d failures" % [checks, failures.size()])
	_finish()

func _finish() -> void:
	get_tree().quit(0 if failures.is_empty() else 1)
