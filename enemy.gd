class_name EnemyBlock
extends RigidBody2D

const BASE_PLAYER_AREA := 16.0 * 16.0
const MIN_AREA := 4.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var base_side := 20.0
var current_side := 20.0
var base_area := 400.0
var current_area := 400.0
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
		Rect2(Vector2(-current_side * 0.5, -current_side * 0.5), Vector2.ONE * current_side),
		fill
	)


func setup(
	side_length: float,
	color: Color,
	material: PhysicsMaterial,
	gravity_amount: float,
	initial_fall_speed: float,
	block_density: float
) -> void:
	base_side = side_length
	current_side = side_length
	base_area = side_length * side_length
	current_area = base_area
	block_color = color
	density = block_density
	physics_material_override = material
	gravity_scale = gravity_amount * density
	linear_velocity = Vector2(0.0, initial_fall_speed)
	linear_damp = 0.15
	if is_node_ready():
		_update_shape()
		_update_mass()
		queue_redraw()


func process_absorption(delta: float, player_area: float, player_position: Vector2) -> Dictionary:
	if _absorbed or has_escaped:
		return {}

	is_absorbing = true
	var ratio := maxf(base_area / maxf(player_area, 1.0), 0.05)
	var duration_seconds := maxf(0.40, pow(ratio, 1.5) * 5.0)
	var previous_progress := absorb_progress
	var previous_bottom := global_position.y + current_side * 0.5
	var previous_x := global_position.x
	absorb_progress = minf(absorb_progress + delta / duration_seconds, 1.0)
	var absorbed_area_delta := base_area * (absorb_progress - previous_progress)
	current_area = maxf(base_area * (1.0 - absorb_progress), MIN_AREA)
	current_side = sqrt(current_area)
	global_position = Vector2(previous_x, previous_bottom - current_side * 0.5)
	linear_velocity *= maxf(0.0, 1.0 - delta * 5.0)
	angular_velocity = 0.0
	_update_shape()
	_update_mass()
	queue_redraw()

	if absorb_progress >= 1.0:
		_absorbed = true
		has_been_scored = true
		var reward_ratio := maxf(base_area / maxf(player_area, 1.0), 0.05)
		return {
			"absorbed_area_delta": absorbed_area_delta,
			"completed": true,
			"points": max(2, int(ceil(2.0 * pow(reward_ratio, 1.2)))),
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
	shape.size = Vector2.ONE * maxf(current_side, 2.0)


func _update_mass() -> void:
	mass = maxf((current_area / BASE_PLAYER_AREA) * density, 0.08)
