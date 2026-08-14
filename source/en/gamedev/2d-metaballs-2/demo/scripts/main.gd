extends Control

const MAX_BALLS := 16

const PALETTE := [
	Vector3(1.0, 0.15, 0.15),  # deep red
	Vector3(1.0, 0.4, 0.1),   # red-orange
	Vector3(1.0, 0.65, 0.1),  # orange
	Vector3(1.0, 0.9, 0.25),  # yellow
]

@export var initial_balls := 5

var _size := Vector2.ZERO
var _positions := PackedVector2Array()
var _radii := PackedFloat32Array()
var _velocities := PackedVector2Array()
var _colors := PackedInt32Array()
var _dragging := -1
var _threshold := 0.5
var _active_count := 0

@onready var _shader_mat := $ColorRect.material as ShaderMaterial
@onready var _label: Label = $Label

func _ready() -> void:
	_size = get_viewport_rect().size
	for i in range(MAX_BALLS):
		_positions.append(Vector2.ZERO)
		_radii.append(0.0)
		_velocities.append(Vector2.ZERO)
		_colors.append(0)
	for i in range(initial_balls):
		_spawn_random()
	_shader_mat.set_shader_parameter("palette", PackedVector3Array(PALETTE))
	_push_threshold()
	_update_label()

func _process(delta: float) -> void:
	for i in range(MAX_BALLS):
		var r := _radii[i]
		if r <= 0.0:
			continue
		if i == _dragging:
			_positions[i] = get_global_mouse_position()
			continue
		var p: Vector2 = _positions[i] + _velocities[i] * delta
		var v := _velocities[i]
		if p.x < r:
			p.x = r
			v.x = abs(v.x)
		elif p.x > _size.x - r:
			p.x = _size.x - r
			v.x = -abs(v.x)
		if p.y < r:
			p.y = r
			v.y = abs(v.y)
		elif p.y > _size.y - r:
			p.y = _size.y - r
			v.y = -abs(v.y)
		_positions[i] = p
		_velocities[i] = v
	_push_uniforms()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = _ball_at(get_global_mouse_position())
			if _dragging == -1:
				_spawn_at(get_global_mouse_position())
		else:
			_dragging = -1
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_BRACKETLEFT:
			_threshold = max(0.0, _threshold - 0.05)
			_push_threshold()
			_update_label()
		elif event.keycode == KEY_BRACKETRIGHT:
			_threshold = min(1.0, _threshold + 0.05)
			_push_threshold()
			_update_label()

func _spawn_random() -> void:
	_spawn_at(Vector2(randf_range(0.0, _size.x), randf_range(0.0, _size.y)))

func _spawn_at(pos: Vector2) -> void:
	for i in range(MAX_BALLS):
		if _radii[i] <= 0.0:
			_positions[i] = pos
			_radii[i] = randf_range(80.0, 180.0)
			_colors[i] = randi_range(0, PALETTE.size() - 1)
			_active_count += 1
			var dir := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
			_velocities[i] = dir * randf_range(20.0, 90.0)
			return

func _ball_at(pos: Vector2) -> int:
	for i in range(MAX_BALLS):
		if _radii[i] > 0.0 and pos.distance_to(_positions[i]) <= _radii[i]:
			return i
	return -1

func _push_uniforms() -> void:
	var packed := PackedVector4Array()
	packed.resize(MAX_BALLS)
	for i in range(MAX_BALLS):
		packed[i] = Vector4(_positions[i].x, _positions[i].y, _radii[i], float(_colors[i]))
	_shader_mat.set_shader_parameter("balls", packed)
	_shader_mat.set_shader_parameter("active_balls", _active_count)

func _push_threshold() -> void:
	_shader_mat.set_shader_parameter("threshold", _threshold)

func _update_label() -> void:
	_label.text = "threshold: %.2f   |   [ ] to change   |   click: add   |   drag: move" % _threshold
