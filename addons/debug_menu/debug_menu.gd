extends CanvasLayer

## Debug menu (autoload DebugMenu) : crée les services, la barre et les
## menus, et offre l'API publique au jeu (add_entry, add_toggle, select,
## inspect, show_physics). Le détail est dans :
## - bar/menu_bar.gd : la barre et ses menus ;
## - selection/ : l'objet sélectionné, partagé par les fenêtres ;
## - windows/ : création, placement, épinglage des fenêtres ; modes souris ;
## - time/ : pause, image +1, vitesse, prises et replays ;
## - display/ : dessins dans le jeu et repères d'écran (Core > Display, Screen) ;
## - settings/ : apparence, raccourcis, tout ce qui est enregistré.

# Menus de la barre, dans l'ordre : Core (outils généraux, avec les
# sous-menus Time, Display, Screen), Objects, Scene. « / » = sous-menu.
const CORE_MENU: String = "Core"
const TIME_MENU: String = "Core/Time"
const DISPLAY_MENU: String = "Core/Display"
const SCREEN_MENU: String = "Core/Screen"
const OBJECTS_MENU: String = "Objects"
const SCENE_MENU: String = "Scene"
const INSPECTOR_KEY: String = "Objects/Inspector"
const PHYSICS_KEY: String = "Objects/Physics"
const RECORDINGS_KEY: String = "Core/Time/Recordings"
const WATCH_KEY: String = "Objects/Watch"
const CHEATS_MENU: String = "Cheats"
const CHEATS_KEY: String = "Cheats/Cheat codes"
const SETTINGS_KEY: String = "Settings" # pas d'entrée de menu : bouton ⚙
## Étiquettes d'export (Export > Fonctionnalités) qui coupent le debug menu :
## no_debug_menu (fichiers gardés) ou strip_debug_menu (fichiers retirés par
## export/strip_export_plugin.gd).
const DISABLED_FEATURES: Array[String] = ["no_debug_menu", "strip_debug_menu"]
const CORE_WINDOWS: Array = [ # [menu, entrée, scène] ; textes en anglais (i18n/)
	[CORE_MENU, "Console", preload("res://addons/debug_menu/tools/console/console_window.tscn")],
	[CORE_MENU, "Performance", preload("res://addons/debug_menu/tools/performance/performance_window.tscn")],
	[CORE_MENU, "Free camera", preload("res://addons/debug_menu/tools/camera/free_camera_window.tscn")],
]
const WINDOWS: Array = [ # après Screenshot et la case Time controls, dans l'ordre des menus
	[TIME_MENU, "Speed and frame stepping", preload("res://addons/debug_menu/time/time_window.tscn")],
	[TIME_MENU, "Recordings", preload("res://addons/debug_menu/time/recording/recordings_window.tscn")],
	[OBJECTS_MENU, "Inspector", preload("res://addons/debug_menu/objects/inspector/inspector_window.tscn")],
	[OBJECTS_MENU, "Physics", preload("res://addons/debug_menu/objects/physics/physics_window.tscn")],
	[OBJECTS_MENU, "Signals", preload("res://addons/debug_menu/objects/signals/signals_window.tscn")],
	[OBJECTS_MENU, "Watch", preload("res://addons/debug_menu/objects/watch/watch_window.tscn")],
	[OBJECTS_MENU, "Variable finder", preload("res://addons/debug_menu/objects/finder/finder_window.tscn")],
	[SCENE_MENU, "Node tree", preload("res://addons/debug_menu/scene/scene_tree_window.tscn")],
	[SCENE_MENU, "Node events", preload("res://addons/debug_menu/scene/node_events_window.tscn")],
	[SCENE_MENU, "Resources", preload("res://addons/debug_menu/scene/resources_window.tscn")],
	[SCENE_MENU, "Snapshots and seed", preload("res://addons/debug_menu/scene/snapshots/snapshots_window.tscn")],
	[CHEATS_MENU, "Cheat codes", preload("res://addons/debug_menu/cheats/cheats_window.tscn")],
]
## Menu Global : chargé seulement si project_init a laissé ce réglage.
const GLOBAL_MENU_MARKER: String = "project_init/version"
const GLOBAL_MENU_SCRIPT: String = "res://addons/debug_menu/global/global_menu.gd"
const SETTINGS_SCENE: PackedScene = preload("res://addons/debug_menu/settings/settings_window.tscn")
const ThemeBuilder = preload("res://addons/debug_menu/settings/debug_menu_theme.gd")
const SettingsStore = preload("res://addons/debug_menu/settings/settings_store.gd")
const Shortcuts = preload("res://addons/debug_menu/settings/shortcuts.gd")
const WindowManager = preload("res://addons/debug_menu/windows/window_manager.gd")
const MouseModes = preload("res://addons/debug_menu/windows/mouse_modes.gd")
const Selection = preload("res://addons/debug_menu/selection/selection.gd")
const SelectionHighlight = preload("res://addons/debug_menu/selection/selection_highlight.gd")
const NodeRecorder = preload("res://addons/debug_menu/scene/node_recorder.gd")
const TimeController = preload("res://addons/debug_menu/time/time_controller.gd")
const InputRecorder = preload("res://addons/debug_menu/time/recording/input_recorder.gd")
const Playback = preload("res://addons/debug_menu/time/playback.gd")
const DisplayLayer = preload("res://addons/debug_menu/display/display_layer.gd")
const DebugBar = preload("res://addons/debug_menu/bar/menu_bar.gd")
const ConsoleService = preload("res://addons/debug_menu/tools/console/console_service.gd")
const BuiltinCommands = preload("res://addons/debug_menu/tools/console/builtin_commands.gd")
const PerfMonitor = preload("res://addons/debug_menu/tools/performance/perf_monitor.gd")
const PerfOverlay = preload("res://addons/debug_menu/tools/performance/perf_overlay.gd")
const Screenshot = preload("res://addons/debug_menu/tools/screenshot.gd")
const InputOverlay = preload("res://addons/debug_menu/display/input_overlay.gd")
const DisplayToggles = preload("res://addons/debug_menu/display/display_toggles.gd")
const ScreenGuides = preload("res://addons/debug_menu/display/screen_guides.gd")
const GridOverlay = preload("res://addons/debug_menu/display/grid/grid_overlay.gd")
const TouchGesture = preload("res://addons/debug_menu/bar/touch_gesture.gd")
const TimeOverlay = preload("res://addons/debug_menu/time/time_overlay.gd")
const WatchList = preload("res://addons/debug_menu/objects/watch/watch_list.gd")
const RandomSeed = preload("res://addons/debug_menu/scene/random_seed.gd")
const Snapshots = preload("res://addons/debug_menu/scene/snapshots/snapshots.gd")
const FreeCamera = preload("res://addons/debug_menu/tools/camera/free_camera.gd")
const Dithering = preload("res://addons/debug_menu/display/dithering.gd")
const Cheats = preload("res://addons/debug_menu/cheats/cheats.gd")
const T = preload("res://addons/debug_menu/i18n/t.gd")

