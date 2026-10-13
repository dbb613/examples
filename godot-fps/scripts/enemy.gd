extends CharacterBody3D
## Enemy AI. Idles until it sees or hears the player, then hunts them along the
## level grid (AStarGrid2D) and attacks in melee or with projectiles.

const Projectile = preload("res://scripts/projectile.gd")
const Pickup = preload("res://scripts/pickup.gd")

const TYPES := {
	"grunt": {hp = 60, speed = 4.3, color = Color(0.72, 0.2, 0.17), size = 1.0,
		melee = true, damage = 10, attack_range = 1.7, cooldown = 0.9, sight = 30.0},
	"soldier": {hp = 80, speed = 3.2, color = Color(0.42, 0.3, 0.72), size = 1.0,
		melee = false, damage = 9, attack_range = 20.0, cooldown = 1.5, sight = 35.0},
	"brute": {hp = 340, speed = 2.6, color = Color(0.85, 0.52, 0.14), size = 1.45,
		melee = true, damage = 28, attack_range = 2.5, cooldown = 1.4, sight = 30.0},
}

enum State { IDLE, HUNT, DEAD }

var kind := "grunt"
var cfg: Dictionary
var hp := 0
var state := State.IDLE

var _mat: StandardMaterial3D
var _path := PackedVector3Array()
var _path_i := 0
var _repath_t := 0.0
var _attack_t := 0.0
var _los_t := 0.0
var _sees_player := false
var _flash := 0.0
var _strafe := 1.0


func _init(enemy_kind := "grunt") -> void:
	kind = enemy_kind


func _ready() -> void:
	cfg = TYPES[kind]
	hp = cfg.hp
	add_to_group("enemies")
	collision_layer = Game.LAYER_ENEMY
	collision_mask = Game.LAYER_WORLD | Game.LAYER_PLAYER | Game.LAYER_ENEMY
	_strafe = 1.0 if randf() < 0.5 else -1.0
	_attack_t = randf_range(0.3, 1.0)

	var s: float = cfg.size
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4 * s
	shape.height = 1.95 * s
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.975 * s
	add_child(cs)

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = cfg.color
	_mat.roughness = 0.6
	_mat.emission_enabled = true
	_mat.emission = Color(1, 1, 1)
	_mat.emission_energy_multiplier = 0.0

	var body := CapsuleMesh.new()
	body.radius = 0.4 * s
	body.height = 1.5 * s
	body.material = _mat
	_add_mesh(body, Vector3(0, 0.75 * s, 0))
	var head := SphereMesh.new()
	head.radius = 0.25 * s
	head.height = 0.5 * s
	head.material = _mat
	_add_mesh(head, Vector3(0, 1.7 * s, 0))

	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(1.0, 0.9, 0.2) if kind != "soldier" else Color(0.3, 1.0, 1.0)
	for x in [-0.09, 0.09]:
		var eye := BoxMesh.new()
		eye.size = Vector3(0.07, 0.04, 0.03) * s
		eye.material = eye_mat
		_add_mesh(eye, Vector3(x * s, 1.74 * s, -0.22 * s))

	if not cfg.melee:
		var gun := BoxMesh.new()
		gun.size = Vector3(0.08, 0.1, 0.6)
		var gun_mat := StandardMaterial3D.new()
		gun_mat.albedo_color = Color(0.15, 0.15, 0.17)
		gun.material = gun_mat
		_add_mesh(gun, Vector3(0.32, 1.1, -0.35))


