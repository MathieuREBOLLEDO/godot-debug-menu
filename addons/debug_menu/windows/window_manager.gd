extends Node

## Fenêtres du debug menu (nœud Windows de debug_menu.tscn) : création au
## premier clic, cadre, placement, épinglage, masquage avec la barre, et
## session (position, taille, épingle gardées d'une partie à l'autre).
## Les fenêtres sont ses enfants.

signal window_created(key: String, window: Window)
signal favorite_toggled(key: String, favorite: bool)
signal window_input(event: InputEvent)

const WindowFrame = preload("res://addons/debug_menu/windows/window_frame.gd")
const T = preload("res://addons/debug_menu/i18n/t.gd")
const MAX_WINDOW_RATIO: float = 0.7 # taille max d'une fenêtre à l'ouverture, en part de l'écran
const CASCADE_STEP: int = 24 # décalage entre deux nouvelles fenêtres

var window_theme: Theme # donné par DebugMenu
var top_margin: int = 0 # hauteur de la barre : les fenêtres s'ouvrent en dessous

# Dictionnaires non typés : les dictionnaires typés demandent Godot 4.4+.
var _scenes: Dictionary = {} # clé -> PackedScene
var _windows: Dictionary = {} # clé -> Window, créée au premier clic
var _pinned: Dictionary = {} # clé -> true : reste affichée quand la barre est cachée
var _frames: Dictionary = {} # clé -> WindowFrame
var _saved: Dictionary = {} # clé -> {position, size} de la partie précédente
var _windows_to_restore: Array[Window] = []
var _bar_hidden: bool = false


## Retourne false si [param key] est déjà enregistrée.
func register(key: String, scene: PackedScene) -> bool:
	if _scenes.has(key):
		return false
	_scenes[key] = scene
	return true


func has_window(key: String) -> bool:
	return _scenes.has(key)


## null tant que la fenêtre n'a jamais été ouverte.
func find_window(key: String) -> Window:
	return _windows.get(key)


func open(key: String, show_star: bool, is_favorite: bool) -> void:
	var window: Window = _windows.get(key)
	if window == null:
		window = _create(key, show_star, is_favorite)
		if window == null:
			return
	window.show()
	window.grab_focus()


## La barre se cache : les fenêtres ouvertes aussi, sauf les épinglées.
func hide_unpinned() -> void:
	_bar_hidden = true
	for key in _windows:
		var window: Window = _windows[key]
		if window.visible and not _pinned.get(key, false):
			_windows_to_restore.append(window)
			window.hide()


## La barre revient : les fenêtres cachées avec elle aussi, à la position où
## elles étaient (un Window masqué la garde).
func restore() -> void:
	_bar_hidden = false
	for window in _windows_to_restore:
		window.show()
	_windows_to_restore.clear()


func set_pinned(key: String, pinned: bool) -> void:
	if _frames.has(key):
		(_frames[key] as WindowFrame).pin_button.button_pressed = pinned


# --- Session ---

## État des fenêtres à enregistrer : [{key, position, size, visible, pinned}].
## Les fenêtres pas ouvertes cette fois gardent leur place précédente.
func get_session() -> Array:
	var entries: Array = []
	for key in _windows:
		var window: Window = _windows[key]
		entries.append({
			"key": key,
			"position": window.position,
			"size": window.size,
			"visible": window.visible or _windows_to_restore.has(window),
			"pinned": _pinned.get(key, false),
		})
	for key in _saved:
		if not _windows.has(key):
			entries.append({"key": key, "position": _saved[key]["position"], "size": _saved[key]["size"], "visible": false, "pinned": false})
	return entries


## Place et taille de la partie précédente, utilisées à la création.
func load_session(entries: Array) -> void:
	for entry in entries:
		if entry is Dictionary and entry.has("key"):
			_saved[entry["key"]] = {"position": entry.get("position", Vector2i.ZERO), "size": entry.get("size", Vector2i.ZERO)}


