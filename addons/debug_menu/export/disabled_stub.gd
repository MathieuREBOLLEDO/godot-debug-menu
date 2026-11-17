extends Node

## Remplace DebugMenu dans un export « strip_debug_menu » (les fichiers de
## l'addon n'y sont pas) : se retire au lancement, comme DebugMenu.disable().

func _ready() -> void:
	name = "DebugMenuDisabled"
	queue_free()