class_name Player
extends BaseEntity
## The Necromancer. Fragile, never fights directly (except Desperation Mode).
## WASD movement + the "Aura of Command" (GDD 3.1) and Soul Bind (GDD 3.2).
## The equipped Tome (GDD §4) rewrites the aura's shape, the passives, the cost
## of Soul Bind, and which desperation weapon the Space bar becomes.

signal soul_bind_completed(corpse: Node2D)
signal state_changed(new_state: int)

enum State { COMMANDER, CHANNELING, DESPERATION }

@export var move_speed: float = 230.0
@export var aura_radius: float = 340.0
@export var soul_bind_range: float = 44.0
@export var soul_bind_time: float = 1.5
@export var soul_bind_slow: float = 0.2  # 80% slow while channeling

var state: int = State.COMMANDER
## Set by UI (rename field / inventory screen) to freeze the Necromancer so
## WASD/E don't leak into gameplay behind an open menu or focused text box.
var input_locked: bool = false

## Networking identity - which peer controls this Necromancer (1 = host/local).
@export var owner_peer_id: int = 1
## This player's own graft stash + minion roster (GDD 3.4). Per-player by design.
var inventory: Inventory = null
## The school of necromancy carried this run (never null; a default is supplied).
var tome: TomeData = null

## Direction the Necromancer faces (toward the cursor); aims cone auras and
## desperation weapons.
var facing: Vector2 = Vector2.RIGHT

## Bone-Carver's Marrow Shield: absorbs damage, regrows while standing still.
var shield: float = 0.0
var _still_time: float = 0.0

var _bind_timer: float = 0.0
var _bind_target: Node2D = null
var _bind_fx: CPUParticles2D = null  # soul wisps corpse -> Necromancer while channeling
var _desperation_atk_cd: float = 0.0
var _ability_cd: float = 0.0
var _refuse_flash: float = 0.0     # red no-entry blink when an action is denied
var _swing_t: float = 0.0          # scythe sweep visual
var _swing_dir: Vector2 = Vector2.RIGHT
var _grasp_target: BaseEntity = null
var _defiance_spent: bool = false  # Death Defiance page fires once per run

func _ready() -> void:
	tome = RunState.tome()
	max_hp = 40.0 * tome.hp_mult  # fragile by design (Sanguine doubles the blood)
	if RunState.page_active("phylactery"):
		max_hp += 15.0
	aura_radius = tome.aura_radius
	shield = tome.marrow_shield
	body_radius = 15.0
	body_color = Color(0.75, 0.85, 1.0).lerp(tome.color, 0.35)
	inventory = Inventory.new()
	inventory.owner_peer_id = owner_peer_id
	super._ready()
	add_to_group("player")
	collision_layer = LAYER_PLAYER
	collision_mask = LAYER_WORLD  # walls only; pass through units
	# Body sprite: the Necromancer faces the cursor, not the walk direction,
	# and wears a faint wash of the equipped Tome's colour.
	setup_sprite("res://assets/sprites/necromancer.svg")
	flip_from_velocity = false
	if sprite != null:
		sprite.modulate = Color.WHITE.lerp(tome.color, 0.22)

func _physics_process(delta: float) -> void:
	_desperation_atk_cd = maxf(0.0, _desperation_atk_cd - delta)
	_ability_cd = maxf(0.0, _ability_cd - delta)
	_refuse_flash = maxf(0.0, _refuse_flash - delta)
	_swing_t = maxf(0.0, _swing_t - delta)
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	if to_mouse.length() > 1.0:
		facing = to_mouse.normalized()
	if sprite != null:
		sprite.flip_h = facing.x < 0.0
	_update_marrow_shield(delta)

	# Frozen while the player is in a menu / typing (rename, inventory).
	if input_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		queue_redraw()
		return
	match state:
		State.COMMANDER:
			_process_commander(delta)
		State.CHANNELING:
			_process_channeling(delta)
		State.DESPERATION:
			_process_desperation(delta)
	queue_redraw()

# --- The Command Aura (GDD 3.1 / per-tome mutations, GDD §4) -----------------

## Is a world position inside this Necromancer's aura? Centralised so minions,
## buffs and Transfusion all agree, whatever shape the Tome bends the aura into.
func is_in_aura(pos: Vector2) -> bool:
	var to_pos: Vector2 = pos - global_position
	var d: float = to_pos.length()
	if d > aura_radius:
		return false
	if tome.aura_shape == TomeData.AuraShape.CONE:
		if d < body_radius + 30.0:
			return true  # never orphan minions standing on your boots
		return absf(facing.angle_to(to_pos)) <= tome.aura_half_angle
	return true