## L'objet sélectionné, partagé par toutes les fenêtres « objet ».
var selection: Selection
## Vie des nœuds du jeu depuis le lancement (Arbre et Événements des nœuds).
var node_recorder: NodeRecorder
## Pause et image par image (bas niveau ; passer plutôt par playback).
var time_controller: TimeController
## Prises et replays d'actions (bouton REC, fenêtre Enregistrements).
var input_recorder: InputRecorder
## Commandes de temps partagées : pause, image +1, vitesse, lecture d'une prise.
var playback: Playback
## Calque des dessins dans le monde du jeu (Core > Display).
var display_layer: DisplayLayer
## Grille du monde, occupation et cadres des sprites (Core > Display > Grid).
var grid_overlay: GridOverlay
## Commandes et journal des logs (Core > Console).
var console: ConsoleService
## Relevés de performance (fenêtre Performance, overlay).
var perf_monitor: PerfMonitor
## Variables suivies dans la fenêtre Watch (gardées d'une partie à l'autre).
var watch: WatchList
## Graine du hasard global (affichée, fixable).
var random_seed: RandomSeed
## Photos de la scène (en mémoire).
var snapshots: Snapshots
## Caméra libre 2D / 3D (Core > Free camera, Ctrl+F).
var free_camera: FreeCamera
## Tramage de l'écran (Core > Display > Dithering).
var dithering: Dithering
## No clip, invincible, vitesse et gel, cheats du jeu (Cheats > Cheat codes, Alt+C).
var cheats: Cheats

