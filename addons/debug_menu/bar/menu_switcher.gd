extends HBoxContainer

## Menus de la barre qui se replient (nœud Bar/Row/Switcher) :
##   écran large  : [★ Favoris] [Objects] [Scene] [Global] [QA]... côte à côte ;
##   écran étroit : [‹] [un seul menu] [›] (compact).
## En compact, ‹ et › passent au menu précédent ou suivant, en boucle (la
## molette aussi). Le menu affiché reste le même quand la barre se replie ou
## se déplie. La barre (menu_bar.gd) choisit le mode avec set_compact().

const ThemeBuilder = preload("res://addons/debug_menu/settings/debug_menu_theme.gd")
const T = preload("res://addons/debug_menu/i18n/t.gd")

var compact: bool = false
var _current: MenuButton = null # menu affiché en compact

@onready var prev_button: Button = $PrevButton
@onready var next_button: Button = $NextButton
@onready var favorites_menu: MenuButton = $FavoritesMenu
@onready var menus: HBoxContainer = $Menus


func _ready() -> void:
	for button in [prev_button, next_button]:
		button.theme_type_variation = ThemeBuilder.BAR_BUTTON
	prev_button.pressed.connect(_step.bind(-1))
	next_button.pressed.connect(_step.bind(1))
	retranslate()


## Molette sur les menus repliés : un menu par cran.
func _input(event: InputEvent) -> void:
	var wheel: InputEventMouseButton = event as InputEventMouseButton
	if wheel == null or not wheel.pressed or not compact or not is_visible_in_tree():
		return
	if not get_global_rect().has_point(get_global_mouse_position()):
		return
	match wheel.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
			_step(-1)
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
			_step(1)
		_:
			return
	get_viewport().set_input_as_handled()


func retranslate() -> void:
	prev_button.tooltip_text = T.t("Previous menu")
	next_button.tooltip_text = T.t("Next menu")


func set_compact(value: bool) -> void:
	compact = value
	refresh()


## Largeur des menus côte à côte (écran large), qu'ils soient affichés ou non.
func wide_width() -> float:
	var width: float = 0.0
	var count: int = 0
	for button in available_menus():
		if button == favorites_menu:
			continue
		width += button.get_combined_minimum_size().x
		count += 1
	# Écart entre les menus (dans Menus), puis Favoris devant (écart de la zone).
	width += float(menus.get_theme_constant("separation")) * maxi(count - 1, 0)
	if favorites_menu.get_popup().item_count > 0:
		width += favorites_menu.get_combined_minimum_size().x + float(get_theme_constant("separation"))
	return width


## Menus à montrer : Favoris s'il a des entrées, puis les autres.
func available_menus() -> Array[MenuButton]:
	var buttons: Array[MenuButton] = []
	if favorites_menu.get_popup().item_count > 0:
		buttons.append(favorites_menu)
	for child in menus.get_children():
		var button: MenuButton = child as MenuButton
		if button != null and not button.is_queued_for_deletion():
			buttons.append(button)
	return buttons


## Montre les menus selon le mode (à rappeler quand des menus changent).
func refresh() -> void:
	var buttons: Array[MenuButton] = available_menus()
	favorites_menu.visible = false
	for child in menus.get_children():
		(child as Control).visible = false
	if not compact:
		prev_button.visible = false
		next_button.visible = false
		for button in buttons:
			button.visible = true
		return
	if buttons.is_empty():
		prev_button.visible = false
		next_button.visible = false
		return
	if not buttons.has(_current):
		# Premier menu après Favoris : Favoris n'est qu'un raccourci.
		_current = buttons[1] if buttons.size() > 1 and buttons[0] == favorites_menu else buttons[0]
	_current.visible = true
	prev_button.visible = buttons.size() > 1
	next_button.visible = buttons.size() > 1


# --- Interne ---

func _step(direction: int) -> void:
	var buttons: Array[MenuButton] = available_menus()
	if buttons.is_empty():
		return
	if _current != null:
		_current.get_popup().hide()
	var index: int = buttons.find(_current)
	_current = buttons[posmod(index + direction, buttons.size())]
	refresh()
