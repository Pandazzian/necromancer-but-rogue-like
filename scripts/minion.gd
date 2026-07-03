class_name Minion
extends BaseEntity
## An undead servant. Obeys RTS orders only inside the Command Aura; outside it,
## it falls into Lethargy and slowly crumbles (GDD 3.1). Units don't hard-collide
## with each other - crowding is smoothed by separation steering. Its identity,
## tier and grafts live in a persistent MinionInstance held by the owning player.

enum State { IDLE, MOVING, ATTACKING, LETHARGY }

const LETHARGY_MELEE_RANGE: float = 46.0
const AVOID_GROUPS: PackedStringArray = ["minions", "enemies"]

## Class definition. Optional - derived from `instance.class_id` when not set.
@export var archetype: UnitArchetype = null
@export var move_speed: float = 210.0
@export var lethargy_dps: float = 6.0
## Idle minions auto-engage any enemy that wanders within this radius.
@export var auto_aggro_range: float = 150.0
## While auto-attacking, a minion won't chase past this multiple of its aggro
## range (keeps it from being lured out of the aura). Ordered attacks ignore this.
@export var auto_leash_mult: float = 1.6

## The persistent roster data this field minion was spawned from (Main sets it).
## If null one is created, so the minion always has identity/tier/grafts.
var instance: MinionInstance = null
## Which peer commands this minion (inherited from its owning Necromancer).
var owner_peer_id: int = 1
var tier: int = 1
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
var _formation_speed: float = 0.0  # >0 = move at this capped speed (slowest in group)

func _ready() -> void:
	# Ensure we always have persistent data (legacy callers may set only archetype).
	if instance == null:
		var cid: String = archetype.id if archetype != null else "warrior"
		instance = MinionInstance.create(cid)
	class_id = instance.class_id
	tier = instance.tier
	if archetype == null:
		archetype = Classes.minion(instance.class_id)

	apply_archetype(archetype)   # base colour, ranges, attack type
	_apply_instance_stats()      # tier + graft scaling on top of the base
	_base_color = body_color.lightened(clampf(0.12 * float(tier - 1), 0.0, 0.4))
	# Ranged classes need to auto-engage from further out than the melee default.
	auto_aggro_range = maxf(auto_aggro_range, attack_range * 0.9)
	super._ready()  # sets current_hp = max_hp
	# Restore any wounds carried over from a previous room.
	if instance.stored_hp >= 0.0:
		current_hp = clampf(instance.stored_hp, 1.0, max_hp)
	add_to_group("minions")
	collision_layer = LAYER_MINION
	collision_mask = LAYER_WORLD  # walls only; pass through units
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

	# Rapid Decay (Rotting Ledger 4.2): the horde is always rotting away.
	var decay: float = player.tome.minion_decay_pct if player.tome != null else 0.0
	if decay > 0.0:
		take_true_damage(max_hp * decay * delta)
		if is_dead:
			return

	# Aura membership is tome-shaped (circle or cone) - the player decides.
	var in_aura: bool = player.is_in_aura(global_position)
	if not in_aura:
		_process_lethargy(delta)  # sets velocity; no separation while crumbling
		move_and_slide()
		queue_redraw()
		return

	if state == State.LETHARGY:
		state = State.IDLE  # tether re-established
	match state:
		State.IDLE:
			_process_idle()
		State.MOVING:
			_process_moving()
		State.ATTACKING:
			_process_attacking()
	velocity += compute_separation(AVOID_GROUPS)
	move_and_slide()
	queue_redraw()

# --- Orders (issued by RTSCommander) ---------------------------------------

## Move to `pos`. If `capped_speed` > 0, march at that speed instead of the
## minion's own (used for cohesive formations: everyone moves at the slowest).
func order_move(pos: Vector2, capped_speed: float = 0.0) -> void:
	order_pos = pos
	target = null
	_ordered_attack = false
	_formation_speed = capped_speed
	state = State.MOVING

func order_attack(enemy: BaseEntity) -> void:
	target = enemy
	_ordered_attack = true  # explicit orders chase relentlessly
	_formation_speed = 0.0
	state = State.ATTACKING

# --- State handlers (set velocity only; caller runs move_and_slide) ---------

