extends PanelContainer

## Animated toast notification for achievement unlocks.
## Slides in from the top, displays for 3 seconds, then fades out.

@onready var name_label: Label = %AchievementName
@onready var desc_label: Label = %AchievementDesc
@onready var icon_label: Label = %AchievementIcon

var _queue: Array[Dictionary] = []
var _showing := false
var _rest_offset_top := 20.0


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	_rest_offset_top = offset_top
	Achievements.achievement_unlocked.connect(_on_achievement_unlocked)


func _on_achievement_unlocked(_id: String, achievement_name: String, description: String) -> void:
	_queue.append({"name": achievement_name, "description": description})
	if not _showing:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return

	_showing = true
	var data: Dictionary = _queue.pop_front()
	name_label.text = data["name"]
	desc_label.text = data["description"]

	# Start offscreen (above viewport)
	visible = true
	offset_top = -100.0
	offset_bottom = offset_top + 70.0
	modulate.a = 0.0

	# Slide in
	var tween := create_tween()
	tween.tween_property(self, "offset_top", _rest_offset_top, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(self, "offset_bottom", _rest_offset_top + 70.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.3)

	# Hold
	tween.tween_interval(3.0)

	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_on_toast_done)


func _on_toast_done() -> void:
	visible = false
	_show_next()
