extends RefCounted

## Tout ce que le debug menu retient d'une partie à l'autre, dans user://
## (propre à la machine, pas au projet) :
## apparence, favoris, mode souris, cases des menus, raccourcis, épingles
## variables suivies (Watch), graine fixe, et la
## session (fenêtres ouvertes, positions, épingles, dernière sélection).

const T = preload("res://addons/debug_menu/i18n/t.gd")
const Tokens = preload("res://addons/debug_menu/settings/design_tokens.gd")
const PATH: String = "user://debug_menu_settings.cfg"
## Anciens défauts de l'apparence (avant les jetons de design, puis jetons
## « carte d'arpenteur ») : une valeur enregistrée égale à l'un d'eux n'avait
## pas été choisie, elle reprend le nouveau défaut.
const OLD_DEFAULTS: Dictionary = {
	"accent_color": [Color("4fa3ff"), Color("ffb020")],
	"background_color": [Color("252a33e6"), Color(Color("141a28"), 0.94)],
	"font_size": [16],
	"font_path": ["res://addons/debug_menu/fonts/Montserrat-wght.ttf"],
}
## Anciennes clés -> clés suivantes, en anglais et indépendantes de la langue
## affichée. Appliqué en chaîne par rename() (une très vieille clé passe par
## plusieurs versions). Historique : premier menu « Core », menus en
## français, menus Time / Tools / Display, puis Core avec sous-menus.
const RENAMED_KEYS: Dictionary = {
	"Core/Time": "Time/Speed and frame stepping",
	"Core/Temps": "Time/Speed and frame stepping",
	"Core/Inspecteur": "Objects/Inspector",
	"Core/Physique": "Objects/Physics",
	"Core/Mémoire": "Scene/Node tree",
	"Core/Arbre des nœuds": "Scene/Node tree",
	"Core/Événements des nœuds": "Scene/Node events",
	"Core/Ressources": "Scene/Resources",
	"Core/Replay": "Time/Recordings",
	"Core/Enregistrements": "Time/Recordings",
	"Objets/Inspecteur": "Objects/Inspector",
	"Objets/Physique": "Objects/Physics",
	"Scène/Arbre des nœuds": "Scene/Node tree",
	"Scène/Événements des nœuds": "Scene/Node events",
	"Scène/Ressources": "Scene/Resources",
	"Temps/Vitesse et image par image": "Time/Speed and frame stepping",
	"Temps/Enregistrements": "Time/Recordings",
	"Paramètres": "Settings",
	"Debug Menu/Settings": "Settings",
	"Affichage/Contour de la sélection": "Display/Selection outline",
	"Affichage/Physique : formes de collision": "Display/Physics: collision shapes",
	"Affichage/Physique : centre de masse": "Display/Physics: center of mass",
	"Affichage/Physique : vitesse": "Display/Physics: velocity",
	"Affichage/Physique : trajectoire (3 s)": "Display/Physics: trajectory (3 s)",
	"Affichage/Physique : contacts et normales": "Display/Physics: contacts and normals",
	"Time/Speed and frame stepping": "Core/Time/Speed and frame stepping",
	"Time/Recordings": "Core/Time/Recordings",
	"Tools/Console": "Core/Console",
	"Tools/Performance": "Core/Performance",
	"Display/Performance overlay": "Core/Display/Performance overlay",
	"Display/Input display": "Core/Display/Input display",
	"Display/Selection outline": "Core/Display/Selection outline",
	"Display/Collision shapes (all)": "Core/Display/Collision shapes",
	"Display/Navigation": "Core/Display/Navigation",
	"Display/Physics: collision shapes": "Core/Display/Physics/Collision shapes",
	"Display/Physics: center of mass": "Core/Display/Physics/Center of mass",
	"Display/Physics: velocity": "Core/Display/Physics/Velocity",
	"Display/Physics: trajectory (3 s)": "Core/Display/Physics/Trajectory (3 s)",
	"Display/Physics: contacts and normals": "Core/Display/Physics/Contacts and normals",
	"Display/Gizmos": "Core/Display/Gizmos/Default",
	"Display/Screen: safe area": "Core/Screen/Safe area",
	"Display/Screen: 16:9": "Core/Screen/16:9",
	"Display/Screen: 4:3": "Core/Screen/4:3",
	"Display/Screen: 19.5:9": "Core/Screen/19.5:9",
	"Display/Screen: 21:9": "Core/Screen/21:9",
	"Objects/Tuning": "Objects/Watch",
}
## Anciennes cases de catégorie de gizmos : « Display/Gizmos: IA ».
const OLD_GIZMO_PREFIX: String = "Display/Gizmos: "
const GIZMO_MENU: String = "Core/Display/Gizmos/"

