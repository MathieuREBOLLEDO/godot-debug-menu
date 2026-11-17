extends "res://addons/debug_menu/ui/debug_window.gd"

## Fenêtre « Physique » : suit l'objet sélectionné (selection/selection.gd) et
## affiche le corps physique qui lui est lié (lui-même, son parent ou un
## enfant, voir physics_target.gd) :
## - ses couches, son mouvement, ses formes (physics_body_view.gd), ce qu'il
##   touche maintenant et ce qu'il peut toucher (son masque) ;
## - par couche : tous les objets d'une couche de collision ;
## - surlignage dans le jeu des objets de chaque liste.
## Les dessins du corps (formes, centre, vitesse, trajectoire, contacts) se
## cochent dans le menu Affichage ; ils sont faits par le calque commun
## (display/display_layer.gd), même fenêtre fermée.
## Barre de sélection en haut ; dans les listes, clic = sélectionner,
## double-clic = Inspecteur.
## Morceaux : physics_target.gd, physics_body_view.gd, physics_query.gd,
## physics_info.gd, physics_overlay.gd.

const PhysicsTarget = preload("res://addons/debug_menu/objects/physics/physics_target.gd")
const PhysicsInfo = preload("res://addons/debug_menu/objects/physics/physics_info.gd")
const PhysicsQuery = preload("res://addons/debug_menu/objects/physics/physics_query.gd")
const PhysicsBodyView = preload("res://addons/debug_menu/objects/physics/physics_body_view.gd")
const PhysicsOverlay = preload("res://addons/debug_menu/objects/physics/physics_overlay.gd")
const PhysicsContacts = preload("res://addons/debug_menu/objects/physics/physics_contacts.gd")
const HIGHLIGHT_INTERVAL: float = 0.5
const TOUCHING_COLOR: Color = Color("ff9f43")
const MASK_COLOR: Color = Color("a78bfa")
const LAYER_COLOR: Color = Color("f472b6")

var _body: Node = null # CollisionObject2D ou 3D
var _watching: bool = false
var _layer: int = 1 # couche affichée dans « Par couche »
# Surlignage dans le jeu des objets de chaque liste.
var _highlight_touching: bool = false
var _highlight_mask: bool = false
var _highlight_layer: bool = false
var _highlight_time: float = 0.0
var _overlay: PhysicsOverlay # celui du calque commun
var _selection: Node # selection.gd


func _ready() -> void:
	var debug_menu: Node = get_debug_menu()
	if debug_menu != null:
		_overlay = (debug_menu.get("display_layer") as Node).get("physics_overlay")
		_selection = debug_menu.get("selection")
		_selection.selection_changed.connect(_follow)
		_follow(_selection.get_selected())
	super()


func _exit_tree() -> void:
	# Plus de listes à surligner sans la fenêtre.
	if _overlay != null:
		_overlay.highlights = []


func _process(delta: float) -> void:
	# Les textes en direct lisent l'objet : s'il est libéré, on vide la fenêtre.
	if _watching and not is_instance_valid(_body):
		_watching = false
		_body = null
		rebuild()
	_highlight_time += delta
	if _highlight_time >= HIGHLIGHT_INTERVAL:
		_highlight_time = 0.0
		_update_highlights()
	super(delta)


# Nouvelle sélection : on affiche le corps physique qui lui est lié.
func _follow(object: Object) -> void:
	_body = PhysicsTarget.resolve(object as Node) if object is Node else null
	_watching = _body != null
	if _rows != null:
		rebuild()


func _build() -> void:
	if _selection == null:
		add_note(T.t("DebugMenu not found: Physics needs the addon to be active."))
		return
	add_selection_bar()
	add_status(_status_text)
	if _body == null:
		var selected: Object = _selection.get_selected()
		if selected == null:
			add_note(T.t("Choose an object: search, picker, or click in a list."))
		else:
			add_note(T.t("\"%s\" has no physics (neither itself, its parent, nor its direct children).") % _object_name(selected))
	else:
		_build_selected()
	_build_layer_section()


# Le corps affiché (peut être le parent ou l'enfant de la sélection).
func _status_text() -> String:
	# Le corps peut sortir de l'arbre un instant (rechargement de la scène).
	if not is_instance_valid(_body) or not _body.is_inside_tree():
		return ""
	return T.t("Body shown: %s") % _body.get_path()


func _object_name(object: Object) -> String:
	if object is Node:
		return String((object as Node).name)
	if object is Resource and (object as Resource).resource_path != "":
		return (object as Resource).resource_path.get_file()
	return object.get_class()


# --- Objet choisi ---

func _build_selected() -> void:
	add_section("%s : %s" % [_body.name, _body.get_class()])
	add_buttons(T.t("Open in"), [T.t("Inspector")], func(_index: int) -> void:
		if is_instance_valid(_body):
			get_debug_menu().call("inspect", _body)
	)
	_build_overlay_checks()
	PhysicsBodyView.build(self, _body)

	add_section(T.t("Touching right now"))
	add_check(T.t("Highlight in the game (orange)"), func() -> bool: return _highlight_touching, func(on: bool) -> void: _highlight_touching = on)
	add_node_list(_touching_nodes)
	add_section(T.t("Can touch (layers of its mask)"))
	add_check(T.t("Highlight in the game (purple)"), func() -> bool: return _highlight_mask, func(on: bool) -> void: _highlight_mask = on)
	add_node_list(_mask_nodes)


# Les cases sont dans le menu Affichage ; ici, ce qui en dépend.
func _build_overlay_checks() -> void:
	if PhysicsInfo.is_3d(_body):
		add_note(T.t("In-game drawings: 2D only for now."))
		return
	add_hint(T.t("In-game drawings (shapes, center, velocity, trajectory, contacts): Display menu."))
	add_live_label(func() -> String:
		if _overlay == null or not _overlay.show_contacts:
			return ""
		return T.t("%d contact(s) (pink, normals in blue) · %s") % [_overlay.current_contact_count(), PhysicsContacts.method_text(_body)]
	)


# --- Par couche ---

func _build_layer_section() -> void:
	var in_3d: bool = _body != null and PhysicsInfo.is_3d(_body)
	add_section(T.t("By collision layer"))
	add_option(T.t("Layer"), PhysicsQuery.layer_names(in_3d), _layer - 1, func(index: int) -> void: _layer = index + 1)
	add_check(T.t("Highlight in the game (pink)"), func() -> bool: return _highlight_layer, func(on: bool) -> void: _highlight_layer = on)
	add_node_list(func() -> Array: return PhysicsQuery.on_layer(get_tree(), _layer), 140.0)


# --- Listes et surlignage ---

func _touching_nodes() -> Array:
	return PhysicsQuery.touching(_body) if is_instance_valid(_body) else []


func _mask_nodes() -> Array:
	return PhysicsQuery.in_mask_of(_body) if is_instance_valid(_body) else []


func _update_highlights() -> void:
	var sets: Array[Dictionary] = []
	if _highlight_touching:
		sets.append({"nodes": _touching_nodes(), "color": TOUCHING_COLOR})
	if _highlight_mask:
		sets.append({"nodes": _mask_nodes(), "color": MASK_COLOR})
	if _highlight_layer:
		sets.append({"nodes": PhysicsQuery.on_layer(get_tree(), _layer), "color": LAYER_COLOR})
	# Les listes ne sont surlignées que tant que la fenêtre est affichée.
	if not visible:
		sets.clear()
	if _overlay != null:
		_overlay.highlights = sets
