extends Node2D

const PLAYER_SCENE := preload("res://Player.tscn")
const ENEMY_SCENE := preload("res://Enemy.tscn")

const WALL_THICKNESS := 56.0
const FLOOR_THICKNESS := 80.0
const FLOOR_DEPTH := 120.0
const KILL_LINE_HEIGHT := 10.0

const GRID_SPACING := 24.0
const GRID_COLUMN_WIDTH := 48.0

const DIFFICULTY_RAMP_TIME := 90.0
const START_SPAWN_MIN := 0.16
const START_SPAWN_MAX := 0.30
const END_SPAWN_MIN := 0.08
const END_SPAWN_MAX := 0.18
const START_ENEMY_MIN_SIDE := 6.0
const START_ENEMY_MAX_SIDE := 20.0
const END_ENEMY_MIN_SIDE := 8.0
const END_ENEMY_MAX_SIDE := 34.0
const START_GRAVITY_MIN := 0.22
const START_GRAVITY_MAX := 0.55
const END_GRAVITY_MIN := 0.34
const END_GRAVITY_MAX := 0.82
const START_FALL_SPEED_MIN := 10.0
const START_FALL_SPEED_MAX := 45.0
const END_FALL_SPEED_MIN := 40.0
const END_FALL_SPEED_MAX := 95.0
const DENSITY_MIN := 1.35
const DENSITY_MAX := 1.85

@onready var enemy_container: Node2D = $World/EnemyContainer
@onready var player_container: Node2D = $World/PlayerContainer
@onready var left_wall: StaticBody2D = $World/Bounds/LeftWall
@onready var right_wall: StaticBody2D = $World/Bounds/RightWall
@onready var floor_body: StaticBody2D = $World/Bounds/Floor
@onready var kill_line: Area2D = $World/Bounds/KillLine
@onready var score_label: Label = $HUD/ScoreLabel
@onready var breakdown_label: Label = $HUD/BreakdownLabel
@onready var message_label: Label = $HUD/MessageLabel

var rng := RandomNumberGenerator.new()
var surface_material := PhysicsMaterial.new()
var player: PlayerBlock
var game_over := false
var run_time := 0.0
var spawn_timer := 0.0


func _ready() -> void:
	rng.randomize()
	_configure_surface_material()
	_ensure_input_actions()
	_configure_bounds()
	kill_line.body_entered.connect(_on_kill_line_body_entered)
	_start_game()
	queue_redraw()


func _process(_delta: float) -> void:
	if game_over and Input.is_action_just_pressed("restart"):
		_start_game()
	_update_hud()


func _physics_process(delta: float) -> void:
	if game_over:
		return
	if not is_instance_valid(player):
		return

	run_time += delta
	player.advance_survival(delta)
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_enemy()
		spawn_timer = _next_spawn_delay()


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color8(16, 21, 29))

	for column in range(0, int(ceil(viewport_size.x / GRID_COLUMN_WIDTH)) + 1):
		var column_x := column * GRID_COLUMN_WIDTH
		draw_rect(
			Rect2(Vector2(column_x, 0.0), Vector2(1.0, viewport_size.y)),
			Color8(24, 34, 45)
		)

	for row in range(0, int(ceil(viewport_size.y / GRID_SPACING)) + 1):
		var row_y := row * GRID_SPACING
		draw_rect(
			Rect2(Vector2(0.0, row_y), Vector2(viewport_size.x, 1.0)),
			Color8(30, 42, 54)
		)
	draw_rect(
		Rect2(Vector2(0.0, viewport_size.y - KILL_LINE_HEIGHT), Vector2(viewport_size.x, KILL_LINE_HEIGHT)),
		Color(0.91, 0.28, 0.25, 0.75)
	)


func _start_game() -> void:
	game_over = false
	run_time = 0.0
	spawn_timer = 0.6
	_clear_enemies()
	_spawn_player()
	message_label.text = "Arrow keys move freely, Space dodges. Touch blocks to absorb. Stay off the bottom."
	_update_hud()


func _spawn_player() -> void:
	for child in player_container.get_children():
		child.free()

	player = PLAYER_SCENE.instantiate() as PlayerBlock
	var viewport_size := get_viewport_rect().size
	player.position = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.42)
	player.physics_material_override = surface_material
	player_container.add_child(player)


func _spawn_enemy() -> void:
	var viewport_size := get_viewport_rect().size
	var difficulty := _difficulty_ratio()
	var min_side := lerpf(START_ENEMY_MIN_SIDE, END_ENEMY_MIN_SIDE, difficulty)
	var max_side := lerpf(START_ENEMY_MAX_SIDE, END_ENEMY_MAX_SIDE, difficulty)
	var size_bias := lerpf(2.8, 1.9, difficulty)
	var side := lerpf(min_side, max_side, pow(rng.randf(), size_bias))
	var enemy := ENEMY_SCENE.instantiate() as EnemyBlock
	var hue := rng.randf_range(0.0, 0.06)
	var saturation := rng.randf_range(0.68, 0.90)
	var density := rng.randf_range(DENSITY_MIN, DENSITY_MAX)
	var density_t := inverse_lerp(DENSITY_MIN, DENSITY_MAX, density)
	var value := lerpf(0.96, 0.52, density_t) * rng.randf_range(0.92, 1.0)
	var gravity_scale := lerpf(START_GRAVITY_MIN, END_GRAVITY_MIN, difficulty)
	gravity_scale = rng.randf_range(gravity_scale, lerpf(START_GRAVITY_MAX, END_GRAVITY_MAX, difficulty))
	var initial_fall_speed := rng.randf_range(
		lerpf(START_FALL_SPEED_MIN, END_FALL_SPEED_MIN, difficulty),
		lerpf(START_FALL_SPEED_MAX, END_FALL_SPEED_MAX, difficulty)
	)
	enemy.setup(
		side,
		Color.from_hsv(hue, saturation, value),
		surface_material,
		gravity_scale,
		initial_fall_speed,
		density
	)
	enemy.position = Vector2(
		rng.randf_range(side * 0.5, viewport_size.x - side * 0.5),
		-side * 0.5 - rng.randf_range(24.0, 160.0)
	)
	enemy_container.add_child(enemy)


