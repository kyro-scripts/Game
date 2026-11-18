class_name FaceRig
extends Node3D
## An almost-human face: something that has studied people and is getting it
## slightly wrong. Sculpted procedurally by MeshKit.face_mesh.
##
## What is wrong (all deliberate, all small):
##  * eyes a little too far apart and too low; eyebrows far too high,
##  * a short nose, a mouth too wide and too close to it, corners that turn
##    up too sharply, a thin line of too many teeth showing through,
##  * real eyeballs that stare at you with perfect convergence, except the
##    right one is set a few degrees off; now and then both snap to stare at
##    nothing and snap back,
##  * almost never blinks, and when it does every face in the castle blinks
##    together (shared world clock),
##  * expressions SNAP between shapes with no in-between frames,
##  * the irises burn red when it means you harm (red = danger).
##
## Head tracking is driven by EnemyBase (it rotates Visual/Head). Interface
## for real art: keep set_expression(), flash() and set_danger().

enum Mood { NEUTRAL, SMILE, OPEN, DEAD }

## Shared blink rhythm (world-time seconds). All faces obey it together.
const BLINK_PERIOD := 8.7
const BLINK_LENGTH := 0.09
const EYE_RADIUS := 0.0128
## The right eye is set this far off true (radians).
const WALL_EYE := 0.07

var mood: Mood = Mood.SMILE

var _head: MeshInstance3D
var _skin: ShaderMaterial
var _eyes: Array[Node3D] = []
var _iris_mat: StandardMaterial3D
var _target: Node3D
var _danger: float = 0.0
var _danger_target: float = 0.0
var _stare_timer: float = 0.0
var _stare_offset: Vector3 = Vector3.ZERO
var _next_stare: float = 0.0
var _flash: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = get_instance_id()
	_next_stare = _rng.randf_range(3.0, 9.0)
	if get_child_count() == 0:
		_build()
	set_expression(mood)


func _process(delta: float) -> void:
	var dt := TimeDirector.scaled(TimeDirector.Channel.ANIMATION, delta)
	# Synchronised blinking on the shared world clock.
	var phase := fposmod(TimeDirector.world_time, BLINK_PERIOD)
	var closed := phase < BLINK_LENGTH and mood != Mood.DEAD
	for eye in _eyes:
		eye.scale = Vector3(1.0, 0.08 if closed else 1.0, 1.0)

	# Gaze: both eyes converge on the player's eyes, except when they snap
	# away to stare at an empty point for a moment.
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group(&"player") as Node3D
	_next_stare -= dt
	if _next_stare <= 0.0 and _stare_timer <= 0.0:
		_stare_timer = _rng.randf_range(0.25, 0.6)
		_stare_offset = Vector3(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-1.0, 2.0), _rng.randf_range(-3.0, 3.0))
		_next_stare = _rng.randf_range(4.0, 11.0)
	_stare_timer -= dt
	if _target != null and mood != Mood.DEAD:
		var look_at_point := _target.global_position + Vector3.UP * 1.6
		if _target is Player:
			look_at_point = (_target as Player).get_eye_position()
		if _stare_timer > 0.0:
			look_at_point += _stare_offset
		for i in _eyes.size():
			_aim_eye(_eyes[i], look_at_point, WALL_EYE if i == 1 else 0.0)

	# Danger glow and hit flash ease, but expressions never do.
	_danger = move_toward(_danger, _danger_target, dt * 8.0)
	_iris_mat.emission_energy_multiplier = _danger * 5.0
	_flash = move_toward(_flash, 0.0, delta * 8.0)
	_skin.set_shader_parameter(&"flash", _flash)


## Instant expression change (no transition, on purpose).
func set_expression(e: Mood) -> void:
	mood = e
	if _head == null:
		return
	_head.mesh = mesh_for(e)
	for eye in _eyes:
		eye.visible = e != Mood.DEAD
	var expr := {Mood.SMILE: Vector2(1.0, 0.0), Mood.NEUTRAL: Vector2(0.15, 0.0),
			Mood.OPEN: Vector2(0.35, 1.0), Mood.DEAD: Vector2(0.2, 0.3)}
	var sv: Vector2 = expr[e]
	_skin.set_shader_parameter(&"smile", sv.x)
	_skin.set_shader_parameter(&"open", sv.y)


## Red irises when the face means harm (attack windups).
func set_danger(on: bool) -> void:
	_danger_target = 1.0 if on else 0.0


## Hit feedback.
func flash(color: Color) -> void:
	if _skin == null:
		return
	_skin.set_shader_parameter(&"flash_color", color)
	_flash = 1.0


static var _meshes: Dictionary = {}


## Shared head meshes, one per mood.
static func mesh_for(m: Mood) -> Mesh:
	if not _meshes.has(m):
		match m:
			Mood.OPEN:
				_meshes[m] = MeshKit.face_mesh(0.35, 1.0)
			Mood.NEUTRAL:
				_meshes[m] = MeshKit.face_mesh(0.15, 0.0)
			_:
				_meshes[m] = MeshKit.face_mesh(1.0, 0.0)
	return _meshes[m]


func _aim_eye(eye: Node3D, point: Vector3, offset: float) -> void:
	var to := point - eye.global_position
	if to.length_squared() < 0.0001:
		return
	# Only rotate within a believable cone; beyond it the eyes hold.
	var fwd := global_basis.z.normalized()
	if fwd.dot(to.normalized()) < 0.2:
		return
	eye.look_at(point, Vector3.UP, true)
	eye.rotate_object_local(Vector3.UP, offset)


func _build() -> void:
	_skin = CastleMaterials.skin()
	_head = MeshInstance3D.new()
	_head.mesh = mesh_for(mood)
	_head.material_override = _skin
	add_child(_head)

	# Eyeballs seated in the sockets: white sclera, a dark iris that is a
	# touch too large.
	_iris_mat = CastleMaterials.iris()
	for side: float in [-1.0, 1.0]:
		var centre := MeshKit.face_point(side * MeshKit.FACE_EYE_X, MeshKit.FACE_EYE_Y)
		var pivot := Node3D.new()
		pivot.position = centre - Vector3(0.0, 0.0, EYE_RADIUS * 0.55)
		add_child(pivot)
		var sclera := Palette.sphere(EYE_RADIUS, CastleMaterials.eye_white(), 14)
		pivot.add_child(sclera)
		var iris := Palette.sphere(EYE_RADIUS * 0.62, _iris_mat, 12)
		iris.scale = Vector3(1.0, 1.0, 0.35)
		iris.position.z = EYE_RADIUS * 0.82
		pivot.add_child(iris)
		_eyes.append(pivot)
