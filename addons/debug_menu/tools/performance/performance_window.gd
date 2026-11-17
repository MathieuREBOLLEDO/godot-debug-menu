extends "res://addons/debug_menu/ui/debug_window.gd"

## Fenêtre « Performance » : une courbe par compteur (perf_monitor.gd) sur
## les 30 dernières secondes, avec la valeur actuelle. L'overlay compact se
## coche dans le menu Affichage.

const PerfMonitor = preload("res://addons/debug_menu/tools/performance/perf_monitor.gd")
const HistoryGraph = preload("res://addons/debug_menu/objects/inspector/history_graph.gd")
const GRAPH_HEIGHT: float = 70.0
const REFRESH_INTERVAL: float = 0.25

var _monitor: PerfMonitor
var _titles: Dictionary = {} # clé -> Label
var _graphs: Dictionary = {} # clé -> HistoryGraph
var _refresh_time: float = 0.0


func _ready() -> void:
	if get_debug_menu() != null:
		_monitor = get_debug_menu().get("perf_monitor")
	super()


func _process(delta: float) -> void:
	_refresh_time += delta
	if _monitor != null and visible and _refresh_time >= REFRESH_INTERVAL:
		_refresh_time = 0.0
		var now: float = PerfMonitor.now_seconds()
		for metric in PerfMonitor.METRICS:
			var key: String = metric[0]
			(_titles[key] as Label).text = T.t("%s: %s") % [T.t(metric[1]), _monitor.format_value(key)]
			(_graphs[key] as HistoryGraph).show_entries(_monitor.history[key], now, PerfMonitor.HISTORY_DURATION)
	super(delta)


func _build() -> void:
	if _monitor == null:
		add_note(T.t("DebugMenu not found: this window needs the addon to be active."))
		return
	add_hint(T.t("Last %d seconds. Compact overlay: Display menu.") % int(PerfMonitor.HISTORY_DURATION))
	for metric in PerfMonitor.METRICS:
		_titles[metric[0]] = add_section(T.t(metric[1]))
		var graph: HistoryGraph = HistoryGraph.new()
		graph.custom_minimum_size.y = GRAPH_HEIGHT
		_graphs[metric[0]] = add_custom(graph)