var _store: SettingsStore = SettingsStore.new()
var _theme: Theme = Theme.new()
var _mouse_modes: MouseModes
var _highlight: SelectionHighlight
var _perf_overlay: PerfOverlay
var _input_overlay: InputOverlay
var _time_overlay: TimeOverlay
var _touch_gesture: TouchGesture = TouchGesture.new() # tap à 3 doigts = touche ²
var _capturing_shortcut: bool = false # Paramètres : on attend une nouvelle touche
var _selection_restored: bool = false
# Tout ce qui a été ajouté aux menus, dans l'ordre, pour les refaire après un
# changement de langue : {kind: "window" / "toggle" / "action", menu, entry, ...}.
var _menu_items: Array[Dictionary] = []
var _actions: Dictionary = {} # clé « menu/entrée » -> Callable (add_action)

@onready var bar: DebugBar = $Bar
@onready var windows: WindowManager = $Windows


func _ready() -> void:
	for feature in DISABLED_FEATURES:
		if OS.has_feature(feature):
			disable()
			return
	_store.load_from_disk()
	T.set_language(_store.language)
	Shortcuts.apply(_store.shortcuts)
	ThemeBuilder.apply(_theme, _store.values)
	_create_services()

	bar.theme = _theme
	bar.setup(_store, input_recorder)
	bar.window_requested.connect(_open_window)
	bar.action_requested.connect(func(key: String) -> void: (_actions[key] as Callable).call())
	bar.settings_requested.connect(_open_window.bind(SETTINGS_KEY))
	bar.mouse_mode_requested.connect(set_mouse_mode)
	bar.show_mouse_mode(_mouse_modes.mode)

	windows.window_theme = _theme
	windows.top_margin = int(bar.get_combined_minimum_size().y)
	# Les Paramètres restent cliquables dans tous les modes souris : c'est
	# là qu'on en change.
	windows.window_created.connect(func(key: String, window: Window) -> void:
		if key != SETTINGS_KEY:
			_mouse_modes.add_window(window)
	)
	windows.favorite_toggled.connect(_on_window_favorite_toggled)
	windows.window_input.connect(_handle_shortcuts)
	windows.register(SETTINGS_KEY, SETTINGS_SCENE)
	windows.load_session(_store.session_windows)

	# Ordre d'ajout = ordre des menus et des entrées.
	for entry in CORE_WINDOWS:
		add_entry(entry[0], entry[1], entry[2])
	add_action(CORE_MENU, "Screenshot", take_screenshot)
	add_toggle(TIME_MENU, "Time controls", func() -> bool: return _time_overlay.visible,
			func(on: bool) -> void: _time_overlay.visible = on)
	for entry in WINDOWS:
		add_entry(entry[0], entry[1], entry[2])
	add_action(SCENE_MENU, "Reload scene", reload_scene)
	DisplayToggles.register(self, DISPLAY_MENU, SCREEN_MENU)
	_add_global_menu()
	_perf_overlay.set_theme(_theme)
	_input_overlay.set_theme(_theme)
	_time_overlay.set_theme(_theme)
	free_camera.set_theme(_theme)
	BuiltinCommands.register(self)