# --- Commander ---------------------------------------------------------------

func _process_commander(_delta: float) -> void:
	_move(1.0)
	if Input.is_action_just_pressed("soul_bind"):
		_try_begin_soul_bind()
	if Input.is_action_just_pressed("ability"):
		_try_transfusion()

## Sanguine Transfusion (GDD 4.3): bleed yourself to mend the horde.
func _try_transfusion() -> void:
	if not tome.has_transfusion or _ability_cd > 0.0:
		return
	var cost: float = maxf(2.0, current_hp * 0.05)
	if current_hp - cost <= 1.0:
		_refuse_flash = 0.5  # not enough blood left to give
		return
	take_true_damage(cost)
	_ability_cd = 1.0
	Audio.sfx("transfusion", -6.0)
	for m in get_tree().get_nodes_in_group("minions"):
		if m is Minion and not (m as Minion).is_dead and is_in_aura((m as Minion).global_position):
			(m as Minion).heal((m as Minion).max_hp * 0.2)
			FX.heal_motes(m.get_parent(), (m as Minion).global_position)

## Start a Soul Bind if a corpse is in range. Elite remains demand a Soul Jar
## charge (GDD 3.2); a full party AND crypt refuses outright.
func _try_begin_soul_bind() -> void:
	var corpse: Node2D = _nearest_corpse()
	if corpse == null:
		return
	if bool(corpse.get("source_elite")) and RunState.soul_jars <= 0:
		_refuse_flash = 0.6  # no jar to hold an elite soul
		return
	if inventory.party.size() >= inventory.party_cap and inventory.crypt.size() >= inventory.reserve_cap:
		_refuse_flash = 0.6  # nowhere to put it
		return
	# Sanguine Pact: the bind costs blood instead of exposure (GDD 4.3).
	if tome.bind_costs_hp:
		var cost: float = maxf(1.0, current_hp * tome.bind_hp_cost_pct)
		if current_hp - cost <= 1.0:
			_refuse_flash = 0.6
			return
		take_true_damage(cost)
	_begin_channel(corpse)

func _move(speed_scale: float) -> void:
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * move_speed * speed_scale
	move_and_slide()

# --- Channeling (Soul Bind) --------------------------------------------------

func _begin_channel(corpse: Node2D) -> void:
	_bind_target = corpse
	_bind_timer = 0.0
	var to_me: Vector2 = (global_position - corpse.global_position).normalized()
	_bind_fx = FX.soul_stream(get_parent(), corpse.global_position, to_me, 90.0)
	Audio.bind_hum(true)
	_set_state(State.CHANNELING)

func _process_channeling(delta: float) -> void:
	# Sanguine channels at full stride; everyone else is slowed and exposed.
	_move(1.0 if tome.bind_costs_hp else soul_bind_slow)
	if _bind_target == null or not is_instance_valid(_bind_target):
		_cancel_channel()
		return
	# Cancel if the corpse drifts out of range or the key is released.
	if global_position.distance_to(_bind_target.global_position) > soul_bind_range \
			or not Input.is_action_pressed("soul_bind"):
		_cancel_channel()
		return
	# Keep the wisp stream aimed at the (moving) Necromancer.
	if _bind_fx != null and is_instance_valid(_bind_fx):
		var d: Vector2 = global_position - _bind_fx.global_position
		if d.length() > 1.0:
			_bind_fx.direction = d.normalized()
			_bind_fx.initial_velocity_min = d.length() * 1.6
			_bind_fx.initial_velocity_max = d.length() * 2.2
	_bind_timer += delta
	if _bind_timer >= soul_bind_time:
		var bound := _bind_target
		_bind_target = null
		_end_bind_stream()
		_set_state(State.COMMANDER)
		soul_bind_completed.emit(bound)

func _cancel_channel() -> void:
	_bind_target = null
	_bind_timer = 0.0
	_end_bind_stream()
	_set_state(State.COMMANDER)

func _end_bind_stream() -> void:
	Audio.bind_hum(false)
	if _bind_fx != null:
		FX.stop_stream(_bind_fx)
		_bind_fx = null

# --- Desperation Mode (GDD 3.3, weapon per Tome §4) --------------------------

