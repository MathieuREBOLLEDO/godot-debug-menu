extends RefCounted

## Entrées à cocher dans les menus de la barre (DebugMenu.add_toggle) :
## chaque entrée lit son état avec un getter et le change avec un setter.
## Les cases sont remises à jour à chaque ouverture du menu, et leur état est
## enregistré (settings_store.gd) pour être rétabli au prochain lancement.
## Dans le PopupMenu, la métadonnée d'une case vaut PREFIX + clé ; celle
## d'une fenêtre vaut sa clé seule.

const PREFIX: String = "toggle:"

var _store: RefCounted # settings_store.gd
var _toggles: Dictionary = {} # clé -> {getter, setter}


func _init(store: RefCounted) -> void:
	_store = store


## Ajoute la case [param key] (« menu/entrée ») au menu [param popup].
func add(popup: PopupMenu, key: String, entry: String, getter: Callable, setter: Callable) -> void:
	_toggles[key] = {"getter": getter, "setter": setter}
	# État enregistré lors d'une partie précédente.
	var saved: Dictionary = _store.get("toggles")
	if saved.has(key):
		setter.call(bool(saved[key]))
	if popup.item_count > 0:
		popup.add_separator()
	popup.add_check_item(entry)
	popup.set_item_metadata(popup.item_count - 1, PREFIX + key)
	popup.set_item_checked(popup.item_count - 1, getter.call())
	# On peut cocher plusieurs cases sans que le menu se ferme.
	popup.hide_on_checkable_item_selection = false
	if not popup.about_to_popup.is_connected(_refresh.bind(popup)):
		popup.about_to_popup.connect(_refresh.bind(popup))


func is_toggle(metadata: Variant) -> bool:
	return metadata is String and (metadata as String).begins_with(PREFIX)


## Inverse la case [param index] de [param popup].
func press(popup: PopupMenu, index: int) -> void:
	var key: String = String(popup.get_item_metadata(index)).trim_prefix(PREFIX)
	var toggle: Dictionary = _toggles[key]
	var value: bool = not bool(toggle["getter"].call())
	toggle["setter"].call(value)
	popup.set_item_checked(index, value)
	var saved: Dictionary = _store.get("toggles")
	saved[key] = value
	_store.call("save")


# L'état a pu changer ailleurs (fenêtre, code du jeu) : on relit les getters.
func _refresh(popup: PopupMenu) -> void:
	for index in popup.item_count:
		var metadata: Variant = popup.get_item_metadata(index)
		if is_toggle(metadata):
			var key: String = String(metadata).trim_prefix(PREFIX)
			popup.set_item_checked(index, _toggles[key]["getter"].call())
