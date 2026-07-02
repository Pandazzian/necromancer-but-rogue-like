extends Node2D
## Run controller (Hades-style). The player clears one walled Room at a time;
## clearing all enemies opens the exit door, and walking through loads the next
## room. The Necromancer and surviving minions persist between rooms.

const MinionScene: PackedScene = preload("res://scenes/minion.tscn")
const RoomScene: PackedScene = preload("res://scenes/room.tscn")

@export var starting_minions: int = 3
@export var base_enemies: int = 3  # enemies = base_enemies + room number

@onready var player: Player = $Actors/Player
@onready var actors: Node2D = $Actors
@onready var commander: Node2D = $RTSCommander
@onready var info_label: Label = $HUD/Info

var _room_number: int = 0
var _current_room: Room = null
var _transitioning: bool = false
var _was_desperate: bool = false

func _ready() -> void:
	randomize()
	commander.player = player
	player.soul_bind_completed.connect(_on_soul_bind_completed)
	player.died.connect(_on_player_died)

	for i in starting_minions:
		_spawn_minion(player.global_position + Vector2(randf_range(-60, 60), randf_range(40, 100)))

	_start_room(1)

func _process(_delta: float) -> void:
	_update_desperation()
	_update_hud()

# --- Room flow -------------------------------------------------------------

func _start_room(n: int) -> void:
	_transitioning = false
	_room_number = n
	var room: Room = RoomScene.instantiate()
	add_child(room)
	move_child(room, 0)  # draw the room floor/walls behind the actors
	_current_room = room
	room.player = player

	# Place the party at the new room's entrance.
	player.global_position = room.entrance_position()
	player.velocity = Vector2.ZERO
	player.exit_desperation()
	_reposition_minions(player.global_position)
	_reset_camera()

	room.room_cleared.connect(_on_room_cleared)
	room.player_exited.connect(_on_room_exited)
	room.begin(base_enemies + n)

func _on_room_cleared() -> void:
	pass  # HUD reacts to the door state; hook for SFX/rewards later.

func _on_room_exited() -> void:
	if _transitioning:
		return
	_transitioning = true
	# Defer: we're inside the door Area2D's physics callback.
	call_deferred("_advance_room")

func _advance_room() -> void:
	if is_instance_valid(_current_room):
		_current_room.queue_free()
	_start_room(_room_number + 1)

func _reposition_minions(center: Vector2) -> void:
	var minions: Array = get_tree().get_nodes_in_group("minions")
	var count: int = maxi(1, minions.size())
	var i: int = 0
	for m in minions:
		if m is Minion:
			var ang: float = TAU * float(i) / float(count)
			m.global_position = center + Vector2(cos(ang), sin(ang)) * 70.0
			m.velocity = Vector2.ZERO
			m.target = null
			m.order_pos = m.global_position
			m.state = Minion.State.IDLE
			i += 1

func _reset_camera() -> void:
	var cam := player.get_node_or_null("Camera2D")
	if cam is Camera2D:
		(cam as Camera2D).reset_smoothing()

# --- Spawning / resurrection ----------------------------------------------

func _spawn_minion(pos: Vector2) -> Minion:
	var m: Minion = MinionScene.instantiate()
	m.global_position = pos
	m.player = player
	actors.add_child(m)
	return m

func _on_soul_bind_completed(corpse: Node2D) -> void:
	if corpse != null and is_instance_valid(corpse):
		_spawn_minion(corpse.global_position)
		corpse.queue_free()

# --- Desperation gate (GDD 3.3) -------------------------------------------

func _update_desperation() -> void:
	if player.is_dead:
		return
	var minion_count: int = get_tree().get_nodes_in_group("minions").size()
	var enemy_count: int = get_tree().get_nodes_in_group("enemies").size()
	var should_be_desperate: bool = minion_count == 0 and enemy_count > 0
	if should_be_desperate and not _was_desperate:
		player.enter_desperation()
	elif not should_be_desperate and _was_desperate:
		player.exit_desperation()
	_was_desperate = should_be_desperate

# --- HUD -------------------------------------------------------------------

func _update_hud() -> void:
	var state_names := ["COMMANDER", "CHANNELING", "DESPERATION"]
	var minions: int = get_tree().get_nodes_in_group("minions").size()
	var enemies: int = get_tree().get_nodes_in_group("enemies").size()
	var corpses: int = get_tree().get_nodes_in_group("corpses").size()
	var lines := PackedStringArray()
	if player.is_dead:
		lines.append("YOU HAVE BEEN PURGED.  (restart: Ctrl+R in editor)")
	else:
		lines.append("Room %d    State: %s    HP: %d/%d" % [_room_number, state_names[player.state], roundi(player.current_hp), roundi(player.max_hp)])
	lines.append("Minions: %d    Enemies remaining: %d    Corpses: %d" % [minions, enemies, corpses])
	lines.append("WASD move | L-drag select | R-click move/attack | hold E near corpse: Soul Bind | 1-4 groups")
	if not player.is_dead:
		if enemies == 0:
			lines.append(">> ROOM CLEARED! The door is open - walk through the green doorway to advance. >>")
		elif corpses > 0:
			lines.append(">> A corpse can be raised. Stand next to it and HOLD E.")
	info_label.text = "\n".join(lines)

func _on_player_died(_e: BaseEntity) -> void:
	pass
