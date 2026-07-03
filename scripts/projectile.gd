class_name Projectile
extends Node2D
## A travelling attack fired by Archers (single-target) and Mages (AoE).
## Detects targets by group (manual distance check, no physics layers needed).

const SCENE: PackedScene = preload("res://scenes/projectile.tscn")

var dir: Vector2 = Vector2.RIGHT
var speed: float = 480.0
var damage: float = 8.0
var target_groups: PackedStringArray = PackedStringArray()
var aoe_radius: float = 0.0
var color: Color = Color.WHITE
var max_dist: float = 400.0

## Who fired this (credited as the damage source for marks, life-steal, reflect).
var source: BaseEntity = null
## Seconds of stun applied to enemies hit (used by the Vermin Lord's rats).
var stun: float = 0.0

var _traveled: float = 0.0
var _blast: float = 0.0  # >0 while the AoE detonation flash is showing

## Fire a projectile from `shooter_parent` (kept in that node so it despawns with it).
static func spawn(shooter_parent: Node, pos: Vector2, direction: Vector2, dmg: float,
		groups: PackedStringArray, spd: float, aoe: float, col: Color, range_px: float,
		src: BaseEntity = null, stun_s: float = 0.0) -> void:
	if shooter_parent == null or not is_instance_valid(shooter_parent):
		return
	var p: Projectile = SCENE.instantiate()
	p.dir = direction
	p.speed = spd
	p.damage = dmg
	p.target_groups = groups
	p.aoe_radius = aoe
	p.color = col
	p.max_dist = range_px
	p.source = src
	p.stun = stun_s
	p.position = pos  # parents (Actors / Room) sit at the origin, so this is world-space
	shooter_parent.add_child(p)

func _physics_process(delta: float) -> void:
	if _blast > 0.0:
		_blast -= delta
		if _blast <= 0.0:
			queue_free()
		else:
			queue_redraw()
		return

	var step: float = speed * delta
	position += dir * step
	_traveled += step
	var hit: BaseEntity = _find_hit()
	if hit != null or _traveled >= max_dist:
		_detonate(hit)
	else:
		queue_redraw()

func _find_hit() -> BaseEntity:
	for g in target_groups:
		for n in get_tree().get_nodes_in_group(g):
			if n is BaseEntity and not (n as BaseEntity).is_dead:
				var e := n as BaseEntity
				if global_position.distance_to(e.global_position) <= e.body_radius + 7.0:
					return e
	return null

func _detonate(hit: BaseEntity) -> void:
	if aoe_radius > 0.0:
		for g in target_groups:
			for n in get_tree().get_nodes_in_group(g):
				if n is BaseEntity and not (n as BaseEntity).is_dead:
					var e := n as BaseEntity
					if global_position.distance_to(e.global_position) <= aoe_radius:
						_deal(e)
		_blast = 0.15  # linger briefly to show the blast
		queue_redraw()
	else:
		if hit != null:
			_deal(hit)
		queue_free()

func _deal(e: BaseEntity) -> void:
	var src: Node = source if source != null and is_instance_valid(source) else self
	e.take_damage(damage, src)
	if stun > 0.0 and e is Enemy:
		(e as Enemy).apply_stun(stun)
	# Life-steal travels with the minion's projectiles too (Vampiric Aura).
	if src is Minion:
		(src as Minion).on_damage_dealt(damage)

func _draw() -> void:
	if _blast > 0.0:
		draw_circle(Vector2.ZERO, aoe_radius, Color(color.r, color.g, color.b, 0.22))
		draw_arc(Vector2.ZERO, aoe_radius, 0.0, TAU, 40, color, 2.0)
	else:
		draw_circle(Vector2.ZERO, 5.0, color)
		draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 12, color.lightened(0.4), 1.5)
