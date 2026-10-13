extends CharacterBody3D
## First-person player: movement, mouse look, hitscan weapons, health and keys.
## The node tree (collision, camera, weapon models) is built in code in _ready().

signal health_changed(hp: int, max_hp: int)
signal ammo_changed(weapon_name: String, mag: int, reserve: int)
signal key_changed(has_key: bool)
signal damaged
signal hit_confirmed(headshot: bool, killed: bool)
signal died

const WALK_SPEED := 6.0
const SPRINT_SPEED := 9.5
const GROUND_ACCEL := 12.0
const AIR_ACCEL := 3.0
const JUMP_VELOCITY := 5.2
const GRAVITY := 16.0
const EYE_HEIGHT := 1.6
const MUZZLE_Z := [-0.36, -0.64, -0.73]  # Barrel tip of each weapon model.

## Mouse look sensitivity in radians per pixel.
@export var mouse_sensitivity := 0.0025

var max_health := 100
var health := 100
var has_key := false
var dead := false

## Weapon definitions. `reserve` of -1 means unlimited ammo.
## `spread` is the half-angle of the cone in degrees.
var weapons := [
	{name = "Pistol", damage = 26, pellets = 1, spread = 0.5, rate = 0.25, auto = false,
		mag_size = 12, mag = 12, reserve = -1, max_reserve = -1, reload = 1.0, sound = "pistol", recoil = 0.015},
	{name = "Shotgun", damage = 13, pellets = 9, spread = 5.0, rate = 0.85, auto = false,
		mag_size = 6, mag = 6, reserve = 18, max_reserve = 48, reload = 1.6, sound = "shotgun", recoil = 0.05},
	{name = "Rifle", damage = 19, pellets = 1, spread = 1.4, rate = 0.095, auto = true,
		mag_size = 30, mag = 30, reserve = 60, max_reserve = 240, reload = 1.5, sound = "rifle", recoil = 0.008},
]
var current := 0

var head: Node3D
var camera: Camera3D
var weapon_root: Node3D
var weapon_models: Array[Node3D] = []
var muzzle_light: OmniLight3D
var muzzle_flash: MeshInstance3D

var _fire_cd := 0.0
var _reload_t := 0.0
var _switch_t := 0.0
var _bob_t := 0.0
var _kick := 0.0
var _weapon_rest := Vector3(0.22, -0.22, -0.42)


func _ready() -> void:
	add_to_group("player")
	collision_layer = Game.LAYER_PLAYER
	collision_mask = Game.LAYER_WORLD | Game.LAYER_ENEMY

	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.9
	add_child(cs)

	head = Node3D.new()
	head.position.y = EYE_HEIGHT
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 80.0
	camera.near = 0.03
	camera.current = true
	head.add_child(camera)

	weapon_root = Node3D.new()
	weapon_root.position = _weapon_rest
	camera.add_child(weapon_root)
	weapon_models = [_build_pistol(), _build_shotgun(), _build_rifle()]
	for m in weapon_models:
		weapon_root.add_child(m)

	muzzle_flash = MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.04
	flash_mesh.height = 0.08
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = Color(1.0, 0.8, 0.35)
	flash_mesh.material = flash_mat
	muzzle_flash.mesh = flash_mesh
	muzzle_flash.visible = false
	weapon_root.add_child(muzzle_flash)

	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.75, 0.4)
	muzzle_light.omni_range = 7.0
	muzzle_light.light_energy = 0.0
	muzzle_light.position = Vector3(0, 0.05, -0.6)
	weapon_root.add_child(muzzle_light)

	_select_weapon(0, true)
	health_changed.emit(health, max_health)
	key_changed.emit(has_key)


func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, -1.5, 1.5)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select_weapon(wrapi(current - 1, 0, weapons.size()))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select_weapon(wrapi(current + 1, 0, weapons.size()))
	if event.is_action_pressed("weapon_1"):
		_select_weapon(0)
	elif event.is_action_pressed("weapon_2"):
		_select_weapon(1)
	elif event.is_action_pressed("weapon_3"):
		_select_weapon(2)
	elif event.is_action_pressed("reload"):
		start_reload()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if dead:
		velocity.x = move_toward(velocity.x, 0, 20 * delta)
		velocity.z = move_toward(velocity.z, 0, 20 * delta)
		move_and_slide()
		return

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	var w := clampf(accel * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, dir.x * speed, w)
	velocity.z = lerpf(velocity.z, dir.z * speed, w)
	move_and_slide()


