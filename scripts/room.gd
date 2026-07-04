class_name Room
extends Node2D
## A single walled combat chamber (Hades-style). Spawns an encounter on begin(),
## seals the exit door until every enemy is dead, then lets the player leave.
## Matches the GDD's "combat rooms" between which Crypt Management happens.
## Dressed as a desecrated crypt hall: stone-flag floor, brick walls, torch
## light, Silver Flame banners and scattered grave props (visual only).

signal room_cleared
signal player_exited

const EnemyScene: PackedScene = preload("res://scenes/enemy.tscn")

const FLOOR_TEX: Texture2D = preload("res://assets/sprites/env/floor_tile.svg")
const TORCH_TEX: Texture2D = preload("res://assets/sprites/env/torch.svg")
const BANNER_TEX: Texture2D = preload("res://assets/sprites/env/banner.svg")
const PROP_TEXTURES: Array = [
	preload("res://assets/sprites/env/tombstone.svg"),
	preload("res://assets/sprites/env/bones.svg"),
	preload("res://assets/sprites/env/shrub.svg"),
	preload("res://assets/sprites/env/pillar.svg"),
]
## How many of each prop to scatter (indices match PROP_TEXTURES).
const PROP_COUNTS: Array = [4, 3, 3, 2]

@export var interior_size: Vector2 = Vector2(1200.0, 760.0)
@export var wall_thickness: float = 24.0
@export var door_gap: float = 170.0

var player: Player = null

var _cleared: bool = false
var _door_open: bool = false
var _spawned: bool = false
var _gate_shape: CollisionShape2D = null
var _seed: int = 0  # per-room look (stains, prop placement)

func _ready() -> void:
	_seed = randi()
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # tile the floor texture
	_build_walls()
	_build_door()
	_decorate()

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
	queue_redraw()  # repaint the portcullis as an open, glowing arch
	_spawn_door_beacon()
	Audio.sfx("door", -6.0)
	room_cleared.emit()

## A soft column of soul-light in the open doorway - "this way out".
func _spawn_door_beacon() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(_half().x + wall_thickness * 0.5, 0.0)
	p.amount = 14
	p.lifetime = 0.9
	p.direction = Vector2.UP
	p.spread = 8.0
	p.initial_velocity_min = 26.0
	p.initial_velocity_max = 60.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(wall_thickness * 0.5, door_gap * 0.45)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.5, 0.91, 0.63, 0.8))
	ramp.set_color(1, Color(0.5, 0.91, 0.63, 0.0))
	p.color_ramp = ramp
	add_child(p)

func _on_door_body_entered(body: Node) -> void:
	if _door_open and body == player:
		player_exited.emit()

# --- Decoration (visual only, no collision) ---------------------------------

func _decorate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var h := _half()
	# Scattered grave props, kept clear of the entrance and the exit corridor.
	for kind in PROP_TEXTURES.size():
		for i in PROP_COUNTS[kind]:
			var pos := _prop_spot(rng, h)
			var s := Sprite2D.new()
			s.texture = PROP_TEXTURES[kind]
			s.position = pos
			s.scale = Vector2.ONE * rng.randf_range(0.8, 1.15)
			s.flip_h = rng.randf() < 0.5
			s.modulate = Color(1, 1, 1, rng.randf_range(0.85, 1.0))
			add_child(s)
	# Torches along the long walls, with live flame + pulsing glow.
	for x in [-h.x * 0.52, -h.x * 0.12, h.x * 0.12, h.x * 0.52]:
		_add_torch(Vector2(x, -h.y + 14.0))
		_add_torch(Vector2(x, h.y - 14.0))
	# Silver Flame banners: the Inquisition has already claimed these halls.
	for x in [-h.x * 0.32, h.x * 0.32]:
		var b := Sprite2D.new()
		b.texture = BANNER_TEX
		b.position = Vector2(x, -h.y + 24.0)
		b.scale = Vector2(0.85, 0.85)
		add_child(b)

## A prop position that avoids the entrance area and the exit corridor.
func _prop_spot(rng: RandomNumberGenerator, h: Vector2) -> Vector2:
	for _try in 10:
		var p := Vector2(rng.randf_range(-h.x + 70.0, h.x - 70.0),
			rng.randf_range(-h.y + 70.0, h.y - 70.0))
		if p.distance_to(Vector2(-h.x + 80.0, 0.0)) < 150.0:
			continue  # entrance: the party lands here each room
		if p.x > h.x - 170.0 and absf(p.y) < door_gap * 0.5 + 50.0:
			continue  # exit corridor
		return p
	return Vector2(0.0, -h.y + 90.0)

func _add_torch(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = TORCH_TEX
	s.position = pos
	s.scale = Vector2(0.7, 0.7)
	add_child(s)
	var glow := TorchGlow.new()
	glow.position = pos + Vector2(0.0, -12.0)  # at the flame bowl
	add_child(glow)

## Pulsing warm light + live flame particles above a torch bowl.
class TorchGlow:
	extends Node2D

	var _phase: float = 0.0

	func _ready() -> void:
		_phase = randf() * TAU  # desync the flicker across torches
		var p := CPUParticles2D.new()
		p.amount = 6
		p.lifetime = 0.45
		p.direction = Vector2.UP
		p.spread = 14.0
		p.initial_velocity_min = 24.0
		p.initial_velocity_max = 42.0
		p.scale_amount_min = 2.2
		p.scale_amount_max = 3.4
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 0.72, 0.3, 0.9))
		ramp.set_color(1, Color(0.9, 0.3, 0.1, 0.0))
		p.color_ramp = ramp
		add_child(p)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var f: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 7.0 + _phase)
		draw_circle(Vector2.ZERO, 44.0 + 5.0 * f, Color(1.0, 0.62, 0.28, 0.05))
		draw_circle(Vector2.ZERO, 24.0 + 3.0 * f, Color(1.0, 0.68, 0.32, 0.07))

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
# Static: repainted only on door state changes, not per frame.

