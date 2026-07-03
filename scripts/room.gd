class_name Room
extends Node2D
## A single walled combat chamber (Hades-style). Spawns an encounter on begin(),
## seals the exit door until every enemy is dead, then lets the player leave.
## Matches the GDD's "combat rooms" between which Crypt Management happens.

signal room_cleared
signal player_exited

const EnemyScene: PackedScene = preload("res://scenes/enemy.tscn")

@export var interior_size: Vector2 = Vector2(1200.0, 760.0)
@export var wall_thickness: float = 24.0
@export var door_gap: float = 170.0

var player: Player = null

var _cleared: bool = false
var _door_open: bool = false
var _spawned: bool = false
var _gate_shape: CollisionShape2D = null

func _ready() -> void:
	_build_walls()
	_build_door()

# --- Public API ------------------------------------------------------------

## World position where the player should stand when entering this room.
func entrance_position() -> Vector2:
	return global_position + Vector2(-interior_size.x * 0.5 + 80.0, 0.0)

## Spawn the encounter. Call once, after the room is in the tree. Elites are
## tougher Inquisitors that guarantee graft drops (GDD 3.5); a boss room fields
## one massive commander in place of two grunts.
func begin(enemy_count: int, elite_count: int = 0, with_boss: bool = false) -> void:
	if with_boss:
		enemy_count = maxi(1, enemy_count - 2)
	for i in enemy_count:
		var e: Enemy = EnemyScene.instantiate()
		e.archetype = Classes.enemy(Classes.random_enemy_id())  # before add_child
		e.is_elite = i < elite_count
		e.global_position = _random_spawn_point()
		add_child(e)
	if with_boss:
		var b: Enemy = EnemyScene.instantiate()
		b.archetype = Classes.enemy("tank")
		b.is_boss = true
		b.global_position = global_position + Vector2(_half().x * 0.55, 0.0)
		add_child(b)
	_spawned = true

func _process(_delta: float) -> void:
	if _spawned and not _cleared:
		if get_tree().get_nodes_in_group("enemies").is_empty():
			_open_door()
	queue_redraw()

# --- Construction ----------------------------------------------------------

func _half() -> Vector2:
	return interior_size * 0.5

func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	add_child(body)
	var h := _half()
	var t := wall_thickness
	# Top / bottom / left are solid; the right wall has a door gap.
	_add_wall(body, Vector2(0.0, -h.y - t * 0.5), Vector2(interior_size.x + 2.0 * t, t))
	_add_wall(body, Vector2(0.0, h.y + t * 0.5), Vector2(interior_size.x + 2.0 * t, t))
	_add_wall(body, Vector2(-h.x - t * 0.5, 0.0), Vector2(t, interior_size.y + 2.0 * t))
	# Right wall split around the central door gap.
	var seg_len: float = h.y - door_gap * 0.5
	var seg_center: float = (h.y + door_gap * 0.5) * 0.5
	_add_wall(body, Vector2(h.x + t * 0.5, -seg_center), Vector2(t, seg_len))
	_add_wall(body, Vector2(h.x + t * 0.5, seg_center), Vector2(t, seg_len))

func _add_wall(body: StaticBody2D, pos: Vector2, size: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)

func _build_door() -> void:
	var h := _half()
	var t := wall_thickness
	# Gate: a solid block filling the door gap while the room is locked.
	var gate := StaticBody2D.new()
	gate.name = "Gate"
	add_child(gate)
	_gate_shape = CollisionShape2D.new()
	var gshape := RectangleShape2D.new()
	gshape.size = Vector2(t, door_gap)
	_gate_shape.shape = gshape
	_gate_shape.position = Vector2(h.x + t * 0.5, 0.0)
	gate.add_child(_gate_shape)

	# Trigger: detects the player leaving through the opened doorway.
	# The player has its own physics layer, so mask specifically for it.
	var area := Area2D.new()
	area.name = "DoorArea"
	area.collision_mask = BaseEntity.LAYER_PLAYER
	add_child(area)
	var acs := CollisionShape2D.new()
	var ashape := RectangleShape2D.new()
	ashape.size = Vector2(70.0, door_gap)
	acs.shape = ashape
	acs.position = Vector2(h.x + t + 30.0, 0.0)
	area.add_child(acs)
	area.body_entered.connect(_on_door_body_entered)

func _open_door() -> void:
	_cleared = true
	_door_open = true
	if _gate_shape != null:
		_gate_shape.set_deferred("disabled", true)
	room_cleared.emit()

func _on_door_body_entered(body: Node) -> void:
	if _door_open and body == player:
		player_exited.emit()

# --- Spawn placement -------------------------------------------------------

func _random_spawn_point() -> Vector2:
	var h := _half()
	var margin: float = 80.0
	# Bias enemies toward the far (right/door) side so the player has room to act.
	for _try in 12:
		var p := global_position + Vector2(
			randf_range(-h.x * 0.2, h.x - margin),
			randf_range(-h.y + margin, h.y - margin))
		if player == null or p.distance_to(player.global_position) > 220.0:
			return p
	return global_position + Vector2(h.x * 0.4, 0.0)

# --- Rendering -------------------------------------------------------------

func _draw() -> void:
	var h := _half()
	var t := wall_thickness
	# Floor.
	draw_rect(Rect2(-h.x, -h.y, interior_size.x, interior_size.y), Color(0.10, 0.10, 0.13))
	# Floor grid.
	var step: float = 80.0
	var grid := Color(1, 1, 1, 0.035)
	var nx: int = int(h.x / step)
	var ny: int = int(h.y / step)
	for i in range(-nx, nx + 1):
		draw_line(Vector2(i * step, -h.y), Vector2(i * step, h.y), grid, 1.0)
	for j in range(-ny, ny + 1):
		draw_line(Vector2(-h.x, j * step), Vector2(h.x, j * step), grid, 1.0)
	# Walls.
	var wall_col := Color(0.28, 0.26, 0.32)
	draw_rect(Rect2(-h.x - t, -h.y - t, interior_size.x + 2 * t, t), wall_col)
	draw_rect(Rect2(-h.x - t, h.y, interior_size.x + 2 * t, t), wall_col)
	draw_rect(Rect2(-h.x - t, -h.y, t, interior_size.y), wall_col)
	var seg_len: float = h.y - door_gap * 0.5
	draw_rect(Rect2(h.x, -h.y, t, seg_len), wall_col)
	draw_rect(Rect2(h.x, h.y - seg_len, t, seg_len), wall_col)
	# Door: red while sealed, glowing green once cleared.
	var door_rect := Rect2(h.x, -door_gap * 0.5, t, door_gap)
	if _door_open:
		draw_rect(door_rect, Color(0.3, 0.9, 0.4, 0.35))
		draw_line(Vector2(h.x + t, -door_gap * 0.5), Vector2(h.x + t, door_gap * 0.5), Color(0.4, 1.0, 0.5), 3.0)
	else:
		draw_rect(door_rect, Color(0.7, 0.2, 0.2))
