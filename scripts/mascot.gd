extends Control

## Animated mascot for the main menu.

var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(230, 210)
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 20.0 or h < 20.0:
		return
	# Dirt mound
	draw_rect(Rect2(w * 0.16, h * 0.74, w * 0.68, h * 0.16), Color("4a3020"))
	draw_rect(Rect2(w * 0.10, h * 0.80, w * 0.80, h * 0.12), Color("5c3b2b"))
	draw_rect(Rect2(w * 0.22, h * 0.70, w * 0.56, h * 0.08), Color("6c4a2f"))
	# Mole
	PixelArt.draw_mole(self, Rect2(w * 0.20, h * 0.08, w * 0.60, h * 0.66), _t)
	# Fruit companion
	var bob := sin(_t * 2.2 + 1.0) * 4.0
	var fr := Rect2(w * 0.76, h * 0.62 + bob, w * 0.18, w * 0.18)
	PixelArt.draw_tile(self, LevelData.T_FRUIT, fr, Vector2i(99, 7), _t, false)
	# Sparkles
	for i in 4:
		var a := 0.25 + 0.65 * maxf(0.0, sin(_t * 2.0 + float(i) * 1.7))
		var p := Vector2(w * (0.16 + 0.19 * float(i)), h * (0.30 + 0.12 * sin(_t * 0.8 + float(i) * 2.3)))
		draw_rect(Rect2(p, Vector2(3, 3)), Color(1.0, 0.78, 0.36, a))
