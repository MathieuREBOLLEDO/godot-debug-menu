extends "res://addons/debug_menu/ui/debug_window.gd"

## Fenêtre « Watch » : les variables suivies (bouton œil de l'Inspecteur ou
## du Variable finder, ou DebugMenu.watch_variable()), groupées par objet,
## avec leur valeur en direct, modifiable. Seuls les objets chargés sont
## affichés ; la liste est gardée d'une partie à l'autre jusqu'à Clear.
## Morceaux : watch_list.gd (la liste), watch_view.gd (le tableau).

const WatchList = preload("res://addons/debug_menu/objects/watch/watch_list.gd")
const WatchView = preload("res://addons/debug_menu/objects/watch/watch_view.gd")
const REFRESH_INTERVAL: float = 0.1
const CHECK_INTERVAL: float = 0.5 # objets chargés ou déchargés
const CLEAR_CONFIRM_TIME: float = 3.0 # Clear demande un second clic

var _watch: WatchList
var _view: WatchView
var _clear_button: Button
var _loaded_ids: Array = [] # id du nœud de chaque entrée (0 : pas chargé), au dernier affichage
var _refresh_time: float = 0.0
var _check_time: float = 0.0
var _clear_armed_time: float = 0.0


func _ready() -> void:
	if get_debug_menu() != null:
		_watch = get_debug_menu().get("watch")
		_watch.changed.connect(_show_entries)
	super()


func _process(delta: float) -> void:
	if _view != null:
		_refresh_time += delta
		if _refresh_time >= REFRESH_INTERVAL:
			_refresh_time = 0.0
			_view.refresh()
		_check_time += delta
		if _check_time >= CHECK_INTERVAL:
			_check_time = 0.0
			if _ids(_resolve_all()) != _loaded_ids:
				_show_entries()
	if _clear_armed_time > 0.0:
		_clear_armed_time -= delta
		if _clear_armed_time <= 0.0:
			_clear_button.text = T.t("Clear")
	super(delta)


func _build() -> void:
	if _watch == null:
		add_note(T.t("DebugMenu not found: Watch needs the addon to be active."))
		return
	add_status(_status_text)
	_clear_button = add_button(T.t("Clear"), _on_clear_pressed)
	_view = WatchView.new()
	_view.custom_minimum_size.y = 120.0
	_view.inspect_requested.connect(func(node: Node) -> void: get_debug_menu().call("inspect", node))
	_view.remove_requested.connect(_watch.remove)
	add_custom(_view, true)
	add_hint(T.t("Add variables with the eye button of the Inspector or the Variable finder."))
	_show_entries()


func _show_entries() -> void:
	if _view == null:
		return
	var nodes: Array = _resolve_all()
	_loaded_ids = _ids(nodes)
	_view.show_entries(_watch.get_entries(), nodes)


# Premier clic : demande confirmation ; second clic dans les 3 s : vide la liste.
func _on_clear_pressed() -> void:
	if _clear_armed_time > 0.0:
		_clear_armed_time = 0.0
		_clear_button.text = T.t("Clear")
		_watch.clear()
	else:
		_clear_armed_time = CLEAR_CONFIRM_TIME
		_clear_button.text = T.t("Click again to clear the list")


func _status_text() -> String:
	if _view == null:
		return ""
	var total: int = _watch.get_entries().size()
	return T.t("%d watched · %d shown · %d not loaded") % [total, _view.get_shown_count(), total - _view.get_shown_count()]


func _resolve_all() -> Array:
	var nodes: Array = []
	for entry in _watch.get_entries():
		nodes.append(WatchList.resolve(get_tree(), entry))
	return nodes


func _ids(nodes: Array) -> Array:
	return nodes.map(func(node: Node) -> int: return node.get_instance_id() if node != null else 0)
