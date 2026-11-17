extends Panel

## Cadre d'une fenêtre de debug : fond, bordure, barre de titre maison
## ([épingle] Titre [étoile] ... [X]), déplacement par la barre de titre et
## poignée de redimensionnement en bas à droite.
## Remplace la décoration de Godot, dans laquelle on ne peut pas ajouter de
## boutons. Ajouté par DebugMenu : la scène de la fenêtre n'en sait rien.

signal pin_toggled(pinned: bool)
signal favorite_toggled(favorite: bool)

const TITLE_HEIGHT: int = 32
const GRIP_SIZE: int = 14
const MIN_WINDOW_SIZE: Vector2i = Vector2i(160, 80)
const PANEL_TYPE: String = "DebugWindowPanel"
const PANEL_FOCUSED_TYPE: String = "DebugWindowPanelFocused"
const TITLE_TYPE: String = "DebugWindowTitle"
const BUTTON_TYPE: String = "DebugBarButton"
const PIN_ICON: Texture2D = preload("res://addons/debug_menu/icons/pin.svg")
const STAR_OUTLINE_ICON: Texture2D = preload("res://addons/debug_menu/icons/star_outline.svg")
const STAR_FILLED_ICON: Texture2D = preload("res://addons/debug_menu/icons/star_filled.svg")
const CLOSE_ICON: Texture2D = preload("res://addons/debug_menu/icons/close.svg")
const Tokens = preload("res://addons/debug_menu/settings/design_tokens.gd")
const T = preload("res://addons/debug_menu/i18n/t.gd")

var pin_button: Button
var star_button: Button # null quand la fenêtre n'a pas d'étoile (Settings)
var _window: Window
var _grip: Control
var _dragging: bool = false
var _resizing: bool = false


## À appeler avant d'ajouter [param window] à l'arbre.
func setup(window: Window, show_star: bool, is_favorite: bool) -> void:
	_window = window
	window.borderless = true
	window.size.y += TITLE_HEIGHT

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = PANEL_TYPE
	window.add_child(self)
	window.move_child(self, 0) # fond : derrière le contenu
	_build_title_bar(show_star, is_favorite)
	_build_grip()
	# Le contenu peut aussi être créé en code dans le _ready() de la fenêtre :
	# chaque Control enfant est donc traité à son entrée dans l'arbre.
	window.child_entered_tree.connect(_on_window_child_entered_tree)
	window.focus_entered.connect(_on_window_focus_changed.bind(true))
	window.focus_exited.connect(_on_window_focus_changed.bind(false))


# Le contenu descend pour laisser la place à la barre de titre (une seule
# fois par nœud), et la poignée reste au-dessus de lui.
func _on_window_child_entered_tree(node: Node) -> void:
	var control: Control = node as Control
	if control == null or control == self or control == _grip or node.get_parent() != _window:
		return
	if not control.has_meta(&"debug_frame_shifted"):
		control.set_meta(&"debug_frame_shifted", true)
		if is_equal_approx(control.anchor_top, control.anchor_bottom):
			control.position.y += TITLE_HEIGHT
		else:
			control.offset_top += TITLE_HEIGHT
	_window.move_child.call_deferred(_grip, -1)


func _build_title_bar(show_star: bool, is_favorite: bool) -> void:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 4
	bar.offset_top = 2
	bar.offset_right = -4
	bar.offset_bottom = TITLE_HEIGHT
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.gui_input.connect(_on_title_bar_gui_input)

	# Épingle tout à gauche, loin de la croix : estompée, sable une fois activée.
	pin_button = _make_button(PIN_ICON, T.t("Pin: stays visible when the bar is hidden"))
	pin_button.toggle_mode = true
	pin_button.add_theme_color_override("icon_pressed_color", Tokens.color("sand"))
	pin_button.add_theme_color_override("icon_hover_pressed_color", Tokens.color("sand"))
	pin_button.toggled.connect(_on_pin_button_toggled)
	bar.add_child(pin_button)

	var title_label: Label = Label.new()
	title_label.text = _window.title
	title_label.theme_type_variation = TITLE_TYPE
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title_label)

	if show_star:
		star_button = _make_button(STAR_OUTLINE_ICON, "")
		star_button.toggle_mode = true
		star_button.button_pressed = is_favorite
		_update_star()
		star_button.toggled.connect(_on_star_button_toggled)
		bar.add_child(star_button)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)

	var close_button: Button = _make_button(CLOSE_ICON, T.t("Close"))
	close_button.add_theme_color_override("icon_hover_color", Tokens.color("bad"))
	close_button.pressed.connect(_window.close_requested.emit)
	bar.add_child(close_button)
	add_child(bar)


# La poignée est le dernier enfant de la fenêtre pour rester au-dessus du contenu.
func _build_grip() -> void:
	_grip = Control.new()
	_grip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_grip.offset_left = -GRIP_SIZE
	_grip.offset_top = -GRIP_SIZE
	_grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	_grip.tooltip_text = T.t("Resize")
	_grip.gui_input.connect(_on_grip_gui_input)
	_grip.draw.connect(_on_grip_draw)
	_window.add_child(_grip)


func _make_button(icon: Texture2D, tooltip: String) -> Button:
	var button: Button = Button.new()
	button.icon = icon
	button.tooltip_text = tooltip
	button.theme_type_variation = BUTTON_TYPE
	button.focus_mode = Control.FOCUS_NONE
	return button


func _on_title_bar_gui_input(event: InputEvent) -> void:
	var button_event: InputEventMouseButton = event as InputEventMouseButton
	if button_event != null and button_event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button_event.pressed
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _dragging:
		var new_position: Vector2i = _window.position + Vector2i(motion.relative)
		new_position.y = maxi(new_position.y, 0) # barre de titre toujours attrapable
		_window.position = new_position


func _on_grip_gui_input(event: InputEvent) -> void:
	var button_event: InputEventMouseButton = event as InputEventMouseButton
	if button_event != null and button_event.button_index == MOUSE_BUTTON_LEFT:
		_resizing = button_event.pressed
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _resizing:
		var new_size: Vector2i = _window.size + Vector2i(motion.relative)
		var min_size: Vector2i = Vector2i(_window.get_contents_minimum_size())
		new_size.x = maxi(new_size.x, maxi(min_size.x, MIN_WINDOW_SIZE.x))
		new_size.y = maxi(new_size.y, maxi(min_size.y, MIN_WINDOW_SIZE.y))
		_window.size = new_size


func _on_grip_draw() -> void:
	var color: Color = _grip.get_theme_color("icon_normal_color", BUTTON_TYPE)
	for i in 3:
		var inset: float = 3.0 + i * 4.0
		_grip.draw_line(Vector2(inset, GRIP_SIZE - 2), Vector2(GRIP_SIZE - 2, inset), color, 1.5, true)


func _on_window_focus_changed(focused: bool) -> void:
	theme_type_variation = PANEL_FOCUSED_TYPE if focused else PANEL_TYPE


func _on_pin_button_toggled(toggled_on: bool) -> void:
	pin_toggled.emit(toggled_on)


func _on_star_button_toggled(toggled_on: bool) -> void:
	_update_star()
	favorite_toggled.emit(toggled_on)


func _update_star() -> void:
	star_button.icon = STAR_FILLED_ICON if star_button.button_pressed else STAR_OUTLINE_ICON
	star_button.tooltip_text = T.t("Remove from favorites") if star_button.button_pressed else T.t("Add to favorites")
