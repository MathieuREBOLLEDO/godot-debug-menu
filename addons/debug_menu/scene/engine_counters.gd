extends RefCounted
const T = preload("res://addons/debug_menu/i18n/t.gd")

## Compteurs de Godot pour tout le jeu (debug menu compris), en une ligne.


static func text() -> String:
	return T.t("Objects %d · Nodes %d · Orphans %d · Resources %d · Memory %.1f MB") % [
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
	]
