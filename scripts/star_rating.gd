class_name StarRating
extends Control

## Small three-star rating widget drawn with polygons.

var filled := 0:
	set(value):
		filled = clampi(value, 0, 3)
		queue_redraw()
var star_radius := 13.0
var empty_color := Color("4a3c52")
var full_color := UITheme.ACCENT

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(star_radius * 8.0, star_radius * 2.4)
	queue_redraw()

func set_rating(value: int) -> void:
	filled = value
	custom_minimum_size = Vector2(star_radius * 8.0, star_radius * 2.4)
	queue_redraw()

func _draw() -> void:
	var gap := star_radius * 1.25
	var total := gap * 2.0
	var start := Vector2((size.x - total) * 0.5, size.y * 0.5)
	for i in 3:
		var center := start + Vector2(gap * float(i), 0.0)
		if i < filled:
			PixelArt.draw_star(self, center + Vector2(0, 1), star_radius, Color(0, 0, 0, 0.25), true)
			PixelArt.draw_star(self, center, star_radius, full_color, true)
		else:
			PixelArt.draw_star(self, center, star_radius, empty_color, false)
