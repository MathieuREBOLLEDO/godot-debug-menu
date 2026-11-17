extends PanelContainer

## La barre du haut (nœud Bar de debug_menu.tscn).
##   écran large  : [Core] [★ Favoris] [Objects] [Scene] [Global] [QA] [menus du jeu]   …   [● REC] [🖱 Souris] [⚙]
##   écran étroit : [Core] [‹ Objects ›] [menus du jeu ▾]   …   [● REC] [⚙]
## Core et les menus du jeu restent collés à gauche, REC et ⚙ à droite.
## Quand tout ne tient plus sur une ligne, les autres menus se replient en
## un seul avec ‹ › (menu_switcher.gd) et le mode souris passe dans le
## premier menu du jeu (ou dans Core s'il n'y en a pas).
## Menus du jeu : celui nommé comme le projet, et ceux déclarés par
## DebugMenu.set_game_menu().
## Elle construit et tient à jour ses menus ; ouvrir une fenêtre est demandé
## à DebugMenu par le signal window_requested.
## Un menu peut avoir des sous-menus : « Core/Time » est le sous-menu Time
## du menu Core (créé à la demande, ouvert au survol par Godot).
## Morceaux : hover_menus.gd (survol), menu_toggles.gd (cases),
## rec_button.gd, menu_switcher.gd.

signal window_requested(key: String)
signal action_requested(key: String)
signal settings_requested
## Mode souris choisi dans la barre (windows/mouse_modes.gd).
signal mouse_mode_requested(mode: int)

const ThemeBuilder = preload("res://addons/debug_menu/settings/debug_menu_theme.gd")
const HoverMenus = preload("res://addons/debug_menu/bar/hover_menus.gd")
const MenuToggles = preload("res://addons/debug_menu/bar/menu_toggles.gd")
const RecButton = preload("res://addons/debug_menu/bar/rec_button.gd")
const MouseModes = preload("res://addons/debug_menu/windows/mouse_modes.gd")
const T = preload("res://addons/debug_menu/i18n/t.gd")
# Métadonnée d'une entrée d'action dans un PopupMenu (une fenêtre : sa clé seule).
const ACTION_PREFIX: String = "action:"
# Entrées du mode souris rangées dans un menu (écran étroit) : « mouse:<mode> ».
const MOUSE_PREFIX: String = "mouse:"
const MOUSE_SECTION: String = "mouse:section"
# Menu toujours visible à gauche (DebugMenu.CORE_MENU).
const CORE_MENU: String = "Core"

## Écran étroit : menus repliés, mode souris dans le menu du jeu.
var compact: bool = false

var _hover_menus: HoverMenus
var _toggles: MenuToggles
var _rec_button: RecButton
var _mouse_mode: int = MouseModes.Mode.BOTH
var _game_menu_names: Array[String] = []
var _layout_queued: bool = false

@onready var row: HBoxContainer = $Row
@onready var core_menus: HBoxContainer = $Row/CoreMenus
@onready var switcher: HBoxContainer = $Row/Switcher
@onready var favorites_menu: MenuButton = $Row/Switcher/FavoritesMenu
@onready var menus: HBoxContainer = $Row/Switcher/Menus
@onready var game_menus: HBoxContainer = $Row/GameMenus
@onready var mouse_mode_button: Button = $Row/MouseModeButton
@onready var settings_button: Button = $Row/SettingsButton


## À appeler une fois, depuis DebugMenu._ready().
func setup(store: RefCounted, recorder: Node) -> void:
	_hover_menus = HoverMenus.new(self, _get_menu_buttons)
	_toggles = MenuToggles.new(store)
	_setup_menu_button(favorites_menu)
	_game_menu_names.append(String(ProjectSettings.get_setting("application/config/name", "")))

	_rec_button = RecButton.new()
	_rec_button.recorder = recorder
	_rec_button.theme_type_variation = ThemeBuilder.BAR_BUTTON
	row.add_child(_rec_button)
	row.move_child(_rec_button, mouse_mode_button.get_index())

	mouse_mode_button.theme_type_variation = ThemeBuilder.BAR_BUTTON
	mouse_mode_button.pressed.connect(func() -> void:
		mouse_mode_requested.emit(posmod(_mouse_mode + 1, MouseModes.NAMES.size()))
	)
	settings_button.theme_type_variation = ThemeBuilder.BAR_BUTTON
	settings_button.pressed.connect(settings_requested.emit)
	retranslate()


func _process(delta: float) -> void:
	if not visible or _hover_menus == null:
		return
	_hover_menus.update(delta)
	# La place change avec la fenêtre : vérifiée à chaque frame (quelques
	# tailles minimales), la barre n'est refaite que si le mode change.
	if (_wide_width() > _available_width()) != compact:
		_queue_layout()


