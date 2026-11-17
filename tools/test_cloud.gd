extends Node

## Quick connectivity check against the deployed Cloudflare Worker.
## Run with:
##   godot --headless --path . res://tools/test_cloud.tscn

const URL := "https://khold-levels.mayam33.workers.dev/health"

func _ready() -> void:
	await get_tree().process_frame
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var err := http.request(URL)
	if err != OK:
		print("FAIL: could not start request (%d)" % err)
		get_tree().quit(1)
		return
	var result: Array = await http.request_completed
	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		print("FAIL: transport error (%s)" % str(result[0]))
		get_tree().quit(1)
		return
	if int(result[1]) != 200:
		print("FAIL: HTTP %d" % int(result[1]))
		get_tree().quit(1)
		return
	var raw: PackedByteArray = result[3]
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if parsed is Dictionary and bool(parsed.get("ok", false)):
		print("ok: Godot reaches the Cloudflare level server (%s levels)" % str(parsed.get("levels", 0)))
		get_tree().quit(0)
	else:
		print("FAIL: unexpected response: %s" % raw.get_string_from_utf8())
		get_tree().quit(1)
