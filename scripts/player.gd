class_name Player
extends BaseEntity
## The Necromancer. Fragile, never fights directly (except Desperation Mode).
## WASD movement + emits the "Aura of Command" (GDD 3.1) and casts Soul Bind (GDD 3.2).

signal soul_bind_completed(corpse: Node2D)
signal state_changed(new_state: int)

enum State { COMMANDER, CHANNELING, DESPERATION }

@export var move_speed: float = 230.0
@export var aura_radius: float = 340.0
@export var soul_bind_range: float = 44.0
@export var soul_bind_time: float = 1.5
@export var soul_bind_slow: float = 0.2  # 80% slow while channeling

var state: int = State.COMMANDER

var _bind_timer: float = 0.0
var _bind_target: Node2D = null
var _desperation_atk_cd: float = 0.0

func _ready() -> void:
	max_hp = 40.0  # fragile by design
	body_radius = 15.0
	body_color = Color(0.75, 0.85, 1.0)
	super._ready()
	add_to_group("player")

func _physics_process(delta: float) -> void:
	_desperation_atk_cd = maxf(0.0, _desperation_atk_cd - delta)
	match state:
		State.COMMANDER:
			_process_commander(delta)
		State.CHANNELING:
			_process_channeling(delta)
		State.DESPERATION:
			_process_desperation(delta)
	queue_redraw()

# --- Commander -------------------------------------------------------------

func _process_commander(_delta: float) -> void:
	_move(1.0)
	if Input.is_action_just_pressed("soul_bind"):
		var corpse: Node2D = _nearest_corpse()
		if corpse != null:
			_begin_channel(corpse)

func _move(speed_scale: float) -> void:
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * move_speed * speed_scale
	move_and_slide()

# --- Channeling (Soul Bind) ------------------------------------------------

func _begin_channel(corpse: Node2D) -> void:
	_bind_target = corpse
	_bind_timer = 0.0
	_set_state(State.CHANNELING)

func _process_channeling(delta: float) -> void:
	_move(soul_bind_slow)  # movement heavily slowed, exposing the player to risk
	if _bind_target == null or not is_instance_valid(_bind_target):
		_cancel_channel()
		return
	# Cancel if the corpse drifts out of range or the key is released.
	if global_position.distance_to(_bind_target.global_position) > soul_bind_range \
			or not Input.is_action_pressed("soul_bind"):
		_cancel_channel()
		return
	_bind_timer += delta
	if _bind_timer >= soul_bind_time:
		var bound := _bind_target
		_bind_target = null
		_set_state(State.COMMANDER)
		soul_bind_completed.emit(bound)

func _cancel_channel() -> void:
	_bind_target = null
	_bind_timer = 0.0
	_set_state(State.COMMANDER)

# --- Desperation Mode (GDD 3.3) --------------------------------------------

func _process_desperation(_delta: float) -> void:
	_move(1.0)
	if Input.is_action_pressed("desperation_attack") and _desperation_atk_cd <= 0.0:
		_desperation_swing()
	# A soul bind still lets you crawl back into Commander mode.
	if Input.is_action_just_pressed("soul_bind"):
		var corpse: Node2D = _nearest_corpse()
		if corpse != null:
			_begin_channel(corpse)

func _desperation_swing() -> void:
	_desperation_atk_cd = 0.35
	# Weak, short-range flail. Cannot clear a room - just enough to free one kill.
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is BaseEntity and global_position.distance_to(e.global_position) <= 60.0:
			(e as BaseEntity).take_damage(6.0, self)

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

# --- Helpers ---------------------------------------------------------------

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

func _draw() -> void:
	# Command Aura ring (only meaningful in Commander/Channeling).
	if state != State.DESPERATION:
		var aura_col := Color(0.5, 0.7, 1.0, 0.16)
		draw_circle(Vector2.ZERO, aura_radius, aura_col)
		draw_arc(Vector2.ZERO, aura_radius, 0.0, TAU, 64, Color(0.6, 0.8, 1.0, 0.5), 2.0)
	else:
		# Desperation vignette hint: red danger ring.
		draw_arc(Vector2.ZERO, 60.0, 0.0, TAU, 48, Color(1.0, 0.2, 0.2, 0.6), 3.0)
	_draw_body_and_health()
	# Channel progress arc.
	if state == State.CHANNELING:
		var frac: float = clampf(_bind_timer / soul_bind_time, 0.0, 1.0)
		draw_arc(Vector2.ZERO, body_radius + 6.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 32, Color(0.6, 1.0, 0.7), 3.0)
