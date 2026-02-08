extends CanvasLayer

## Full-screen fade-to-black scene transition.
## Usage: SceneTransition.change_scene("res://scenes/main.tscn")

var _is_transitioning := false
var _color_rect: ColorRect


func _ready() -> void:
	layer = 100
	_color_rect = ColorRect.new()
	_color_rect.color = Color(0, 0, 0, 0)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_color_rect)


func change_scene(path: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	# Block input during transition
	_color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	# Fade to black
	var fade_out := create_tween()
	fade_out.tween_property(_color_rect, "color:a", 1.0, 0.5)
	await fade_out.finished

	# Change scene
	get_tree().change_scene_to_file(path)

	# Wait two frames for the new scene to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# Fade from black
	var fade_in := create_tween()
	fade_in.tween_property(_color_rect, "color:a", 0.0, 0.5)
	await fade_in.finished

	# Restore input and allow new transitions
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
