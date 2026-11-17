extends CanvasLayer

## Calque unique des dessins dans le monde du jeu (enfant de DebugMenu,
## DebugMenu.display_layer). Il suit la caméra : on y dessine directement en
## coordonnées du monde. Il reste affiché quelles que soient les fenêtres
## ouvertes ; chaque dessin se coupe dans le menu Affichage.
## Contient :
## - collision_drawer : toutes les formes de collision 2D ;
## - navigation_drawer : zones de navigation et chemins des agents ;
## - physics_overlay : la physique de l'objet sélectionné (formes, centre,
##   vitesse, trajectoire, contacts) et le surlignage des listes de la
##   fenêtre Physique ;
## - gizmos : ce que le jeu dessine avec DebugMenu.draw_...().

const PhysicsOverlay = preload("res://addons/debug_menu/objects/physics/physics_overlay.gd")
const PhysicsTarget = preload("res://addons/debug_menu/objects/physics/physics_target.gd")
const CollisionDrawer = preload("res://addons/debug_menu/display/collision_drawer.gd")
const NavigationDrawer = preload("res://addons/debug_menu/display/navigation_drawer.gd")
const Gizmos = preload("res://addons/debug_menu/display/gizmos.gd")
const LAYER: int = 99 # sous la barre du debug menu (100)

var collision_drawer: CollisionDrawer
var navigation_drawer: NavigationDrawer
var physics_overlay: PhysicsOverlay
var gizmos: Gizmos


func _init() -> void:
	layer = LAYER
	follow_viewport_enabled = true
	# Ordre de dessin : du fond (toutes les collisions) au premier plan (gizmos).
	collision_drawer = _add_drawer(CollisionDrawer.new(), "CollisionDrawer")
	navigation_drawer = _add_drawer(NavigationDrawer.new(), "NavigationDrawer")
	physics_overlay = _add_drawer(PhysicsOverlay.new(), "PhysicsOverlay")
	gizmos = _add_drawer(Gizmos.new(), "Gizmos")


func _add_drawer(drawer: Node2D, drawer_name: String) -> Node2D:
	drawer.name = drawer_name
	add_child(drawer)
	return drawer


## Les dessins de physique suivent le corps lié à l'objet sélectionné.
func follow_selection(selection: Node) -> void:
	selection.selection_changed.connect(_on_selection_changed)
	_on_selection_changed(selection.call("get_selected"))


func _on_selection_changed(object: Object) -> void:
	physics_overlay.set_body(PhysicsTarget.resolve(object as Node) if object is Node else null)