func _configure_surface_material() -> void:
	surface_material.friction = 1.45
	surface_material.bounce = 0.0


func _ensure_input_actions() -> void:
	_ensure_key_action("dodge", [KEY_SPACE])
	_ensure_key_action("restart", [KEY_ENTER, KEY_KP_ENTER])


func _ensure_key_action(action_name: String, keycodes: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	var existing_events := InputMap.action_get_events(action_name)
	for keycode in keycodes:
		var already_present := false
		for event in existing_events:
			if event is InputEventKey:
				if event.physical_keycode == keycode or event.keycode == keycode:
					already_present = true
					break
		if already_present:
			continue

		var input_event := InputEventKey.new()
		input_event.physical_keycode = keycode
		input_event.keycode = keycode
		InputMap.action_add_event(action_name, input_event)


func _configure_bounds() -> void:
	var viewport_size := get_viewport_rect().size
	var wall_height := viewport_size.y + FLOOR_DEPTH * 2.0
	var wall_shape := left_wall.get_node("CollisionShape2D").shape as RectangleShape2D
	if wall_shape == null:
		wall_shape = RectangleShape2D.new()
		left_wall.get_node("CollisionShape2D").shape = wall_shape
	wall_shape.size = Vector2(WALL_THICKNESS, wall_height)
	left_wall.global_position = Vector2(-WALL_THICKNESS * 0.5, viewport_size.y * 0.5)
	left_wall.physics_material_override = surface_material

	var right_shape := right_wall.get_node("CollisionShape2D").shape as RectangleShape2D
	if right_shape == null:
		right_shape = RectangleShape2D.new()
		right_wall.get_node("CollisionShape2D").shape = right_shape
	right_shape.size = Vector2(WALL_THICKNESS, wall_height)
	right_wall.global_position = Vector2(viewport_size.x + WALL_THICKNESS * 0.5, viewport_size.y * 0.5)
	right_wall.physics_material_override = surface_material

	var floor_shape := floor_body.get_node("CollisionShape2D").shape as RectangleShape2D
	if floor_shape == null:
		floor_shape = RectangleShape2D.new()
		floor_body.get_node("CollisionShape2D").shape = floor_shape
	floor_shape.size = Vector2(viewport_size.x + WALL_THICKNESS * 4.0, FLOOR_THICKNESS)
	floor_body.global_position = Vector2(viewport_size.x * 0.5, viewport_size.y + FLOOR_DEPTH + FLOOR_THICKNESS * 0.5)
	floor_body.physics_material_override = surface_material

	var kill_shape := kill_line.get_node("CollisionShape2D").shape as RectangleShape2D
	if kill_shape == null:
		kill_shape = RectangleShape2D.new()
		kill_line.get_node("CollisionShape2D").shape = kill_shape
	kill_shape.size = Vector2(viewport_size.x + WALL_THICKNESS * 2.0, KILL_LINE_HEIGHT)
	kill_line.global_position = Vector2(viewport_size.x * 0.5, viewport_size.y - KILL_LINE_HEIGHT * 0.5)


func _difficulty_ratio() -> float:
	return clampf(run_time / DIFFICULTY_RAMP_TIME, 0.0, 1.0)


func _next_spawn_delay() -> float:
	var difficulty := _difficulty_ratio()
	var min_delay := lerpf(START_SPAWN_MIN, END_SPAWN_MIN, difficulty)
	var max_delay := lerpf(START_SPAWN_MAX, END_SPAWN_MAX, difficulty)
	return rng.randf_range(min_delay, max_delay)


func _clear_enemies() -> void:
	for child in enemy_container.get_children():
		child.free()


func _update_hud() -> void:
	if not is_instance_valid(player):
		score_label.text = "Score: 0"
		breakdown_label.text = "Escaped: 0   Time: 0   Absorb: 0   Size: 1.0x"
		return

	score_label.text = "Score: %d" % player.get_total_score()
	breakdown_label.text = "Escaped: %d   Time: %d   Absorb: %d   Size: %.2fx" % [
		player.escape_score,
		player.survival_score,
		player.absorb_score,
		player.get_size_multiplier(),
	]

	if game_over:
		message_label.text = "You touched the bottom. Final score: %d. Press Enter to restart." % player.get_total_score()


func _end_game() -> void:
	if game_over:
		return

	game_over = true
	if is_instance_valid(player):
		player.set_active(false)
		player.freeze = true

	for body in enemy_container.get_children():
		if body is RigidBody2D:
			var rigid_body := body as RigidBody2D
			rigid_body.freeze = true

	_update_hud()


func _on_kill_line_body_entered(body: Node) -> void:
	if game_over:
		return
	if body == player:
		_end_game()
		return
	if body is EnemyBlock:
		var enemy := body as EnemyBlock
		if enemy.has_been_scored or enemy.is_absorbed():
			return
		enemy.mark_escaped()
		if is_instance_valid(player):
			player.register_escape_point()
		enemy.queue_free()
