extends RefCounted

## Ouverture des menus de la barre au survol : un menu survolé s'ouvre et se
## referme quand la souris s'en va ; un clic sur son bouton le fixe (il reste
## ouvert), un second clic le referme. La souris dans un sous-menu ouvert
## compte comme dans le menu.
## DebugMenu appelle watch() pour chaque menu et update() à chaque frame.

const CLOSE_DELAY: float = 0.25 # secondes hors du menu avant de le refermer

var _bar: Control # sert à lire la position de la souris
var _get_buttons: Callable # () -> Array[MenuButton]
var _open_menu: MenuButton = null
var _pinned: bool = false
var _leave_time: float = 0.0
var _blocked_menu: MenuButton = null # refermé par un clic : pas de réouverture avant d'en sortir


func _init(bar: Control, get_buttons: Callable) -> void:
	_bar = bar
	_get_buttons = get_buttons


func watch(menu_button: MenuButton) -> void:
	# Menu ouvert : passer sur un autre bouton de la barre ouvre celui-là.
	menu_button.switch_on_hover = true
	menu_button.focus_mode = Control.FOCUS_NONE
	menu_button.get_popup().popup_hide.connect(_on_popup_hide.bind(menu_button))


func update(delta: float) -> void:
	var hovered: MenuButton = _get_menu_under_mouse()
	if hovered != _blocked_menu:
		_blocked_menu = null

	_open_menu = null
	for menu_button in _get_buttons.call():
		if menu_button.get_popup().visible:
			_open_menu = menu_button

	if _open_menu == null:
		_pinned = false
		if hovered != null and hovered != _blocked_menu:
			hovered.show_popup()
			_open_menu = hovered
			_leave_time = 0.0
		return
	if _pinned:
		return
	var popup: PopupMenu = _open_menu.get_popup()
	if hovered == _open_menu or _is_over(popup, _bar.get_global_mouse_position()):
		_leave_time = 0.0
		return
	_leave_time += delta
	if _leave_time >= CLOSE_DELAY:
		popup.hide()


# La souris est sur [param popup] ou sur l'un de ses sous-menus ouverts.
static func _is_over(popup: PopupMenu, mouse: Vector2) -> bool:
	if Rect2(Vector2(popup.position), Vector2(popup.size)).has_point(mouse):
		return true
	for child in popup.get_children():
		if child is PopupMenu and child.visible and _is_over(child, mouse):
			return true
	return false


func _get_menu_under_mouse() -> MenuButton:
	var mouse: Vector2 = _bar.get_global_mouse_position()
	for menu_button in _get_buttons.call():
		if menu_button.is_visible_in_tree() and _visible_rect(menu_button).has_point(mouse):
			return menu_button
	return null


# Partie visible de [param control] : un menu à moitié sorti de la zone
# défilante ne s'ouvre pas quand la souris est sur une flèche à côté.
static func _visible_rect(control: Control) -> Rect2:
	var rect: Rect2 = control.get_global_rect()
	var parent: Control = control.get_parent() as Control
	while parent != null:
		if parent.clip_contents:
			rect = rect.intersection(parent.get_global_rect())
		parent = parent.get_parent() as Control
	return rect


# Un clic hors d'un menu ouvert le referme (comportement de Godot). Si ce clic
# est sur le bouton du menu, on l'interprète : menu ouvert au survol -> on le
# rouvre fixé ; menu déjà fixé -> il reste fermé jusqu'à ce que la souris sorte.
func _on_popup_hide(menu_button: MenuButton) -> void:
	if menu_button != _open_menu:
		return
	var hovered: MenuButton = _get_menu_under_mouse()
	if hovered == menu_button:
		if _pinned:
			_pinned = false
			_blocked_menu = menu_button
		else:
			_pinned = true
			menu_button.call_deferred("show_popup")
	elif hovered == null:
		# Sur un autre menu (switch_on_hover), on garde l'état fixé.
		_pinned = false
