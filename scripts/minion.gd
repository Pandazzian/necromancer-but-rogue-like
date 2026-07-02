class_name Minion
extends BaseEntity
## An undead servant. Obeys RTS orders only inside the Command Aura; outside it,
## it falls into Lethargy and slowly crumbles (GDD 3.1).

enum State { IDLE, MOVING, ATTACKING, LETHARGY }

const LETHARGY_MELEE_RANGE: float = 46.0

## Class definition. Assign before adding to the tree (set by Main via Classes).
@export var archetype: UnitArchetype = null
@export var move_speed: float = 210.0
@export var lethargy_dps: float = 6.0
## Idle minions auto-engage any enemy that wanders within this radius.
@export var auto_aggro_range: float = 150.0
## While auto-attacking, a minion won't chase past this multiple of its aggro
## range (keeps it from being lured out of the aura). Ordered attacks ignore this.
@export var auto_leash_mult: float = 1.6

var class_id: String = "warrior"
var state: int = State.IDLE
var order_pos: Vector2
var target: BaseEntity = null
var selected: bool = false
var player: Player = null

var _atk_cd: float = 0.0
var _attack_flash: float = 0.0
var _ordered_attack: bool = false  # true = explicit R-click order, false = auto
var _base_color: Color = Color(0.45, 0.8, 0.45)

func _ready() -> void:
	if archetype != null:
		apply_archetype(archetype)
		move_speed = archetype.move_speed
		class_id = archetype.id
	else:
		max_hp = 55.0
		body_radius = 13.0
		body_color = Color(0.45, 0.8, 0.45)
	_base_color = body_color
	# Ranged classes need to auto-engage from further out than the melee default.
	auto_aggro_range = maxf(auto_aggro_range, attack_range * 0.9)
	super._ready()
	add_to_group("minions")
	attack_target_groups = PackedStringArray(["enemies"])
	order_pos = global_position

func _physics_process(delta: float) -> void:
	_atk_cd = maxf(0.0, _atk_cd - delta)
	_attack_flash = maxf(0.0, _attack_flash - delta)

	if player == null or not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return

	var in_aura: bool = global_position.distance_to(player.global_position) <= player.aura_radius
	if not in_aura:
		_process_lethargy(delta)
	else:
		if state == State.LETHARGY:
			state = State.IDLE  # tether re-established
		match state:
			State.IDLE:
				_process_idle()
			State.MOVING:
				_process_moving()
			State.ATTACKING:
				_process_attacking()
	queue_redraw()

# --- Orders (issued by RTSCommander) ---------------------------------------

func order_move(pos: Vector2) -> void:
	order_pos = pos
	target = null
	_ordered_attack = false
	state = State.MOVING

func order_attack(enemy: BaseEntity) -> void:
	target = enemy
	_ordered_attack = true  # explicit orders chase relentlessly
	state = State.ATTACKING

# --- State handlers --------------------------------------------------------

func _process_idle() -> void:
	# Auto-engage the nearest enemy that strays into range (attack-move guard).
	var enemy: BaseEntity = _nearest_enemy_within(auto_aggro_range)
	if enemy != null:
		target = enemy
		_ordered_attack = false
		state = State.ATTACKING
		return
	velocity = Vector2.ZERO
	move_and_slide()

func _process_moving() -> void:
	var to_target: Vector2 = order_pos - global_position
	if to_target.length() <= 6.0:
		velocity = Vector2.ZERO
		move_and_slide()
		state = State.IDLE
		return
	velocity = to_target.normalized() * move_speed
	move_and_slide()

func _process_attacking() -> void:
	if target == null or not is_instance_valid(target) or target.is_dead:
		target = null
		state = State.IDLE
		return
	var to_target: Vector2 = target.global_position - global_position
	# Auto-acquired targets have a leash so minions can't be baited out of the aura.
	if not _ordered_attack and to_target.length() > auto_aggro_range * auto_leash_mult:
		target = null
		state = State.IDLE
		return
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
				_attack_flash = 0.1

func _process_lethargy(delta: float) -> void:
	state = State.LETHARGY
	velocity = Vector2.ZERO
	move_and_slide()
	take_true_damage(lethargy_dps * delta)  # crumbles over time, ignores defense
	# Crippled: no movement and no ranged attacks, just weak flails at melee range.
	if _atk_cd <= 0.0:
		var enemy: BaseEntity = _nearest_enemy_within(LETHARGY_MELEE_RANGE)
		if enemy != null:
			enemy.take_damage(attack_damage * 0.5, self)  # weakened
			target = enemy
			_atk_cd = attack_cooldown
			_attack_flash = 0.1

func _nearest_enemy_within(radius: float) -> BaseEntity:
	var best: BaseEntity = null
	var best_d: float = radius
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is BaseEntity and not (e as BaseEntity).is_dead:
			var d: float = global_position.distance_to((e as BaseEntity).global_position)
			if d <= best_d:
				best_d = d
				best = e
	return best

func _on_death() -> void:
	queue_free()

func _draw() -> void:
	if selected:
		draw_arc(Vector2.ZERO, body_radius + 6.0, 0.0, TAU, 32, Color(1.0, 1.0, 0.4), 2.0)
	if state == State.LETHARGY:
		body_color = _base_color.darkened(0.4)  # dull, drained
	else:
		body_color = _base_color
	_draw_body_and_health()
	if _attack_flash > 0.0 and target != null and is_instance_valid(target):
		draw_line(Vector2.ZERO, to_local(target.global_position), Color(1, 1, 0.5, 0.8), 2.0)
