extends RefCounted

## Modes souris des fenêtres de debug (choisis dans les Paramètres, qui
## restent cliquables dans tous les modes) :
## - DEBUG : la souris ne sert qu'au debug ; ailleurs, les clics sont bloqués
##   pour le jeu ;
## - GAME : la souris ne sert qu'au jeu ; les fenêtres ne réagissent plus,
##   ne prennent plus le clavier et laissent passer les clics ;
## - BOTH : une fenêtre sous la souris la prend, sinon c'est le jeu.
## La barre reste toujours cliquable, pour pouvoir ouvrir les Paramètres.
##
## Limites :
## - le blocage du mode DEBUG passe par l'interface (un Control plein écran) :
##   un jeu qui lit la souris dans _input() ou avec Input.is_mouse_button_pressed()
##   la voit quand même ;
## - mouse_passthrough n'a pas d'effet sur une fenêtre intégrée au jeu : en mode
##   GAME, chaque événement souris est donc renvoyé au jeu en masquant la
##   fenêtre le temps de le transmettre.

enum Mode { DEBUG, GAME, BOTH }

# Textes en anglais, traduits à l'affichage (i18n/).
const NAMES: Array[String] = ["Debug", "Game", "Both"]
const TOOLTIPS: Array[String] = [
	"Mouse: debug only (clicks no longer reach the game)",
	"Mouse: game only (windows let clicks through)",
	"Mouse: window under the mouse, otherwise game",
]

var mode: int = Mode.BOTH
var _blocker: Control
var _windows: Array[Window] = []
var _forwarding: bool = false


## [param blocker] : Control plein écran qui arrête les clics en mode DEBUG.
func _init(blocker: Control) -> void:
	_blocker = blocker
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP


func add_window(window: Window) -> void:
	_windows.append(window)
	window.window_input.connect(_on_window_input.bind(window))
	_apply_to(window)


func set_mode(value: int) -> void:
	mode = value
	_blocker.visible = mode == Mode.DEBUG
	# Les fenêtres refaites (changement de langue) ont libéré les anciennes.
	_windows = _windows.filter(func(window: Window) -> bool: return is_instance_valid(window))
	for window in _windows:
		_apply_to(window)


func _apply_to(window: Window) -> void:
	var game_only: bool = mode == Mode.GAME
	window.gui_disable_input = game_only
	window.unfocusable = game_only


func _on_window_input(event: InputEvent, window: Window) -> void:
	if mode != Mode.GAME or _forwarding:
		return
	var mouse_event: InputEventMouse = event as InputEventMouse
	if mouse_event == null:
		return
	# Coordonnées de la fenêtre -> coordonnées du jeu.
	var forwarded: InputEventMouse = mouse_event.duplicate()
	forwarded.position = Vector2(window.position) + mouse_event.position
	forwarded.global_position = forwarded.position
	_forwarding = true
	window.visible = false
	window.get_tree().root.push_input(forwarded)
	window.visible = true
	_forwarding = false