func _draw() -> void:
	var h := _half()
	var t := wall_thickness
	# Stone-flag floor, tiled from the 64px SVG.
	draw_texture_rect(FLOOR_TEX, Rect2(-h.x, -h.y, interior_size.x, interior_size.y), true)
	_draw_floor_stains(h)
	# Brick walls.
	_draw_brick_wall(Rect2(-h.x - t, -h.y - t, interior_size.x + 2 * t, t), true)
	_draw_brick_wall(Rect2(-h.x - t, h.y, interior_size.x + 2 * t, t), true)
	_draw_brick_wall(Rect2(-h.x - t, -h.y, t, interior_size.y), false)
	var seg_len: float = h.y - door_gap * 0.5
	_draw_brick_wall(Rect2(h.x, -h.y, t, seg_len), false)
	_draw_brick_wall(Rect2(h.x, h.y - seg_len, t, seg_len), false)
	# Sealed arch where the party entered - no way back.
	draw_rect(Rect2(-h.x - t, -door_gap * 0.35, t, door_gap * 0.7), Color(0.12, 0.11, 0.16))
	draw_rect(Rect2(-h.x - t, -door_gap * 0.35, t, door_gap * 0.7), Color(0.3, 0.28, 0.38, 0.5), false, 1.5)
	# The exit door.
	_draw_door(h, t)

## Mossy and bloody memories of earlier slaughters, seeded per room.
func _draw_floor_stains(h: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	for i in 4:
		var pos := Vector2(rng.randf_range(-h.x * 0.85, h.x * 0.85), rng.randf_range(-h.y * 0.8, h.y * 0.8))
		var r: float = rng.randf_range(50.0, 130.0)
		var moss: bool = rng.randf() < 0.6
		var col := Color(0.22, 0.34, 0.22, 0.07) if moss else Color(0.3, 0.08, 0.08, 0.06)
		draw_circle(pos, r, col)
		draw_circle(pos + Vector2(r * 0.3, r * 0.2), r * 0.55, col)

## A course of bricks with per-brick shade variation (position-hashed, stable).
func _draw_brick_wall(rect: Rect2, horizontal: bool) -> void:
	draw_rect(rect, Color(0.13, 0.12, 0.17))  # mortar
	var brick_len: float = 34.0
	var course: float = rect.size.y * 0.5 if horizontal else rect.size.x * 0.5
	var length: float = rect.size.x if horizontal else rect.size.y
	var courses: int = 2
	for c in courses:
		var offset: float = 0.0 if c % 2 == 0 else brick_len * 0.5
		var along: float = -offset
		while along < length:
			var seg: float = minf(brick_len, length - along)
			var start: float = maxf(along, 0.0)
			seg -= start - along
			if seg > 2.0:
				var b: Rect2
				if horizontal:
					b = Rect2(rect.position.x + start + 1.0, rect.position.y + c * course + 1.0, seg - 2.0, course - 2.0)
				else:
					b = Rect2(rect.position.x + c * course + 1.0, rect.position.y + start + 1.0, course - 2.0, seg - 2.0)
				var v: float = fposmod(sin(b.position.x * 12.9898 + b.position.y * 78.233) * 43758.5453, 1.0)
				var shade := Color(0.27, 0.25, 0.33).lightened(v * 0.08)
				draw_rect(b, shade)
			along += brick_len

## Sealed: an iron portcullis warded in red. Open: a soul-lit green archway.
func _draw_door(h: Vector2, t: float) -> void:
	var door_rect := Rect2(h.x, -door_gap * 0.5, t, door_gap)
	if _door_open:
		draw_rect(door_rect, Color(0.09, 0.14, 0.1))
		draw_rect(Rect2(h.x, -door_gap * 0.5, t, door_gap), Color(0.3, 0.9, 0.4, 0.22))
		draw_line(Vector2(h.x + t, -door_gap * 0.5), Vector2(h.x + t, door_gap * 0.5), Color(0.4, 1.0, 0.5), 3.0)
		draw_line(Vector2(h.x, -door_gap * 0.5), Vector2(h.x, door_gap * 0.5), Color(0.4, 1.0, 0.5, 0.5), 1.5)
	else:
		draw_rect(door_rect, Color(0.10, 0.09, 0.13))
		# Portcullis bars.
		var bar := Color(0.36, 0.36, 0.44)
		var y0: float = -door_gap * 0.5 + 4.0
		var y1: float = door_gap * 0.5 - 4.0
		var x: float = h.x + 4.0
		while x < h.x + t - 2.0:
			draw_line(Vector2(x, y0), Vector2(x, y1), bar, 3.0)
			x += 8.0
		draw_line(Vector2(h.x + 2.0, -door_gap * 0.22), Vector2(h.x + t - 2.0, -door_gap * 0.22), bar.darkened(0.2), 4.0)
		draw_line(Vector2(h.x + 2.0, door_gap * 0.22), Vector2(h.x + t - 2.0, door_gap * 0.22), bar.darkened(0.2), 4.0)
		# Red warding glow: sealed while the Inquisition still stands.
		draw_line(Vector2(h.x + t, -door_gap * 0.5), Vector2(h.x + t, door_gap * 0.5), Color(0.9, 0.25, 0.2, 0.6), 3.0)