# Services enfants de DebugMenu ; l'ordre compte (voir les commentaires).
func _create_services() -> void:
	_mouse_modes = MouseModes.new($MouseBlocker)
	_mouse_modes.set_mode(_store.mouse_mode)
	selection = _add_service(Selection.new(), "Selection")
	_highlight = _add_service(SelectionHighlight.new(), "SelectionHighlight")
	_highlight.selection = selection
	display_layer = _add_service(DisplayLayer.new(), "DisplayLayer")
	display_layer.follow_selection(selection)
	grid_overlay = _add_service(GridOverlay.new(), "GridOverlay")
	# Démarré tout de suite pour voir arriver la scène principale.
	node_recorder = _add_service(NodeRecorder.new(), "NodeRecorder")
	time_controller = _add_service(TimeController.new(), "TimeController")
	# Après TimeController : voit le jeu en marche pendant l'image par image.
	input_recorder = _add_service(InputRecorder.new(), "InputRecorder")
	input_recorder.time_controller = time_controller
	# Fin de prise : les Enregistrements s'ouvrent sur la nouvelle prise.
	input_recorder.recording_saved.connect(func(path: String) -> void:
		_open_window(RECORDINGS_KEY)
		windows.find_window(RECORDINGS_KEY).call("select", path)
	)
	playback = Playback.new(input_recorder, time_controller)
	cheats = _add_service(Cheats.new(), "Cheats")
	cheats.playback = playback
	watch = WatchList.new(_store)
	# Avant la scène principale : son _ready() tire déjà avec cette graine.
	random_seed = RandomSeed.new(_store)
	random_seed.apply_next()
	snapshots = _add_service(Snapshots.new(), "Snapshots")
	snapshots.selection = selection
	console = _add_service(ConsoleService.new(), "Console")
	perf_monitor = _add_service(PerfMonitor.new(), "PerfMonitor")
	_perf_overlay = _add_service(PerfOverlay.new(), "PerfOverlay")
	_perf_overlay.monitor = perf_monitor
	_input_overlay = _add_service(InputOverlay.new(), "InputOverlay")
	_time_overlay = _add_service(TimeOverlay.new(), "TimeOverlay")
	_time_overlay.set_playback(playback)
	_add_service(ScreenGuides.new(), "ScreenGuides")
	# Après Playback : la caméra libre met le jeu en pause par lui.
	free_camera = _add_service(FreeCamera.new(), "FreeCamera")
	dithering = _add_service(Dithering.new(), "Dithering")
	dithering.store = _store
	dithering.load_values(_store.dithering)
	_touch_gesture.tapped.connect(func() -> void: _set_menu_visible(not bar.visible))


# Menu Global (global/) : seulement dans un projet initialisé par project_init
# (réglage project_init/version) ; sinon le dossier n'est même pas chargé.
func _add_global_menu() -> void:
	if not ProjectSettings.has_setting(GLOBAL_MENU_MARKER):
		return
	var global_menu: Node = _add_service(load(GLOBAL_MENU_SCRIPT).new(), "GlobalMenu")
	global_menu.call("register", self)


func _add_service(node: Node, node_name: String) -> Node:
	node.name = node_name
	add_child(node)
	return node


func _process(_delta: float) -> void:
	# La session est rétablie quand la scène principale est là.
	if not _selection_restored and get_tree().current_scene != null:
		_selection_restored = true
		_restore_session()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not is_queued_for_deletion():
		_save_session()


## Retire le debug menu pour toute la partie (export avec une étiquette de
## DISABLED_FEATURES). Renommé tout de suite : get_node_or_null("/root/DebugMenu")
## renvoie null dès les _ready() du jeu, sans attendre la libération.
func disable() -> void:
	name = "DebugMenuDisabled"
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	queue_free()


# --- API publique ---

## Ajoute l'entrée [param entry] au menu [param menu] (créé si besoin ;
## « Menu/Sous-menu » pour un sous-menu).
## [param scene] doit avoir un Window comme racine. Les noms sont traduits
## par le debug menu s'ils sont dans son dictionnaire (i18n/), sinon
## affichés tels quels.
func add_entry(menu: String, entry: String, scene: PackedScene) -> void:
	var key: String = menu + "/" + entry
	if not windows.register(key, scene):
		push_warning(T.t("DebugMenu: the entry \"%s\" already exists.") % key)
		return
	_add_menu_item({"kind": "window", "menu": menu, "entry": entry, "key": key})
	# Un favori enregistré peut correspondre à une entrée ajoutée seulement maintenant.
	if _store.favorites.has(key):
		_refresh_favorites()


