extends RefCounted

## Une photo de la scène en cours, gardée en mémoire (pas sur disque) :
## - une copie des nœuds (Node.duplicate) avec leurs propriétés enregistrables
##   (position, vitesse, variables @export...), nœuds créés en jeu compris ;
## - les variables de script de chaque nœud, que la copie ne garde pas ; une
##   variable qui vise un nœud de la scène est retrouvée par son chemin.
## Restaurer remplace la scène en cours par une nouvelle copie : les _ready()
## sont rappelés, puis les variables remises.
## Limites : autoloads, Timer (temps restant), Tween, AnimationPlayer
## (position de lecture), état interne de la physique et hasard ne sont pas
## gardés ; une ressource modifiée en jeu est partagée, donc pas remise ;
## un nœud qui crée des enfants dans _ready() les recrée.

const FLAGS: int = Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS
const NODE_KEY: String = "__debug_menu_node" # {NODE_KEY: chemin} : variable qui vise un nœud de la scène

var snapshot_name: String
var date_text: String
var scene_path: String
var node_count: int = 0

var _copy: Node
var _values: Dictionary = {} # chemin depuis la racine -> {variable: valeur}


func _init(scene: Node, given_name: String) -> void:
	snapshot_name = given_name
	date_text = Time.get_time_string_from_system()
	scene_path = scene.scene_file_path
	_copy = scene.duplicate(FLAGS)
	_capture_values(scene, scene)


func _notification(what: int) -> void:
	# La copie est hors de l'arbre : personne d'autre ne la libère.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_copy):
		_copy.free()


## Remplace la scène en cours par la photo (à appeler hors d'un calcul de
## physique : DebugMenu passe par call_deferred). Renvoie la nouvelle scène.
func restore(tree: SceneTree) -> Node:
	var scene: Node = _copy.duplicate(FLAGS)
	scene.scene_file_path = scene_path # pour REC et le rechargement
	var old: Node = tree.current_scene
	if old != null:
		tree.root.remove_child(old)
		old.queue_free()
	tree.root.add_child(scene) # _ready() ici
	tree.current_scene = scene
	for path in _values:
		var node: Node = scene.get_node_or_null(NodePath(path))
		if node == null:
			continue
		var variables: Dictionary = _values[path]
		for variable in variables:
			node.set(variable, _load_value(variables[variable], scene))
	return scene


# --- Variables de script ---

func _capture_values(scene: Node, node: Node) -> void:
	node_count += 1
	var variables: Dictionary = {}
	for property in node.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			variables[property["name"]] = _store_value(node.get(property["name"]), scene)
	if not variables.is_empty():
		_values[String(scene.get_path_to(node))] = variables
	for child in node.get_children():
		_capture_values(scene, child)


static func _store_value(value: Variant, scene: Node) -> Variant:
	if typeof(value) == TYPE_OBJECT:
		if is_instance_valid(value) and value is Node and (value == scene or scene.is_ancestor_of(value)):
			return {NODE_KEY: String(scene.get_path_to(value))}
		return value # ressource, autoload... : la même référence
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	return value


static func _load_value(value: Variant, scene: Node) -> Variant:
	if value is Dictionary and value.size() == 1 and value.has(NODE_KEY):
		return scene.get_node_or_null(NodePath(value[NODE_KEY]))
	if value is Array or value is Dictionary:
		return value.duplicate(true) # la photo reste intacte pour la prochaine fois
	return value
