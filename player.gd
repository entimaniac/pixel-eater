class_name PlayerBlock
extends RigidBody2D

const BASE_WIDTH := 96.0
const BASE_HEIGHT := 12.0
const CONTROL_FORCE := 1650.0
const CONTROL_DRAG := 7.0
const IDLE_DRAG := 18.0
const DODGE_IMPULSE := 290.0
const DODGE_COOLDOWN := 0.32
const MAX_SPEED := 430.0
const MAX_DODGE_SPEED := 620.0
const ABSORB_HORIZONTAL_OVERLAP := 0.35
const ABSORB_TOP_TOLERANCE := 0.35

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var base_area := BASE_WIDTH * BASE_HEIGHT
var current_area := BASE_WIDTH * BASE_HEIGHT
var current_width := BASE_WIDTH
var current_height := BASE_HEIGHT
var survival_score_accumulator := 0.0
var escape_score := 0
var survival_score := 0
var absorb_score := 0
var input_enabled := true
var dodge_cooldown := 0.0
var touching_enemies: Dictionary = {}
var last_move_direction := Vector2.ZERO


func _ready() -> void:
	lock_rotation = true
	contact_monitor = true
	max_contacts_reported = 64
	can_sleep = false
	continuous_cd = CCD_MODE_CAST_SHAPE
	gravity_scale = 0.0
	linear_damp = 0.0
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_shape()
	_update_mass()
	queue_redraw()


func _physics_process(delta: float) -> void:
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	if not input_enabled:
		return

	_apply_movement_control()
	_handle_dodge()
	_handle_absorption(delta)
	var max_allowed_speed := MAX_SPEED
	if dodge_cooldown > 0.0:
		max_allowed_speed = MAX_DODGE_SPEED
	if linear_velocity.length() > max_allowed_speed:
		linear_velocity = linear_velocity.limit_length(max_allowed_speed)


func _draw() -> void:
	var tone := Color8(244, 247, 251)
	if not touching_enemies.is_empty() and input_enabled:
		tone = Color8(255, 231, 176)
	draw_rect(
		Rect2(
			Vector2(-current_width * 0.5, -current_height * 0.5),
			Vector2(current_width, current_height)
		),
		tone
	)


func advance_survival(delta: float) -> void:
	survival_score_accumulator += delta
	while survival_score_accumulator >= 1.0:
		survival_score += 1
		survival_score_accumulator -= 1.0


func register_escape_point() -> void:
	escape_score += 1


func get_total_score() -> int:
	return escape_score + survival_score + absorb_score


func get_size_multiplier() -> float:
	return sqrt(current_area / base_area)


func set_active(active: bool) -> void:
	input_enabled = active
	if not active:
		for enemy in touching_enemies.values():
			if is_instance_valid(enemy):
				enemy.stop_absorbing()
		touching_enemies.clear()
		linear_velocity = Vector2.ZERO


func _apply_movement_control() -> void:
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var area_scale := current_area / base_area
	if input_vector != Vector2.ZERO:
		last_move_direction = input_vector.normalized()
	apply_central_force(input_vector * CONTROL_FORCE * area_scale)
	var drag_strength := CONTROL_DRAG
	if input_vector == Vector2.ZERO and touching_enemies.is_empty():
		drag_strength = IDLE_DRAG
	apply_central_force(-linear_velocity * drag_strength * area_scale)


func _handle_dodge() -> void:
	if not Input.is_action_just_pressed("dodge"):
		return
	if dodge_cooldown > 0.0:
		return

	var dodge_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dodge_direction != Vector2.ZERO:
		dodge_direction = dodge_direction.normalized()
	elif linear_velocity.length() > 12.0:
		dodge_direction = linear_velocity.normalized()
	else:
		dodge_direction = last_move_direction
	if dodge_direction == Vector2.ZERO:
		return

	dodge_cooldown = DODGE_COOLDOWN
	last_move_direction = dodge_direction
	var area_scale := current_area / base_area
	apply_central_impulse(dodge_direction * DODGE_IMPULSE * area_scale)
	if linear_velocity.length() > MAX_DODGE_SPEED:
		linear_velocity = linear_velocity.limit_length(MAX_DODGE_SPEED)


func _handle_absorption(delta: float) -> void:
	var stale_ids: Array[int] = []
	for enemy_id in touching_enemies.keys():
		var enemy: EnemyBlock = touching_enemies[enemy_id]
		if not is_instance_valid(enemy):
			stale_ids.append(enemy_id)
			continue
		if enemy.is_absorbed() or enemy.has_escaped:
			stale_ids.append(enemy_id)
			continue
		if not _can_absorb_enemy_from_top(enemy):
			enemy.stop_absorbing()
			continue

		var result := enemy.process_absorption(delta, current_area, global_position)
		var absorbed_area_delta := float(result.get("absorbed_area_delta", 0.0))
		if absorbed_area_delta > 0.0:
			_grow_from_absorb(absorbed_area_delta)
		if result.get("completed", false):
			absorb_score += int(result["points"])
			enemy.queue_free()
			stale_ids.append(enemy_id)

	for enemy_id in stale_ids:
		touching_enemies.erase(enemy_id)


func _grow_from_absorb(absorbed_area: float) -> void:
	var growth_efficiency := clampf(
		0.12 / sqrt(current_area / base_area),
		0.04,
		0.12
	)
	current_area += absorbed_area * growth_efficiency
	var area_scale := sqrt(current_area / base_area)
	current_width = BASE_WIDTH * area_scale
	current_height = BASE_HEIGHT * area_scale
	_update_shape()
	_update_mass()
	queue_redraw()


func _can_absorb_enemy_from_top(enemy: EnemyBlock) -> bool:
	var player_half_width := current_width * 0.5
	var player_half_height := current_height * 0.5
	var enemy_half := enemy.current_side * 0.5
	if enemy.global_position.y >= global_position.y:
		return false

	var player_left := global_position.x - player_half_width
	var player_right := global_position.x + player_half_width
	var enemy_left := enemy.global_position.x - enemy_half
	var enemy_right := enemy.global_position.x + enemy_half
	var overlap := minf(player_right, enemy_right) - maxf(player_left, enemy_left)
	var required_overlap := minf(current_width, enemy.current_side) * ABSORB_HORIZONTAL_OVERLAP
	if overlap < required_overlap:
		return false

	var player_top := global_position.y - player_half_height
	var enemy_bottom := enemy.global_position.y + enemy_half
	var tolerance := maxf(4.0, minf(current_height, enemy.current_side) * ABSORB_TOP_TOLERANCE)
	return enemy_bottom >= player_top - tolerance and enemy_bottom <= player_top + tolerance


func _update_shape() -> void:
	var shape := collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		collision_shape.shape = shape
	shape.size = Vector2(current_width, current_height)


func _update_mass() -> void:
	mass = maxf(current_area / base_area, 0.2)


func _on_body_entered(body: Node) -> void:
	if body is EnemyBlock:
		touching_enemies[body.get_instance_id()] = body
		queue_redraw()


func _on_body_exited(body: Node) -> void:
	if body is EnemyBlock:
		var enemy_id := body.get_instance_id()
		touching_enemies.erase(enemy_id)
		if is_instance_valid(body):
			body.stop_absorbing()
		queue_redraw()
