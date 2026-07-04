extends Node2D
## Run controller (Hades-style). The player clears one walled Room at a time;
## clearing all enemies opens the exit door. Walking through opens the Crypt /
## Inventory management screen (Flesh-Stitching, swaps, grafting), then loads the
## next room. The roster lives in the player's per-player Inventory; field minions
## are spawned from it each room.

const MinionScene: PackedScene = preload("res://scenes/minion.tscn")
const RoomScene: PackedScene = preload("res://scenes/room.tscn")

@export var base_enemies: int = 3  # enemies = base_enemies + room number

@onready var player: Player = $Actors/Player
@onready var actors: Node2D = $Actors
@onready var commander: Node2D = $RTSCommander
@onready var hud: CanvasLayer = $HUD
@onready var info_label: Label = $HUD/Info

var _minion_panel: MinionPanel = null
var _inventory_ui: InventoryUI = null
var _room_number: int = 0
var _current_room: Room = null
var _transitioning: bool = false
var _was_desperate: bool = false

## How close the Necromancer must be to hoover up a dropped graft.
const PICKUP_RANGE: float = 32.0

func _ready() -> void:
	randomize()
	commander.player = player
	player.soul_bind_completed.connect(_on_soul_bind_completed)
	player.died.connect(_on_player_died)
	# Run soundtrack + the Desperation audio treatment (GDD 3.3).
	Audio.play_music("music_run")
	player.state_changed.connect(func(s: int) -> void:
		Audio.set_desperation(s == Player.State.DESPERATION))

	# Mouse-driven selected-minion card (name / stats / rename).
	_minion_panel = MinionPanel.new()
	_minion_panel.player = player
	hud.add_child(_minion_panel)
	commander.selection_changed.connect(_on_selection_changed)

	# Consolidated Inventory / Crypt / grafting screen. Toggle mid-combat with
	# I / Tab; it also serves as the between-rooms management step.
	_inventory_ui = InventoryUI.new()
	_inventory_ui.player = player
	hud.add_child(_inventory_ui)
	_inventory_ui.continue_pressed.connect(_advance_room)
	_inventory_ui.roster_changed.connect(_sync_field_to_party)

	# Direct F5-on-main launches skip the hub: snapshot a default loadout.
	if RunState.tome_id == "":
		RunState.begin_run()

	# Apply the Tome's party rules and the Grimoire's crypt pages (GDD §4 / 5.3).
	var tome: TomeData = RunState.tome()
	if tome.party_cap_override >= 0:
		player.inventory.party_cap = tome.party_cap_override
	else:
		player.inventory.party_cap += tome.party_cap_add
	if RunState.page_active("ossuary"):
		player.inventory.reserve_cap += 2

	# Fresh run roster: the party drafted at the Graveyard (GDD 5.1).
	player.inventory.reset_run()
	for inst in RunState.take_drafted_party():
		if player.inventory.party.size() < player.inventory.party_cap:
			player.inventory.add_to_party(inst)
		else:
			player.inventory.crypt.append(inst)  # Stitcher cap overflow waits below

	_start_room(1)

func _process(_delta: float) -> void:
	_update_desperation()
	_collect_pickups()
	_update_hud()

## The Necromancer harvests any graft it walks over into its own inventory.
func _collect_pickups() -> void:
	if player.is_dead:
		return
	for p in get_tree().get_nodes_in_group("graft_pickups"):
		if p is GraftPickup and player.global_position.distance_to(p.global_position) <= PICKUP_RANGE:
			player.inventory.add_graft(p.graft)
			FX.pickup_sparkle(actors, p.global_position, p.graft.color)
			Audio.sfx("pickup", -8.0)
			p.queue_free()

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
	# Escalation: elites appear from room 3, a boss commands every 5th room.
	var elites: int = clampi((n - 1) / 2 - 1, 0, 3)
	var boss: bool = n % 5 == 0
	room.begin(base_enemies + n, elites, boss)

func _on_room_cleared() -> void:
	# Clearing pays out even before the run ends (banked on death, GDD 2.B).
	RunState.rooms_cleared += 1
	RunState.run_essence += 10
	RunState.run_xp += 5

func _on_room_exited() -> void:
	if _transitioning:
		return
	_transitioning = true
	# Between rooms: open the management screen (deferred - we're in a physics cb).
	_inventory_ui.call_deferred("open_between_rooms")

func _advance_room() -> void:
	if is_instance_valid(_current_room):
		_current_room.queue_free()
	_start_room(_room_number + 1)

## Despawn last room's minion nodes and spawn fresh ones from the active party.
func _deploy_party(center: Vector2) -> void:
	for m in get_tree().get_nodes_in_group("minions"):
		m.remove_from_group("minions")  # so counts are correct this frame
		m.queue_free()
	var count: int = maxi(1, player.inventory.party.size())
	var i: int = 0
	for inst in player.inventory.party:
		var ang: float = TAU * float(i) / float(count)
		var pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * 70.0
		_spawn_minion(inst, pos)
		i += 1