func _add_mesh(mesh: Mesh, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y -= 16.0 * delta

	_flash = move_toward(_flash, 0.0, delta * 8.0)
	_mat.emission_energy_multiplier = _flash * 2.0

	var player := Game.player
	if player == null or player.dead:
		_stop(delta)
		return

	var to_player := player.global_position - global_position
	to_player.y = 0
	var dist := to_player.length()

	_los_t -= delta
	if _los_t <= 0.0:
		_los_t = 0.2
		_sees_player = dist < cfg.sight and _has_line_of_sight(player)
		if _sees_player and state == State.IDLE:
			alert()

	if state == State.IDLE:
		_stop(delta)
		return

	_attack_t -= delta
	var move_dir := Vector3.ZERO
	var speed: float = cfg.speed

	if cfg.melee:
		if dist <= cfg.attack_range:
			if _attack_t <= 0.0:
				_attack_t = cfg.cooldown
				player.take_damage(cfg.damage, global_position)
				Sfx.play_at("melee", global_position)
		else:
			move_dir = _chase_direction(player, dist, delta)
	else:
		if _sees_player and dist <= cfg.attack_range:
			if _attack_t <= 0.0:
				_attack_t = cfg.cooldown * randf_range(0.8, 1.3)
				_fire_at(player)
			# Keep some distance and strafe while shooting.
			var side := to_player.normalized().cross(Vector3.UP) * _strafe
			move_dir = side * 0.6
			if dist < 7.0:
				move_dir -= to_player.normalized()
			if randf() < delta * 0.4:
				_strafe = -_strafe
			speed *= 0.6
		else:
			move_dir = _chase_direction(player, dist, delta)

	if _sees_player:
		_face(to_player)
	elif move_dir != Vector3.ZERO:
		_face(move_dir)

	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed
	move_and_slide()


func _stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 20 * delta)
	velocity.z = move_toward(velocity.z, 0, 20 * delta)
	move_and_slide()


func _chase_direction(player: Node3D, dist: float, delta: float) -> Vector3:
	var target := player.global_position
	if not (_sees_player and dist < 8.0):
		_repath_t -= delta
		if _repath_t <= 0.0 or _path_i >= _path.size():
			_repath_t = 0.5
			_path = Game.find_path(global_position, player.global_position)
			_path_i = 1 if _path.size() > 1 else 0
		while _path_i < _path.size() - 1 and _flat_dist(_path[_path_i]) < 0.6:
			_path_i += 1
		if _path_i < _path.size():
			target = _path[_path_i]
	var d := target - global_position
	d.y = 0
	return d.normalized() if d.length() > 0.05 else Vector3.ZERO


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _face(dir: Vector3) -> void:
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 0.25)


func _eye_position() -> Vector3:
	return global_position + Vector3(0, 1.6 * cfg.size, 0)


func _has_line_of_sight(player: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(_eye_position(), player.global_position + Vector3(0, 1.4, 0),
		Game.LAYER_WORLD | Game.LAYER_PLAYER, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.collider == player


func _fire_at(player: Node3D) -> void:
	var muzzle := global_position + Vector3(0, 1.15, 0) + (-global_transform.basis.z) * 0.7
	var aim: Vector3 = player.global_position + Vector3(0, 1.2, 0) + player.velocity * 0.15
	aim += Vector3(randf_range(-0.6, 0.6), randf_range(-0.3, 0.3), randf_range(-0.6, 0.6))
	var p := Projectile.new()
	p.velocity = (aim - muzzle).normalized() * 17.0
	p.damage = cfg.damage
	get_parent().add_child(p)
	p.global_position = muzzle
	Sfx.play_at("enemy_shot", muzzle, -4.0)


## Wake up and start hunting the player.
func alert() -> void:
	if state == State.IDLE:
		state = State.HUNT
		_repath_t = 0.0
		Sfx.play_at("alert", global_position, -6.0)


func is_headshot(hit_pos: Vector3) -> bool:
	return hit_pos.y - global_position.y > 1.45 * cfg.size


## Applies damage. Returns true if this hit killed the enemy.
func take_damage(amount: int, dir := Vector3.ZERO) -> bool:
	if state == State.DEAD:
		return false
	hp -= amount
	_flash = 1.0
	alert()
	velocity += Vector3(dir.x, 0, dir.z) * 2.0 / cfg.size
	if hp <= 0:
		_die()
		return true
	return false


func _die() -> void:
	state = State.DEAD
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	_mat.emission_energy_multiplier = 0.0
	Sfx.play_at("enemy_death", global_position)
	Game.register_kill()

	var roll := randf()
	if roll < 0.25:
		_drop("health")
	elif roll < 0.55:
		_drop("ammo")

	var tw := create_tween()
	tw.tween_property(self, "rotation:x", PI / 2.0, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(self, "position:y", position.y + 0.35 * cfg.size, 0.45)
	tw.tween_interval(6.0)
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.6)
	tw.tween_callback(queue_free)


func _drop(pickup_kind: String) -> void:
	var p := Pickup.new(pickup_kind)
	get_parent().add_child(p)
	p.global_position = Vector3(global_position.x, 0.0, global_position.z)
