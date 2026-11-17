extends RefCounted

## Règle de clic commune à toutes les listes et tous les arbres de nœuds du
## debug menu : clic = sélectionner, double-clic = ouvrir dans l'Inspecteur.
## Ne fait rien si le nœud a été libéré ou si l'addon est inactif.

const DEBUG_MENU_PATH: NodePath = ^"/root/DebugMenu"


static func select(tree: SceneTree, node: Variant) -> void:
	_call(tree, "select", node)


static func inspect(tree: SceneTree, node: Variant) -> void:
	_call(tree, "inspect", node)


static func _call(tree: SceneTree, method: String, node: Variant) -> void:
	var debug_menu: Node = tree.root.get_node_or_null(DEBUG_MENU_PATH)
	if is_instance_valid(node) and debug_menu != null:
		debug_menu.call(method, node)
