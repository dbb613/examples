extends Area3D
## Floating pickup: "health", "ammo" or "key". Collected by walking over it.

var kind := "health"
var _visual: Node3D
var _t := 0.0


func _init(pickup_kind := "health") -> void:
	kind = pickup_kind


func _ready() -> void:
	collision_layer = 0
	collision_mask = Game.LAYER_PLAYER
	var shape := SphereShape3D.new()
	shape.radius = 0.9
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.8
	add_child(cs)

	_visual = Node3D.new()
	_visual.position.y = 0.6
	add_child(_visual)
	_t = randf() * TAU

	match kind:
		"health":
			_box(Vector3(0.5, 0.35, 0.5), Vector3.ZERO, Color(0.92, 0.92, 0.92))
			_box(Vector3(0.36, 0.08, 0.12), Vector3(0, 0.2, 0), Color(0.85, 0.1, 0.1), true)
			_box(Vector3(0.12, 0.08, 0.36), Vector3(0, 0.2, 0), Color(0.85, 0.1, 0.1), true)
			_glow(Color(1.0, 0.4, 0.4))
		"ammo":
			_box(Vector3(0.55, 0.3, 0.35), Vector3.ZERO, Color(0.35, 0.4, 0.2))
			_box(Vector3(0.4, 0.06, 0.2), Vector3(0, 0.18, 0), Color(0.95, 0.75, 0.2), true)
			_glow(Color(1.0, 0.85, 0.3))
		"key":
			_box(Vector3(0.45, 0.3, 0.04), Vector3(0, 0.1, 0), Color(1.0, 0.15, 0.1), true)
			_glow(Color(1.0, 0.2, 0.15), 2.5)


func _box(size: Vector3, pos: Vector3, color: Color, emissive := false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.5
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	_visual.add_child(mi)


func _glow(color: Color, energy := 1.0) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 3.0
	light.position.y = 0.4
	_visual.add_child(light)


func _physics_process(delta: float) -> void:
	_t += delta
	_visual.rotation.y += delta * 1.5
	_visual.position.y = 0.6 + sin(_t * 2.5) * 0.12
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and not body.dead and _apply(body):
			queue_free()
			return


func _apply(player: Node) -> bool:
	match kind:
		"health":
			if player.heal(25):
				Sfx.play("pickup")
				Game.show_message("+25 health", 1.2)
				return true
		"ammo":
			if player.add_ammo():
				Sfx.play("pickup")
				Game.show_message("Ammo", 1.2)
				return true
		"key":
			player.give_key()
			Sfx.play("key")
			Game.show_message("Picked up the red keycard")
			return true
	return false