## Reconcile the field to the active party after a Deploy/Store/Stitch: spawn
## newly-deployed minions, despawn any that left the party. Lets Crypt management
## take effect immediately instead of only on the next room.
func _sync_field_to_party() -> void:
	var party: Array = player.inventory.party
	var have: Dictionary = {}  # MinionInstance -> already on the field
	for m in get_tree().get_nodes_in_group("minions"):
		if m is Minion:
			if party.has((m as Minion).instance):
				have[(m as Minion).instance] = true
			else:
				# Left the party (stored or stitched away) - pull it off the field.
				m.remove_from_group("minions")
				m.queue_free()
	for inst in party:
		if not have.has(inst):
			var pos: Vector2 = player.global_position + Vector2(randf_range(-60, 60), randf_range(40, 90))
			_spawn_minion(inst, pos)

func _reset_camera() -> void:
	var cam := player.get_node_or_null("Camera2D")
	if cam is Camera2D:
		(cam as Camera2D).reset_smoothing()

# --- Spawning / resurrection ----------------------------------------------

func _spawn_minion(inst: MinionInstance, pos: Vector2) -> Minion:
	var m: Minion = MinionScene.instantiate()
	# Assign data before add_child so _ready() configures class + tier + grafts.
	m.instance = inst
	m.archetype = Classes.minion(inst.class_id)
	m.owner_peer_id = player.owner_peer_id
	m.global_position = pos
	m.player = player
	m.died.connect(_on_minion_died)
	actors.add_child(m)
	return m

func _on_minion_died(entity: BaseEntity) -> void:
	# Its grafts die with it (GDD 3.5 high stakes): drop the instance from the roster.
	if entity is Minion and (entity as Minion).instance != null:
		player.inventory.remove((entity as Minion).instance)

func _on_soul_bind_completed(corpse: Node2D) -> void:
	if corpse == null or not is_instance_valid(corpse):
		return
	# Raise a minion of the same class as the enemy that left this corpse. It
	# joins the active party if there's room, else it's stored in the Crypt.
	# Elite remains cost a Soul Jar charge and rise at a higher tier (GDD 3.2).
	var cid: String = corpse.source_class if "source_class" in corpse else "warrior"
	var tier: int = int(corpse.get("source_tier")) if "source_tier" in corpse else 1
	if bool(corpse.get("source_elite")):
		RunState.soul_jars -= 1
	FX.soul_burst(actors, corpse.global_position)
	Audio.sfx("soul_burst", -5.0)
	var result: Dictionary = player.inventory.capture(cid, tier)
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

func _on_selection_changed(selected: Array) -> void:
	if selected.size() == 1 and selected[0] is Minion:
		_minion_panel.show_for(selected[0])
	else:
		_minion_panel.hide_panel()

# --- HUD -------------------------------------------------------------------

func _update_hud() -> void:
	var state_names := ["COMMANDER", "CHANNELING", "DESPERATION"]
	var minions: int = get_tree().get_nodes_in_group("minions").size()
	var enemies: int = get_tree().get_nodes_in_group("enemies").size()
	var corpses: int = get_tree().get_nodes_in_group("corpses").size()
	var inv: Inventory = player.inventory
	var tome: TomeData = RunState.tome()
	var lines := PackedStringArray()
	if player.is_dead:
		lines.append("YOU HAVE BEEN PURGED.")
		lines.append("The Graveyard keeps what you gathered: %d essence, %d exp, %d rooms." % [
			RunState.run_essence, RunState.run_xp, RunState.rooms_cleared])
		lines.append(">> Press ENTER to crawl home to the Graveyard. <<")
		info_label.text = "\n".join(lines)
		return
	lines.append("Room %d    %s    State: %s    HP: %d/%d%s" % [
		_room_number, tome.display_name, state_names[player.state],
		roundi(player.current_hp), roundi(player.max_hp),
		"  Shield: %d" % roundi(player.shield) if tome.marrow_shield > 0.0 else ""])
	lines.append("Party: %d/%d    Crypt: %d/%d    Grafts: %d    Soul Jars: %d    Essence: +%d    Enemies: %d" % [
		minions, inv.party_cap, inv.crypt.size(), inv.reserve_cap,
		inv.grafts.size(), RunState.soul_jars, RunState.run_essence, enemies])
	var controls: String = "WASD | L-drag select | R-click order | hold E: Soul Bind | I/Tab: Crypt"
	if tome.has_transfusion:
		controls += " | Q: Transfusion"
	lines.append(controls)
	if enemies == 0:
		lines.append(">> ROOM CLEARED! Raise any corpses you want, then walk through the green doorway. >>")
	elif corpses > 0:
		var elite_waiting: bool = false
		for c in get_tree().get_nodes_in_group("corpses"):
			if bool(c.get("source_elite")):
				elite_waiting = true
				break
		if elite_waiting:
			lines.append(">> An ELITE corpse glints gold - capturing it costs a Soul Jar. HOLD E beside it.")
		else:
			lines.append(">> A corpse can be raised. Stand next to it and HOLD E.  (overflow goes to the Crypt)")
	info_label.text = "\n".join(lines)

func _on_player_died(_e: BaseEntity) -> void:
	pass  # the HUD switches to the death banner; Enter banks the run (below)

func _input(event: InputEvent) -> void:
	# Death is the run's only exit (rogue-lite): bank the loot, go home.
	if player != null and player.is_dead and event.is_action_pressed("ui_accept"):
		RunState.end_run()
		get_tree().change_scene_to_file("res://scenes/hub.tscn")
