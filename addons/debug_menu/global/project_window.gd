extends "res://addons/debug_menu/ui/debug_window.gd"

## Fenêtre Global > Project : réglages laissés par project_init, état du jeu
## en cours et liste des autoloads du projet (clic = sélectionner,
## double-clic = Inspecteur).

const GlobalMenu = preload("res://addons/debug_menu/global/global_menu.gd")
const SETTINGS: Array = [ # [réglage, libellé anglais]
	["application/config/name", "Name"],
	["application/run/main_scene", "Main scene"],
	["project_init/domains", "Domains"],
	["project_init/menus_domain", "Menus domain"],
	["project_init/game_domain", "Game domain"],
	["project_init/pause_action", "Pause action"],
	["project_init/version", "project_init version"],
]


func _build() -> void:
	add_section(T.t("Project"))
	for entry in SETTINGS:
		add_label("%s: %s" % [T.t(entry[1]), _setting_text(entry[0])])
	add_section(T.t("Running game"))
	add_live_label(func() -> String: return T.t("Current scene: %s") % _current_scene_text())
	add_live_label(func() -> String: return T.t("Paused: %s") % (T.t("yes") if get_tree().paused else T.t("no")))
	add_section(T.t("Managers (autoloads)"))
	add_node_list(_autoload_nodes)
	add_hint(T.t("Click: select. Double-click: open in the Inspector."))


func _setting_text(setting: String) -> String:
	var value: Variant = ProjectSettings.get_setting(setting, "")
	if value is PackedStringArray:
		return ", ".join(value)
	var text: String = str(value)
	return text if text != "" else "-"


func _current_scene_text() -> String:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return "-"
	return scene.scene_file_path if scene.scene_file_path != "" else String(scene.name)


func _autoload_nodes() -> Array:
	var nodes: Array = []
	for autoload_name in GlobalMenu.autoload_names():
		var node: Node = get_tree().root.get_node_or_null(NodePath(autoload_name))
		if node != null:
			nodes.append(node)
	return nodes
