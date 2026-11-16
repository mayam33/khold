extends Node

## Persistence for settings, campaign progress, local levels and downloads.
## Everything lives under user:// so the game works offline.

const SETTINGS_PATH := "user://settings.json"
const PROGRESS_PATH := "user://progress.json"
const LEVELS_DIR := "user://levels"
const DOWNLOADS_DIR := "user://downloads"

const DEFAULT_SETTINGS := {
	"sound": true,
	"haptics": true,
	"author": "لاعب",
	"server_url": "http://127.0.0.1:8787",
	"client_id": "",
}

var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var progress: Dictionary = {"best": {}, "completed": []}

func _ready() -> void:
	_ensure_dirs()
	settings = _load_dict(SETTINGS_PATH, DEFAULT_SETTINGS.duplicate(true))
	for key in DEFAULT_SETTINGS:
		if not settings.has(key):
			settings[key] = DEFAULT_SETTINGS[key]
	if String(settings.get("client_id", "")) == "":
		settings["client_id"] = _new_client_id()
		_save_json(SETTINGS_PATH, settings)

	progress = _load_dict(PROGRESS_PATH, {"best": {}, "completed": []})
	if not (progress.get("best", null) is Dictionary):
		progress["best"] = {}
	if not (progress.get("completed", null) is Array):
		progress["completed"] = []
	_apply_audio()

func _ensure_dirs() -> void:
	for path in [LEVELS_DIR, DOWNLOADS_DIR]:
		if not DirAccess.dir_exists_absolute(path):
			DirAccess.make_dir_recursive_absolute(path)

func _new_client_id() -> String:
	var crypto := Crypto.new()
	return crypto.generate_random_bytes(8).hex_encode()

# ---------------------------------------------------------------- settings

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_save_json(SETTINGS_PATH, settings)
	if key == "sound":
		_apply_audio()

func _apply_audio() -> void:
	AudioServer.set_bus_mute(0, not bool(settings.get("sound", true)))

# ---------------------------------------------------------------- progress

func best_for(id: String) -> int:
	return int(progress.get("best", {}).get(id, 0))

func is_completed(id: String) -> bool:
	return (progress.get("completed", []) as Array).has(id)

func mark_complete(id: String, moves: int) -> void:
	if id == "":
		return
	var best: Dictionary = progress["best"]
	var old := int(best.get(id, 0))
	if old == 0 or moves < old:
		best[id] = moves
	var done: Array = progress["completed"]
	if not done.has(id):
		done.append(id)
	_save_json(PROGRESS_PATH, progress)

func stars_for(level: Dictionary, moves: int) -> int:
	if moves <= 0:
		return 0
	var par := int(level.get("par", 0))
	if par <= 0:
		return 3
	if moves <= ceili(float(par) * 1.15):
		return 3
	if moves <= ceili(float(par) * 1.55):
		return 2
	return 1

func reset_progress() -> void:
	progress = {"best": {}, "completed": []}
	_save_json(PROGRESS_PATH, progress)

# ---------------------------------------------------------------- levels

func list_user_levels() -> Array:
	return _list_levels_in(LEVELS_DIR, "user")

func list_downloads() -> Array:
	return _list_levels_in(DOWNLOADS_DIR, "online")

func _list_levels_in(dir: String, source: String) -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for file_name in DirAccess.get_files_at(dir):
		if not file_name.ends_with(".json"):
			continue
		var data := _load_dict(dir.path_join(file_name), {})
		if data.is_empty() or not data.has("rows"):
			continue
		data["source"] = source
		if not data.has("id"):
			data["id"] = file_name.get_basename()
		out.append(data)
	out.sort_custom(func(a, b):
		return int(a.get("updated_at", a.get("created_at", 0))) > int(b.get("updated_at", b.get("created_at", 0))))
	return out

func get_user_level(id: String) -> Dictionary:
	var path := LEVELS_DIR.path_join(_safe_id(id) + ".json")
	return _load_dict(path, {})

func save_user_level(level: Dictionary) -> Dictionary:
	var copy: Dictionary = level.duplicate(true)
	var id := _safe_id(String(copy.get("id", "")))
	if id == "" or not id.begins_with("user_"):
		id = "user_%d_%d" % [int(Time.get_unix_time_from_system()), randi() % 10000]
	copy["id"] = id
	copy["source"] = "user"
	var now := int(Time.get_unix_time_from_system())
	copy["updated_at"] = now
	if not copy.has("created_at"):
		copy["created_at"] = now
	_save_json(LEVELS_DIR.path_join(id + ".json"), copy)
	return copy

func delete_user_level(id: String) -> void:
	_remove_file(LEVELS_DIR.path_join(_safe_id(id) + ".json"))

func save_download(level: Dictionary) -> Dictionary:
	var copy: Dictionary = level.duplicate(true)
	var online_id := String(copy.get("online_id", copy.get("id", "")))
	var id := "dl_" + _safe_id(online_id)
	if id == "dl_":
		id = "dl_%d" % int(Time.get_unix_time_from_system())
	copy["id"] = id
	copy["online_id"] = online_id
	copy["source"] = "online"
	copy["saved_at"] = int(Time.get_unix_time_from_system())
	_save_json(DOWNLOADS_DIR.path_join(id + ".json"), copy)
	return copy

func delete_download(id: String) -> void:
	_remove_file(DOWNLOADS_DIR.path_join(_safe_id(id) + ".json"))

# ---------------------------------------------------------------- helpers

func _safe_id(id: String) -> String:
	return id.strip_edges().replace("/", "_").replace("\\", "_").replace("..", "_")

func _load_dict(path: String, fallback: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return fallback
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return fallback

func _save_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write " + path)
		return
	file.store_string(JSON.stringify(data, "\t"))

func _remove_file(path: String) -> void:
	var dir := DirAccess.open(path.get_base_dir())
	if dir:
		dir.remove(path.get_file())
