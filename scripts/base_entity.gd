class_name BaseEntity
extends CharacterBody2D
## Shared base for the Necromancer, minions and enemies.
## Owns HP, damage handling and death events (GDD 6.2 "BaseEntity (Abstract)").

signal died(entity: BaseEntity)
signal health_changed(current: float, maximum: float)

# Physics layer bit-values. Units collide only with WORLD (walls), never with
# each other - crowding is resolved by soft separation steering instead.
const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_MINION: int = 4
const LAYER_ENEMY: int = 8

const SEPARATION_GAIN: float = 6.0
const SEPARATION_MAX: float = 170.0

@export var max_hp: float = 100.0
## Radius of this actor's body, used for drawing and melee range checks.
@export var body_radius: float = 16.0
@export var body_color: Color = Color.WHITE
## Flat damage reduction per hit (Tanks have a lot).
@export var defense: float = 0.0

# Combat stats shared by minions and enemies. Set directly or via apply_archetype().
# (The Player subclass runs its own combat and leaves these at their defaults.)
var attack_damage: float = 8.0
var attack_range: float = 42.0
var attack_cooldown: float = 0.8
var attack_type: int = UnitArchetype.AttackType.MELEE
var projectile_speed: float = 480.0
var aoe_radius: float = 0.0
var attack_target_groups: PackedStringArray = PackedStringArray()

var current_hp: float
var is_dead: bool = false

## Bleed DoT (Serrated Bone-Blades etc.): true damage per second while active.
var _bleed_dps: float = 0.0
var _bleed_time: float = 0.0
## Surgical Strike mark: the next hit from a Minion is multiplied by this.
var marked_mult: float = 1.0

func _ready() -> void:
	current_hp = max_hp

## Status effects tick in _process so every subclass gets them for free
## (subclasses use _physics_process for movement and don't override this).
func _process(delta: float) -> void:
	if _bleed_time > 0.0 and not is_dead:
		_bleed_time -= delta
		take_true_damage(_bleed_dps * delta)

## Open a wound: `dps` true damage for `duration` seconds (refreshes, no stack).
func apply_bleed(dps: float, duration: float) -> void:
	_bleed_dps = maxf(_bleed_dps, dps)
	_bleed_time = maxf(_bleed_time, duration)

## Configure combat/appearance from a class definition (GDD 6.1 MinionData).
func apply_archetype(a: UnitArchetype) -> void:
	max_hp = a.max_hp
	defense = a.defense
	body_radius = a.body_radius
	body_color = a.color
	attack_damage = a.attack_damage
	attack_range = a.attack_range
	attack_cooldown = a.attack_cooldown
	attack_type = a.attack_type
	projectile_speed = a.projectile_speed
	aoe_radius = a.aoe_radius

## Execute one attack against `target`: melee hit, or fire a projectile for
## ranged/AoE classes. Callers gate this on their own cooldown.
func perform_attack(target: BaseEntity) -> void:
	if target == null or not is_instance_valid(target):
		return
	if attack_type == UnitArchetype.AttackType.MELEE:
		target.take_damage(attack_damage, self)
		return
	var d: Vector2 = target.global_position - global_position
	d = d.normalized() if d.length() > 0.001 else Vector2.RIGHT
	Projectile.spawn(get_parent(), global_position, d, attack_damage,
		attack_target_groups, projectile_speed, aoe_radius, body_color, attack_range + 140.0, self)

func take_damage(amount: float, source: Node = null) -> void:
	if is_dead:
		return
	# Surgical Strike (GDD 4.1): a marked target takes multiplied damage from
	# the next minion that strikes it, then the mark is spent.
	if marked_mult > 1.0 and source is Minion:
		amount *= marked_mult
		marked_mult = 1.0
	var dealt: float = maxf(1.0, amount - defense)  # always chip at least 1
	current_hp = maxf(0.0, current_hp - dealt)
	health_changed.emit(current_hp, max_hp)
	if current_hp <= 0.0:
		die()

## Damage that ignores defense (used by DoTs like Lethargy).
func take_true_damage(amount: float) -> void:
	if is_dead:
		return
	current_hp = maxf(0.0, current_hp - amount)
	health_changed.emit(current_hp, max_hp)
	if current_hp <= 0.0:
		die()

func heal(amount: float) -> void:
	if is_dead:
		return
	current_hp = minf(max_hp, current_hp + amount)
	health_changed.emit(current_hp, max_hp)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(self)
	_on_death()

## Subclasses override to add drops, effects, etc. Default: despawn.
func _on_death() -> void:
	queue_free()

## Boids-style separation: a velocity that pushes this unit away from nearby
## units so crowds spread out instead of jamming. Add to velocity before
## move_and_slide(). `groups` lists which unit groups to avoid.
func compute_separation(groups: PackedStringArray) -> Vector2:
	var push: Vector2 = Vector2.ZERO
	for g in groups:
		for other in get_tree().get_nodes_in_group(g):
			if other == self or not (other is BaseEntity):
				continue
			var ob := other as BaseEntity
			if ob.is_dead:
				continue
			var d: Vector2 = global_position - ob.global_position
			var dist: float = d.length()
			var min_d: float = body_radius + ob.body_radius + 4.0
			if dist < min_d:
				if dist > 0.001:
					push += (d / dist) * (min_d - dist)
				else:
					# Exact overlap: shove apart in a random direction.
					push += Vector2(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0) * min_d
	push *= SEPARATION_GAIN
	if push.length() > SEPARATION_MAX:
		push = push.normalized() * SEPARATION_MAX
	return push

## Helper for subclasses: draw the body circle + a small HP bar in _draw().
func _draw_body_and_health() -> void:
	draw_circle(Vector2.ZERO, body_radius, body_color)
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 24, body_color.darkened(0.4), 2.0)
	if current_hp < max_hp and not is_dead:
		var w: float = body_radius * 2.0
		var y: float = -body_radius - 10.0
		var frac: float = clampf(current_hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(-body_radius, y, w, 4.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-body_radius, y, w * frac, 4.0), Color(0.3, 0.9, 0.3))
