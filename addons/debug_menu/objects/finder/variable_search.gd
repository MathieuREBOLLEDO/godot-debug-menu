extends RefCounted

## Recherche de variables dans les objets chargés (fenêtre Variable finder).
## Parcourt l'arbre (sans le debug menu) et garde les variables dont le nom
## contient le texte, ou aussi la valeur (texte court de value_format.gd).
## Texte vide : toutes les variables des objets retenus.
## Faite à la demande (pas à chaque image) et limitée à MAX_RESULTS.

const ValueFormat = preload("res://addons/debug_menu/ui/value_format.gd")
const MAX_RESULTS: int = 200
const DEBUG_MENU_PATH: NodePath = ^"/root/DebugMenu"

## Objets retenus.
enum Scope { ACTIVE, INACTIVE, ALL, SELECTION }
## Textes en anglais (traduits à l'affichage), dans l'ordre de Scope.
const SCOPE_NAMES: Array[String] = ["Active objects", "Inactive objects", "All objects", "Selection and children"]


## [{node, property}] ; [param selected] : le nœud de départ pour Scope.SELECTION.
static func search(tree: SceneTree, text: String, scope: int, in_values: bool, include_engine: bool, selected: Node) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var start: Node = selected if scope == Scope.SELECTION else tree.root
	if start == null:
		return results
	_search_node(start, text.strip_edges().to_lower(), scope, in_values, include_engine,
			tree.root.get_node_or_null(DEBUG_MENU_PATH), results)
	return results


## Un objet actif : pas désactivé (process_mode, lui ou un parent) et, s'il
## s'affiche, visible. La pause du jeu n'en fait pas un objet inactif.
static func is_active(node: Node) -> bool:
	if not node.is_inside_tree() or _is_disabled(node):
		return false
	if node is CanvasItem:
		return (node as CanvasItem).is_visible_in_tree()
	if node is Node3D:
		return (node as Node3D).is_visible_in_tree()
	return true


static func _search_node(node: Node, text: String, scope: int, in_values: bool, include_engine: bool, debug_menu: Node, results: Array[Dictionary]) -> void:
	if results.size() >= MAX_RESULTS or node == debug_menu:
		return
	if _in_scope(node, scope):
		for property in node.get_property_list():
			if not _is_listed(property, include_engine):
				continue
			var property_name: String = property["name"]
			if text == "" or property_name.to_lower().contains(text) \
					or (in_values and ValueFormat.text(node.get(property_name)).to_lower().contains(text)):
				results.append({"node": node, "property": property_name})
				if results.size() >= MAX_RESULTS:
					return
	for child in node.get_children():
		_search_node(child, text, scope, in_values, include_engine, debug_menu, results)


# PROCESS_MODE_DISABLED sur le nœud, ou hérité d'un parent.
static func _is_disabled(node: Node) -> bool:
	while node != null:
		if node.process_mode == Node.PROCESS_MODE_DISABLED:
			return true
		if node.process_mode != Node.PROCESS_MODE_INHERIT:
			return false
		node = node.get_parent()
	return false


static func _in_scope(node: Node, scope: int) -> bool:
	match scope:
		Scope.ACTIVE:
			return is_active(node)
		Scope.INACTIVE:
			return not is_active(node)
	return true


# Variables du script ; avec [param include_engine], aussi les propriétés de
# Godot visibles dans l'inspecteur de l'éditeur.
static func _is_listed(property: Dictionary, include_engine: bool) -> bool:
	var usage: int = property["usage"]
	if usage & (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP | PROPERTY_USAGE_CATEGORY):
		return false
	return (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 or (include_engine and (usage & PROPERTY_USAGE_EDITOR) != 0)