func _process_desperation(delta: float) -> void:
	_grasp_target = null
	if tome.desperation_weapon == TomeData.DesperationWeapon.GRASP \
			and Input.is_action_pressed("desperation_attack"):
		_process_grasp(delta)  # rooted tether: no movement while feeding
	else:
		_move(1.0)
		if Input.is_action_pressed("desperation_attack") and _desperation_atk_cd <= 0.0:
			_desperation_attack()
	# A soul bind still lets you crawl back into Commander mode.
	if Input.is_action_just_pressed("soul_bind"):
		_try_begin_soul_bind()

func _desperation_attack() -> void:
	match tome.desperation_weapon:
		TomeData.DesperationWeapon.SCALPEL:
			_attack_scalpel()
		TomeData.DesperationWeapon.RATS:
			_attack_rats()
		TomeData.DesperationWeapon.SCYTHE:
			_attack_scythe()
		_:
			_attack_flail()

## Default: a weak, short-range flail. Just enough to free one kill.
func _attack_flail() -> void:
	_desperation_atk_cd = 0.35
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is BaseEntity and global_position.distance_to(e.global_position) <= 60.0:
			(e as BaseEntity).take_damage(6.0, self)

## Stitcher (4.1): rapid, feeble cuts that mark the victim for 3x minion damage.
func _attack_scalpel() -> void:
	_desperation_atk_cd = 0.16
	var best: BaseEntity = null
	var best_d: float = 70.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is BaseEntity and not (e as BaseEntity).is_dead:
			var d: float = global_position.distance_to((e as BaseEntity).global_position)
			if d <= best_d:
				best_d = d
				best = e
	if best != null:
		best.take_damage(2.0, self)
		best.marked_mult = 3.0  # your next resurrected minion hits like a train

## Rotting (4.2): hurl a handful of corpse-rats that gnaw and stun.
func _attack_rats() -> void:
	_desperation_atk_cd = 0.8
	for i in 3:
		var spread: float = (float(i) - 1.0) * 0.3
		Projectile.spawn(get_parent(), global_position, facing.rotated(spread), 3.0,
			PackedStringArray(["enemies"]), 300.0, 42.0, Color(0.55, 0.45, 0.3), 380.0,
			self, 1.1)

## Bone-Carver (4.4): a huge spectral scythe. Slow, wide, brutal knockback.
func _attack_scythe() -> void:
	_desperation_atk_cd = 1.1
	_swing_t = 0.22
	_swing_dir = facing
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not (e as Enemy).is_dead:
			var to_e: Vector2 = (e as Enemy).global_position - global_position
			if to_e.length() <= 160.0 and absf(facing.angle_to(to_e)) <= 1.05:
				(e as Enemy).take_damage(18.0, self)
				(e as Enemy).apply_knockback(to_e.normalized() * 380.0)

