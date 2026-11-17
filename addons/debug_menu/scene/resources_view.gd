extends Tree

## Fichiers ressources du projet (scènes, ressources, scripts, images, sons,
## polices) et leur état : « en mémoire » si Godot les a chargés et gardés en
## cache, « pas chargée » sinon. Rangés par dossier ; les compteurs des
## dossiers disent combien de fichiers sont chargés.
## Limites : un chargement en cours en arrière-plan n'est pas visible ; une
## ressource chargée sans passer par son fichier (créée en code) non plus.
## Dans un export, les fichiers apparaissent en .remap / .import : on retire
## ces suffixes pour retrouver le chemin d'origine.

const EXTENSIONS: Array[String] = ["tscn", "scn", "tres", "res", "gd", "png", "jpg", "jpeg", "svg", "webp", "wav", "ogg", "mp3", "ttf", "otf"]
const SKIPPED_FOLDERS: Array[String] = [".godot", ".git", ".import"]
const T = preload("res://addons/debug_menu/i18n/t.gd")
const Tokens = preload("res://addons/debug_menu/settings/design_tokens.gd")
static var LOADED_COLOR: Color = Tokens.color("good")

var _paths: Array[String] = []
var _items: Dictionary = {} # chemin -> TreeItem (fichiers)
var _folder_items: Dictionary = {} # dossier -> TreeItem
var _only_loaded: bool = false


func _init() -> void:
	columns = 2
	column_titles_visible = true
	hide_root = true
	select_mode = Tree.SELECT_ROW
	focus_mode = Control.FOCUS_NONE
	set_column_title(0, T.t("File"))
	set_column_title(1, T.t("State"))
	set_column_expand_ratio(0, 4)
	set_column_expand_ratio(1, 1)


## Relit la liste des fichiers du projet puis reconstruit l'arbre.
func rescan() -> void:
	_paths.clear()
	_scan("res://")
	_paths.sort()
	_rebuild()


func set_only_loaded(value: bool) -> void:
	_only_loaded = value
	_rebuild()


## Met à jour les états (sans relire les fichiers).
func refresh() -> void:
	if _only_loaded:
		_rebuild() # la liste elle-même dépend des états
		return
	var loaded_per_folder: Dictionary = {}
	for path in _items:
		var loaded: bool = ResourceLoader.has_cached(path)
		_set_state(_items[path], loaded)
		var folder: String = path.get_base_dir()
		loaded_per_folder[folder] = loaded_per_folder.get(folder, 0) + (1 if loaded else 0)
	for folder in _folder_items:
		var item: TreeItem = _folder_items[folder]
		item.set_text(1, T.t("%d loaded") % loaded_per_folder.get(folder, 0))


func _scan(folder: String) -> void:
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return
	for sub_folder in dir.get_directories():
		if not SKIPPED_FOLDERS.has(sub_folder):
			_scan(folder.path_join(sub_folder))
	for file in dir.get_files():
		var path: String = folder.path_join(file.trim_suffix(".remap").trim_suffix(".import"))
		if EXTENSIONS.has(path.get_extension().to_lower()) and not _paths.has(path):
			_paths.append(path)


func _rebuild() -> void:
	clear()
	_items.clear()
	_folder_items.clear()
	var root: TreeItem = create_item()
	for path in _paths:
		if _only_loaded and not ResourceLoader.has_cached(path):
			continue
		var item: TreeItem = create_item(_get_folder_item(root, path.get_base_dir()))
		item.set_text(0, path.get_file())
		item.set_tooltip_text(0, path)
		_items[path] = item
	if not _only_loaded:
		refresh()
	else:
		for path in _items:
			_set_state(_items[path], true)


# Crée au besoin l'élément du dossier et de ses parents.
func _get_folder_item(root: TreeItem, folder: String) -> TreeItem:
	if folder == "res://" or folder == "res:":
		return root
	if _folder_items.has(folder):
		return _folder_items[folder]
	var item: TreeItem = create_item(_get_folder_item(root, folder.get_base_dir()))
	item.set_text(0, folder.get_file() + "/")
	item.set_selectable(0, false)
	_folder_items[folder] = item
	return item


func _set_state(item: TreeItem, loaded: bool) -> void:
	item.set_text(1, T.t("in memory") if loaded else T.t("not loaded"))
	item.set_custom_color(1, LOADED_COLOR if loaded else Tokens.color("sand_dim"))
