extends CanvasLayer

## Overlay de performance (menu Affichage) : un petit cadre en haut à droite
## de l'écran avec les valeurs de perf_monitor.gd. Visible même barre cachée,
## pour jouer en le gardant sous les yeux.

const T = preload("res://addons/debug_menu/i18n/t.gd")
const PerfMonitor = preload("res://addons/debug_menu/tools/performance/perf_monitor.gd")
const LAYER: int = 101 # au-dessus de la barre (100)
const MARGIN: float = 8.0
const SHOWN: Array[String] = ["fps", "frame_ms", "draw_calls", "nodes", "objects", "memory_mb"]

var monitor: PerfMonitor
var _panel: PanelContainer
var _label: Label


func _init() -> void:
	layer = LAYER
	visible = false
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_panel)
	_label = Label.new()
	_label.theme_type_variation = "DebugPanelNote"
	_panel.add_child(_label)


## Le thème du debug menu (le CanvasLayer ne le transmet pas tout seul).
func set_theme(theme: Theme) -> void:
	_panel.theme = theme


func _process(_delta: float) -> void:
	if not visible or monitor == null:
		return
	var lines: PackedStringArray = PackedStringArray()
	for metric in PerfMonitor.METRICS:
		if SHOWN.has(metric[0]):
			lines.append("%s  %s" % [T.t(metric[1]), monitor.call("format_value", metric[0])])
	_label.text = "\n".join(lines)
	# Sous la barre quand elle est affichée, sinon tout en haut.
	var bar: Control = get_parent().get_node_or_null("Bar") as Control
	var top: float = bar.size.y if bar != null and bar.visible else 0.0
	_panel.offset_top = top + MARGIN
	_panel.offset_right = -MARGIN