func _process(delta: float) -> void:
	_update_view(delta)
	if dead:
		return
	var wpn: Dictionary = weapons[current]
	_fire_cd -= delta
	_switch_t -= delta
	if _reload_t > 0.0:
		_reload_t -= delta
		if _reload_t <= 0.0:
			_finish_reload()

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var wants_fire := Input.is_action_pressed("fire") if wpn.auto else Input.is_action_just_pressed("fire")
	if wants_fire and _fire_cd <= 0.0 and _reload_t <= 0.0 and _switch_t <= 0.0:
		if wpn.mag > 0:
			shoot()
		elif wpn.reserve != 0:
			start_reload()
		elif Input.is_action_just_pressed("fire"):
			Sfx.play("empty")
			Game.show_message("Out of %s ammo" % wpn.name, 1.2)


## Fires the current weapon. Public so tests can trigger it directly.
func shoot() -> void:
	var wpn: Dictionary = weapons[current]
	wpn.mag -= 1
	_fire_cd = wpn.rate
	_kick = 1.0
	head.rotation.x = clampf(head.rotation.x + wpn.recoil, -1.5, 1.5)
	muzzle_light.light_energy = 3.0
	muzzle_flash.visible = true
	Sfx.play(wpn.sound, -4.0)
	Game.alert_enemies(global_position, 28.0)

	var space := get_world_3d().direct_space_state
	var cam_basis := camera.global_transform.basis
	var spread := tan(deg_to_rad(wpn.spread))
	var any_hit := false
	var any_head := false
	var any_kill := false
	for i in wpn.pellets:
		var dir := -cam_basis.z
		dir += cam_basis.x * randf_range(-spread, spread) + cam_basis.y * randf_range(-spread, spread)
		dir = dir.normalized()
		var from := camera.global_position
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 150.0,
			Game.LAYER_WORLD | Game.LAYER_ENEMY, [get_rid()])
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		var col: Object = hit.collider
		var flesh: bool = col.has_method("take_damage")
		Game.spawn_impact(get_parent(), hit.position, hit.normal, flesh)
		if flesh:
			var headshot: bool = col.is_headshot(hit.position)
			var killed: bool = col.take_damage(wpn.damage * (2 if headshot else 1), dir)
			any_hit = true
			any_head = any_head or headshot
			any_kill = any_kill or killed
	if any_hit:
		hit_confirmed.emit(any_head, any_kill)
		Sfx.play("headshot" if any_head else "hit", -6.0)
	_emit_ammo()


func start_reload() -> void:
	var wpn: Dictionary = weapons[current]
	if _reload_t > 0.0 or wpn.mag >= wpn.mag_size or wpn.reserve == 0:
		return
	_reload_t = wpn.reload
	Sfx.play("reload", -6.0)


func _finish_reload() -> void:
	var wpn: Dictionary = weapons[current]
	var need: int = wpn.mag_size - wpn.mag
	var got: int = need if wpn.reserve < 0 else mini(need, wpn.reserve)
	wpn.mag += got
	if wpn.reserve > 0:
		wpn.reserve -= got
	Sfx.play("reload", -6.0)
	_emit_ammo()


func _select_weapon(index: int, force := false) -> void:
	if index == current and not force:
		return
	current = index
	_reload_t = 0.0
	_switch_t = 0.3 if not force else 0.0
	for i in weapon_models.size():
		weapon_models[i].visible = i == current
	muzzle_flash.position = Vector3(0, 0.035, MUZZLE_Z[current])
	_emit_ammo()


func _emit_ammo() -> void:
	var wpn: Dictionary = weapons[current]
	ammo_changed.emit(wpn.name, wpn.mag, wpn.reserve)


func take_damage(amount: int, _from: Vector3 = Vector3.ZERO) -> void:
	if dead:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	damaged.emit()
	Sfx.play("hurt", -3.0)
	if health <= 0:
		_die()