## Ajoute une case à cocher [param entry] au menu [param menu] (créé si
## besoin). [param getter] () -> bool lit l'état, [param setter] (bool) le
## change. L'état est gardé d'une partie à l'autre.
func add_toggle(menu: String, entry: String, getter: Callable, setter: Callable) -> void:
	_add_menu_item({"kind": "toggle", "menu": menu, "entry": entry, "getter": getter, "setter": setter})


## Ajoute une entrée [param entry] au menu [param menu] (créé si besoin) qui
## appelle [param action] () au clic, sans ouvrir de fenêtre.
func add_action(menu: String, entry: String, action: Callable) -> void:
	var key: String = menu + "/" + entry
	_actions[key] = action
	_add_menu_item({"kind": "action", "menu": menu, "entry": entry, "key": key})


## Joueur que la caméra libre téléporte d'un clic gauche pendant le vol
## (Node2D ou Node3D ; null : aucun). À rappeler quand le joueur est recréé.
## Un nœud qui a une méthode debug_teleport(position) (Vector2 en 2D,
## Vector3 en 3D) la voit appelée à la place : pour un personnage sur une
## grille, ou un groupe. C'est aussi le joueur des cheats no clip et
## invincible (cheats/cheats.gd).
func set_player(node: Node) -> void:
	free_camera.player = node
	cheats.player = node


## Ajoute le cheat [param cheat_name] à l'onglet [param category] de la
## fenêtre Cheat codes (Alt+C) ; [param action] () est appelé au clic.
## Exemple : add_cheat("Teleport", "Main town", _go_to_town).
func add_cheat(category: String, cheat_name: String, action: Callable) -> void:
	cheats.add(category, cheat_name, action)


## Range le menu [param menu] avec les menus du jeu : collé à gauche après
## les autres menus, jamais replié sur un écran étroit. Le menu nommé comme
## le projet (application/config/name) l'est déjà.
func set_game_menu(menu: String) -> void:
	bar.set_game_menu(menu)


## Langue du debug menu : « en » ou « fr ». Le changement est immédiat : la
## barre est refaite et les fenêtres ouvertes sont rouvertes au même endroit.
func set_language(language: String) -> void:
	T.set_language(language)
	_store.language = T.get_language()
	_store.save()
	bar.clear_menus()
	for item in _menu_items:
		_show_menu_item(item)
	bar.retranslate()
	_refresh_favorites()
	windows.recreate(_open_window)


func _add_menu_item(item: Dictionary) -> void:
	_menu_items.append(item)
	_show_menu_item(item)


func _show_menu_item(item: Dictionary) -> void:
	match item["kind"]:
		"window":
			bar.add_window_entry(item["menu"], item["entry"], item["key"])
		"toggle":
			bar.add_toggle(item["menu"], item["entry"], item["getter"], item["setter"])
		"action":
			bar.add_action_entry(item["menu"], item["entry"], item["key"])


## Déclare une commande de console. [param callable]
## (args: PackedStringArray) -> Variant : une valeur renvoyée est affichée.
## Exemple : add_command("give", func(args): ..., "Give an item", "<item> [n]").
func add_command(command_name: String, callable: Callable, description: String = "", usage: String = "") -> void:
	console.add_command(command_name, callable, description, usage)


## Capture d'écran du jeu seul (sans le debug menu), dans
## user://debug_menu/screenshots ; le chemin s'affiche dans la console.
func take_screenshot() -> void:
	var path: String = await Screenshot.take(self)
	if path == "":
		console.add_line(ConsoleService.Kind.ERROR, T.t("Screenshot failed."))
	else:
		console.add_line(ConsoleService.Kind.RESULT, T.t("Screenshot saved: %s") % ProjectSettings.globalize_path(path))


# --- Gizmos (dessins du jeu, display/gizmos.gd) ---
# Coordonnées du monde 2D. duration : 0 = une image, sinon en secondes.
# category : une case par catégorie dans le menu Display.

