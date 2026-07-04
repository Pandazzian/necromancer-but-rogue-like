class_name Enemy
extends BaseEntity
## An Inquisitor of the Silver Flame. Simple melee AI: chase nearest target
## (player or minion) and attack. On death, leaves a Corpse to be Soul Bound,
## drops Soul Essence, and sometimes a harvestable Graft. Elites are tougher,
## always drop grafts, and their corpses demand a Soul Jar to capture; Bosses
## (every few rooms) are walking calamities that shower loot.

const CorpseScene: PackedScene = preload("res://scenes/corpse.tscn")
const AVOID_GROUPS: PackedStringArray = ["enemies", "minions"]

## Class definition. Assign before adding to the tree (set by Room via Classes).
@export var archetype: UnitArchetype = null
@export var move_speed: float = 120.0
@export var retarget_interval: float = 0.4
## Chance to drop a harvestable graft on death (GDD 3.5). Elites guarantee one.
@export var graft_drop_chance: float = 0.2
@export var is_elite: bool = false
@export var is_boss: bool = false

var class_id: String = "warrior"
var target: BaseEntity = null
var _atk_cd: float = 0.0
var _retarget_cd: float = 0.0
var _attack_flash: float = 0.0
var _stun_timer: float = 0.0
var _slow_timer: float = 0.0
var _knockback: Vector2 = Vector2.ZERO

func _ready() -> void:
	if archetype != null:
		apply_archetype(archetype)
		move_speed = archetype.move_speed
		class_id = archetype.id
	else:
		max_hp = 30.0
		body_radius = 14.0
		body_color = Color(0.85, 0.3, 0.3)
	if is_boss:
		is_elite = true  # bosses count as elites everywhere (jars, drops)
		max_hp *= 4.5
		attack_damage *= 2.0
		defense += 3.0
		body_radius += 10.0
		move_speed *= 0.85
	elif is_elite:
		max_hp *= 1.8
		attack_damage *= 1.5
		body_radius += 4.0
	super._ready()
	add_to_group("enemies")
	collision_layer = LAYER_ENEMY
	collision_mask = LAYER_WORLD  # walls only; pass through units
	attack_target_groups = PackedStringArray(["minions", "player"])
	# Body sprite last: elite/boss scaling above has settled body_radius.
	setup_sprite("res://assets/sprites/inquisitor_%s.svg" % class_id)
	start_rise(0.25)  # brief march-in fade so spawns don't pop

func _physics_process(delta: float) -> void:
	_atk_cd = maxf(0.0, _atk_cd - delta)
	_retarget_cd = maxf(0.0, _retarget_cd - delta)
	_attack_flash = maxf(0.0, _attack_flash - delta)
	_stun_timer = maxf(0.0, _stun_timer - delta)
	_slow_timer = maxf(0.0, _slow_timer - delta)

	# Knockback (Reaper's Sweep) decays quickly but overrides intent.
	if _knockback.length() > 5.0:
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		queue_redraw()
		return

	# Stunned (corpse-rats): rooted and helpless.
	if _stun_timer > 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return

	if _retarget_cd <= 0.0 or target == null or not is_instance_valid(target) or (target as BaseEntity).is_dead:
		target = _acquire_target()
		_retarget_cd = retarget_interval

	if target == null or not is_instance_valid(target):
		velocity = compute_separation(AVOID_GROUPS)
		move_and_slide()
		queue_redraw()
		return

	var speed: float = move_speed * (0.5 if _slow_timer > 0.0 else 1.0)
	var to_target: Vector2 = target.global_position - global_position
	if to_target.length() > attack_range:
		velocity = to_target.normalized() * speed
	else:
		velocity = Vector2.ZERO
		if _atk_cd <= 0.0:
			perform_attack(target)
			_atk_cd = attack_cooldown
			if attack_type == UnitArchetype.AttackType.MELEE:
				_attack_flash = 0.12
	velocity += compute_separation(AVOID_GROUPS)
	move_and_slide()
	queue_redraw()

# --- Status (applied by player weapons / toxic clouds) ----------------------

func apply_stun(duration: float) -> void:
	_stun_timer = maxf(_stun_timer, duration)

func apply_slow(duration: float) -> void:
	_slow_timer = maxf(_slow_timer, duration)

func apply_knockback(impulse: Vector2) -> void:
	_knockback = impulse

func _acquire_target() -> BaseEntity:
	var best: BaseEntity = null
	var best_d: float = INF
	# Prefer minions; fall back to the player.
	var candidates: Array = get_tree().get_nodes_in_group("minions")
	candidates.append_array(get_tree().get_nodes_in_group("player"))
	for c in candidates:
		if c is BaseEntity and not (c as BaseEntity).is_dead:
			var d: float = global_position.distance_to((c as BaseEntity).global_position)
			if d < best_d:
				best_d = d
				best = c
	return best

func _on_death() -> void:
	var corpse := CorpseScene.instantiate()
	corpse.global_position = global_position
	corpse.source_class = class_id  # soul-binding raises a minion of this class
	corpse.source_color = body_color  # keep the class colour (dulled) on the corpse
	corpse.source_elite = is_elite  # elites demand a Soul Jar (GDD 3.2)
	corpse.source_tier = 3 if is_boss else (2 if is_elite else 1)
	# Defer so we don't add a sibling while the tree is busy with this frame's physics.
	get_parent().call_deferred("add_child", corpse)
	# Soul Essence for the macro-loop (GDD 2.B); banked when the run ends.
	RunState.run_essence += 25 if is_boss else (6 if is_elite else 2)
	RunState.run_xp += 12 if is_boss else (4 if is_elite else 1)
	if is_boss:
		RunState.soul_jars += 1  # bosses yield a fresh Soul Jar
	_maybe_drop_graft()
	if is_boss:
		_maybe_drop_graft()  # bosses guarantee a second organ (GDD 3.5)
	DeathFX.spawn(get_parent(), self)  # topple visual; corpse lands beneath it
	FX.bone_burst(get_parent(), global_position)
	Audio.sfx("bones", -8.0)
	queue_free()

## Elites always drop; regular Inquisitors drop by chance (GDD 3.5 harvesting).
func _maybe_drop_graft() -> void:
	if not is_elite and randf() > graft_drop_chance:
		return
	var pickup := GraftPickup.new()
	pickup.graft = Grafts.random_drop()
	# Nudge the gem clear of the corpse so both are grabbable.
	pickup.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-28, -12))
	get_parent().call_deferred("add_child", pickup)

func _draw() -> void:
	_draw_body_and_health()
	# Elite/boss insignia: a golden (boss: double) ring.
	if is_elite:
		draw_arc(Vector2.ZERO, body_radius + 4.0, 0.0, TAU, 32, Color(1.0, 0.8, 0.25, 0.9), 2.0)
	if is_boss:
		draw_arc(Vector2.ZERO, body_radius + 8.0, 0.0, TAU, 40, Color(1.0, 0.6, 0.15, 0.8), 2.0)
	# Marked (Surgical Strike): a sickly green cross-hair.
	if marked_mult > 1.0:
		draw_arc(Vector2.ZERO, body_radius + 2.0, 0.0, TAU, 24, Color(0.5, 1.0, 0.6, 0.9), 1.5)
	if _stun_timer > 0.0:
		draw_arc(Vector2(0, visual_top() - 6.0), 4.0, 0.0, TAU, 12, Color(1, 1, 1, 0.8), 1.5)
	if _attack_flash > 0.0 and target != null and is_instance_valid(target):
		draw_line(Vector2.ZERO, to_local(target.global_position), Color(1, 0.4, 0.4, 0.9), 2.0)
