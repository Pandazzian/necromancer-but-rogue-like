extends Node2D
## Vertical-slice arena. Wires the Necromancer, RTS commander, minions and enemy
## waves together, handles Soul Bind resurrection and the Desperation trigger.

const MinionScene: PackedScene = preload("res://scenes/minion.tscn")
const EnemyScene: PackedScene = preload("res://scenes/enemy.tscn")

@export var starting_minions: int = 3
@export var wave_interval: float = 5.0
@export var enemies_per_wave: int = 3
@export var arena_half_extent: float = 900.0

@onready var player: Player = $Actors/Player
@onready var actors: Node2D = $Actors
@onready var commander: Node2D = $RTSCommander
@onready var info_label: Label = $HUD/Info
@onready var wave_timer: Timer = $WaveTimer

var _wave: int = 0
var _was_desperate: bool = false

func _ready() -> void:
	randomize()
	commander.player = player
	player.soul_bind_completed.connect(_on_soul_bind_completed)
	player.died.connect(_on_player_died)

	for i in starting_minions:
		var offset := Vector2(randf_range(-80, 80), randf_range(40, 120))
		_spawn_minion(player.global_position + offset)

	wave_timer.wait_time = wave_interval
	wave_timer.timeout.connect(_spawn_wave)
	wave_timer.start()
	_spawn_wave()  # first wave immediately

func _process(_delta: float) -> void:
	_update_desperation()
	_update_hud()
	queue_redraw()

# --- Spawning --------------------------------------------------------------

func _spawn_minion(pos: Vector2) -> Minion:
	var m: Minion = MinionScene.instantiate()
	m.global_position = pos
	m.player = player
	actors.add_child(m)
	return m

func _spawn_wave() -> void:
	if player.is_dead:
		return
	_wave += 1
	for i in enemies_per_wave + _wave:
		var angle := randf() * TAU
		var dist := randf_range(500.0, 750.0)
		var pos := player.global_position + Vector2(cos(angle), sin(angle)) * dist
		var e: Enemy = EnemyScene.instantiate()
		e.global_position = pos
		actors.add_child(e)

# --- Soul Bind resurrection (GDD 3.2) --------------------------------------

func _on_soul_bind_completed(corpse: Node2D) -> void:
	if corpse != null and is_instance_valid(corpse):
		_spawn_minion(corpse.global_position)
		corpse.queue_free()

# --- Desperation Mode gate (GDD 3.3) ---------------------------------------

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
		lines.append("State: %s    HP: %d/%d" % [state_names[player.state], roundi(player.current_hp), roundi(player.max_hp)])
	lines.append("Minions: %d    Enemies: %d    Wave: %d    Corpses: %d" % [minions, enemies, _wave, corpses])
	lines.append("WASD move | L-drag select | R-click move/attack | hold E near corpse: Soul Bind | 1-4 groups | Space (desperation)")
	if corpses > 0 and not player.is_dead:
		lines.append(">> A corpse can be raised. Stand next to it and HOLD E.")
	info_label.text = "\n".join(lines)

func _on_player_died(_e: BaseEntity) -> void:
	wave_timer.stop()

# --- Backdrop grid (movement reference) ------------------------------------

func _draw() -> void:
	var step: float = 80.0
	var col := Color(1, 1, 1, 0.04)
	var n: int = int(arena_half_extent / step)
	for i in range(-n, n + 1):
		var x: float = i * step
		draw_line(Vector2(x, -arena_half_extent), Vector2(x, arena_half_extent), col, 1.0)
		draw_line(Vector2(-arena_half_extent, x), Vector2(arena_half_extent, x), col, 1.0)
	# Arena boundary.
	draw_rect(Rect2(-arena_half_extent, -arena_half_extent, arena_half_extent * 2, arena_half_extent * 2), Color(0.5, 0.2, 0.2, 0.3), false, 3.0)
