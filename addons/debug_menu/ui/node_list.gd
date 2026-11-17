extends ItemList

## Liste de nœuds qui se met à jour toute seule (debug_window.gd,
## add_node_list). [member getter] () -> Array de nœuds est rappelé toutes
## les REFRESH_INTERVAL secondes ; la liste n'est refaite que si son contenu
## a changé (la sélection reste en place).
## Règle commune à tout le debug menu : clic = sélectionner le nœud,
## double-clic = l'ouvrir dans l'Inspecteur.

const NodeActions = preload("res://addons/debug_menu/ui/node_actions.gd")
const T = preload("res://addons/debug_menu/i18n/t.gd")
const REFRESH_INTERVAL: float = 0.5

var getter: Callable
var _shown_ids: Array[int] = []
var _refresh_time: float = 0.0


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	item_selected.connect(_on_item_selected)
	item_activated.connect(_on_item_activated)


func _ready() -> void:
	refresh()


func _process(delta: float) -> void:
	_refresh_time += delta
	if _refresh_time >= REFRESH_INTERVAL and is_visible_in_tree():
		_refresh_time = 0.0
		refresh()


func refresh() -> void:
	if not getter.is_valid():
		return
	var nodes: Array = getter.call()
	var ids: Array[int] = []
	for node in nodes:
		ids.append((node as Node).get_instance_id())
	if ids == _shown_ids:
		return
	_shown_ids = ids
	clear()
	for node in nodes:
		add_item("%s   (%s)" % [node.name, node.get_class()])
		set_item_tooltip(item_count - 1, String(node.get_path()) if node.is_inside_tree() else "")
		set_item_metadata(item_count - 1, node)
	if item_count == 0:
		add_item(T.t("none"))
		set_item_disabled(0, true)


func _on_item_selected(index: int) -> void:
	NodeActions.select(get_tree(), get_item_metadata(index))


func _on_item_activated(index: int) -> void:
	NodeActions.inspect(get_tree(), get_item_metadata(index))
