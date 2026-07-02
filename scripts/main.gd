extends Node2D
## Run controller (Hades-style). The player clears one walled Room at a time;
## clearing all enemies opens the exit door. Walking through opens the Crypt
## management screen (Flesh-Stitching / swaps), then loads the next room.
## The roster persists in the Crypt autoload; field minions are spawned from it.

const MinionScene: PackedScene = preload("res://scenes/minion.tscn")
const RoomScene: PackedScene = preload("res://scenes/room.tscn")

@export var base_enemies: int = 3  # enemies = base_enemies + room number

@onready var player: Player = $Actors/Player
@onready var actors: Node2D = $Actors
@onready var commander: Node2D = $RTSCommander
@onready var info_label: Label = $HUD/Info
@onready var crypt_screen: CanvasLayer = $CryptScreen

var _room_number: int = 0
var _current_room: Room = null
var _transitioning: bool = false
var _was_desperate: bool = false

func _ready() -> void:
	randomize()
	commander.player = player
	player.soul_bind_completed.connect(_on_soul_bind_completed)
	player.died.connect(_on_player_died)
	crypt_screen.continue_pressed.connect(_advance_room)

	# Fresh run roster.
	Crypt.reset_run()
	for cid in ["warrior", "archer", "tank"]:
		Crypt.add_to_party(cid)

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

	# Place the Necromancer at the entrance and (re)deploy the active party.
	player.global_position = room.entrance_position()
	player.velocity = Vector2.ZERO
	player.exit_desperation()
	_deploy_party(player.global_position)
	_reset_camera()

	room.room_cleared.connect(_on_room_cleared)
	room.player_exited.connect(_on_room_exited)
	room.begin(base_enemies + n)

func _on_room_cleared() -> void:
	pass  # HUD reacts to the door state.

func _on_room_exited() -> void:
	if _transitioning:
		return
	_transitioning = true
	# Between rooms: pause for Crypt management (deferred - we're in a physics cb).
	crypt_screen.call_deferred("open")

func _advance_room() -> void:
	if is_instance_valid(_current_room):
		_current_room.queue_free()
	_start_room(_room_number + 1)

## Despawn last room's minion nodes and spawn fresh ones from the active party.
func _deploy_party(center: Vector2) -> void:
	for m in get_tree().get_nodes_in_group("minions"):
		m.remove_from_group("minions")  # so counts are correct this frame
		m.queue_free()
	var count: int = maxi(1, Crypt.party.size())
	var i: int = 0
	for inst in Crypt.party:
		var ang: float = TAU * float(i) / float(count)
		var pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * 70.0
		_spawn_minion(inst, pos)
		i += 1

func _reset_camera() -> void:
	var cam := player.get_node_or_null("Camera2D")
	if cam is Camera2D:
		(cam as Camera2D).reset_smoothing()

# --- Spawning / resurrection ----------------------------------------------

func _spawn_minion(inst: MinionInstance, pos: Vector2) -> Minion:
	var m: Minion = MinionScene.instantiate()
	# Assign data before add_child so _ready() configures class + tier.
	m.instance = inst
	m.archetype = Classes.minion(inst.class_id)
	m.global_position = pos
	m.player = player
	m.died.connect(_on_minion_died)
	actors.add_child(m)
	return m

func _on_minion_died(entity: BaseEntity) -> void:
	if entity is Minion and (entity as Minion).instance != null:
		Crypt.remove((entity as Minion).instance)

func _on_soul_bind_completed(corpse: Node2D) -> void:
	if corpse == null or not is_instance_valid(corpse):
		return
	# Raise a minion of the same class as the enemy that left this corpse. It
	# joins the active party if there's room, else it's stored in the Crypt.
	var cid: String = corpse.source_class if "source_class" in corpse else "warrior"
	var result: Dictionary = Crypt.capture(cid)
	if result.dest == "party":
		_spawn_minion(result.inst, corpse.global_position)
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
	lines.append("Deployed: %d/%d    Crypt: %d/%d    Enemies: %d    Corpses: %d" % [minions, Crypt.party_cap, Crypt.reserve.size(), Crypt.reserve_cap, enemies, corpses])
	lines.append("WASD move | L-drag select | R-click move/attack | hold E near corpse: Soul Bind | 1-4 groups")
	if not player.is_dead:
		if enemies == 0:
			lines.append(">> ROOM CLEARED! Raise any corpses you want, then walk through the green doorway. >>")
		elif corpses > 0:
			lines.append(">> A corpse can be raised. Stand next to it and HOLD E.  (overflow goes to the Crypt)")
	info_label.text = "\n".join(lines)

func _on_player_died(_e: BaseEntity) -> void:
	pass