func _process_idle() -> void:
	# Auto-engage the nearest enemy that strays into range (attack-move guard).
	var enemy: BaseEntity = _nearest_enemy_within(auto_aggro_range)
	if enemy != null:
		target = enemy
		_ordered_attack = false
		state = State.ATTACKING
		return
	velocity = Vector2.ZERO

func _process_moving() -> void:
	var to_target: Vector2 = order_pos - global_position
	if to_target.length() <= 6.0:
		velocity = Vector2.ZERO
		state = State.IDLE
		_formation_speed = 0.0
		return
	var spd: float = _formation_speed if _formation_speed > 0.0 else move_speed
	velocity = to_target.normalized() * spd

func _process_attacking() -> void:
	if target == null or not is_instance_valid(target) or target.is_dead:
		target = null
		velocity = Vector2.ZERO
		state = State.IDLE
		return
	var to_target: Vector2 = target.global_position - global_position
	# Auto-acquired targets have a leash so minions can't be baited out of the aura.
	if not _ordered_attack and to_target.length() > auto_aggro_range * auto_leash_mult:
		target = null
		velocity = Vector2.ZERO
		state = State.IDLE
		return
	if to_target.length() > attack_range:
		velocity = to_target.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
		if _atk_cd <= 0.0:
			perform_attack(target)
			_atk_cd = _effective_cooldown()
			if attack_type == UnitArchetype.AttackType.MELEE:
				_attack_flash = 0.1

## Attack cooldown after aura buffs: the Bone-Carver's cone hastens everyone
## fighting inside it (GDD 4.4 Directional Command).
func _effective_cooldown() -> float:
	var cd: float = attack_cooldown
	if player != null and is_instance_valid(player) and player.tome != null \
			and player.tome.aura_attack_speed > 0.0 and player.is_in_aura(global_position):
		cd /= 1.0 + player.tome.aura_attack_speed
	return cd

func _process_lethargy(delta: float) -> void:
	state = State.LETHARGY
	velocity = Vector2.ZERO
	take_true_damage(lethargy_dps * delta)  # crumbles over time, ignores defense
	# Crippled: no movement and no ranged attacks, just weak flails at melee range.
	if _atk_cd <= 0.0:
		var enemy: BaseEntity = _nearest_enemy_within(LETHARGY_MELEE_RANGE)
		if enemy != null:
			enemy.take_damage(attack_damage * 0.5, self)  # weakened
			target = enemy
			_atk_cd = attack_cooldown
			_attack_flash = 0.1

# --- Stats -----------------------------------------------------------------

## Recompute combat stats from the instance's tier and equipped grafts, layered
## on top of the base archetype (which apply_archetype() must have set first).
## Tier scaling is the Flesh-Stitching reward; graft bonuses add on top.
func _apply_instance_stats() -> void:
	var t: float = float(instance.tier - 1)
	max_hp = archetype.max_hp * (1.0 + 0.7 * t) + instance.hp_bonus()
	attack_damage = archetype.attack_damage * (1.0 + 0.6 * t) + instance.damage_bonus()
	defense = archetype.defense + 2.0 * t + instance.defense_bonus()
	attack_cooldown = archetype.attack_cooldown * instance.attack_speed_mult()
	move_speed = archetype.move_speed * instance.move_speed_mult()
	body_radius = archetype.body_radius + 2.0 * t

## Re-apply stats after a graft is added in the field (heals by any new max HP so
## a defensive graft takes effect immediately). Called by the inventory screen.
func refresh_from_instance() -> void:
	var old_max: float = max_hp
	_apply_instance_stats()
	var delta: float = max_hp - old_max
	if delta > 0.0:
		current_hp = minf(max_hp, current_hp + delta)
	else:
		current_hp = minf(current_hp, max_hp)
	queue_redraw()

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

# --- Combat hooks (grafts + Grimoire pages) ----------------------------------