## Returns false when already at full health, so the pickup stays.
func heal(amount: int) -> bool:
	if health >= max_health:
		return false
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)
	return true


## Adds ammo to every weapon that uses it. Returns false if all are full.
func add_ammo() -> bool:
	var took := false
	for wpn in weapons:
		if wpn.max_reserve > 0 and wpn.reserve < wpn.max_reserve:
			wpn.reserve = mini(wpn.reserve + wpn.mag_size * 2, wpn.max_reserve)
			took = true
	_emit_ammo()
	return took


func give_key() -> void:
	has_key = true
	key_changed.emit(true)


func use_key() -> void:
	has_key = false
	key_changed.emit(false)


func _die() -> void:
	dead = true
	weapon_root.visible = false
	Sfx.play("player_death")
	var tw := create_tween().set_parallel()
	tw.tween_property(head, "position:y", 0.35, 0.8).set_ease(Tween.EASE_IN)
	tw.tween_property(head, "rotation:z", 0.6, 0.8)
	died.emit()


func _update_view(delta: float) -> void:
	# Head bob while moving on the ground, weapon sway and recoil recovery.
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and flat_speed > 0.5:
		_bob_t += delta * flat_speed * 1.6
	var bob := Vector3(cos(_bob_t * 0.5) * 0.012, absf(sin(_bob_t * 0.5)) * 0.018, 0) * minf(flat_speed / WALK_SPEED, 1.4)
	_kick = move_toward(_kick, 0.0, delta * 9.0)
	var reload_dip := Vector3(0, -0.15, 0.05) if _reload_t > 0.0 else Vector3.ZERO
	var switch_dip := Vector3(0, -0.25, 0) * clampf(_switch_t / 0.3, 0.0, 1.0)
	var target := _weapon_rest + bob + Vector3(0, 0, 0.07) * _kick + reload_dip + switch_dip
	weapon_root.position = weapon_root.position.lerp(target, clampf(delta * 18.0, 0, 1))
	weapon_root.rotation.x = 0.12 * _kick

	muzzle_light.light_energy = move_toward(muzzle_light.light_energy, 0.0, delta * 40.0)
	if muzzle_light.light_energy < 1.5:
		muzzle_flash.visible = false


# --- Weapon models (simple primitives; replace with imported .glb models) ---

func _part(parent: Node3D, size: Vector3, pos: Vector3, color: Color, metal := 0.6) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.45
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _build_pistol() -> Node3D:
	var n := Node3D.new()
	_part(n, Vector3(0.06, 0.07, 0.26), Vector3(0, 0.03, -0.2), Color(0.18, 0.19, 0.21))
	_part(n, Vector3(0.05, 0.1, 0.06), Vector3(0, -0.04, -0.12), Color(0.1, 0.08, 0.07), 0.1)
	return n


func _build_shotgun() -> Node3D:
	var n := Node3D.new()
	_part(n, Vector3(0.07, 0.07, 0.62), Vector3(0, 0.03, -0.3), Color(0.2, 0.2, 0.22))
	_part(n, Vector3(0.08, 0.06, 0.22), Vector3(0, -0.03, -0.38), Color(0.42, 0.26, 0.14), 0.1)
	_part(n, Vector3(0.07, 0.11, 0.24), Vector3(0, -0.03, 0.02), Color(0.42, 0.26, 0.14), 0.1)
	return n


func _build_rifle() -> Node3D:
	var n := Node3D.new()
	_part(n, Vector3(0.06, 0.09, 0.55), Vector3(0, 0.03, -0.25), Color(0.16, 0.18, 0.17))
	_part(n, Vector3(0.03, 0.03, 0.2), Vector3(0, 0.05, -0.6), Color(0.1, 0.1, 0.1))
	_part(n, Vector3(0.05, 0.16, 0.06), Vector3(0, -0.08, -0.22), Color(0.12, 0.12, 0.12))
	_part(n, Vector3(0.04, 0.05, 0.12), Vector3(0, 0.1, -0.2), Color(0.1, 0.1, 0.1))
	return n
