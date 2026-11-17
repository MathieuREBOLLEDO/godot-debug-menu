extends CanvasLayer

## Pipette (lancée par selection.gd, toggle_pipette()) : couvre l'écran du jeu
## (les fenêtres de debug restent au-dessus). Au survol, le nom du nœud visé
## suit la souris ; le clic gauche le choisit ; clic droit ou Échap annule.
## Se supprime ensuite.

signal node_picked(node: Node)
signal cancelled

const NodeFinder = preload("res://addons/debug_menu/selection/node_finder.gd")
const LAYER: int = 101 # au-dessus de la barre (100)

var _overlay: Control
var _hint: Label


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.mouse_default_cursor_shape = Control.CURSOR_CROSS
	_overlay.gui_input.connect(_on_overlay_gui_input)
	add_child(_overlay)
	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 4)
	_overlay.add_child(_hint)


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_finish(null)


func _on_overlay_gui_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		var hovered: Node = _pick(motion.position)
		_hint.text = "" if hovered == null else String(hovered.name)
		_hint.position = motion.position + Vector2(16, 16)
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_LEFT:
		_finish(_pick(button.position))
	elif button.button_index == MOUSE_BUTTON_RIGHT:
		_finish(null)


# Le calque lui-même est un Control plein écran : on le masque le temps de
# chercher pour ne pas le trouver.
func _pick(screen_position: Vector2) -> Node:
	visible = false
	var node: Node = NodeFinder.pick_at(get_viewport(), screen_position)
	visible = true
	return node


func _finish(node: Node) -> void:
	if node == null:
		cancelled.emit()
	else:
		node_picked.emit(node)
	queue_free()
