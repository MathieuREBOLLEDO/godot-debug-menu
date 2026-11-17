extends Node

## Relevés de performance (enfant de DebugMenu, DebugMenu.perf_monitor) :
## toutes les SAMPLE_INTERVAL secondes (temps réel), les compteurs de Godot
## (Performance) sont lus et gardés HISTORY_DURATION secondes, pour l'overlay
## (perf_overlay.gd) et les courbes de la fenêtre Performance.

const SAMPLE_INTERVAL: float = 0.25
const HISTORY_DURATION: float = 30.0
## [clé, libellé (anglais, traduit à l'affichage), format].
const METRICS: Array = [
	["fps", "FPS", "%.0f"],
	["frame_ms", "Frame time (ms)", "%.2f"],
	["physics_ms", "Physics time (ms)", "%.2f"],
	["draw_calls", "Draw calls", "%.0f"],
	["nodes", "Nodes", "%.0f"],
	["objects", "Objects", "%.0f"],
	["orphans", "Orphan nodes", "%.0f"],
	["memory_mb", "Memory (MB)", "%.1f"],
	["video_mb", "Video memory (MB)", "%.1f"],
]

## Dernières valeurs : clé -> nombre.
var current: Dictionary = {}
## Historique : clé -> Array de [temps, valeur], du plus ancien au plus récent.
var history: Dictionary = {}

var _last_sample: float = -INF # premier relevé tout de suite


func _ready() -> void:
	for metric in METRICS:
		history[metric[0]] = []


func _process(_delta: float) -> void:
	# Temps réel : les relevés continuent au ralenti ou en pause.
	var now: float = now_seconds()
	if now - _last_sample < SAMPLE_INTERVAL:
		return
	_last_sample = now
	current = {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"frame_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"video_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
	}
	for key in current:
		var entries: Array = history[key]
		entries.append([now, current[key]])
		while entries.size() > 1 and entries[0][0] < now - HISTORY_DURATION:
			entries.pop_front()


## Valeur formatée de [param key] (« 60 », « 16.67 »...).
func format_value(key: String) -> String:
	for metric in METRICS:
		if metric[0] == key:
			return metric[2] % float(current.get(key, 0.0))
	return ""


static func now_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
