extends CanvasLayer

## Overlay des commandes de temps (Core > Time > Time controls) : un petit
## cadre en haut à gauche de l'écran avec [pause/lecture] [image +1]
## [vitesse ▾] (time_controls.gd). Visible même barre cachée, pour faire de
## l'image par image en jouant. Contrairement aux autres overlays, il est
## cliquable.

const TimeControls = preload("res://addons/debug_menu/time/time_controls.gd")
const LAYER: int = 101 # au-dessus de la barre (100)
const MARGIN: float = 8.0

var _panel: PanelContainer
var _controls: TimeControls


func _init() -> void:
	layer = LAYER
	visible = false
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(_panel)
	_controls = TimeControls.new()
	_panel.add_child(_controls)


func set_playback(playback: RefCounted) -> void:
	_controls.playback = playback


## Le thème du debug menu (le CanvasLayer ne le transmet pas tout seul).
func set_theme(theme: Theme) -> void:
	_panel.theme = theme


func _process(_delta: float) -> void:
	if not visible:
		return
	# Sous la barre quand elle est affichée, sinon tout en haut.
	var bar: Control = get_parent().get_node_or_null("Bar") as Control
	var top: float = bar.size.y if bar != null and bar.visible else 0.0
	_panel.offset_top = top + MARGIN
	_panel.offset_left = MARGIN
