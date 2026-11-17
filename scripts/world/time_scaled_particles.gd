class_name TimeScaledParticles
extends GPUParticles3D
## GPU particles whose simulation speed follows a TimeDirector channel.

## TimeDirector.Channel value (default WORLD).
@export var time_channel: int = 0


func _process(_delta: float) -> void:
	speed_scale = TimeDirector.get_scale(time_channel)


## Sparse pale dust hanging in the air. Purely atmospheric, but it also makes
## Borrow Time readable in an otherwise empty room.
static func create_dust(extents: Vector3, amount: int = 160) -> TimeScaledParticles:
	var p := TimeScaledParticles.new()
	p.amount = amount
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.visibility_aabb = AABB(-extents, extents * 2.0)
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = extents
	mat.gravity = Vector3(0.0, -0.04, 0.0)
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.02
	mat.initial_velocity_max = 0.12
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.025, 0.025)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.albedo_color = Color(0.9, 0.88, 0.84, 0.55)
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = qm
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
