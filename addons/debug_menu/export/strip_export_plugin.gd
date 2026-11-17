@tool
extends EditorExportPlugin

## Export avec l'étiquette « strip_debug_menu » (Export > Fonctionnalités >
## Fonctionnalités personnalisées) : les fichiers de l'addon ne sont pas
## exportés. L'autoload DebugMenu est remplacé par une petite scène
## (disabled_stub.gd) qui se retire au lancement.
## Si des fichiers du jeu citent l'addon (reference_scan.gd), rien n'est
## retiré (l'export marcherait mal) : une erreur les liste, et le debug menu
## est seulement coupé au lancement.
## Ajouté par plugin.gd ; sans l'étiquette, il ne fait rien.

const ReferenceScan = preload("res://addons/debug_menu/export/reference_scan.gd")
const STRIP_FEATURE: String = "strip_debug_menu"
const AUTOLOAD_SCENE: String = "res://addons/debug_menu/debug_menu.tscn"
const STUB_SCRIPT: String = "res://addons/debug_menu/export/disabled_stub.gd"

var _strip: bool = false


func _get_name() -> String:
	return "DebugMenuStrip"


func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	_strip = features.has(STRIP_FEATURE)
	if not _strip:
		return
	var users: PackedStringArray = ReferenceScan.find_users()
	if not users.is_empty():
		_strip = false
		push_error("DebugMenu: strip_debug_menu ignored, these files use the addon: %s. The files are exported; the debug menu is only disabled at launch." % ", ".join(users))


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if not _strip or not path.begins_with(ReferenceScan.ADDON_DIR) or path == STUB_SCRIPT:
		return
	skip()
	if path == AUTOLOAD_SCENE:
		add_file(AUTOLOAD_SCENE, stub_scene().to_utf8_buffer(), false)


## Scène qui remplace l'autoload : un Node avec disabled_stub.gd.
static func stub_scene() -> String:
	return "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"Script\" path=\"%s\" id=\"1\"]\n\n[node name=\"DebugMenu\" type=\"Node\"]\nscript = ExtResource(\"1\")\n" % STUB_SCRIPT