## Melee attacks gain crits (Ruthless Command), graft bleeds and life-steal.
## Ranged/AoE classes defer to the base projectile path (source-credited).
func perform_attack(atk_target: BaseEntity) -> void:
	if atk_target == null or not is_instance_valid(atk_target):
		return
	if attack_type != UnitArchetype.AttackType.MELEE:
		super.perform_attack(atk_target)
		return
	var dmg: float = attack_damage
	if RunState.page_active("ruthless_command") and randf() < 0.15:
		dmg *= 2.0  # critical strike
	atk_target.take_damage(dmg, self)
	var bleed: float = instance.bleed_dps()
	if bleed > 0.0:
		atk_target.apply_bleed(bleed, 3.0)  # Serrated Bone-Blades
	on_damage_dealt(dmg)

## Credited whenever this minion deals damage (melee or via its projectiles).
func on_damage_dealt(dmg: float) -> void:
	if RunState.page_active("vampiric_aura"):
		heal(dmg * 0.2)

## Incoming damage: Stitcher aura shields the pack; Mirror-Glass Scales bite back.
func take_damage(amount: float, source: Node = null) -> void:
	if player != null and is_instance_valid(player) and player.tome != null \
			and player.tome.aura_damage_reduction > 0.0 and player.is_in_aura(global_position):
		amount *= 1.0 - player.tome.aura_damage_reduction
	var refl: float = instance.reflect_pct() if instance != null else 0.0
	if refl > 0.0 and source is Enemy and is_instance_valid(source):
		(source as Enemy).take_true_damage(amount * refl)
	super.take_damage(amount, source)

func _on_death() -> void:
	# Volatile Bile Gland / Explosive Decay: the dead repay their debts loudly.
	var boom: float = instance.death_explosion() if instance != null else 0.0
	if RunState.page_active("explosive_decay"):
		boom += 14.0
	if boom > 0.0:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is BaseEntity and not (e as BaseEntity).is_dead \
					and global_position.distance_to((e as BaseEntity).global_position) <= 80.0:
				(e as BaseEntity).take_damage(boom, null)
	# Rotting Ledger (4.2): death inside the aura fumes into a slowing miasma.
	if player != null and is_instance_valid(player) and player.tome != null \
			and player.tome.death_clouds and player.is_in_aura(global_position):
		ToxicCloud.spawn(get_parent(), global_position)
	queue_free()

# --- Rendering -------------------------------------------------------------

func _draw() -> void:
	if selected:
		draw_arc(Vector2.ZERO, body_radius + 6.0, 0.0, TAU, 32, Color(1.0, 1.0, 0.4), 2.0)
	if state == State.LETHARGY:
		body_color = _base_color.darkened(0.4)  # dull, drained
	else:
		body_color = _base_color
	_draw_body_and_health()
	_draw_tier_pips()
	_draw_name()
	_draw_graft_pips()
	if _attack_flash > 0.0 and target != null and is_instance_valid(target):
		draw_line(Vector2.ZERO, to_local(target.global_position), Color(1, 1, 0.5, 0.8), 2.0)

## Golden dots above the head, one per tier beyond the first (Flesh-Stitching).
func _draw_tier_pips() -> void:
	if tier <= 1:
		return
	for i in range(tier - 1):
		draw_circle(Vector2(-6.0 + float(i) * 6.0, -body_radius - 7.0), 2.4, Color(1.0, 0.85, 0.3))

## Small coloured dots beneath the body, one per equipped graft, so grafted
## (valuable) minions are recognisable at a glance on the field.
func _draw_graft_pips() -> void:
	if instance == null or instance.grafts.is_empty():
		return
	var n: int = instance.grafts.size()
	var spacing: float = 7.0
	var y: float = body_radius + 6.0
	var x0: float = -float(n - 1) * spacing * 0.5
	for i in n:
		var g: GraftItem = instance.grafts[i]
		draw_circle(Vector2(x0 + float(i) * spacing, y), 2.6, g.color)

## Floating name tag so the player can tell their minions apart at a glance
## (brighter when selected). Sits just above the tier pips.
func _draw_name() -> void:
	if instance == null or instance.unit_name.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var fs: int = 12
	var nm: String = instance.unit_name
	var w: float = font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var col: Color = Color(1.0, 0.95, 0.5) if selected else Color(0.85, 0.9, 0.95, 0.6)
	draw_string(font, Vector2(-w * 0.5, -body_radius - 18.0), nm,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