## Crée le menu [param menu] s'il n'existe pas (les menus gardent leur
## ordre de création). [param menu] est son nom en anglais ; le texte
## affiché est traduit.
func get_or_create_menu(menu: String) -> MenuButton:
	for menu_button in _get_menu_buttons():
		if menu_button.get_meta(&"menu_key", "") == menu:
			return menu_button
	var new_menu: MenuButton = MenuButton.new()
	new_menu.set_meta(&"menu_key", menu)
	new_menu.text = T.t(menu)
	_container_for(menu).add_child(new_menu)
	_setup_menu_button(new_menu)
	_queue_layout()
	return new_menu


## Range le menu [param menu] avec les menus du jeu (collés à gauche, jamais
## repliés), qu'il existe déjà ou non.
func set_game_menu(menu: String) -> void:
	if not _game_menu_names.has(menu):
		_game_menu_names.append(menu)
	for child in menus.get_children():
		if child.get_meta(&"menu_key", "") == menu:
			child.reparent(game_menus)
	_queue_layout()


## Liste déroulante du menu ou sous-menu [param menu] (« Core » ou
## « Core/Display/Physics »), créée avec ses parents si besoin.
func get_popup(menu: String) -> PopupMenu:
	var parts: PackedStringArray = menu.split("/")
	var popup: PopupMenu = get_or_create_menu(parts[0]).get_popup()
	var path: String = parts[0]
	for index in range(1, parts.size()):
		path += "/" + parts[index]
		popup = _get_or_create_submenu(popup, path, parts[index])
	return popup


## Entrée qui ouvre la fenêtre [param key].
func add_window_entry(menu: String, entry: String, key: String) -> void:
	_add_item(get_popup(menu), T.t(entry), key)


## Entrée qui déclenche l'action [param key] (DebugMenu.add_action).
func add_action_entry(menu: String, entry: String, key: String) -> void:
	_add_item(get_popup(menu), T.t(entry), ACTION_PREFIX + key)


## Entrée à cocher (voir menu_toggles.gd).
func add_toggle(menu: String, entry: String, getter: Callable, setter: Callable) -> void:
	_toggles.add(get_popup(menu), menu + "/" + entry, T.t(entry), getter, setter)


## Retire tous les menus (avant de les refaire dans une autre langue).
func clear_menus() -> void:
	for container in [core_menus, menus, game_menus]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	_queue_layout()


## Textes fixes de la barre, dans la langue en cours.
func retranslate() -> void:
	favorites_menu.text = T.t("Favorites")
	settings_button.tooltip_text = T.t("Settings")
	switcher.call("retranslate")
	show_mouse_mode(_mouse_mode)


## Montre le mode souris [param mode] (bouton, ou entrées du menu du jeu).
func show_mouse_mode(mode: int) -> void:
	_mouse_mode = mode
	mouse_mode_button.text = T.t(MouseModes.NAMES[mode])
	mouse_mode_button.tooltip_text = T.t(MouseModes.TOOLTIPS[mode])
	_queue_layout()


## Menu Favoris : les clés de [param keys] qui ont une fenêtre
## ([param has_window] (clé) -> bool). Caché s'il est vide.
func refresh_favorites(keys: Array[String], has_window: Callable) -> void:
	var popup: PopupMenu = favorites_menu.get_popup()
	popup.clear()
	for key in keys:
		if not has_window.call(key):
			continue
		if popup.item_count > 0:
			popup.add_separator()
		var label: PackedStringArray = PackedStringArray()
		for part in key.split("/"):
			label.append(T.t(part))
		popup.add_item(" › ".join(label))
		popup.set_item_metadata(popup.item_count - 1, key)
	_queue_layout()


# --- Disposition (écran large ou étroit) ---

# Une seule mise en page par frame, même si plusieurs menus changent.
func _queue_layout() -> void:
	if _layout_queued or not is_inside_tree():
		return
	_layout_queued = true
	_update_layout.call_deferred()


func _update_layout() -> void:
	_layout_queued = false
	compact = _wide_width() > _available_width()
	switcher.call("set_compact", compact)
	mouse_mode_button.visible = not compact
	_place_mouse_entries()


# Largeur de la barre en écran large (tous les menus, bouton souris), que
# les éléments soient affichés ou non.
func _wide_width() -> float:
	if _rec_button == null:
		return 0.0
	var widths: Array[float] = [
		core_menus.get_combined_minimum_size().x,
		switcher.call("wide_width"),
		game_menus.get_combined_minimum_size().x,
		0.0, # espace libre du milieu
		_rec_button.get_combined_minimum_size().x,
		mouse_mode_button.get_combined_minimum_size().x,
		settings_button.get_combined_minimum_size().x,
	]
	var width: float = 0.0
	for value in widths:
		width += value
	return width + float(row.get_theme_constant("separation")) * (widths.size() - 1)


