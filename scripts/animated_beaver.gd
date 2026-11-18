extends TextureRect

## Cycles beaver frames so a sprite can be used as a lively menu mascot.
## The default "shovel" animation shows the beaver gripping its digging tool.

@export var animation := "shovel"
@export var fps := 4.0

var _elapsed := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_apply_frame(0)

func _process(delta: float) -> void:
	_elapsed += delta
	var frames := BeaverArt.frames_for(animation)
	if frames.is_empty():
		return
	var index := int(_elapsed * fps) % frames.size()
	if texture != frames[index]:
		_apply_frame(index)

func _apply_frame(index: int) -> void:
	var frames := BeaverArt.frames_for(animation)
	if not frames.is_empty():
		texture = frames[posmod(index, frames.size())] as Texture2D
