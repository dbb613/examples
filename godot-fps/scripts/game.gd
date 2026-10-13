extends Node
## Global game state (autoloaded as `Game`).
## Holds references shared by the player, enemies and level objects:
## the player node, the grid pathfinder and level statistics.

signal message(text: String, duration: float)
signal exit_reached
signal kill_registered

const CELL := 3.0          # Size of one map grid cell in metres.
const WALL_HEIGHT := 3.6

# Physics layers (bit values).
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4

var player: CharacterBody3D = null
var astar: AStarGrid2D = null
var kills := 0
var total_enemies := 0


func reset_stats() -> void:
	kills = 0
	total_enemies = 0


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


func cell_to_world(c: Vector2i, y := 0.0) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, y, (c.y + 0.5) * CELL)


## Returns world-space waypoints (cell centres) from `from` to `to`,
## or an empty array when no path exists.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	if astar == null:
		return out
	var a := world_to_cell(from)
	var b := world_to_cell(to)
	if not astar.is_in_boundsv(a) or not astar.is_in_boundsv(b):
		return out
	if astar.is_point_solid(a) or astar.is_point_solid(b):
		return out
	for c in astar.get_id_path(a, b):
		out.append(cell_to_world(c))
	return out


func set_cell_solid(c: Vector2i, solid: bool) -> void:
	if astar and astar.is_in_boundsv(c):
		astar.set_point_solid(c, solid)


## Wakes every enemy within `radius` metres (used for gunfire noise).
func alert_enemies(pos: Vector3, radius: float) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(pos) < radius:
			e.alert()


func register_kill() -> void:
	kills += 1
	kill_registered.emit()


func show_message(text: String, duration := 2.5) -> void:
	message.emit(text, duration)


## Small burst of particles where a bullet lands.
func spawn_impact(parent: Node, pos: Vector3, normal: Vector3, flesh: bool) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 10 if flesh else 6
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.direction = normal if normal != Vector3.ZERO else Vector3.UP
	p.spread = 50.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.05
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.7, 0.05, 0.05) if flesh else Color(1.0, 0.85, 0.5)
	mesh.material = mat
	p.mesh = mesh
	parent.add_child(p)
	p.global_position = pos + normal * 0.02
	p.emitting = true
	get_tree().create_timer(1.0, false).timeout.connect(p.queue_free)
