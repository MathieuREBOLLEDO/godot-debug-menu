extends RefCounted

## Commandes fournies par le debug menu (le jeu ajoute les siennes avec
## DebugMenu.add_command). Descriptions en anglais, traduites à l'affichage.

const NodeFinder = preload("res://addons/debug_menu/selection/node_finder.gd")
const T = preload("res://addons/debug_menu/i18n/t.gd")


static func register(debug_menu: Node) -> void:
	var console: Node = debug_menu.get("console")
	var playback: RefCounted = debug_menu.get("playback")
	var selection: Node = debug_menu.get("selection")
	var tree: SceneTree = debug_menu.get_tree()

	console.call("add_command", "help", func(args: PackedStringArray) -> String: return _help(console, args),
			"List the commands, or describe one", "[command]")
	console.call("add_command", "clear", func(_args: PackedStringArray) -> void: console.call("clear"),
			"Clear the console")
	console.call("add_command", "pause", func(_args: PackedStringArray) -> void: playback.call("set_paused", true),
			"Pause the game")
	console.call("add_command", "resume", func(_args: PackedStringArray) -> void: playback.call("set_paused", false),
			"Resume the game")
	console.call("add_command", "step", func(_args: PackedStringArray) -> void: playback.call("step"),
			"Advance one frame (pauses first if needed)")
	console.call("add_command", "speed", func(args: PackedStringArray) -> String: return _speed(playback, args),
			"Show or set the game speed", "[x]")
	console.call("add_command", "reload", func(_args: PackedStringArray) -> void: debug_menu.call("reload_scene"),
			"Reload the current scene")
	console.call("add_command", "seed", func(args: PackedStringArray) -> String: return _seed(debug_menu.get("random_seed"), args),
			"Show the random seed, fix it, or go back to a random one", "[value | random]")
	console.call("add_command", "snapshot", func(args: PackedStringArray) -> String: return _snapshot(debug_menu.get("snapshots"), args),
			"Take a snapshot of the scene", "[name]")
	console.call("add_command", "restore", func(args: PackedStringArray) -> String: return _restore(debug_menu.get("snapshots"), args),
			"Restore a snapshot (the last one by default)", "[n]")
	console.call("add_command", "select", func(args: PackedStringArray) -> String: return _select(tree, selection, args),
			"Select the first node whose name contains this text", "<name>")
	console.call("add_command", "tp", func(args: PackedStringArray) -> String: return _teleport(selection, args),
			"Move the selected node to a position", "<x> <y> [z]")
	console.call("add_command", "screenshot", func(_args: PackedStringArray) -> void: debug_menu.call("take_screenshot"),
			"Save a screenshot of the game")
	console.call("add_command", "quit", func(_args: PackedStringArray) -> void: tree.quit(),
			"Quit the game")


static func _help(console: Node, args: PackedStringArray) -> String:
	if not args.is_empty():
		var description: String = console.call("describe", args[0])
		return description if description != "" else T.t("Unknown command: %s (type help)") % args[0]
	var lines: PackedStringArray = PackedStringArray()
	for command_name in console.call("get_command_names"):
		lines.append(console.call("describe", command_name))
	return "\n".join(lines)


static func _speed(playback: RefCounted, args: PackedStringArray) -> String:
	if args.is_empty() or not args[0].is_valid_float():
		return T.t("Speed: x%s") % str(playback.get("speed"))
	playback.set("speed", clampf(args[0].to_float(), 0.0, 10.0))
	return T.t("Speed: x%s") % str(playback.get("speed"))


static func _seed(random_seed: RefCounted, args: PackedStringArray) -> String:
	if not args.is_empty() and args[0] == "random":
		random_seed.call("set_fixed", false, random_seed.call("get_fixed_value"))
	elif not args.is_empty() and args[0].is_valid_int():
		random_seed.call("set_fixed", true, args[0].to_int())
	elif not args.is_empty():
		return T.t("Usage: %s") % "seed [value | random]"
	var fixed_text: String = T.t("fixed") if random_seed.call("is_fixed") else T.t("random on each reload")
	return T.t("Seed: %d (%s)") % [random_seed.get("current"), fixed_text]


static func _snapshot(snapshots: Node, args: PackedStringArray) -> String:
	var snapshot: RefCounted = snapshots.call("take", " ".join(args))
	if snapshot == null:
		return T.t("No scene to take.")
	return T.t("Snapshot taken: %s (%d)") % [snapshot.get("snapshot_name"), snapshots.call("get_list").size()]


static func _restore(snapshots: Node, args: PackedStringArray) -> String:
	var count: int = snapshots.call("get_list").size()
	if count == 0:
		return T.t("No snapshot yet (snapshot command).")
	var number: int = args[0].to_int() if not args.is_empty() and args[0].is_valid_int() else count
	if number < 1 or number > count:
		return T.t("Usage: %s") % "restore [1-%d]" % count
	snapshots.call("restore", number - 1)
	return T.t("Restoring snapshot %d.") % number


static func _select(tree: SceneTree, selection: Node, args: PackedStringArray) -> String:
	if args.is_empty():
		return T.t("Usage: %s") % "select <name>"
	var found: Array[Node] = NodeFinder.search(tree, " ".join(args))
	if found.is_empty():
		return T.t("No node named like \"%s\".") % " ".join(args)
	selection.call("select", found[0])
	return T.t("Selected: %s") % found[0].get_path()


static func _teleport(selection: Node, args: PackedStringArray) -> String:
	var node: Object = selection.call("get_selected")
	if not (node is Node2D or node is Node3D):
		return T.t("Select a 2D or 3D node first.")
	if args.size() < 2 or not args[0].is_valid_float() or not args[1].is_valid_float():
		return T.t("Usage: %s") % "tp <x> <y> [z]"
	if node is Node2D:
		(node as Node2D).global_position = Vector2(args[0].to_float(), args[1].to_float())
	else:
		var z: float = args[2].to_float() if args.size() > 2 else (node as Node3D).global_position.z
		(node as Node3D).global_position = Vector3(args[0].to_float(), args[1].to_float(), z)
	return T.t("%s moved to %s") % [(node as Node).name, str(node.get("global_position"))]
