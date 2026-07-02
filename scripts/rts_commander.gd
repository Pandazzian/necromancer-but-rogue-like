extends Node2D
## Mouse-driven RTS layer (GDD 3.1 / 6.2 "RTSCommander").
## Left-click/drag box-selects minions. Right-click issues Move or Attack orders.
## Number keys 1-4 recall control groups; Ctrl+1-4 assign the current selection.

@export var min_drag: float = 6.0  # px before a click becomes a drag-select

var player: Player = null

var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _drag_now: Vector2 = Vector2.ZERO
var _control_groups: Dictionary = {}  # int -> Array[Minion]

func _unhandled_input(event: InputEvent) -> void:
	if player == null or not is_instance_valid(player) or player.state == Player.State.DESPERATION:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_start = get_global_mouse_position()
				_drag_now = _drag_start
			else:
				_finish_selection()
				_dragging = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_issue_order(get_global_mouse_position())

	elif event is InputEventMouseMotion and _dragging:
		_drag_now = get_global_mouse_position()
		queue_redraw()

	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		for i in range(1, 5):
			if key.keycode == KEY_0 + i:
				if key.ctrl_pressed:
					_assign_group(i)
				else:
					_recall_group(i)

# --- Selection -------------------------------------------------------------

func _finish_selection() -> void:
	var rect := Rect2(_drag_start, _drag_now - _drag_start).abs()
	var is_click: bool = rect.size.length() < min_drag
	_clear_selection()
	if is_click:
		var m: Minion = _minion_under(get_global_mouse_position())
		if m != null:
			_set_selected(m, true)
	else:
		for m in _all_minions():
			if rect.has_point(m.global_position):
				_set_selected(m, true)
	queue_redraw()

## Front-to-back battle order for formation rows (Age-of-Empires style):
## tanks soak up front, archers stay safe at the back.
const ROLE_ORDER: Dictionary = {"tank": 0, "warrior": 1, "mage": 2, "archer": 3}
const FORMATION_SPACING: float = 48.0  # gap between units within a row
const FORMATION_ROW_GAP: float = 54.0  # gap between rows (depth)

func _issue_order(pos: Vector2) -> void:
	var enemy: Enemy = _enemy_under(pos)
	var selected: Array = _selected_minions()
	if enemy != null:
		for m in selected:
			m.order_attack(enemy)
	elif selected.size() <= 1:
		for m in selected:
			m.order_move(pos)
	else:
		_formation_move(selected, pos)

## Arrange the selected minions into role-ordered rows facing the march direction.
func _formation_move(minions: Array, pos: Vector2) -> void:
	# Face from the group's current centre toward the destination.
	var centroid: Vector2 = Vector2.ZERO
	for m in minions:
		centroid += m.global_position
	centroid /= float(minions.size())
	var dir: Vector2 = pos - centroid
	dir = dir.normalized() if dir.length() > 1.0 else Vector2.UP
	var perp: Vector2 = Vector2(-dir.y, dir.x)  # row-width axis

	# Cohesive march: the whole group moves at the slowest unit's speed so the
	# formation stays together and faster units don't outrun the tanks.
	var group_speed: float = INF
	for m in minions:
		group_speed = minf(group_speed, m.move_speed)

	# Bucket minions by role, one row per present role.
	var rows: Dictionary = {}  # rank -> Array[Minion]
	for m in minions:
		var rank: int = ROLE_ORDER.get(m.class_id, 1)
		if not rows.has(rank):
			rows[rank] = []
		rows[rank].append(m)
	var ranks: Array = rows.keys()
	ranks.sort()

	# Front row (lowest rank = tanks) sits closest to the target; rows step back.
	var total_depth: float = float(ranks.size() - 1) * FORMATION_ROW_GAP
	var row_index: int = 0
	for rank in ranks:
		var row: Array = rows[rank]
		var depth: float = total_depth * 0.5 - float(row_index) * FORMATION_ROW_GAP
		var row_center: Vector2 = pos + dir * depth
		var k: int = row.size()
		for i in range(k):
			var offset: float = (float(i) - float(k - 1) * 0.5) * FORMATION_SPACING
			row[i].order_move(row_center + perp * offset, group_speed)
		row_index += 1

# --- Control groups --------------------------------------------------------

func _assign_group(n: int) -> void:
	_control_groups[n] = _selected_minions()

func _recall_group(n: int) -> void:
	if not _control_groups.has(n):
		return
	_clear_selection()
	for m in _control_groups[n]:
		if is_instance_valid(m) and not m.is_dead:
			_set_selected(m, true)
	queue_redraw()

# --- Helpers ---------------------------------------------------------------

func _all_minions() -> Array:
	return get_tree().get_nodes_in_group("minions")

func _selected_minions() -> Array:
	var out: Array = []
	for m in _all_minions():
		if m is Minion and (m as Minion).selected:
			out.append(m)
	return out

func _minion_under(pos: Vector2) -> Minion:
	for m in _all_minions():
		if m is Minion and pos.distance_to((m as Minion).global_position) <= (m as Minion).body_radius + 6.0:
			return m
	return null

func _enemy_under(pos: Vector2) -> Enemy:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and pos.distance_to((e as Enemy).global_position) <= (e as Enemy).body_radius + 8.0:
			return e
	return null

func _set_selected(m: Minion, v: bool) -> void:
	m.selected = v
	m.queue_redraw()

func _clear_selection() -> void:
	for m in _all_minions():
		if m is Minion:
			_set_selected(m, false)

func _draw() -> void:
	if _dragging:
		var rect := Rect2(_drag_start, _drag_now - _drag_start).abs()
		draw_rect(rect, Color(0.4, 0.8, 1.0, 0.15), true)
		draw_rect(rect, Color(0.5, 0.9, 1.0, 0.8), false, 1.5)
