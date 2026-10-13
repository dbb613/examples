extends RefCounted
## Turns an ASCII map (see levels.gd for the legend) into a playable 3D level:
## walls, floor, ceiling, lights, doors, enemies, pickups and the exit.
## Also builds the AStarGrid2D that enemies use for pathfinding.

const Enemy = preload("res://scripts/enemy.gd")
const Door = preload("res://scripts/door.gd")
const Pickup = preload("res://scripts/pickup.gd")
const ExitPad = preload("res://scripts/exit_pad.gd")
const MapGrid = preload("res://scripts/map_grid.gd")

const ENEMY_CHARS := {"g": "grunt", "s": "soldier", "b": "brute"}
const PICKUP_CHARS := {"h": "health", "a": "ammo", "k": "key"}


## Builds `level` under `root`. Returns {start_position, start_yaw, enemies}.
static func build(level: Dictionary, root: Node3D) -> Dictionary:
	var rows := MapGrid.parse(level.map)
	var h := rows.size()
	var w := rows[0].length()
	var cell := Game.CELL
	var wall_h := Game.WALL_HEIGHT
	var accent: Color = level.get("accent", Color(1.0, 0.85, 0.65))

	_add_environment(root, level)

	# Pathfinding grid.
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	Game.astar = astar

	# Floor and ceiling.
	var size := Vector3(w * cell, 0, h * cell)
	var center := Vector3(size.x / 2.0, 0, size.z / 2.0)
	var floor_mat := _grid_material(level.get("floor", Color(0.22, 0.23, 0.25)), 0.75)
	var ceil_mat := _grid_material(level.get("ceiling", Color(0.12, 0.12, 0.14)), 0.85)
	var wall_mat := _grid_material(level.get("wall", Color(0.36, 0.37, 0.4)), 0.8, true)

	# Visual floor/ceiling in 4x4-cell chunks so each piece is lit only by
	# nearby lamps (the Compatibility renderer caps lights per mesh).
	var chunk := 4
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2.ONE * chunk * cell
	floor_mesh.material = floor_mat
	var ceil_mesh := PlaneMesh.new()
	ceil_mesh.size = floor_mesh.size
	ceil_mesh.flip_faces = true
	ceil_mesh.material = ceil_mat
	for cy in range(0, h, chunk):
		for cx in range(0, w, chunk):
			if not _chunk_has_open(rows, cx, cy, chunk):
				continue
			var chunk_center := Vector3((cx + chunk / 2.0) * cell, 0, (cy + chunk / 2.0) * cell)
			var floor_mi := MeshInstance3D.new()
			floor_mi.mesh = floor_mesh
			floor_mi.position = chunk_center
			root.add_child(floor_mi)
			var ceil_mi := MeshInstance3D.new()
			ceil_mi.mesh = ceil_mesh
			ceil_mi.position = chunk_center + Vector3(0, wall_h, 0)
			ceil_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(ceil_mi)

	var ground := StaticBody3D.new()
	ground.collision_layer = Game.LAYER_WORLD
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(size.x, 1.0, size.z)
	var gcs := CollisionShape3D.new()
	gcs.shape = ground_shape
	ground.add_child(gcs)
	ground.position = center + Vector3(0, -0.5, 0)
	root.add_child(ground)

	var ceiling_body := StaticBody3D.new()
	ceiling_body.collision_layer = Game.LAYER_WORLD
	var ccs := CollisionShape3D.new()
	ccs.shape = ground_shape
	ceiling_body.add_child(ccs)
	ceiling_body.position = center + Vector3(0, wall_h + 0.5, 0)
	root.add_child(ceiling_body)

	# Walls: one shared mesh + shape; only cells that touch open space.
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(cell, wall_h, cell)
	wall_mesh.material = wall_mat
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(cell, wall_h, cell)
	var walls := StaticBody3D.new()
	walls.collision_layer = Game.LAYER_WORLD
	root.add_child(walls)

	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_mat.albedo_color = accent
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.9, 0.06, 0.9)
	lamp_mesh.material = lamp_mat

	var result := {start_position = Vector3.ZERO, start_yaw = 0.0, enemies = 0}

	for y in h:
		for x in w:
			var c := rows[y][x]
			var pos := Vector3((x + 0.5) * cell, 0, (y + 0.5) * cell)
			if c == "#":
				astar.set_point_solid(Vector2i(x, y), true)
				if _touches_open(rows, x, y):
					var cs := CollisionShape3D.new()
					cs.shape = wall_shape
					cs.position = pos + Vector3(0, wall_h / 2.0, 0)
					walls.add_child(cs)
					var mi := MeshInstance3D.new()
					mi.mesh = wall_mesh
					mi.position = cs.position
					root.add_child(mi)
				continue

			# Ceiling lamps on a regular lattice keep rooms readable.
			if x % 3 == 1 and y % 3 == 1:
				var lamp := MeshInstance3D.new()
				lamp.mesh = lamp_mesh
				lamp.position = pos + Vector3(0, wall_h - 0.03, 0)
				lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(lamp)
				var light := OmniLight3D.new()
				light.light_color = accent
				light.light_energy = 1.4
				light.omni_range = 9.0
				light.omni_attenuation = 1.2
				light.position = pos + Vector3(0, wall_h - 0.4, 0)
				root.add_child(light)

			match c:
				"P":
					result.start_position = pos
					result.start_yaw = _open_direction_yaw(rows, x, y)
				"E":
					var exit_pad := ExitPad.new()
					exit_pad.position = pos
					root.add_child(exit_pad)
				"d", "D":
					var along_x := MapGrid.char_at(rows, x - 1, y) == "#" and MapGrid.char_at(rows, x + 1, y) == "#"
					var door := Door.new(c == "D", along_x, Vector2i(x, y))
					door.position = pos
					root.add_child(door)
					if c == "D":
						astar.set_point_solid(Vector2i(x, y), true)
				_:
					if ENEMY_CHARS.has(c):
						var e := Enemy.new(ENEMY_CHARS[c])
						e.position = pos
						e.rotation.y = randf() * TAU
						root.add_child(e)
						result.enemies += 1
					elif PICKUP_CHARS.has(c):
						var p := Pickup.new(PICKUP_CHARS[c])
						p.position = pos
						root.add_child(p)
	return result


