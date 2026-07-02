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

func _issue_order(pos: Vector2) -> void:
	var enemy: Enemy = _enemy_under(pos)
	for m in _selected_minions():
		if enemy != null:
			m.order_attack(enemy)
		else:
			m.order_move(pos)

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
