extends Area2D
class_name DartProjectile

const PROJECTILE_KIND_DART := &"dart"
const DESTROY_REASON_PLAYER := &"player"
const DESTROY_REASON_LIFETIME := &"lifetime"
const DESTROY_REASON_BOUNDS := &"bounds"
const DESTROY_REASON_CLEARED := &"cleared"

@export var speed := 145.0
@export var max_lifetime := 1.8
@export var bounds_padding := 8.0
@export var dart_color := Color8(232, 221, 170)
@export var fletching_color := Color8(116, 152, 105)
@export var shadow_color := Color(0.0, 0.0, 0.0, 0.22)

var player: Player
var arena_rect := Rect2()
var direction := Vector2.RIGHT
var lifetime_left := 0.0
var has_resolved_hit := false
var burst_id := Player.INVALID_DART_BURST_ID
var dart_index := Player.INVALID_DART_INDEX
var projectile_token := Player.INVALID_PROJECTILE_TOKEN

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	body_entered.connect(_on_body_entered)
	lifetime_left = max_lifetime
	rotation = direction.angle()
	queue_redraw()


func setup(
	player_ref: Player,
	new_arena_rect: Rect2,
	fire_direction: Vector2,
	new_burst_id: int = Player.INVALID_DART_BURST_ID,
	new_dart_index: int = Player.INVALID_DART_INDEX
) -> void:
	player = player_ref
	arena_rect = new_arena_rect
	direction = fire_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	burst_id = new_burst_id
	dart_index = new_dart_index
	projectile_token = int(get_instance_id())
	lifetime_left = max_lifetime
	has_resolved_hit = false
	rotation = direction.angle()
	monitoring = true
	monitorable = false
	if collision_shape != null:
		collision_shape.disabled = false
	queue_redraw()


func _physics_process(delta: float) -> void:
	if has_resolved_hit:
		return

	global_position += direction * speed * delta
	lifetime_left = maxf(lifetime_left - delta, 0.0)

	if lifetime_left == 0.0:
		destroy_projectile(DESTROY_REASON_LIFETIME)
		return

	if arena_rect.size != Vector2.ZERO and not arena_rect.grow(bounds_padding).has_point(global_position):
		destroy_projectile(DESTROY_REASON_BOUNDS)


func destroy_projectile(_reason: StringName = DESTROY_REASON_CLEARED) -> void:
	if has_resolved_hit:
		return

	has_resolved_hit = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	queue_free()


func _on_body_entered(body: Node) -> void:
	if has_resolved_hit:
		return

	var hit_player := body as Player
	if hit_player == null and body != player:
		return
	if hit_player == null:
		hit_player = player

	if hit_player != null:
		hit_player.take_damage(
			global_position,
			Player.DAMAGE_SOURCE_DART,
			burst_id,
			dart_index,
			projectile_token
		)

	destroy_projectile(DESTROY_REASON_PLAYER)


func _draw() -> void:
	draw_line(Vector2(-4.0, 1.5), Vector2(4.0, 1.5), shadow_color, 2.0)
	draw_line(Vector2(-4.0, 0.0), Vector2(4.0, 0.0), dart_color, 2.0)
	draw_line(Vector2(-5.0, -1.5), Vector2(-2.0, 0.0), fletching_color, 1.0)
	draw_line(Vector2(-5.0, 1.5), Vector2(-2.0, 0.0), fletching_color, 1.0)
	draw_circle(Vector2(4.5, 0.0), 1.0, dart_color.lightened(0.2))
