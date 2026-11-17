extends RefCounted

## Fichiers d'enregistrement d'actions, en JSON dans FOLDER (user://, donc
## propres à la machine). Contenu :
## {version, scene, seed, date, frames (nombre d'images),
##  inputs: [[image, action, force], ...]   changements d'état seulement,
##  tracks: {chemin: [[image, x, y(, z)], ...]}   positions des corps suivis}

const FOLDER: String = "user://debug_menu/recordings"
const T = preload("res://addons/debug_menu/i18n/t.gd")
const VERSION: int = 1


static func save(data: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var path: String = FOLDER.path_join("%s.json" % Time.get_datetime_string_from_system().replace(":", "-"))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning(T.t("DebugMenu: could not write %s (%s).") % [path, error_string(FileAccess.get_open_error())])
		return ""
	file.store_string(JSON.stringify(data))
	return path


## null si le fichier est illisible.
static func load_file(path: String) -> Variant:
	var text: String = FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary or int(data.get("version", 0)) != VERSION:
		return null
	return data


## Chemins des enregistrements, du plus récent au plus ancien.
static func list() -> Array[String]:
	var paths: Array[String] = []
	var dir: DirAccess = DirAccess.open(FOLDER)
	if dir == null:
		return paths
	for file in dir.get_files():
		if file.get_extension() == "json":
			paths.append(FOLDER.path_join(file))
	paths.sort()
	paths.reverse()
	return paths


static func delete(path: String) -> void:
	DirAccess.remove_absolute(path)
