extends RefCounted

## Traduction des textes du debug menu, indépendante de celle du jeu (le
## TranslationServer de Godot est global : changer sa langue changerait
## aussi celle du jeu).
## Les textes sont écrits en anglais dans le code : T.t("Inspector").
## Avec une autre langue, la traduction est cherchée dans le dictionnaire de
## cette langue (i18n/fr.gd) ; un texte absent reste en anglais.
## Un texte avec des valeurs garde ses %d / %s : T.t("%d contact(s)") % n.

const FR = preload("res://addons/debug_menu/i18n/fr.gd")
const LANGUAGES: Array[String] = ["en", "fr"]
const LANGUAGE_NAMES: Array[String] = ["English", "Français"]
# Rangée dans les métadonnées d'Engine : lisible depuis n'importe quelle
# fonction statique, sans variable statique (Godot 4.1+).
const META: StringName = &"debug_menu_language"


static func t(text: String) -> String:
	if get_language() == "fr":
		return FR.TEXTS.get(text, text)
	return text


static func get_language() -> String:
	return Engine.get_meta(META, "en")


static func set_language(language: String) -> void:
	Engine.set_meta(META, language if LANGUAGES.has(language) else "en")
