extends RefCounted

## Variables suivies dans la fenêtre Watch (DebugMenu.watch) : chemin du nœud
## + nom de la variable, gardés d'une partie à l'autre (settings_store.gd)
## jusqu'à ce qu'on les retire (× ou Clear). Le nœud est retrouvé par son
## chemin : une variable d'un objet déchargé n'est pas affichée, et revient
## quand l'objet est rechargé.

signal changed

var _store: RefCounted # settings_store.gd


func _init(store: RefCounted) -> void:
	_store = store


## [{path: String, property: String}], dans l'ordre d'ajout.
func get_entries() -> Array:
	return _store.get("watch_entries")


func has(node: Node, property: String) -> bool:
	return _find(String(node.get_path()), property) != -1


func add(node: Node, property: String) -> void:
	if not node.is_inside_tree() or has(node, property):
		return
	get_entries().append({"path": String(node.get_path()), "property": property})
	_save()


func remove(path: String, property: String) -> void:
	var index: int = _find(path, property)
	if index != -1:
		get_entries().remove_at(index)
		_save()


func clear() -> void:
	get_entries().clear()
	_save()


## Le nœud visé par [param entry], ou null s'il n'est pas chargé.
static func resolve(tree: SceneTree, entry: Dictionary) -> Node:
	return tree.root.get_node_or_null(NodePath(entry["path"]))


func _find(path: String, property: String) -> int:
	var entries: Array = get_entries()
	for index in entries.size():
		if entries[index]["path"] == path and entries[index]["property"] == property:
			return index
	return -1


func _save() -> void:
	_store.call("save")
	changed.emit()
