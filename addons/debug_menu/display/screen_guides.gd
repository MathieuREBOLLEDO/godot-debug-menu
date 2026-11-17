extends CanvasLayer

## Repères d'écran (menu Display), pour vérifier l'interface sur mobile :
## - safe area : la zone sûre de l'écran (hors encoche, coins arrondis,
##   barre système), donnée par DisplayServer ; le reste est assombri.
##   Sur ordinateur, c'est la zone de l'écran hors barre des tâches ;
## - formats : le plus grand cadre centré au format 16:9, 4:3, 19.5:9 ou
##   21:9 (tourné si le jeu est en portrait), pour voir ce qui serait coupé
##   ou ajouté sur un autre écran.
## Fixe à l'écran (ne suit pas la caméra), sous les fenêtres du debug menu.

const T = preload("res://addons/debug_menu/i18n/t.gd")
const LAYER: int = 101
const RATIOS: Array = [ # [nom, largeur / hauteur, couleur]
	["16:9", 16.0 / 9.0, Color(0.3, 0.8, 1.0)],
	["4:3", 4.0 / 3.0, Color(1.0, 0.8, 0.2)],
	["19.5:9", 19.5 / 9.0, Color(1.0, 0.4, 0.8)],
	["21:9", 21.0 / 9.0, Color(0.6, 1.0, 0.4)],
]
const SAFE_COLOR: Color = Color(0.3, 1.0, 0.5)
const UNSAFE_COLOR: Color = Color(1.0, 0.2, 0.2, 0.25)
const FONT_SIZE: int = 14
const LINE_WIDTH: float = 2.0

var show_safe_area: bool = false:
	set(value):
		show_safe_area = value
		_update()

var _shown_ratios: Dictionary = {} # nom -> true
var _canvas: Control


func _init() -> void:
	layer = LAYER
	visible = false
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_guides)
	_canvas.resized.connect(_canvas.queue_redraw)
	add_child(_canvas)


func is_ratio_shown(ratio_name: String) -> bool:
	return _shown_ratios.has(ratio_name)


func set_ratio_shown(ratio_name: String, shown: bool) -> void:
	if shown:
		_shown_ratios[ratio_name] = true
	else:
		_shown_ratios.erase(ratio_name)
	_update()


## Zone sûre en coordonnées du jeu (Rect2() si inconnue).
func get_safe_rect() -> Rect2:
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if safe.size == Vector2i.ZERO:
		return Rect2()
	# Écran -> fenêtre -> coordonnées du jeu (étirement de l'affichage compris).
	var window_rect: Rect2 = Rect2(safe.position - DisplayServer.window_get_position(), safe.size)
	var to_game: Transform2D = _canvas.get_viewport().get_screen_transform().affine_inverse()
	return (to_game * window_rect).intersection(Rect2(Vector2.ZERO, _canvas.size))


func _update() -> void:
	visible = show_safe_area or not _shown_ratios.is_empty()
	_canvas.queue_redraw()


func _draw_guides() -> void:
	var area: Rect2 = Rect2(Vector2.ZERO, _canvas.size)
	var font: Font = ThemeDB.fallback_font
	var label_row: int = 0
	for ratio in RATIOS:
		if not _shown_ratios.has(ratio[0]):
			continue
		var frame: Rect2 = _fit(area, ratio[1])
		_canvas.draw_rect(frame, ratio[2], false, LINE_WIDTH)
		label_row += 1
		_canvas.draw_string(font, frame.position + Vector2(6, FONT_SIZE * label_row + 4), ratio[0],
				HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, ratio[2])
	if show_safe_area:
		var safe: Rect2 = get_safe_rect()
		if safe.has_area():
			_draw_outside(area, safe)
			_canvas.draw_rect(safe, SAFE_COLOR, false, LINE_WIDTH)
			_canvas.draw_string(font, safe.end - Vector2(90, 6), T.t("Safe area"), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, SAFE_COLOR)


# Plus grand cadre centré de rapport [param ratio] dans [param area] ; le
# rapport est inversé si l'écran est en portrait.
static func _fit(area: Rect2, ratio: float) -> Rect2:
	if area.size.y > area.size.x:
		ratio = 1.0 / ratio
	var size: Vector2 = area.size
	if size.x / size.y > ratio:
		size.x = size.y * ratio
	else:
		size.y = size.x / ratio
	return Rect2(area.position + (area.size - size) / 2.0, size)


# Assombrit ce qui est hors de la zone sûre (4 bandes).
func _draw_outside(area: Rect2, safe: Rect2) -> void:
	_canvas.draw_rect(Rect2(area.position, Vector2(area.size.x, safe.position.y)), UNSAFE_COLOR)
	_canvas.draw_rect(Rect2(0, safe.end.y, area.size.x, area.end.y - safe.end.y), UNSAFE_COLOR)
	_canvas.draw_rect(Rect2(0, safe.position.y, safe.position.x, safe.size.y), UNSAFE_COLOR)
	_canvas.draw_rect(Rect2(safe.end.x, safe.position.y, area.end.x - safe.end.x, safe.size.y), UNSAFE_COLOR)
