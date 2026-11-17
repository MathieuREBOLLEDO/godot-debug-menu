extends CanvasLayer

## Entrées à l'écran (menu Display) : en bas de l'écran, une étiquette par
## action du jeu appuyée (force affichée pour une action analogique), et le
## bouton de souris appuyé. Visible même barre cachée, et pendant un replay
## (on voit alors les entrées rejouées).
## Les actions du debug menu et celles de l'interface de Godot (ui_*) sont
## ignorées : elles encombreraient l'affichage.

const LAYER: int = 101
const MARGIN: float = 12.0
const IGNORED_PREFIXES: Array[String] = ["debug_menu_", "ui_"]

var _row: HBoxContainer
var _labels: Dictionary = {} # texte -> PanelContainer affiché


func _init() -> void:
	layer = LAYER
	visible = false
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_row.offset_bottom = -MARGIN
	add_child(_row)


## Le thème du debug menu (le CanvasLayer ne le transmet pas tout seul).
func set_theme(theme: Theme) -> void:
	_row.theme = theme


func _process(_delta: float) -> void:
	if not visible:
		return
	var pressed: PackedStringArray = PackedStringArray()
	for action in InputMap.get_actions():
		if _is_ignored(String(action)) or not Input.is_action_pressed(action):
			continue
		var strength: float = Input.get_action_strength(action)
		pressed.append(String(action) if strength >= 0.99 else "%s %.2f" % [action, strength])
	for button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if Input.is_mouse_button_pressed(button):
			pressed.append(["", "LMB", "RMB", "MMB"][button])
	_show(pressed)


# Étiquettes : on garde celles déjà affichées, on ajoute ou retire le reste.
func _show(texts: PackedStringArray) -> void:
	for text in _labels.keys():
		if not texts.has(text):
			(_labels[text] as Node).queue_free()
			_labels.erase(text)
	for text in texts:
		if _labels.has(text):
			continue
		var chip: PanelContainer = PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label: Label = Label.new()
		label.text = text
		chip.add_child(label)
		_row.add_child(chip)
		_labels[text] = chip


func _is_ignored(action: String) -> bool:
	for prefix in IGNORED_PREFIXES:
		if action.begins_with(prefix):
			return true
	return false
