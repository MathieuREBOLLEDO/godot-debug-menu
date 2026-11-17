extends RefCounted

## Jetons de design du projet (voir DESIGN.md de l'addon) : couleurs, polices
## et tailles communes à toutes les interfaces d'outils, lues dans
## res://design_tokens.cfg s'il existe. Une valeur absente garde son défaut.
## Les défauts sont la direction commune à tous les addons (« comme l'éditeur
## Godot », mêmes valeurs que editor/feel_theme.gd de game_feel) : sans ce
## fichier, l'addon a déjà le bon design ; le fichier ne sert qu'à s'en écarter.
## Les réglages de l'utilisateur (Paramètres > Apparence) passent par-dessus
## l'accent, le fond, la taille et la police.

const PATH: String = "res://design_tokens.cfg"
## Valeur de font_path (réglages) qui désigne la police des jetons.
const FONT_FROM_TOKENS: String = "tokens"

const DEFAULT_COLORS: Dictionary = {
	"ink": "1d2229",
	"ink_panel": "252b34",
	"ink_raised": "363d4a",
	"ink_line": "414957",
	"sand": "e0e0e0",
	"sand_dim": "8b929c",
	"accent": "70bbfa",
	"good": "45d17c",
	"bad": "ff786b",
	"info": "a5b6cc",
}
const DEFAULT_FONTS: Dictionary = {
	"ui": ["@engine"],
	"mono": ["JetBrains Mono", "Cascadia Mono", "Consolas", "Menlo"],
	"condensed_width": 100,
	"condensed_weight": 600,
}
const DEFAULT_SIZES: Dictionary = {"text": 14, "title": 16, "small": 12, "radius": 3}

static var _config: ConfigFile = null
static var _fonts: Dictionary = {}


static func color(key: String) -> Color:
	return Color(String(_value("colors", key, DEFAULT_COLORS[key])))


static func size(key: String) -> int:
	return int(_value("sizes", key, DEFAULT_SIZES[key]))


## Police du système des jetons : &"ui", &"condensed" (version étroite et
## grasse de ui, pour les titres) ou &"mono". Nom « @engine » : la police de
## l'éditeur Godot (dans l'éditeur), sinon celle de Godot par défaut.
static func font(kind: StringName) -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var names: PackedStringArray = PackedStringArray(_value("fonts", "mono" if kind == &"mono" else "ui", DEFAULT_FONTS["mono" if kind == &"mono" else "ui"]))
	var result: Font
	if names.has("@engine"):
		result = _engine_font()
	else:
		var system: SystemFont = SystemFont.new()
		system.font_names = names
		result = system
	if kind == &"condensed":
		var narrow: FontVariation = FontVariation.new()
		narrow.base_font = result
		var server: TextServer = TextServerManager.get_primary_interface()
		narrow.variation_opentype = {
			server.name_to_tag("wdth"): int(_value("fonts", "condensed_width", DEFAULT_FONTS["condensed_width"])),
			server.name_to_tag("wght"): int(_value("fonts", "condensed_weight", DEFAULT_FONTS["condensed_weight"])),
		}
		result = narrow
	_fonts[kind] = result
	return result


static func _engine_font() -> Font:
	# EditorInterface n'existe pas en jeu exporté : passé par Engine.
	if Engine.is_editor_hint() and Engine.has_singleton(&"EditorInterface"):
		var editor_theme: Theme = Engine.get_singleton(&"EditorInterface").get_editor_theme()
		if editor_theme != null and editor_theme.default_font != null:
			return editor_theme.default_font
	return ThemeDB.fallback_font


static func _value(section: String, key: String, default: Variant) -> Variant:
	if _config == null:
		_config = ConfigFile.new()
		if FileAccess.file_exists(PATH):
			_config.load(PATH)
	return _config.get_value(section, key, default)
