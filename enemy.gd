class_name EnemyBlock
extends RigidBody2D

const BASE_PLAYER_AREA := 16.0 * 16.0
const MIN_AREA := 4.0
const BASE_ABSORPTION_TIME := 12.8
const MIN_ABSORPTION_TIME := 0.45
const ABSORPTION_MASS_EXPONENT := 3.1
const PHYSICS_WEIGHT_MULTIPLIER := 2.4
const FALL_FORCE_MULTIPLIER := 1.6

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var base_size := Vector2(4.0, 9.0)
var current_size := Vector2(4.0, 9.0)
var base_area := 36.0
var current_area := 36.0
var absorb_progress := 0.0
var is_absorbing := false
var has_escaped := false
var has_been_scored := false
var block_color := Color8(255, 122, 92)
var density := 1.0
var _absorbed := false

func _ready() -> void:
	lock_rotation = true
	can_sleep = false
	continuous_cd = CCD_MODE_CAST_SHAPE
	_update_shape()
	_update_mass()
	queue_redraw()


func _draw() -> void:
	var fill := block_color
	if is_absorbing:
		fill = fill.lightened(0.2)
	draw_rect(
		Rect2(-current_size * 0.5, current_size),
		fill
	)


func setup(
	block_size: Vector2,
	color: Color,
	material: PhysicsMaterial,
	gravity_amount: float,
	initial_fall_speed: float,
	block_density: float
) -> void:
	base_size = block_size
	current_size = block_size
	base_area = block_size.x * block_size.y
	current_area = base_area
	block_color = color
	density = block_density
	physics_material_override = material
	gravity_scale = gravity_amount * density * FALL_FORCE_MULTIPLIER
	linear_velocity = Vector2(0.0, initial_fall_speed)
	linear_damp = 0.15
	if is_node_ready():
		_update_shape()
		_update_mass()
		queue_redraw()


func process_absorption(delta: float, player_area: float, _player_position: Vector2) -> Dictionary:
	if _absorbed or has_escaped:
		return {}

	is_absorbing = true
	var duration_seconds := _get_absorption_duration(player_area)
	var previous_progress := absorb_progress
	var previous_bottom := global_position.y + current_size.y * 0.5
	var previous_x := global_position.x
	absorb_progress = minf(absorb_progress + delta / duration_seconds, 1.0)
	var absorbed_area_delta := base_area * (absorb_progress - previous_progress)
	current_area = maxf(base_area * (1.0 - absorb_progress), MIN_AREA)
	var area_scale := sqrt(current_area / base_area)
	current_size = base_size * area_scale
	global_position = Vector2(previous_x, previous_bottom - current_size.y * 0.5)
	linear_velocity *= maxf(0.0, 1.0 - delta * 5.0)
	angular_velocity = 0.0
	_update_shape()
	_update_mass()
	queue_redraw()

	if absorb_progress >= 1.0:
		_absorbed = true
		has_been_scored = true
		return {
			"absorbed_area_delta": absorbed_area_delta,
			"completed": true,
			"points": _get_absorption_reward_points(player_area),
		}

	return {
		"absorbed_area_delta": absorbed_area_delta,
	}


func stop_absorbing() -> void:
	if not _absorbed:
		is_absorbing = false
		queue_redraw()


func mark_escaped() -> void:
	has_escaped = true
	has_been_scored = true
	is_absorbing = false


func is_absorbed() -> bool:
	return _absorbed


func _update_shape() -> void:
	var shape := collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		collision_shape.shape = shape
	shape.size = Vector2(maxf(current_size.x, 2.0), maxf(current_size.y, 2.0))


func _update_mass() -> void:
	mass = maxf(_get_current_intrinsic_mass() * PHYSICS_WEIGHT_MULTIPLIER, 0.08)


func _get_absorption_duration(player_area: float) -> float:
	var enemy_mass := _get_base_intrinsic_mass()
	var player_mass := maxf(player_area / BASE_PLAYER_AREA, 0.08)
	var mass_ratio := enemy_mass / player_mass
	return maxf(
		MIN_ABSORPTION_TIME,
		BASE_ABSORPTION_TIME * exp((mass_ratio - 1.0) * ABSORPTION_MASS_EXPONENT)
	)


func _get_base_intrinsic_mass() -> float:
	return maxf((base_area / BASE_PLAYER_AREA) * density, 0.08)


func _get_absorption_reward_points(player_area: float) -> int:
	var enemy_mass := _get_base_intrinsic_mass()
	var player_mass := maxf(player_area / BASE_PLAYER_AREA, 0.08)
	var mass_ratio := maxf(enemy_mass / player_mass, 0.05)
	return max(2, int(ceil(2.0 * pow(mass_ratio, 1.2))))


func _get_current_intrinsic_mass() -> float:
	return maxf((current_area / BASE_PLAYER_AREA) * density, 0.08)