## Sanguine (4.3): rooted mid-range tether that siphons life back into you.
func _process_grasp(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	var best: BaseEntity = null
	var best_d: float = 260.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is BaseEntity and not (e as BaseEntity).is_dead:
			var d: float = global_position.distance_to((e as BaseEntity).global_position)
			if d <= best_d:
				best_d = d
				best = e
	_grasp_target = best
	if best != null:
		var drain: float = 14.0 * delta
		best.take_true_damage(drain)
		heal(drain)

func enter_desperation() -> void:
	if state != State.DESPERATION:
		_cancel_channel()
		_set_state(State.DESPERATION)

func exit_desperation() -> void:
	if state == State.DESPERATION:
		_set_state(State.COMMANDER)

func _set_state(s: int) -> void:
	if state != s:
		state = s
		state_changed.emit(s)

# --- Defenses (Marrow Shield, Death Defiance) --------------------------------

## Bone-Carver (4.4): the shield regrows only while standing completely still.
func _update_marrow_shield(delta: float) -> void:
	if tome.marrow_shield <= 0.0:
		return
	if velocity.length() < 1.0:
		_still_time += delta
		if _still_time > 0.6:
			shield = minf(tome.marrow_shield, shield + 9.0 * delta)
	else:
		_still_time = 0.0

func take_damage(amount: float, source: Node = null) -> void:
	if is_dead:
		return
	# Marrow Shield soaks first.
	if shield > 0.0:
		var absorbed: float = minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		if amount <= 0.0:
			return
	# Death Defiance (Grimoire): once per run, a minion pays your toll.
	if RunState.page_active("death_defiance") and not _defiance_spent \
			and amount - defense >= current_hp:
		var minions: Array = get_tree().get_nodes_in_group("minions")
		if not minions.is_empty():
			_defiance_spent = true
			var victim: Minion = minions[randi() % minions.size()]
			victim.die()
			current_hp = maxf(current_hp, max_hp * 0.3)
			health_changed.emit(current_hp, max_hp)
			return
	super.take_damage(amount, source)

# --- Helpers -----------------------------------------------------------------

func _nearest_corpse() -> Node2D:
	var best: Node2D = null
	var best_d: float = soul_bind_range
	for c in get_tree().get_nodes_in_group("corpses"):
		if c is Node2D:
			var d: float = global_position.distance_to((c as Node2D).global_position)
			if d <= best_d:
				best_d = d
				best = c
	return best

func _on_death() -> void:
	# Game-over handling is owned by Main; just stop the body here.
	set_physics_process(false)
	body_color = Color(0.4, 0.4, 0.45)
	if sprite != null:
		sprite.modulate = Color(0.4, 0.4, 0.45)
		sprite.rotation = 0.35  # slumped

func _draw() -> void:
	if state != State.DESPERATION:
		_draw_aura()
	else:
		# Desperation vignette hint: red danger ring.
		draw_arc(Vector2.ZERO, 60.0, 0.0, TAU, 48, Color(1.0, 0.2, 0.2, 0.6), 3.0)
	# Scythe sweep flash.
	if _swing_t > 0.0:
		var a0: float = _swing_dir.angle() - 1.05
		draw_arc(Vector2.ZERO, 150.0, a0, a0 + 2.1, 32, Color(0.9, 0.95, 1.0, _swing_t * 3.0), 6.0)
	# Vampiric Grasp tether.
	if _grasp_target != null and is_instance_valid(_grasp_target):
		draw_line(Vector2.ZERO, to_local(_grasp_target.global_position), Color(0.95, 0.25, 0.3, 0.85), 3.0)
	_draw_body_and_health()
	# Marrow Shield: a pale arc that thins as it breaks.
	if tome.marrow_shield > 0.0 and shield > 0.0:
		var frac: float = shield / tome.marrow_shield
		draw_arc(Vector2.ZERO, body_radius + 4.0, -PI * frac, PI * frac, 28, Color(0.9, 0.9, 0.75, 0.8), 2.5)
	# Channel progress arc.
	if state == State.CHANNELING:
		var frac2: float = clampf(_bind_timer / soul_bind_time, 0.0, 1.0)
		draw_arc(Vector2.ZERO, body_radius + 6.0, -PI / 2.0, -PI / 2.0 + TAU * frac2, 32, Color(0.6, 1.0, 0.7), 3.0)
	# Refusal feedback: a red no-entry ring above the head.
	if _refuse_flash > 0.0:
		var c := Vector2(0.0, visual_top() - 14.0)
		var a: float = clampf(_refuse_flash / 0.6, 0.0, 1.0)
		draw_arc(c, 9.0, 0.0, TAU, 20, Color(1.0, 0.25, 0.25, a), 2.5)
		draw_line(c + Vector2(-6.4, -6.4), c + Vector2(6.4, 6.4), Color(1.0, 0.25, 0.25, a), 2.5)

func _draw_aura() -> void:
	var fill := Color(tome.color.r, tome.color.g, tome.color.b, 0.10)
	var edge := Color(tome.color.r, tome.color.g, tome.color.b, 0.5)
	if tome.aura_shape == TomeData.AuraShape.CONE:
		# Directional Command (4.4): a wide cone toward the cursor.
		var a0: float = facing.angle() - tome.aura_half_angle
		var a1: float = facing.angle() + tome.aura_half_angle
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in 25:
			var ang: float = lerpf(a0, a1, float(i) / 24.0)
			pts.append(Vector2(cos(ang), sin(ang)) * aura_radius)
		draw_colored_polygon(pts, fill)
		draw_arc(Vector2.ZERO, aura_radius, a0, a1, 40, edge, 2.0)
		draw_line(Vector2.ZERO, pts[1], edge, 1.0)
		draw_line(Vector2.ZERO, pts[pts.size() - 1], edge, 1.0)
	else:
		draw_circle(Vector2.ZERO, aura_radius, fill)
		draw_arc(Vector2.ZERO, aura_radius, 0.0, TAU, 64, edge, 2.0)