func draw_line(from: Vector2, to: Vector2, color: Color = Color.YELLOW, duration: float = 0.0, category: String = "", width: float = 2.0) -> void:
	display_layer.gizmos.add({"kind": "line", "from": from, "to": to, "color": color, "width": width}, duration, category)


func draw_arrow(from: Vector2, to: Vector2, color: Color = Color.YELLOW, duration: float = 0.0, category: String = "", width: float = 2.0) -> void:
	display_layer.gizmos.add({"kind": "arrow", "from": from, "to": to, "color": color, "width": width}, duration, category)


func draw_circle(center: Vector2, radius: float, color: Color = Color.YELLOW, duration: float = 0.0, category: String = "", filled: bool = false, width: float = 2.0) -> void:
	display_layer.gizmos.add({"kind": "circle", "center": center, "radius": radius, "color": color, "filled": filled, "width": width}, duration, category)


func draw_rect(rect: Rect2, color: Color = Color.YELLOW, duration: float = 0.0, category: String = "", filled: bool = false, width: float = 2.0) -> void:
	display_layer.gizmos.add({"kind": "rect", "rect": rect, "color": color, "filled": filled, "width": width}, duration, category)


func draw_text(position: Vector2, text: String, color: Color = Color.WHITE, duration: float = 0.0, category: String = "") -> void:
	display_layer.gizmos.add({"kind": "text", "position": position, "text": text, "color": color}, duration, category)


## Grille de Core > Display > Grid pour la scène en cours (oubliée au
## changement de scène) : [param cell_size] taille d'une case en pixels du
## monde, [param bounds] cadre du niveau (son coin est l'origine de la
## grille ; Rect2() si inconnu), une ligne marquée toutes les
## [param major_every] cases.
func set_grid(cell_size: Vector2, bounds: Rect2 = Rect2(), major_every: int = 5) -> void:
	grid_overlay.set_game_grid(cell_size, bounds, major_every)


## Sélectionne [param object] (nœud, ressource...) : les fenêtres « objet »
## ouvertes le suivent.
func select(object: Object) -> void:
	selection.select(object)


## Sélectionne [param object] et ouvre l'Inspecteur.
func inspect(object: Object) -> void:
	selection.select(object)
	_open_window(INSPECTOR_KEY)


## Sélectionne [param node] et ouvre la fenêtre Physique.
func show_physics(node: Node) -> void:
	selection.select(node)
	_open_window(PHYSICS_KEY)


## Recharge la scène en cours, avec la graine fixe s'il y en a une, sinon
## une nouvelle graine (affichée dans « Snapshots and seed »).
func reload_scene() -> void:
	random_seed.apply_next()
	get_tree().reload_current_scene()


## Ajoute [param property] de [param node] à la fenêtre Watch (gardé d'une
## partie à l'autre) et ouvre la fenêtre.
func watch_variable(node: Node, property: String) -> void:
	watch.add(node, property)
	_open_window(WATCH_KEY)


# --- Fenêtres et barre ---

func _open_window(key: String) -> void:
	windows.open(key, key != SETTINGS_KEY, _store.favorites.has(key))


# Seule la barre se cache : le bloqueur du mode souris Debug et les fenêtres
# épinglées restent actifs.
func _set_menu_visible(value: bool) -> void:
	if value == bar.visible:
		return
	bar.visible = value
	if value:
		windows.restore()
	else:
		windows.hide_unpinned()


func _on_window_favorite_toggled(key: String, favorite: bool) -> void:
	_store.set_favorite(key, favorite)
	_store.save()
	_refresh_favorites()


func _refresh_favorites() -> void:
	bar.refresh_favorites(_store.favorites, windows.has_window)


# --- Raccourcis ---

# Une fenêtre de debug qui a le focus reçoit le clavier à la place de la
# barre : elle transmet donc aussi ses événements (signal window_input).
func _input(event: InputEvent) -> void:
	_handle_shortcuts(event)