# Place pour la ligne : largeur de l'écran moins les marges du panneau de
# la barre (pas sa taille actuelle, qui déborde quand rien ne tient).
func _available_width() -> float:
	return get_viewport_rect().size.x - get_theme_stylebox("panel").get_minimum_size().x


# Écran étroit : le mode souris dans le premier menu du jeu (sinon Core),
# en bas, en boutons radio. Les anciennes entrées sont retirées d'abord.
func _place_mouse_entries() -> void:
	for menu_button in _get_menu_buttons():
		_remove_mouse_entries(menu_button.get_popup())
	if not compact:
		return
	var target: MenuButton = null
	if game_menus.get_child_count() > 0:
		target = game_menus.get_child(0) as MenuButton
	elif core_menus.get_child_count() > 0:
		target = core_menus.get_child(0) as MenuButton
	if target == null:
		return
	var popup: PopupMenu = target.get_popup()
	popup.add_separator(T.t("Mouse"))
	popup.set_item_metadata(popup.item_count - 1, MOUSE_SECTION)
	for mode in MouseModes.NAMES.size():
		popup.add_radio_check_item(T.t(MouseModes.NAMES[mode]))
		var index: int = popup.item_count - 1
		popup.set_item_metadata(index, MOUSE_PREFIX + str(mode))
		popup.set_item_checked(index, mode == _mouse_mode)
		popup.set_item_tooltip(index, T.t(MouseModes.TOOLTIPS[mode]))


static func _remove_mouse_entries(popup: PopupMenu) -> void:
	for index in range(popup.item_count - 1, -1, -1):
		var metadata: Variant = popup.get_item_metadata(index)
		if metadata != null and String(metadata).begins_with(MOUSE_PREFIX):
			popup.remove_item(index)


# --- Interne ---

func _setup_menu_button(menu_button: MenuButton) -> void:
	_hover_menus.watch(menu_button)
	_connect_popup(menu_button.get_popup())


func _connect_popup(popup: PopupMenu) -> void:
	popup.index_pressed.connect(func(index: int) -> void:
		var metadata: Variant = popup.get_item_metadata(index)
		if metadata == null: # entrée de sous-menu
			return
		var key: String = String(metadata)
		if _toggles.is_toggle(metadata):
			_toggles.press(popup, index)
		elif key.begins_with(MOUSE_PREFIX):
			if key != MOUSE_SECTION:
				mouse_mode_requested.emit(int(key.trim_prefix(MOUSE_PREFIX)))
		elif key.begins_with(ACTION_PREFIX):
			action_requested.emit(key.trim_prefix(ACTION_PREFIX))
		else:
			window_requested.emit(metadata)
	)


# Un trait fin entre deux entrées pour bien les délimiter.
func _add_item(popup: PopupMenu, text: String, metadata: String) -> void:
	if popup.item_count > 0:
		popup.add_separator()
	popup.add_item(text)
	popup.set_item_metadata(popup.item_count - 1, metadata)
	_queue_layout() # les entrées souris restent en bas


# Sous-menu [param path] de [param parent] : un PopupMenu enfant, relié à
# une entrée « texte ▸ » (add_submenu_item, compatible Godot 4.0).
func _get_or_create_submenu(parent: PopupMenu, path: String, text: String) -> PopupMenu:
	for child in parent.get_children():
		if child is PopupMenu and child.get_meta(&"menu_key", "") == path:
			return child
	var submenu: PopupMenu = PopupMenu.new()
	submenu.name = "Submenu%d" % parent.get_child_count()
	submenu.set_meta(&"menu_key", path)
	parent.add_child(submenu)
	if parent.item_count > 0:
		parent.add_separator()
	parent.add_submenu_item(T.t(text), submenu.name)
	_connect_popup(submenu)
	return submenu


# Core à gauche, les menus du jeu juste après les menus repliables, les
# autres dans les menus repliables.
func _container_for(menu: String) -> HBoxContainer:
	if menu == CORE_MENU:
		return core_menus
	if _game_menu_names.has(menu):
		return game_menus
	return menus


func _get_menu_buttons() -> Array[MenuButton]:
	var buttons: Array[MenuButton] = [favorites_menu]
	for container in [core_menus, menus, game_menus]:
		for child in container.get_children():
			var menu_button: MenuButton = child as MenuButton
			if menu_button != null:
				buttons.append(menu_button)
	return buttons
