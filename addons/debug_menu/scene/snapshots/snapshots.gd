extends Node

## Photos de la scène prises pendant la partie (DebugMenu.snapshots), en
## mémoire seulement : elles disparaissent à la fermeture du jeu. Les plus
## anciennes sont oubliées au-delà de MAX_SNAPSHOTS. Voir snapshot.gd.

signal changed

const Snapshot = preload("res://addons/debug_menu/scene/snapshots/snapshot.gd")
const T = preload("res://addons/debug_menu/i18n/t.gd")
const MAX_SNAPSHOTS: int = 10

## selection.gd : l'objet sélectionné est retrouvé dans la scène restaurée.
var selection: Node

var _list: Array[Snapshot] = []
var _taken: int = 0


## Photo de la scène en cours ([param snapshot_name] vide : « Snapshot n »).
## null s'il n'y a pas de scène.
func take(snapshot_name: String = "") -> Snapshot:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	_taken += 1
	var snapshot: Snapshot = Snapshot.new(scene, snapshot_name if snapshot_name != "" else T.t("Snapshot %d") % _taken)
	_list.append(snapshot)
	if _list.size() > MAX_SNAPSHOTS:
		_list.pop_front()
	changed.emit()
	return snapshot


## Remet la photo [param index] à la fin de l'image (pas au milieu d'un
## calcul de physique).
func restore(index: int) -> void:
	if index >= 0 and index < _list.size():
		_restore.call_deferred(_list[index])


func remove(index: int) -> void:
	if index >= 0 and index < _list.size():
		_list.remove_at(index)
		changed.emit()


func get_list() -> Array[Snapshot]:
	return _list


func _restore(snapshot: Snapshot) -> void:
	var tree: SceneTree = get_tree()
	var selected_path: String = ""
	var selected: Object = selection.call("get_selected") if selection != null else null
	if selected is Node and tree.current_scene != null and tree.current_scene.is_ancestor_of(selected):
		selected_path = String(tree.current_scene.get_path_to(selected))
	var scene: Node = snapshot.restore(tree)
	if selected_path != "":
		var node: Node = scene.get_node_or_null(NodePath(selected_path))
		if node != null:
			selection.call("select", node)