func _handle_shortcuts(event: InputEvent) -> void:
	_touch_gesture.handle(event)
	if _capturing_shortcut or not event is InputEventKey:
		return
	var handled: bool = true
	if event.is_action_pressed(Shortcuts.TOGGLE):
		_set_menu_visible(not bar.visible)
	elif event.is_action_pressed(Shortcuts.PAUSE):
		playback.toggle_pause()
	elif event.is_action_pressed(Shortcuts.STEP):
		playback.step()
	elif event.is_action_pressed(Shortcuts.PIPETTE):
		selection.toggle_pipette()
	elif event.is_action_pressed(Shortcuts.SCREENSHOT):
		take_screenshot()
	elif event.is_action_pressed(Shortcuts.FREE_CAMERA):
		free_camera.toggle()
	elif event.is_action_pressed(Shortcuts.REC):
		if input_recorder.state == InputRecorder.State.IDLE:
			input_recorder.start_recording()
		else:
			input_recorder.stop()
	elif event.is_action_pressed(Shortcuts.CHEATS):
		_open_window(CHEATS_KEY)
	elif event.is_action_pressed(Shortcuts.NOCLIP):
		cheats.toggle_noclip()
	elif event.is_action_pressed(Shortcuts.INVINCIBLE):
		cheats.toggle_invincible()
	elif event.is_action_pressed(Shortcuts.FREEZE):
		cheats.toggle_freeze()
	else:
		handled = _handle_speed_shortcut(event)
	if handled:
		get_viewport().set_input_as_handled()


# Alt+1 à Alt+5 : vitesses de cheats/cheats.gd (SPEEDS).
func _handle_speed_shortcut(event: InputEvent) -> bool:
	for i in Shortcuts.SPEED_ACTIONS.size():
		if event.is_action_pressed(Shortcuts.SPEED_ACTIONS[i]):
			cheats.set_speed(Cheats.SPEEDS[i])
			return true
	return false


# --- Paramètres (appelés par settings/settings_window.gd) ---

func get_setting(setting_name: String) -> Variant:
	return _store.values[setting_name]


func set_setting(setting_name: String, value: Variant) -> void:
	_store.values[setting_name] = value
	ThemeBuilder.apply(_theme, _store.values)
	_store.save()


func get_mouse_mode() -> int:
	return _mouse_modes.mode


## Mode souris (windows/mouse_modes.gd), gardé d'une partie à l'autre.
func set_mouse_mode(mode: int) -> void:
	_mouse_modes.set_mode(mode)
	bar.show_mouse_mode(mode)
	_store.mouse_mode = mode
	_store.save()


func reset_settings() -> void:
	_store.reset_values()
	ThemeBuilder.apply(_theme, _store.values)
	_store.save()


func set_shortcut(action: String, event: InputEventKey) -> void:
	var data: Dictionary = Shortcuts.to_dict(event)
	Shortcuts.set_key(action, Shortcuts.make_event(data))
	_store.shortcuts[action] = data
	_store.save()


func reset_shortcut(action: String) -> void:
	Shortcuts.set_key(action, Shortcuts.default_event(action))
	_store.shortcuts.erase(action)
	_store.save()


## Pendant que les Paramètres attendent une touche, les raccourcis sont coupés.
func set_shortcut_capture(capturing: bool) -> void:
	_capturing_shortcut = capturing


# --- Session ---

func _save_session() -> void:
	_store.session_windows = windows.get_session()
	var selected: Object = selection.get_selected()
	_store.session_selection = String((selected as Node).get_path()) if selected is Node and (selected as Node).is_inside_tree() else ""
	_store.save()


# Fenêtres ouvertes à la dernière fermeture (cachées avec la barre, sauf les
# épinglées) et dernière sélection, si le nœud existe encore.
func _restore_session() -> void:
	for entry in _store.session_windows:
		if not entry is Dictionary or not entry.get("visible", false) or not windows.has_window(entry.get("key", "")):
			continue
		_open_window(entry["key"])
		windows.set_pinned(entry["key"], entry.get("pinned", false))
	if not bar.visible:
		windows.hide_unpinned()
	if _store.session_selection != "":
		var node: Node = get_tree().root.get_node_or_null(NodePath(_store.session_selection))
		if node != null:
			selection.select(node)
