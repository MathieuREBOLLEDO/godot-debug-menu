extends Node

## Menu « Global » (service GlobalMenu, enfant de DebugMenu) : seulement dans
## un projet initialisé par l'addon project_init, qui laisse le réglage
## project_init/version dans project.godot. Sans ce réglage, debug_menu.gd ne
## charge même pas ce fichier.
## Aucune dépendance aux fichiers du projet : le menu lit les réglages
## project_init/* et la liste des autoloads.
## Contenu : la fenêtre Project, puis une entrée par autoload du projet
## (GameManager, AudioManager...) qui l'ouvre dans l'Inspecteur.

const MARKER: String = "project_init/version"
const MENU: String = "Global"
const PROJECT_WINDOW: String = "res://addons/debug_menu/global/project_window.tscn"
const SELF_AUTOLOAD: String = "DebugMenu"

var _debug_menu: Node


## Vrai si le projet a été initialisé par project_init.
static func is_project_initialized() -> bool:
	return ProjectSettings.has_setting(MARKER)


## Noms des autoloads du projet (sauf DebugMenu), dans l'ordre de project.godot.
static func autoload_names() -> Array[String]:
	var names: Array[String] = []
	for property in ProjectSettings.get_property_list():
		var setting: String = property["name"]
		if setting.begins_with("autoload/"):
			var autoload_name: String = setting.trim_prefix("autoload/")
			if autoload_name != SELF_AUTOLOAD:
				names.append(autoload_name)
	return names


## Ajoute le menu Global à [param debug_menu].
func register(debug_menu: Node) -> void:
	_debug_menu = debug_menu
	debug_menu.add_entry(MENU, "Project", load(PROJECT_WINDOW))
	for autoload_name in autoload_names():
		debug_menu.add_action(MENU, autoload_name, inspect_autoload.bind(autoload_name))


## Ouvre l'autoload [param autoload_name] dans l'Inspecteur. Il est cherché au
## clic : les autoloads placés après DebugMenu n'existent pas encore quand le
## menu est créé.
func inspect_autoload(autoload_name: String) -> void:
	var node: Node = get_tree().root.get_node_or_null(NodePath(autoload_name))
	if node != null:
		_debug_menu.inspect(node)
