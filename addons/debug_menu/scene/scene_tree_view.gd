extends Tree

## Arborescence vivante du jeu : Nom | Type | Ordre | État.
## - « Arbre de la scène » : les nœuds chargés, dans leur hiérarchie ;
## - « Hors de l'arbre » : retirés de l'arbre mais encore en mémoire.
## « Ordre » est l'ordre d'arrivée dans l'arbre (node_recorder.gd).
## Reconstruit seulement quand l'enregistreur signale un changement (ou sur
## demande) ; les branches repliées sont conservées (par chemin) et la ligne
## de l'objet sélectionné est surlignée.
## Clic = sélectionner, double-clic = Inspecteur (ui/node_actions.gd).

const NodeRecorder = preload("res://addons/debug_menu/scene/node_recorder.gd")
const NodeActions = preload("res://addons/debug_menu/ui/node_actions.gd")
const T = preload("res://addons/debug_menu/i18n/t.gd")
const Tokens = preload("res://addons/debug_menu/settings/design_tokens.gd")
static var QUEUED_COLOR: Color = Tokens.color("bad") # libération demandée (queue_free)
static var OUTSIDE_COLOR: Color = Tokens.color("info")

var recorder: NodeRecorder
## Objet sélectionné dans le debug menu : sa ligne est surlignée.
var selected_object: Object = null
var _collapsed: Dictionary = {} # chemin -> true
var _built_revision: int = -1
var _rebuilding: bool = false # surligner la sélection ne doit pas la renvoyer


func _init() -> void:
	columns = 4
	column_titles_visible = true
	hide_root = true
	select_mode = Tree.SELECT_ROW
	focus_mode = Control.FOCUS_NONE
	set_column_title(0, T.t("Name"))
	set_column_title(1, T.t("Type"))
	set_column_title(2, T.t("Order"))
	set_column_title(3, T.t("State"))
	set_column_expand_ratio(0, 3)
	set_column_expand_ratio(1, 2)
	set_column_expand_ratio(2, 1)
	set_column_expand_ratio(3, 2)
	item_collapsed.connect(_on_item_collapsed)
	item_selected.connect(_on_item_selected)
	item_activated.connect(_on_item_activated)


## Reconstruit si quelque chose a changé depuis la dernière fois (ou
## toujours, avec [param force]).
func refresh(force: bool = false) -> void:
	if recorder == null or (recorder.revision == _built_revision and not force):
		return
	_built_revision = recorder.revision
	_rebuilding = true
	clear()
	var root: TreeItem = create_item()

	var scene_root: TreeItem = _add_group(root, T.t("Scene tree"))
	for child in get_tree().root.get_children():
		if not recorder.is_ignored(child):
			_add_node(scene_root, child)

	var outside: Array[Dictionary] = recorder.get_outside_nodes()
	var outside_root: TreeItem = _add_group(root, T.t("Outside the tree, in memory (%d)") % outside.size())
	for entry in outside:
		var node: Node = entry["node"]
		var item: TreeItem = _add_item(outside_root, node, T.t("outside the tree"), OUTSIDE_COLOR)
		item.set_tooltip_text(0, T.t("Removed from: %s") % String(entry["event"]["path"]))
	_rebuilding = false


func _add_group(parent: TreeItem, title: String) -> TreeItem:
	var item: TreeItem = create_item(parent)
	item.set_text(0, title)
	item.set_metadata(0, "#" + title)
	item.set_selectable(0, false)
	return item


func _add_node(parent: TreeItem, node: Node) -> void:
	var queued: bool = node.is_queued_for_deletion()
	var item: TreeItem = _add_item(parent, node, T.t("free requested") if queued else T.t("loaded"), QUEUED_COLOR if queued else Color(0, 0, 0, 0))
	item.collapsed = _collapsed.has(String(node.get_path()))
	for child in node.get_children():
		if not recorder.is_ignored(child):
			_add_node(item, child)


func _add_item(parent: TreeItem, node: Node, state: String, color: Color) -> TreeItem:
	var item: TreeItem = create_item(parent)
	item.set_text(0, node.name)
	item.set_text(1, node.get_class())
	var order: int = recorder.get_order(node)
	item.set_text(2, str(order) if order >= 0 else "")
	item.set_text(3, state)
	if color.a > 0.0:
		for column in columns:
			item.set_custom_color(column, color)
	item.set_metadata(0, String(node.get_path()) if node.is_inside_tree() else "")
	item.set_metadata(1, node.get_instance_id())
	if node == selected_object:
		item.select(0)
	return item


func _on_item_collapsed(item: TreeItem) -> void:
	var path: String = item.get_metadata(0)
	if item.collapsed:
		_collapsed[path] = true
	else:
		_collapsed.erase(path)


func _on_item_selected() -> void:
	if not _rebuilding:
		NodeActions.select(get_tree(), _item_node(get_selected()))


func _on_item_activated() -> void:
	NodeActions.inspect(get_tree(), _item_node(get_selected()))


func _item_node(item: TreeItem) -> Object:
	if item == null or item.get_metadata(1) == null:
		return null
	return instance_from_id(item.get_metadata(1))