## Refait toutes les fenêtres créées (après un changement de langue) : les
## anciennes sont libérées, celles qui étaient ouvertes sont rouvertes au
## même endroit avec la même épingle. [param open_window] (clé) ouvre une
## fenêtre comme le menu.
func recreate(open_window: Callable) -> void:
	var entries: Array = get_session()
	for key in _windows:
		(_windows[key] as Window).queue_free()
	_windows.clear()
	_frames.clear()
	_pinned.clear()
	_windows_to_restore.clear()
	load_session(entries)
	var bar_hidden: bool = _bar_hidden
	for entry in entries:
		if entry["visible"]:
			open_window.call(entry["key"])
			set_pinned(entry["key"], entry["pinned"])
	if bar_hidden:
		hide_unpinned()


func _create(key: String, show_star: bool, is_favorite: bool) -> Window:
	var node: Node = (_scenes[key] as PackedScene).instantiate()
	var window: Window = node as Window
	if window == null:
		push_error(T.t("DebugMenu: the scene of \"%s\" must have a Window as its root.") % key)
		node.free()
		return null
	# Titre écrit en anglais dans la scène, traduit ici (un titre absent du
	# dictionnaire, comme ceux du jeu, reste tel quel).
	window.title = T.t(window.title)
	# Le thème ne passe pas du CanvasLayer aux Window : on le donne ici, sauf
	# si la fenêtre a déjà le sien.
	if window.theme == null:
		window.theme = window_theme
	var frame: WindowFrame = WindowFrame.new()
	frame.setup(window, show_star, is_favorite)
	frame.pin_toggled.connect(_on_pin_toggled.bind(key, window))
	frame.favorite_toggled.connect(func(favorite: bool) -> void: favorite_toggled.emit(key, favorite))
	_frames[key] = frame
	window.close_requested.connect(window.hide)
	window.window_input.connect(func(event: InputEvent) -> void: window_input.emit(event))
	add_child(window)
	if _saved.has(key):
		_place_saved(window, _saved[key])
	else:
		_place(window)
	_windows[key] = window
	window_created.emit(key, window)
	return window


# Première ouverture : taille limitée à une part de l'écran, fenêtre centrée
# sous la barre, légèrement décalée à chaque nouvelle fenêtre pour ne pas les
# empiler exactement. Ensuite elle garde la position et la taille choisies.
func _place(window: Window) -> void:
	var area: Vector2 = get_viewport().get_visible_rect().size
	var max_size: Vector2i = Vector2i(int(area.x * MAX_WINDOW_RATIO), int((area.y - top_margin) * MAX_WINDOW_RATIO))
	window.size = Vector2i(mini(window.size.x, max_size.x), mini(window.size.y, max_size.y))
	var cascade: int = (_windows.size() % 5) * CASCADE_STEP
	var centered: Vector2i = Vector2i((area - Vector2(window.size)) / 2.0) + Vector2i(cascade, cascade)
	window.position = Vector2i(maxi(centered.x, 0), maxi(centered.y, top_margin))


# Place de la partie précédente, ramenée dans l'écran (la résolution a pu
# changer).
func _place_saved(window: Window, saved: Dictionary) -> void:
	var area: Vector2i = Vector2i(get_viewport().get_visible_rect().size)
	var saved_size: Vector2i = saved["size"]
	if saved_size.x > 0 and saved_size.y > 0:
		window.size = Vector2i(mini(saved_size.x, area.x), mini(saved_size.y, area.y))
	var saved_position: Vector2i = saved["position"]
	window.position = Vector2i(clampi(saved_position.x, 0, maxi(area.x - window.size.x, 0)), clampi(saved_position.y, 0, maxi(area.y - window.size.y, 0)))


# Désépinglée pendant que la barre est cachée : la fenêtre se cache aussi,
# et reviendra avec la barre.
func _on_pin_toggled(pinned: bool, key: String, window: Window) -> void:
	_pinned[key] = pinned
	if not pinned and _bar_hidden and window.visible:
		_windows_to_restore.append(window)
		window.hide()
