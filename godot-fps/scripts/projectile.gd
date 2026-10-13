extends Area3D
## Glowing enemy bolt. Flies straight; damages the player or fizzles on walls.

var velocity := Vector3.ZERO
var damage := 10
var _life := 4.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Game.LAYER_WORLD | Game.LAYER_PLAYER
	var shape := SphereShape3D.new()
	shape.radius = 0.15
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)

	var mesh := SphereMesh.new()
	mesh.radius = 0.13
	mesh.height = 0.26
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.75, 0.45, 1.0)
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.4, 1.0)
	light.omni_range = 3.0
	light.light_energy = 1.5
	add_child(light)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.take_damage(damage, global_position)
	queue_free()
