extends SceneTree
## Checks every map in levels.gd for mistakes that would make it unplayable.
## Run: godot --headless --path . -s res://tests/validate_levels.gd

const Levels = preload("res://scripts/levels.gd")
const MapGrid = preload("res://scripts/map_grid.gd")

const KNOWN := "#.PEdDkhagsb"


func _initialize() -> void:
	var failures := 0
	for i in Levels.LEVELS.size():
		var level: Dictionary = Levels.LEVELS[i]
		var errors := _check(level.map)
		if errors.is_empty():
			print("OK    level %d (%s)" % [i + 1, level.name])
		else:
			failures += 1
			for e in errors:
				print("FAIL  level %d (%s): %s" % [i + 1, level.name, e])
	quit(1 if failures > 0 else 0)


func _check(map_text: String) -> Array[String]:
	var errors: Array[String] = []
	var raw := map_text.strip_edges().split("\n")
	var width := raw[0].strip_edges().length()
	for y in raw.size():
		if raw[y].strip_edges().length() != width:
			errors.append("row %d has length %d, expected %d" % [y, raw[y].strip_edges().length(), width])
	var rows := MapGrid.parse(map_text)
	var h := rows.size()

	var counts := {}
	var cells := {}
	for y in h:
		for x in width:
			var c := rows[y][x]
			if not KNOWN.contains(c):
				errors.append("unknown character '%s' at (%d, %d)" % [c, x, y])
			if (x == 0 or y == 0 or x == width - 1 or y == h - 1) and c != "#":
				errors.append("border cell (%d, %d) is not a wall" % [x, y])
			counts[c] = counts.get(c, 0) + 1
			if not cells.has(c):
				cells[c] = []
			cells[c].append(Vector2i(x, y))
			if c == "d" or c == "D":
				var horiz := MapGrid.char_at(rows, x - 1, y) == "#" and MapGrid.char_at(rows, x + 1, y) == "#"
				var vert := MapGrid.char_at(rows, x, y - 1) == "#" and MapGrid.char_at(rows, x, y + 1) == "#"
				if not (horiz or vert):
					errors.append("door at (%d, %d) is not between two walls" % [x, y])
	for c in ["P", "E"]:
		if counts.get(c, 0) != 1:
			errors.append("expected exactly one '%s', found %d" % [c, counts.get(c, 0)])
	if not errors.is_empty():
		return errors

	var start: Vector2i = cells["P"][0]
	var exit: Vector2i = cells["E"][0]
	var without_locked := _flood(rows, start, false)
	var has_locked: bool = counts.get("D", 0) > 0
	if has_locked:
		if counts.get("k", 0) == 0:
			errors.append("locked door 'D' but no keycard 'k'")
		elif not cells["k"].any(func(k): return without_locked.has(k)):
			errors.append("keycard is not reachable without passing a locked door")
	var full := _flood(rows, start, true)
	if not full.has(exit):
		errors.append("exit is not reachable from the start")
	for y in h:
		for x in width:
			var c := rows[y][x]
			if c != "#" and c != "." and not full.has(Vector2i(x, y)):
				errors.append("'%s' at (%d, %d) is unreachable" % [c, x, y])
	return errors


func _flood(rows: PackedStringArray, start: Vector2i, through_locked: bool) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + d
			var c := MapGrid.char_at(rows, n.x, n.y)
			if c == "#" or seen.has(n) or (c == "D" and not through_locked):
				continue
			seen[n] = true
			queue.append(n)
	return seen
