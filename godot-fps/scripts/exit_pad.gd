extends Area3D
## Glowing pad that ends the level when the player steps on it.

var _ring: MeshInstance3D
var _done := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = Game.LAYER_PLAYER
	var shape := CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = 2.0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 1.0
	add_child(cs)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.9, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.9, 0.45)
	mat.emission_energy_multiplier = 2.0
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.1
	mesh.bottom_radius = 1.1
	mesh.height = 0.08
	mesh.material = mat
	_ring = MeshInstance3D.new()
	_ring.mesh = mesh
	_ring.position.y = 0.04
	add_child(_ring)

	var light := OmniLight3D.new()
	light.light_color = Color(0.2, 1.0, 0.5)
	light.light_energy = 2.0
	light.omni_range = 7.0
	light.position.y = 1.2
	add_child(light)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_ring.rotation.y += delta


func _on_body_entered(body: Node3D) -> void:
	if not _done and body.is_in_group("player") and not body.dead:
		_done = true
		Sfx.play("exit")
		Game.exit_reached.emit()
