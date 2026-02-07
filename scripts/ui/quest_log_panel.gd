extends PanelContainer

## Full-screen overlay showing all quests in Active/Completed tabs.
## Toggle with J key.

@onready var tab_container: TabContainer = $VBox/TabContainer
@onready var active_list: VBoxContainer = $VBox/TabContainer/Active/ScrollContainer/ActiveList
@onready var completed_list: VBoxContainer = $VBox/TabContainer/Completed/ScrollContainer/CompletedList
@onready var close_button: Button = $VBox/Header/CloseButton
@onready var title_label: Label = $VBox/Header/TitleLabel

var _is_open := false


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_close)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("quest_log"):
		if _is_open:
			_close()
		else:
			_open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("escape") and _is_open:
		_close()
		get_viewport().set_input_as_handled()


func _open() -> void:
	_is_open = true
	visible = true
	_refresh()


func _close() -> void:
	_is_open = false
	visible = false


func _refresh() -> void:
	_clear_list(active_list)
	_clear_list(completed_list)

	var active := QuestManager.get_active_quests()
	for quest in active:
		_add_quest_entry(active_list, quest, false)

	var completed := QuestManager.get_completed_quests()
	for quest in completed:
		_add_quest_entry(completed_list, quest, true)

	title_label.text = "Quest Log (%d/%d)" % [QuestManager.get_completed_count(), QuestManager.get_total_quest_count()]


func _clear_list(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()


func _add_quest_entry(container: VBoxContainer, quest: Dictionary, is_completed: bool) -> void:
	var panel := PanelContainer.new()
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var name_label := Label.new()
	var prefix := "[Done] " if is_completed else "[Active] "
	name_label.text = prefix + quest.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 14)
	if is_completed:
		name_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	else:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = quest.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)

	if not is_completed:
		var progress_bar := ProgressBar.new()
		progress_bar.custom_minimum_size.y = 12
		var progress := QuestManager._get_quest_progress(quest)
		var target := QuestManager._get_quest_target(quest)
		progress_bar.max_value = target
		progress_bar.value = progress
		progress_bar.show_percentage = false
		vbox.add_child(progress_bar)

		var pct_label := Label.new()
		pct_label.text = "%d / %d" % [progress, target]
		pct_label.add_theme_font_size_override("font_size", 10)
		pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vbox.add_child(pct_label)
	else:
		var reward_label := Label.new()
		reward_label.text = quest.get("reward_text", "")
		reward_label.add_theme_font_size_override("font_size", 10)
		reward_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
		reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(reward_label)

	container.add_child(panel)