var language: String = "en" # i18n/t.gd
var values: Dictionary = defaults()
var favorites: Array[String] = [] # clés « menu/entrée », dans l'ordre d'ajout
var mouse_mode: int = 2 # MouseModes.Mode.BOTH (windows/mouse_modes.gd)
var toggles: Dictionary = {} # « menu/entrée » -> bool : cases des menus (bar/menu_toggles.gd)
var shortcuts: Dictionary = {} # action -> touche (settings/shortcuts.gd)
var session_windows: Array = [] # [{key, position, size, visible, pinned}] (window_manager.gd)
var session_selection: String = "" # chemin du nœud sélectionné
var watch_entries: Array = [] # [{path, property}] (objects/watch/watch_list.gd)
var seed_fixed: bool = false # scene/random_seed.gd
var seed_value: int = 0
var dithering: Dictionary = {} # réglages du tramage (display/dithering.gd)


func load_from_disk() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(PATH) != OK:
		return
	var default_values: Dictionary = defaults()
	for setting_name in default_values:
		var value: Variant = config.get_value("theme", setting_name, default_values[setting_name])
		# Valeur d'un mauvais type (fichier modifié à la main) : on garde le défaut.
		if typeof(value) == typeof(default_values[setting_name]) and not _is_old_default(setting_name, value):
			values[setting_name] = value
	for key in config.get_value("favorites", "keys", []):
		var renamed: String = rename(key)
		if not favorites.has(renamed):
			favorites.append(renamed)
	language = str(config.get_value("general", "language", language))
	mouse_mode = clampi(config.get_value("mouse", "mode", mouse_mode), 0, 2)
	for key in _dictionary(config.get_value("display", "toggles", {})):
		toggles[rename(key)] = config.get_value("display", "toggles")[key]
	shortcuts = _dictionary(config.get_value("shortcuts", "keys", {}))
	var windows: Variant = config.get_value("session", "windows", [])
	session_windows = windows if windows is Array else []
	for entry in session_windows:
		if entry is Dictionary and entry.has("key"):
			entry["key"] = rename(entry["key"])
	session_selection = str(config.get_value("session", "selection", ""))
	seed_fixed = config.get_value("random", "fixed", false) == true
	var fixed_value: Variant = config.get_value("random", "seed", 0)
	seed_value = fixed_value if fixed_value is int else 0
	dithering = _dictionary(config.get_value("dithering", "values", {}))
	watch_entries.clear()
	# Avant Watch, les variables suivies étaient les épingles de Tuning.
	var watched: Variant = config.get_value("watch", "entries", config.get_value("tuning", "pins", []))
	for entry in (watched if watched is Array else []):
		if entry is Dictionary and entry.has("path") and entry.has("property"):
			watch_entries.append(entry)


func save() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("general", "language", language)
	for setting_name in values:
		config.set_value("theme", setting_name, values[setting_name])
	config.set_value("favorites", "keys", favorites)
	config.set_value("mouse", "mode", mouse_mode)
	config.set_value("display", "toggles", toggles)
	config.set_value("shortcuts", "keys", shortcuts)
	config.set_value("session", "windows", session_windows)
	config.set_value("session", "selection", session_selection)
	config.set_value("watch", "entries", watch_entries)
	config.set_value("random", "fixed", seed_fixed)
	config.set_value("random", "seed", seed_value)
	config.set_value("dithering", "values", dithering)
	var error: Error = config.save(PATH)
	if error != OK:
		push_warning(T.t("DebugMenu: could not save the settings (%s).") % error_string(error))


## Remet l'apparence par défaut (le reste est gardé).
func reset_values() -> void:
	values = defaults()


static func _is_old_default(setting_name: String, value: Variant) -> bool:
	for old in OLD_DEFAULTS[setting_name]:
		if value is Color and (value as Color).is_equal_approx(old):
			return true
		if not value is Color and value == old:
			return true
	return false


## Apparence par défaut : celle des jetons de design (design_tokens.gd), fond
## des panneaux légèrement transparent.
static func defaults() -> Dictionary:
	return {
		"accent_color": Tokens.color("accent"),
		"background_color": Color(Tokens.color("ink_panel"), 0.94),
		"font_size": Tokens.size("text"),
		"font_path": Tokens.FONT_FROM_TOKENS, # "" = police de Godot
	}


func set_favorite(key: String, favorite: bool) -> void:
	if favorite and not favorites.has(key):
		favorites.append(key)
	elif not favorite:
		favorites.erase(key)


## Clé actuelle d'une clé enregistrée par une version précédente.
static func rename(key: String) -> String:
	if key.begins_with(OLD_GIZMO_PREFIX):
		return GIZMO_MENU + key.trim_prefix(OLD_GIZMO_PREFIX)
	for _step in 5: # chaîne courte : évite toute boucle
		if not RENAMED_KEYS.has(key):
			break
		key = RENAMED_KEYS[key]
	return key


# Valeur d'un mauvais type (fichier modifié à la main) : dictionnaire vide.
static func _dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
