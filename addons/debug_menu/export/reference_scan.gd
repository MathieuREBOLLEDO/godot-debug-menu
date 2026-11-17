extends RefCounted

## Fichiers du jeu qui citent un fichier de l'addon (preload, extends,
## ext_resource...). Si le jeu en a, retirer l'addon de l'export casserait
## ces fichiers : strip_export_plugin.gd ne retire alors rien.
## Recherche de texte simple dans les scripts, scènes et ressources texte.

const ADDON_DIR: String = "res://addons/debug_menu/"
const SCANNED_EXTENSIONS: Array[String] = ["gd", "tscn", "tres", "gdshader"]
const SKIPPED_DIRS: Array[String] = ["res://.godot/", ADDON_DIR]


## Chemins des fichiers hors de l'addon qui citent l'addon.
static func find_users(dir_path: String = "res://") -> PackedStringArray:
	var users: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return users
	for file_name in dir.get_files():
		var path: String = dir_path.path_join(file_name)
		if SCANNED_EXTENSIONS.has(file_name.get_extension()) and FileAccess.get_file_as_string(path).contains(ADDON_DIR):
			users.append(path)
	for sub_dir in dir.get_directories():
		var sub_path: String = dir_path.path_join(sub_dir) + "/"
		if not sub_dir.begins_with(".") and not SKIPPED_DIRS.has(sub_path):
			users.append_array(find_users(sub_path.trim_suffix("/")))
	return users
