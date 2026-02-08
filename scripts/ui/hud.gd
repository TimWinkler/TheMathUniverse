extends CanvasLayer

## Heads-up display showing discovery progress, node info, and controls.

@onready var node_count_label: Label = %NodeCountLabel
@onready var hover_label: Label = %HoverLabel
@onready var controls_label: Label = %ControlsLabel
@onready var discovery_label: Label = %DiscoveryLabel
@onready var progress_bar: ProgressBar = %DiscoveryProgressBar
@onready var domain_indicators: HBoxContainer = %DomainIndicators
@onready var achievement_label: Label = %AchievementLabel

var _hovered_node_id: String = ""
var _level_buttons: Dictionary = {}

const _LEVEL_CONFIG = {
	"beginner": "Elementary",
	"intermediate": "High School",
	"profi": "University",
}


func _ready() -> void:
	hover_label.text = ""
	controls_label.text = "Right-drag: orbit | Scroll: zoom | WASD: move | Click: discover | H: home | J: quests | M: map | C: connections | F1: mute | F9: reset | Esc: close"

	await get_tree().process_frame
	await get_tree().process_frame

	_update_discovery_display()
	_build_domain_indicators()

	DiscoveryManager.discovery_count_changed.connect(_on_discovery_changed)
	Achievements.achievement_unlocked.connect(_on_achievement_unlocked)

	_build_level_toggle()


func _on_discovery_changed(_count: int, _total: int) -> void:
	_update_discovery_display()


func _on_achievement_unlocked(_id: String, _name: String, _desc: String) -> void:
	_update_achievement_count()


func _update_discovery_display() -> void:
	var count := DiscoveryManager.get_discovery_count()
	var total := DiscoveryManager.get_total_count()

	discovery_label.text = "%d / %d discovered" % [count, total]
	progress_bar.max_value = total
	progress_bar.value = count

	node_count_label.text = "The Math Universe"

	_update_domain_indicators()
	_update_achievement_count()


func _build_domain_indicators() -> void:
	# Clear existing
	for child in domain_indicators.get_children():
		child.queue_free()

	if DataLoader.graph == null:
		return

	for domain in DataLoader.graph.domains:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.color = domain.color
		dot.name = domain.id
		dot.tooltip_text = domain.node_name
		domain_indicators.add_child(dot)

		var lbl := Label.new()
		lbl.name = domain.id + "_pct"
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.add_theme_color_override("font_color", domain.color.lightened(0.3))
		lbl.text = "0%"
		domain_indicators.add_child(lbl)


func _update_domain_indicators() -> void:
	if DataLoader.graph == null:
		return

	for domain in DataLoader.graph.domains:
		var pct := DiscoveryManager.get_domain_progress(domain.id)
		var lbl = domain_indicators.get_node_or_null(domain.id + "_pct")
		if lbl:
			lbl.text = "%d%%" % int(pct * 100)


func _update_achievement_count() -> void:
	achievement_label.text = "%d/%d" % [Achievements.get_unlocked_count(), Achievements.get_total_count()]


func show_hover(node_id: String) -> void:
	_hovered_node_id = node_id
	var math_node := DataLoader.graph.get_node(node_id)
	if math_node:
		var state := DiscoveryManager.get_state(node_id)
		if state == "adjacent":
			hover_label.text = "??? (Click to discover)"
			hover_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		else:
			hover_label.text = math_node.node_name
			hover_label.add_theme_color_override("font_color", math_node.color)


func clear_hover(node_id: String) -> void:
	if _hovered_node_id == node_id:
		hover_label.text = ""
		_hovered_node_id = ""


func set_connections_visible(showing: bool) -> void:
	if showing:
		hover_label.text = "All connections visible"
		hover_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
	else:
		hover_label.text = "Connections: discovered only"
		hover_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	# Clear after 2 seconds
	await get_tree().create_timer(2.0).timeout
	if hover_label.text.begins_with("All connections") or hover_label.text.begins_with("Connections:"):
		hover_label.text = ""


func _build_level_toggle() -> void:
	var top_bar = %TopBar

	# Insert level toggle at end of top bar
	var sep := VSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	top_bar.add_child(sep)

	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	top_bar.add_child(container)

	var label := Label.new()
	label.text = "Level:"
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	container.add_child(label)

	for level_key in _LEVEL_CONFIG:
		var btn := Button.new()
		btn.text = _LEVEL_CONFIG[level_key]
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 10)
		btn.toggle_mode = true
		btn.button_pressed = (level_key == DataLoader.resource_level)
		btn.pressed.connect(_on_level_pressed.bind(level_key))
		container.add_child(btn)
		_level_buttons[level_key] = btn

	_update_level_button_styles()


func _on_level_pressed(level: String) -> void:
	DataLoader.resource_level = level
	_update_level_button_styles()
	DataLoader.resource_level_changed.emit(level)


func _update_level_button_styles() -> void:
	for key in _level_buttons:
		var btn: Button = _level_buttons[key]
		btn.button_pressed = (key == DataLoader.resource_level)
		if key == DataLoader.resource_level:
			btn.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
			btn.add_theme_color_override("font_pressed_color", Color(0.4, 0.8, 1.0))
		else:
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
			btn.add_theme_color_override("font_pressed_color", Color(0.5, 0.5, 0.6))
