extends Node2D

const PLAYER_SIZE := 8.0
const PLAYER_SPEED := 260.0
const PLAYER_ANCHOR_RATIO := 0.72
const PLAYER_RECENTER_SPEED := 4.0
const SCROLL_SPEED := 190.0
const SPAWN_INTERVAL_MIN := 0.20
const SPAWN_INTERVAL_MAX := 0.45
const ENEMY_SIZE_MIN := 10.0
const ENEMY_SIZE_MAX := 54.0
const GRID_SPACING := 24.0
const GRID_COLUMN_WIDTH := 48.0

@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var message_label: Label = $CanvasLayer/MessageLabel

var rng := RandomNumberGenerator.new()
var enemies: Array[Dictionary] = []
var player_position := Vector2.ZERO
var score := 0
var spawn_timer := 0.0
var scroll_offset := 0.0
var game_over := false


func _ready() -> void:
	rng.randomize()
	_start_game()


func _process(delta: float) -> void:
	if game_over:
		if Input.is_action_just_pressed("ui_accept"):
			_start_game()
		return

	var viewport_size := get_viewport_rect().size
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	player_position += input_vector * PLAYER_SPEED * delta
	var anchor_y := viewport_size.y * PLAYER_ANCHOR_RATIO - PLAYER_SIZE * 0.5
	player_position.y = lerpf(
		player_position.y,
		anchor_y,
		clampf(PLAYER_RECENTER_SPEED * delta, 0.0, 1.0)
	)
	player_position.x = clampf(player_position.x, 0.0, viewport_size.x - PLAYER_SIZE)
	player_position.y = clampf(player_position.y, 0.0, viewport_size.y - PLAYER_SIZE)

	scroll_offset = wrapf(scroll_offset + SCROLL_SPEED * delta, 0.0, GRID_SPACING)
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_enemy(viewport_size)
		spawn_timer = rng.randf_range(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)

	_update_enemies(delta, viewport_size)
	if game_over:
		_update_hud()
		queue_redraw()
		return

	if player_position.y + PLAYER_SIZE >= viewport_size.y:
		_end_game("You touched the bottom.")
		_update_hud()
		queue_redraw()
		return

	_update_hud()
	queue_redraw()


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color8(16, 21, 29))
	_draw_background(viewport_size)

	for enemy in enemies:
		var enemy_position: Vector2 = enemy["position"]
		var enemy_size: Vector2 = enemy["size"]
		var enemy_color: Color = enemy["color"]
		draw_rect(Rect2(enemy_position, enemy_size), enemy_color)

	var player_color := Color8(244, 247, 251)
	if game_over:
		player_color = Color8(141, 150, 165)
	draw_rect(Rect2(player_position, Vector2.ONE * PLAYER_SIZE), player_color)
	draw_rect(Rect2(Vector2(0.0, viewport_size.y - 2.0), Vector2(viewport_size.x, 2.0)), Color8(255, 107, 87))


func _draw_background(viewport_size: Vector2) -> void:
	for column in range(0, int(ceil(viewport_size.x / GRID_COLUMN_WIDTH)) + 1):
		var column_x := column * GRID_COLUMN_WIDTH
		draw_rect(
			Rect2(Vector2(column_x, 0.0), Vector2(1.0, viewport_size.y)),
			Color8(25, 33, 43)
		)

	for row in range(0, int(ceil(viewport_size.y / GRID_SPACING)) + 2):
		var row_y := fmod(row * GRID_SPACING + scroll_offset, viewport_size.y + GRID_SPACING) - GRID_SPACING
		draw_rect(
			Rect2(Vector2(0.0, row_y), Vector2(viewport_size.x, 1.0)),
			Color8(32, 43, 54)
		)


func _start_game() -> void:
	var viewport_size := get_viewport_rect().size
	player_position = Vector2(
		viewport_size.x * 0.5 - PLAYER_SIZE * 0.5,
		viewport_size.y * PLAYER_ANCHOR_RATIO - PLAYER_SIZE * 0.5
	)
	enemies.clear()
	score = 0
	spawn_timer = 0.35
	scroll_offset = 0.0
	game_over = false
	message_label.text = "Arrow keys move. Dodge the enemy pixels. Press Enter or Space to restart."
	_update_hud()
	queue_redraw()


func _spawn_enemy(viewport_size: Vector2) -> void:
	var enemy_size := Vector2(
		rng.randf_range(ENEMY_SIZE_MIN, ENEMY_SIZE_MAX),
		rng.randf_range(ENEMY_SIZE_MIN, ENEMY_SIZE_MAX)
	)
	var max_x := viewport_size.x - enemy_size.x
	if max_x < 0.0:
		max_x = 0.0
	var enemy_position := Vector2(
		rng.randf_range(0.0, max_x),
		-enemy_size.y - rng.randf_range(6.0, viewport_size.y * 0.25)
	)
	var enemy_color := Color.from_hsv(
		rng.randf_range(0.0, 0.05),
		rng.randf_range(0.65, 0.90),
		rng.randf_range(0.85, 1.0)
	)
	enemies.append({
		"position": enemy_position,
		"size": enemy_size,
		"color": enemy_color,
	})


func _update_enemies(delta: float, viewport_size: Vector2) -> void:
	var player_rect := Rect2(player_position, Vector2.ONE * PLAYER_SIZE)

	for index in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[index]
		var enemy_position: Vector2 = enemy["position"]
		var enemy_size: Vector2 = enemy["size"]
		enemy_position.y += SCROLL_SPEED * delta
		enemy["position"] = enemy_position

		var enemy_rect := Rect2(enemy_position, enemy_size)
		if player_rect.intersects(enemy_rect):
			enemies[index] = enemy
			_end_game("An enemy pixel hit you.")
			return

		if enemy_position.y + enemy_size.y >= viewport_size.y:
			score += 1
			enemies.remove_at(index)
			continue

		enemies[index] = enemy


func _update_hud() -> void:
	score_label.text = "Score: %d" % score


func _end_game(reason: String) -> void:
	game_over = true
	message_label.text = "%s Final score: %d. Press Enter or Space to restart." % [reason, score]
