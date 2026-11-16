extends Node

## Focused gameplay/parser checks. Run with:
##   godot --headless --path . res://tools/test_mechanics.tscn

var failures: Array = []
var checks := 0
var won_flag := false
var died_flag := false
var message_flag := ""

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

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _level(rows: Array, id := "t_mech") -> Dictionary:
	return {"id": id, "name": "اختبار", "author": "اختبار", "par": 0, "source": "test", "rows": rows}

func _make_board() -> DigBoard:
	var board := DigBoard.new()
	board.size = Vector2(720, 1000)
	add_child(board)
	board.won.connect(func(): won_flag = true)
	board.died.connect(func(): died_flag = true)
	board.message_requested.connect(func(text): message_flag = text)
	return board

func _run() -> void:
	# --- Parser validation ------------------------------------------------
	var no_exit := _level(["SSSSSSS", "SPF SSS", "SSSSSSS", "SSSSSSS", "SSSSSSS", "SSSSSSS", "SSSSSSS"])
	_check(not bool(LevelData.build(no_exit).get("ok", false)), "parser rejects a level without exit")
	var no_fruit := _level(["SSSSSSS", "SP ESSS", "SSSSSSS", "SSSSSSS", "SSSSSSS", "SSSSSSS", "SSSSSSS"])
	_check(not bool(LevelData.build(no_fruit).get("ok", false)), "parser rejects a level without fruit")
	var double_player := _level(["SSSSSSS", "SPFESPS", "SSSSSSS", "SSSSSSS", "SSSSSSS", "SSSSSSS", "SSSSSSS"])
	_check(not bool(LevelData.build(double_player).get("ok", false)), "parser rejects two player starts")
	var uneven := _level(["SSSSSSS", "SPFESS", "SSSSSSS", "SSSSSSS", "SSSSSSS", "SSSSSSS", "SSSSSSS"])
	_check(not bool(LevelData.build(uneven).get("ok", false)), "parser rejects uneven rows")
	var unknown := _level(["SSSSSSS", "SPFESXS", "SSSSSSS", "SSSSSSS", "SSSSSSS", "SSSSSSS", "SSSSSSS"])
	_check(not bool(LevelData.build(unknown).get("ok", false)), "parser rejects unknown symbols")

	# --- Locked exit ------------------------------------------------------
	var locked := _level(["SSSSSSS", "SPES SS", "SSSSFSS", "SSSSSSS", "SSSSSSS", "SSSSSSS", "SSSSSSS"])
	var b1 := _make_board()
	_check(b1.load_level(locked), "locked-exit level loads")
	message_flag = ""
	var moved := b1.try_move(Vector2i(1, 0))
	_check(not moved, "exit refuses entry while fruit remains")
	_check(not b1.finished, "exit stays closed")
	_check(message_flag.contains("المخرج"), "locked exit explains itself")
	b1.queue_free()

	# --- Collect fruit then win -------------------------------------------
	var easy := _level(["SSSSSSS", "SPFESSS", "SSSSSSS", "SSSSSSS", "SSSSSSS", "SSSSSSS", "SSSSSSS"])
	won_flag = false
	var b2 := _make_board()
	_check(b2.load_level(easy), "easy level loads")
	_check(b2.fruits_left == 1, "easy level has one fruit")
	b2.try_move(Vector2i(1, 0))
	_check(b2.fruits_left == 0, "moving onto fruit collects it")
	await _wait(0.3)
	b2.try_move(Vector2i(1, 0))
	_check(won_flag, "entering the exit after all fruit wins")
	_check(b2.finished, "winning marks the board finished")
	b2.queue_free()

	# --- Rock push + undo -------------------------------------------------
	var push_level := _level(["SSSSSSSS", "SPR  ESS", "SF SSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS", "SSSSSSSS"])
	won_flag = false
	var b3 := _make_board()
	_check(b3.load_level(push_level), "push level loads")
	_check(int(b3.grid[1][2]) == LevelData.T_ROCK, "rock starts ahead of the player")
	b3.try_move(Vector2i(1, 0))
	_check(int(b3.grid[1][3]) == LevelData.T_ROCK, "rock is pushed into the empty cell")
	_check(int(b3.grid[1][2]) == LevelData.T_EMPTY, "pushed rock leaves its cell empty")
	_check(b3.px == 2 and b3.py == 1, "player follows the pushed rock")
	b3.undo()
	_check(int(b3.grid[1][2]) == LevelData.T_ROCK, "undo restores the rock")
	_check(b3.px == 1 and b3.py == 1, "undo restores the player")
	b3.queue_free()

	# --- Falling rock kills the player ------------------------------------
	var death_level := _level(["SSSSSSS", "SSR SSS", "SP.FESS", "SSSSSSS", "SSSSSSS", "SSSSSSS", "SSSSSSS"])
	died_flag = false
	var b4 := _make_board()
	_check(b4.load_level(death_level), "death level loads")
	b4.try_move(Vector2i(1, 0))
	_check(died_flag, "falling rock kills the player")
	_check(b4.dead, "death marks the board dead")
	_check(not b4.finished, "death is not a win")
	b4.undo()
	_check(not b4.dead, "undo revives the player")
	b4.queue_free()

	# --- Gravity drops a rock into an emptied cell ------------------------
	var gravity_level := _level(["SSSSSSS", "SPR SSS", "SS  SSS", "SSSSFES", "SSSSSSS", "SSSSSSS", "SSSSSSS"])
	var b5 := _make_board()
	_check(b5.load_level(gravity_level), "gravity level loads")
	# Pushing the rock to (3,1) leaves empty space below it, so it falls to (3,2).
	b5.try_move(Vector2i(1, 0))
	_check(int(b5.grid[2][3]) == LevelData.T_ROCK, "unsupported rock falls down")
	_check(int(b5.grid[1][3]) == LevelData.T_EMPTY, "fallen rock leaves its old cell")
	b5.queue_free()

	# --- Star thresholds --------------------------------------------------
	var par_level := {"par": 10}
	_check(Store.stars_for(par_level, 10) == 3, "par gets three stars")
	_check(Store.stars_for(par_level, 12) == 3, "15% over par still gets three stars")
	_check(Store.stars_for(par_level, 16) == 2, "55% over par gets two stars")
	_check(Store.stars_for(par_level, 20) == 1, "slow clear gets one star")

	# --- Progress persistence --------------------------------------------
	Store.reset_progress()
	Store.mark_complete("b99", 12)
	Store.mark_complete("b99", 15)
	_check(Store.best_for("b99") == 12, "best result keeps the smaller move count")
	_check(Store.is_completed("b99"), "completion is recorded")
	Store.reset_progress()

	Sfx.stop_all()
	print("")
	print("Mechanics test: %d checks, %d failures" % [checks, failures.size()])
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
