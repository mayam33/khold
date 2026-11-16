extends Control

## Animated soil backdrop shared by every screen.

var _motes: Array = []
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 24:
		_motes.append({
			"x": randf(),
			"y": randf(),
			"speed": randf_range(0.006, 0.026),
			"size": randf_range(1.0, 2.6),
			"phase": randf() * TAU,
		})

func _process(delta: float) -> void:
	_t += delta
	for m in _motes:
		m["y"] = float(m["y"]) - float(m["speed"]) * delta
		if float(m["y"]) < -0.02:
			m["y"] = 1.02
			m["x"] = randf()
	queue_redraw()

func _draw() -> void:
	var r := size
	if r.x <= 0.0 or r.y <= 0.0:
		return
	var bands := 40
	for i in bands:
		var k := float(i) / float(bands - 1)
		var c := UITheme.BG.lerp(UITheme.BG_2, smoothstep(0.0, 1.0, k))
		draw_rect(Rect2(0.0, floorf(r.y * float(i) / float(bands)), r.x, ceilf(r.y / float(bands)) + 1.0), c)

	# Soft warm glow from above.
	draw_circle(Vector2(r.x * 0.5, -r.y * 0.04), r.x * 0.9, Color(0.94, 0.66, 0.24, 0.045))

	# Deterministic dirt speckles for texture.
	var step := 52
	var cols := int(r.x / step) + 1
	var rows := int(r.y / step) + 1
	for gy in rows:
		for gx in cols:
			var h := _hash01(gx, gy, 7)
			if h > 0.55:
				continue
			var px := gx * step + _hash01(gx, gy, 2) * step
			var py := gy * step + _hash01(gx, gy, 3) * step
			var s := 1.0 + _hash01(gx, gy, 4) * 2.0
			var c := Color(0.42, 0.30, 0.21, 0.10 + _hash01(gx, gy, 5) * 0.10)
			draw_rect(Rect2(px, py, s, s), c)

	# Drifting dust motes.
	for m in _motes:
		var a := 0.10 + 0.10 * sin(_t * 1.4 + float(m["phase"]))
		var p := Vector2(float(m["x"]) * r.x, float(m["y"]) * r.y)
		draw_rect(Rect2(p, Vector2(float(m["size"]), float(m["size"]))), Color(0.95, 0.78, 0.48, maxf(0.0, a)))

func _hash01(x: int, y: int, s: int) -> float:
	var n := x * 374761393 + y * 668265263 + s * 1442695041
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0
