extends PanelContainer

## HUD widget showing the current active quest name and progress bar.
## Slides in from the right when a quest activates or updates.

@onready var quest_name_label: Label = $VBox/QuestName
@onready var quest_desc_label: Label = $VBox/QuestDesc
@onready var progress_bar: ProgressBar = $VBox/ProgressBar
@onready var progress_label: Label = $VBox/ProgressLabel

var _current_quest_id: String = ""
var _tween: Tween


func _ready() -> void:
	modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	QuestManager.quest_activated.connect(_on_quest_activated)
	QuestManager.quest_completed.connect(_on_quest_completed)
	QuestManager.quest_progress_updated.connect(_on_quest_progress)
	# Show initial quest
	_refresh_primary()


func _refresh_primary() -> void:
	var quest := QuestManager.get_primary_active_quest()
	if quest.is_empty():
		_hide_tracker()
		return
	_current_quest_id = quest.get("id", "")
	quest_name_label.text = quest.get("name", "???")
	quest_desc_label.text = quest.get("description", "")
	var progress := QuestManager._get_quest_progress(quest)
	var target := QuestManager._get_quest_target(quest)
	progress_bar.max_value = target
	progress_bar.value = progress
	progress_label.text = "%d / %d" % [progress, target]
	_show_tracker()


func _on_quest_activated(_quest_id: String, _quest_name: String, _description: String) -> void:
	_refresh_primary()


func _on_quest_completed(quest_id: String, quest_name: String, _reward_text: String) -> void:
	if quest_id == _current_quest_id:
		quest_name_label.text = quest_name + " - Complete!"
		progress_bar.value = progress_bar.max_value
		# After a delay, switch to next quest
		await get_tree().create_timer(2.0).timeout
		_refresh_primary()


func _on_quest_progress(quest_id: String, current: int, target: int) -> void:
	if quest_id != _current_quest_id:
		return
	progress_bar.max_value = target
	progress_bar.value = current
	progress_label.text = "%d / %d" % [current, target]


func _show_tracker() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.3)


func _hide_tracker() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.3)
