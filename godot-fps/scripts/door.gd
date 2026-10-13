extends Node3D
## Sliding door that fills one grid cell. Opens when the player or an enemy is
## near. A locked door (red) needs the keycard and blocks enemy pathfinding
## until the player unlocks it.

var locked := false
var spans_x := true   # true: the slab runs along X (blocks travel along Z).
var cell := Vector2i.ZERO

var _slab: AnimatableBody3D
var _sensor: Area3D
var _open := 0.0
var _was_moving := false
var _msg_cooldown := 0.0


func _init(is_locked := false, along_x := true, grid_cell := Vector2i.ZERO) -> void:
	locked = is_locked
	spans_x = along_x
	cell = grid_cell


func _ready() -> void:
	var w := Game.CELL
	var h := Game.WALL_HEIGHT
	var size := Vector3(w, h, 0.3) if spans_x else Vector3(0.3, h, w)

	_slab = AnimatableBody3D.new()
	_slab.collision_layer = Game.LAYER_WORLD
	_slab.collision_mask = 0
	_slab.position.y = h / 2.0
	add_child(_slab)
	var box := BoxShape3D.new()
	box.size = size
	var cs := CollisionShape3D.new()
	cs.shape = box
	_slab.add_child(cs)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.12, 0.1) if locked else Color(0.32, 0.36, 0.42)
	mat.metallic = 0.5
	mat.roughness = 0.4
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	_slab.add_child(mi)

	# A bright stripe so doors read clearly against walls.
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stripe_mat.albedo_color = Color(1.0, 0.3, 0.2) if locked else Color(0.95, 0.75, 0.2)
	var stripe := BoxMesh.new()
	stripe.size = Vector3(size.x * 0.8 if spans_x else 0.34, 0.15, 0.34 if spans_x else size.z * 0.8)
	stripe.material = stripe_mat
	var smi := MeshInstance3D.new()
	smi.mesh = stripe
	smi.position.y = 0.2
	_slab.add_child(smi)

	_sensor = Area3D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = Game.LAYER_PLAYER | Game.LAYER_ENEMY
	var sensor_shape := BoxShape3D.new()
	sensor_shape.size = Vector3(w, 2.5, w + 2.4) if spans_x else Vector3(w + 2.4, 2.5, w)
	var scs := CollisionShape3D.new()
	scs.shape = sensor_shape
	scs.position.y = 1.25
	_sensor.add_child(scs)
	add_child(_sensor)


func _physics_process(delta: float) -> void:
	_msg_cooldown -= delta
	var want_open := false
	for body in _sensor.get_overlapping_bodies():
		if body.is_in_group("player"):
			if locked:
				if body.has_key:
					_unlock(body)
				elif _msg_cooldown <= 0.0:
					_msg_cooldown = 3.0
					Game.show_message("Locked. Find the red keycard.")
					Sfx.play_at("locked", global_position)
			want_open = want_open or not locked
		elif not locked:
			want_open = true

	var target := 1.0 if want_open else 0.0
	var moving := not is_equal_approx(_open, target)
	if moving and not _was_moving:
		Sfx.play_at("door", global_position, -4.0)
	_was_moving = moving
	_open = move_toward(_open, target, delta * 1.8)
	_slab.position.y = Game.WALL_HEIGHT / 2.0 + _open * (Game.WALL_HEIGHT - 0.25)


func _unlock(player: Node) -> void:
	locked = false
	player.use_key()
	Game.set_cell_solid(cell, false)
	Game.show_message("Door unlocked")
	Sfx.play("key")