static func _chunk_has_open(rows: PackedStringArray, cx: int, cy: int, chunk: int) -> bool:
	for y in range(cy, cy + chunk):
		for x in range(cx, cx + chunk):
			if MapGrid.char_at(rows, x, y) != "#":
				return true
	return false


static func _touches_open(rows: PackedStringArray, x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		if MapGrid.char_at(rows, x + d.x, y + d.y) != "#":
			return true
	return false


## Faces the player down the longest open corridor from the start cell.
static func _open_direction_yaw(rows: PackedStringArray, x: int, y: int) -> float:
	var best := Vector2i(0, -1)
	var best_len := -1
	for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var n := 0
		while MapGrid.char_at(rows, x + d.x * (n + 1), y + d.y * (n + 1)) not in ["#", "d", "D"]:
			n += 1
		if n > best_len:
			best_len = n
			best = d
	return atan2(-float(best.x), -float(best.y))


static func _add_environment(root: Node3D, level: Dictionary) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = level.get("ambient", Color(0.35, 0.38, 0.45))
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = env.background_color
	env.fog_density = 0.02
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)


## Tiled panel texture generated at runtime (no image files needed).
static func _grid_material(base: Color, roughness: float, panels := false) -> StandardMaterial3D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(base.r * 1000 + base.g * 100 + base.b * 10)
	for y in n:
		for x in n:
			var v := rng.randf_range(-0.025, 0.025)
			img.set_pixel(x, y, Color(base.r + v, base.g + v, base.b + v))
	var line := base.darkened(0.45)
	for i in n:
		for t in 2:
			img.set_pixel(i, t, line)
			img.set_pixel(t, i, line)
		if panels:
			img.set_pixel(i, n / 2, line)
	img.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.roughness = roughness
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / Game.CELL
	return mat
