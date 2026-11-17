extends "res://addons/debug_menu/ui/debug_window.gd"

## Fenêtre « Dithering settings » (Core > Display > Dithering) : réglages du
## tramage de l'écran (display/dithering.gd).

var _dithering: Node = null


func _ready() -> void:
	if get_debug_menu() != null:
		_dithering = get_debug_menu().get("dithering")
	super()


func _build() -> void:
	if _dithering == null:
		add_note(T.t("DebugMenu not found: this window needs the addon to be active."))
		return
	add_check(T.t("Dithering on"), func() -> bool: return _dithering.visible, func(on: bool) -> void: _dithering.visible = on)
	add_hint(T.t("A filter over the whole game (not over the debug menu): try a dithered look without changing the game. Same as the Dithering box of the menu."))

	add_section(T.t("Pattern"))
	var sizes: Array = []
	for size in _dithering.MATRIX_SIZES:
		sizes.append("%d × %d" % [size, size])
	add_option(T.t("Bayer matrix"), sizes, _dithering.MATRIX_SIZES.find(_dithering.call("get_value", "matrix_size")), func(index: int) -> void:
		_dithering.call("set_value", "matrix_size", _dithering.MATRIX_SIZES[index]))
	add_hint(T.t("Bigger matrix: smoother gradients, finer pattern."))
	_value_slider("levels", T.t("Levels per channel"), 2.0, 32.0, 1.0)
	add_hint(T.t("Number of shades kept for each color (or gray). 2: one bit."))
	_value_slider("pixel_size", T.t("Pixel size"), 1.0, 8.0, 1.0)
	_value_slider("spread", T.t("Dither strength"), 0.0, 2.0, 0.05)
	add_hint(T.t("0: plain color reduction (bands); 1: classic ordered dithering."))

	add_section(T.t("Palette"))
	var palettes: Array = []
	for palette in _dithering.PALETTES:
		palettes.append(T.t(palette))
	add_option(T.t("Palette"), palettes, _dithering.call("get_value", "palette_mode"), func(index: int) -> void:
		_dithering.call("set_value", "palette_mode", index))
	add_color(T.t("Dark color"), _dithering.call("get_value", "dark_color"), false, func(color: Color) -> void:
		_dithering.call("set_value", "dark_color", color))
	add_color(T.t("Light color"), _dithering.call("get_value", "light_color"), false, func(color: Color) -> void:
		_dithering.call("set_value", "light_color", color))
	add_hint(T.t("Used by the Two colors palette: shades go from the dark to the light color."))
	add_button(T.t("Reset the dithering"), func() -> void:
		_dithering.call("reset")
		rebuild())


func _value_slider(key: String, text: String, min_value: float, max_value: float, step: float) -> void:
	# Le curseur règle une copie ; chaque changement passe par set_value (enregistré).
	var holder: SliderValue = SliderValue.new()
	holder.value = _dithering.call("get_value", key)
	holder.on_changed = func(value: float) -> void: _dithering.call("set_value", key, value)
	add_slider(holder, &"value", text, min_value, max_value, step)
	_holders.append(holder)


var _holders: Array = []


class SliderValue extends RefCounted:
	var on_changed: Callable
	var value: float = 0.0:
		set(new_value):
			value = new_value
			if on_changed.is_valid():
				on_changed.call(new_value)
