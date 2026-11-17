extends CanvasLayer

## Tramage de l'écran (service Dithering, Core > Display > Dithering) : un
## filtre par-dessus le jeu (shader dithering.gdshader), sous les dessins
## et les fenêtres du debug menu, pour essayer un rendu tramé sans toucher au
## jeu. Réglages gardés d'une partie à l'autre (settings_store.gd, section
## « dithering ») ; la case du menu dit s'il est affiché.

signal changed

const LAYER: int = 97 # sous la grille (98), les dessins (99) et la barre (100)
const SHADER: Shader = preload("res://addons/debug_menu/display/dithering.gdshader")
const MATRIX_SIZES: Array = [2, 4, 8]
const PALETTES: Array = ["Colors", "Grayscale", "Two colors"]
const DEFAULTS: Dictionary = {
	"matrix_size": 4,
	"levels": 4.0,
	"pixel_size": 2.0,
	"spread": 1.0,
	"palette_mode": 0,
	"dark_color": Color(0.08, 0.09, 0.14),
	"light_color": Color(0.93, 0.85, 0.68),
}

## Réglages enregistrés (settings_store.gd) ; null hors du debug menu.
var store: Object = null
var _material: ShaderMaterial
var _values: Dictionary = DEFAULTS.duplicate()


func _init() -> void:
	layer = LAYER
	visible = false
	var rect: ColorRect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	rect.material = _material
	add_child(rect)


## Reprend les réglages enregistrés (au lancement).
func load_values(saved: Dictionary) -> void:
	for key in DEFAULTS:
		if saved.has(key) and typeof(saved[key]) == typeof(DEFAULTS[key]):
			_values[key] = saved[key]
	_apply()


func get_value(key: String) -> Variant:
	return _values[key]


func set_value(key: String, value: Variant) -> void:
	_values[key] = value
	_apply()
	_save()


func reset() -> void:
	_values = DEFAULTS.duplicate()
	_apply()
	_save()


func _apply() -> void:
	for key in _values:
		_material.set_shader_parameter(key, _values[key])
	changed.emit()


func _save() -> void:
	if store != null:
		store.set("dithering", _values.duplicate())
		store.call("save")
