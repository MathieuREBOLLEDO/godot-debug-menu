extends Node

## Enregistre la vie des nœuds du jeu dès le lancement (enfant de DebugMenu,
## pour ne rien rater avant l'ouverture de la fenêtre Mémoire) :
## - ordre d'arrivée de chaque nœud dans l'arbre ;
## - événements : présent au démarrage, ajouté, retiré, libéré ;
## - nœuds retirés de l'arbre mais encore en mémoire (« hors de l'arbre »).
## Une libération est constatée au plus tard FREE_CHECK_INTERVAL après.
## Les nœuds du debug menu sont ignorés.

signal changed

enum Kind { PRESENT, ADDED, REMOVED, FREED }

const KIND_NAMES: Array[String] = ["present", "added", "removed", "freed"] # anglais, traduits à l'affichage
const MAX_EVENTS: int = 3000 # les plus anciens sont oubliés au-delà
const FREE_CHECK_INTERVAL: float = 0.25

## Du plus ancien au plus récent : {time, kind, name, class, path, order, id}.
var events: Array[Dictionary] = []
## Incrémenté à chaque changement (les vues ne se reconstruisent que s'il bouge).
var revision: int = 0

var _order: Dictionary = {} # id d'instance -> ordre d'arrivée
var _next_order: int = 0
var _outside: Dictionary = {} # id d'instance -> {ref: WeakRef, event} : retirés, encore en mémoire
var _check_time: float = 0.0
var _ignored_root: Node # le debug menu


func _ready() -> void:
	_ignored_root = get_parent()
	_register_existing(get_tree().root)
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)


func _process(delta: float) -> void:
	_check_time += delta
	if _check_time < FREE_CHECK_INTERVAL:
		return
	_check_time = 0.0
	for id in _outside.keys():
		var entry: Dictionary = _outside[id]
		var ref: WeakRef = entry["ref"]
		if ref.get_ref() == null:
			_outside.erase(id)
			_order.erase(id)
			var removed: Dictionary = entry["event"]
			_add_event(Kind.FREED, removed["name"], removed["class"], removed["path"], removed["order"], id)


## Ordre d'arrivée de [param node] dans l'arbre (-1 si inconnu).
func get_order(node: Node) -> int:
	return _order.get(node.get_instance_id(), -1)


## Nœuds retirés de l'arbre mais pas libérés, avec leur événement de retrait.
func get_outside_nodes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in _outside:
		var entry: Dictionary = _outside[id]
		var node: Node = (entry["ref"] as WeakRef).get_ref() as Node
		if node != null:
			result.append({"node": node, "event": entry["event"]})
	return result


func is_ignored(node: Node) -> bool:
	return node == _ignored_root or _ignored_root.is_ancestor_of(node)


func _register_existing(node: Node) -> void:
	for child in node.get_children():
		if is_ignored(child):
			continue
		_order[child.get_instance_id()] = _next_order
		_next_order += 1
		_add_event(Kind.PRESENT, child.name, child.get_class(), String(child.get_path()), _order[child.get_instance_id()], child.get_instance_id())
		_register_existing(child)


func _on_node_added(node: Node) -> void:
	if is_ignored(node):
		return
	var id: int = node.get_instance_id()
	_outside.erase(id) # remis dans l'arbre (déplacé ailleurs, par exemple)
	if not _order.has(id):
		_order[id] = _next_order
		_next_order += 1
	_add_event(Kind.ADDED, node.name, node.get_class(), String(node.get_path()), _order[id], id)


func _on_node_removed(node: Node) -> void:
	if is_ignored(node):
		return
	var id: int = node.get_instance_id()
	var event: Dictionary = _add_event(Kind.REMOVED, node.name, node.get_class(), String(node.get_path()), _order.get(id, -1), id)
	_outside[id] = {"ref": weakref(node), "event": event}


func _add_event(kind: int, node_name: String, class_text: String, path: String, order: int, id: int) -> Dictionary:
	var event: Dictionary = {
		"time": Time.get_ticks_msec() / 1000.0,
		"kind": kind,
		"name": node_name,
		"class": class_text,
		"path": path,
		"order": order,
		"id": id,
	}
	events.append(event)
	if events.size() > MAX_EVENTS:
		events.pop_front()
	revision += 1
	changed.emit()
	return event
