@tool
extends EditorPlugin

## À l'activation : l'autoload DebugMenu et les actions des raccourcis
## (settings/shortcuts.gd), chacune seulement si elle n'existe pas, pour
## garder un raccourci déjà personnalisé par le projet. À la désactivation,
## l'autoload est retiré (les actions restent).
## Les touches choisies dans les Paramètres en jeu passent avant celles du
## projet, sans modifier le projet.
## Ajoute aussi le plugin d'export (export/strip_export_plugin.gd), qui ne
## fait rien sans l'étiquette strip_debug_menu.
## Dans un jeu sans test runner (addons/test_runner), les tests de l'addon
## sont cachés à Godot (tests/.gdignore, ignoré par git) : sans lui, leur
## classe TestCase manque et l'éditeur affiche une erreur par fichier.
## get_editor_interface() plutôt que le singleton EditorInterface (4.2+).

const AUTOLOAD_NAME: String = "DebugMenu"
const AUTOLOAD_PATH: String = "res://addons/debug_menu/debug_menu.tscn"
const TESTS_IGNORE: String = "res://addons/debug_menu/tests/.gdignore"
const TEST_RUNNER: String = "res://addons/test_runner/test_case.gd"
const Shortcuts = preload("res://addons/debug_menu/settings/shortcuts.gd")
const StripExportPlugin = preload("res://addons/debug_menu/export/strip_export_plugin.gd")

var _export_plugin: EditorExportPlugin = null


func _enter_tree() -> void:
	_export_plugin = StripExportPlugin.new()
	add_export_plugin(_export_plugin)
	_hide_tests()


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	for entry in Shortcuts.LIST:
		_add_action(entry[0])
	ProjectSettings.save()


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)


# Touche physique : même position quelle que soit la disposition du clavier
# (² en AZERTY, ` en QWERTY pour la barre).
func _add_action(action: String) -> void:
	var setting_name: String = "input/" + action
	if ProjectSettings.has_setting(setting_name):
		return
	ProjectSettings.set_setting(setting_name, {"deadzone": 0.5, "events": [Shortcuts.default_event(action)]})


func _hide_tests() -> void:
	if FileAccess.file_exists(TEST_RUNNER) or FileAccess.file_exists(TESTS_IGNORE):
		return
	var file: FileAccess = FileAccess.open(TESTS_IGNORE, FileAccess.WRITE)
	if file != null:
		file.close()
		get_editor_interface().get_resource_filesystem().scan()
