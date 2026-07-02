class_name Enemy
extends BaseEntity
## An Inquisitor of the Silver Flame. Simple melee AI: chase nearest target
## (player or minion) and attack. On death, leaves a Corpse to be Soul Bound.

const CorpseScene: PackedScene = preload("res://scenes/corpse.tscn")

## Class definition. Assign before adding to the tree (set by Room via Classes).
@export var archetype: UnitArchetype = null
@export var move_speed: float = 120.0
@export var retarget_interval: float = 0.4

var class_id: String = "warrior"
var target: BaseEntity = null
var _atk_cd: float = 0.0
var _retarget_cd: float = 0.0
var _attack_flash: float = 0.0

func _ready() -> void:
	if archetype != null:
		apply_archetype(archetype)
		move_speed = archetype.move_speed
		class_id = archetype.id
	else:
		max_hp = 30.0
		body_radius = 14.0
		body_color = Color(0.85, 0.3, 0.3)
	super._ready()
	add_to_group("enemies")
	attack_target_groups = PackedStringArray(["minions", "player"])

func _physics_process(delta: float) -> void:
	_atk_cd = maxf(0.0, _atk_cd - delta)
	_retarget_cd = maxf(0.0, _retarget_cd - delta)
	_attack_flash = maxf(0.0, _attack_flash - delta)

	if _retarget_cd <= 0.0 or target == null or not is_instance_valid(target) or (target as BaseEntity).is_dead:
		target = _acquire_target()
		_retarget_cd = retarget_interval

	if target == null or not is_instance_valid(target):
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return

	var to_target: Vector2 = target.global_position - global_position
	if to_target.length() > attack_range:
		velocity = to_target.normalized() * move_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		move_and_slide()
		if _atk_cd <= 0.0:
			perform_attack(target)
			_atk_cd = attack_cooldown
			if attack_type == UnitArchetype.AttackType.MELEE:
				_attack_flash = 0.12
	queue_redraw()

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
	# Defer so we don't add a sibling while the tree is busy with this frame's physics.
	get_parent().call_deferred("add_child", corpse)
	queue_free()

func _draw() -> void:
	_draw_body_and_health()
	if _attack_flash > 0.0 and target != null and is_instance_valid(target):
		draw_line(Vector2.ZERO, to_local(target.global_position), Color(1, 0.4, 0.4, 0.9), 2.0)
