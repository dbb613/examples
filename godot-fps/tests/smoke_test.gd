extends Node
## Headless end-to-end check of every level: builds it, shoots an enemy,
## takes damage, opens a door, uses the keycard and reaches the exit.
## Run: godot --headless --path . --fixed-fps 60 res://tests/smoke_test.tscn

const Enemy = preload("res://scripts/enemy.gd")
const Levels = preload("res://scripts/levels.gd")
const MapGrid = preload("res://scripts/map_grid.gd")

var failures := 0


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(5)
	for i in Levels.LEVELS.size():
		await _test_level(main, i)
	print("SMOKE TEST %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _test_level(main: Node, index: int) -> void:
	var tag := "level %d" % (index + 1)
	main.start_level(index)
	main._resume()
	await _frames(10)
	var player = Game.player
	_check(player != null, tag + ": player spawned")
	_check(Game.total_enemies > 0 and get_tree().get_nodes_in_group("enemies").size() == Game.total_enemies,
		tag + ": %d enemies spawned" % Game.total_enemies)

	# Put a grunt 5 m in front of the player and shoot it.
	var forward: Vector3 = -player.global_transform.basis.z
	var target := Enemy.new("grunt")
	main.level_root.add_child(target)
	target.global_position = player.global_position + forward * 5.0
	player.head.rotation.x = -0.1
	await _frames(3)
	var hp_before: int = target.hp
	player._select_weapon(2)
	player._switch_t = 0.0
	player.shoot()
	await _frames(1)
	_check(target.hp < hp_before, tag + ": rifle hit damages enemy (%d -> %d)" % [hp_before, target.hp])
	_check(target.state == target.State.HUNT, tag + ": shot enemy is alerted")

	# Let it close in and attack.
	await _frames(150)
	_check(player.health < 100, tag + ": enemy melee damages player (hp %d)" % player.health)
	for n in 20:
		if target.state == target.State.DEAD:
			break
		player.weapons[2].mag = 30
		player.look_at(target.global_position, Vector3.UP)
		player.rotation.x = 0
		player.rotation.z = 0
		player.head.rotation.x = -0.25
		player.shoot()
		await _frames(2)
	_check(target.state == target.State.DEAD, tag + ": enemy can be killed")

	# Neutralise the rest of the level so the traversal checks are deterministic.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.take_damage(10000)
	player.health = 100

	var rows := MapGrid.parse(Levels.LEVELS[index].map)
	var doors := _cells(rows, "d")
	if not doors.is_empty():
		var door_cell: Vector2i = doors[0]
		var door_node := _door_at(main.level_root, door_cell)
		player.global_position = Game.cell_to_world(door_cell) + _door_offset(rows, door_cell)
		player.velocity = Vector3.ZERO
		await _frames(90)
		_check(door_node != null and door_node._open > 0.9, tag + ": door opens when the player is near")

	var locked := _cells(rows, "D")
	if not locked.is_empty():
		var key_cells := _cells(rows, "k")
		_check(not Game.find_path(Game.cell_to_world(_cells(rows, "P")[0]), Game.cell_to_world(key_cells[0])).is_empty(),
			tag + ": enemies can path from start to keycard")
		player.global_position = Game.cell_to_world(key_cells[0])
		await _frames(10)
		_check(player.has_key, tag + ": keycard picked up")
		var locked_node := _door_at(main.level_root, locked[0])
		player.global_position = Game.cell_to_world(locked[0]) + _door_offset(rows, locked[0])
		await _frames(120)
		_check(not locked_node.locked and locked_node._open > 0.9, tag + ": locked door opens with keycard")
		_check(not Game.astar.is_point_solid(locked[0]), tag + ": unlocked door is walkable for enemies")

	var exited := [false]
	var cb := func(): exited[0] = true
	Game.exit_reached.connect(cb)
	player.global_position = Game.cell_to_world(_cells(rows, "E")[0]) + Vector3(0, 0.2, 0)
	await _frames(15)
	Game.exit_reached.disconnect(cb)
	_check(exited[0] and get_tree().paused, tag + ": exit pad completes the level")


func _door_offset(rows: PackedStringArray, c: Vector2i) -> Vector3:
	# Stand in the open cell next to the door, not inside the slab.
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var ch := MapGrid.char_at(rows, c.x + d.x, c.y + d.y)
		if ch != "#":
			return Vector3(d.x, 0, d.y) * (Game.CELL * 0.75)
	return Vector3.ZERO


func _door_at(root: Node, c: Vector2i) -> Node:
	for n in root.get_children():
		if n.get("cell") == c and n.has_method("_unlock"):
			return n
	return null


func _cells(rows: PackedStringArray, ch: String) -> Array:
	var out := []
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == ch:
				out.append(Vector2i(x, y))
	return out


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
