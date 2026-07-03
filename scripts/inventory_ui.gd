class_name InventoryUI
extends Control
## The Crypt screen (GDD 3.4/3.5): a single mouse-driven overlay where the player
## manages their own graft stash and minion roster. It does three jobs:
##   * Flesh-Grafting - click a graft, then click a minion to attach it.
##   * Roster management - Deploy/Store swaps between the active party and Crypt.
##   * Flesh-Stitching - merge two same-class/same-tier minions into Tier+1.
## Toggle it mid-combat with I / Tab, or it opens automatically between rooms
## (with a "March On" button). Per-player and non-pausing, so it's co-op-safe -
## the shared world keeps running while this player's Necromancer holds still.

signal continue_pressed
## Emitted when the active party changes (deploy/store/stitch) so Main can sync
## the field immediately instead of waiting for the next room.
signal roster_changed

var player: Player = null

var _open: bool = false
var _between_rooms: bool = false
var _selected_graft: GraftItem = null
var _selected_minion: MinionInstance = null

var _minion_list: VBoxContainer
var _graft_list: VBoxContainer
var _graft_header: Label
var _minion_header: Label
var _status: Label
var _march_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false
	if player != null and player.inventory != null:
		player.inventory.inventory_changed.connect(_on_inventory_changed)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Don't hijack keystrokes while the player is typing (e.g. renaming).
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		var kc: int = (event as InputEventKey).keycode
		if kc == KEY_I or kc == KEY_TAB:
			_toggle()
			get_viewport().set_input_as_handled()
		elif kc == KEY_ESCAPE and _open and not _between_rooms:
			_toggle()
			get_viewport().set_input_as_handled()

# --- Open / close ----------------------------------------------------------

## Mid-combat quick toggle (I / Tab). Disabled during the between-rooms step,
## where the only way forward is the March On button.
func _toggle() -> void:
	if _between_rooms:
		return
	_open = not _open
	visible = _open
	_march_btn.visible = false
	_reset_selection()
	_set_input_locked(_open)
	if _open:
		_status.text = ""
		_rebuild()

## Open as the mandatory between-rooms management step.
func open_between_rooms() -> void:
	_between_rooms = true
	_open = true
	visible = true
	_march_btn.visible = true
	_reset_selection()
	_set_input_locked(true)
	_status.text = "Manage your army, then March On to the next room."
	_rebuild()

func _on_march_pressed() -> void:
	_between_rooms = false
	_open = false
	visible = false
	_set_input_locked(false)
	continue_pressed.emit()

func _on_inventory_changed() -> void:
	if _open:
		_rebuild()

func _reset_selection() -> void:
	_selected_graft = null
	_selected_minion = null

func _set_input_locked(v: bool) -> void:
	if player != null and is_instance_valid(player):
		player.input_locked = v

# --- Construction ----------------------------------------------------------

func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.04, 0.66)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP  # swallow clicks behind the menu
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 60)
	add_child(margin)

	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.13, 0.98)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.5, 0.6, 0.8, 0.8)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(16)
	frame.add_theme_stylebox_override("panel", sb)
	margin.add_child(frame)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	frame.add_child(vb)

	var title := Label.new()
	title.text = "THE CRYPT  —  Inventory · Grafting · Flesh-Stitching"
	title.add_theme_font_size_override("font_size", 22)
	title.modulate = Color(0.85, 0.9, 1.0)
	vb.add_child(title)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(cols)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	_minion_header = Label.new()
	_minion_header.add_theme_font_size_override("font_size", 14)
	_minion_header.modulate = Color(0.7, 0.8, 0.95)
	left.add_child(_minion_header)
	_minion_list = _make_scroll_list(left)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	_graft_header = Label.new()
	_graft_header.add_theme_font_size_override("font_size", 14)
	_graft_header.modulate = Color(0.7, 0.8, 0.95)
	right.add_child(_graft_header)
	_graft_list = _make_scroll_list(right)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 14)
	_status.modulate = Color(0.9, 0.85, 0.6)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	vb.add_child(buttons)
	buttons.add_child(_make_button("Deploy →", _on_deploy))
	buttons.add_child(_make_button("→ Store", _on_store))
	buttons.add_child(_make_button("Flesh-Stitch (merge)", _on_stitch))
	_march_btn = _make_button("March On  ⚔", _on_march_pressed)
	buttons.add_child(_march_btn)
	buttons.add_child(_make_button("Close (I / Tab)", _toggle))

func _make_scroll_list(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(320, 300)
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	return list

func _make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(cb)
	return b

# --- Population ------------------------------------------------------------

func _rebuild() -> void:
	if player == null or player.inventory == null:
		return
	_rebuild_minions()
	_rebuild_grafts()

func _rebuild_minions() -> void:
	for c in _minion_list.get_children():
		c.queue_free()
	var inv: Inventory = player.inventory
	_minion_header.text = "MINIONS   party %d/%d   crypt %d/%d" % [
		inv.party.size(), inv.party_cap, inv.crypt.size(), inv.reserve_cap]
	if inv.party.is_empty() and inv.crypt.is_empty():
		_minion_list.add_child(_dim_label("No minions. Raise some with Soul Bind."))
		return
	for inst in inv.party:
		_minion_list.add_child(_minion_button(inst, "Party"))
	for inst in inv.crypt:
		_minion_list.add_child(_minion_button(inst, "Crypt"))

func _minion_button(inst: MinionInstance, where: String) -> Button:
	var btn := Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 14)
	btn.text = ("> " if inst == _selected_minion else "") + _minion_text(inst, where)
	btn.pressed.connect(_on_minion_pressed.bind(inst))
	return btn

func _rebuild_grafts() -> void:
	for c in _graft_list.get_children():
		c.queue_free()
	var stash: Array = player.inventory.grafts
	_graft_header.text = "GRAFT STASH  (%d)" % stash.size()
	if stash.is_empty():
		_graft_list.add_child(_dim_label("Empty. Slain Inquisitors drop grafts to harvest."))
		return
	for g in stash:
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 14)
		btn.text = ("> " if g == _selected_graft else "") + "%s  [%s]\n   %s" % [
			g.display_name, g.category_name(), g.effect_text()]
		btn.add_theme_color_override("font_color", Color(1, 1, 1) if g == _selected_graft else g.color)
		btn.pressed.connect(_on_graft_pressed.bind(g))
		_graft_list.add_child(btn)

func _minion_text(inst: MinionInstance, where: String) -> String:
	var node: Minion = _node_for(inst)
	var hp: String = "HP %d/%d" % [roundi(node.current_hp), roundi(node.max_hp)] if node != null else "benched"
	var line: String = "%s   [%s]\n   %s  T%d  %s  Grafts %d/%d" % [
		inst.unit_name, where, inst.class_id.capitalize(), inst.tier, hp,
		inst.used_slots(), inst.graft_slots()]
	if not inst.grafts.is_empty():
		var names: PackedStringArray = []
		for g in inst.grafts:
			names.append(g.display_name)
		line += "\n   [" + ", ".join(names) + "]"
	return line

func _dim_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = Color(0.6, 0.6, 0.65)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

# --- Interaction -----------------------------------------------------------

func _on_graft_pressed(g: GraftItem) -> void:
	_selected_graft = null if g == _selected_graft else g
	_rebuild()
	if _selected_graft != null:
		_status.text = "Selected %s — click a minion to graft it." % _selected_graft.display_name

func _on_minion_pressed(inst: MinionInstance) -> void:
	# A pending graft attaches; otherwise the click just selects the minion.
	if _selected_graft != null:
		var g: GraftItem = _selected_graft
		if player.inventory.apply_graft(inst, g):
			var node: Minion = _node_for(inst)
			if node != null:
				node.refresh_from_instance()
			_selected_graft = null
			_status.text = "Grafted %s onto %s." % [g.display_name, inst.unit_name]
		else:
			_status.text = "%s has no free graft slot (%d/%d) — Flesh-Stitch for more." % [
				inst.unit_name, inst.used_slots(), inst.graft_slots()]
		return
	_selected_minion = null if inst == _selected_minion else inst
	_rebuild()

func _on_deploy() -> void:
	if _selected_minion == null or not player.inventory.crypt.has(_selected_minion):
		_status.text = "Select a Crypt minion to deploy into the active party."
		return
	var inst: MinionInstance = _selected_minion
	if not player.inventory.deploy(inst):
		_status.text = "Active party is full (%d)." % player.inventory.party_cap
		return
	_selected_minion = null
	roster_changed.emit()  # spawn it on the field now
	_status.text = "Deployed %s to the field." % inst.unit_name

func _on_store() -> void:
	if _selected_minion == null or not player.inventory.party.has(_selected_minion):
		_status.text = "Select an active-party minion to bench in the Crypt."
		return
	var inst: MinionInstance = _selected_minion
	if not player.inventory.store(inst):
		_status.text = "Crypt is full (%d)." % player.inventory.reserve_cap
		return
	_selected_minion = null
	roster_changed.emit()  # pull it off the field now
	_status.text = "Stored %s in the Crypt." % inst.unit_name

func _on_stitch() -> void:
	if _selected_minion == null:
		_status.text = "Select a minion to Flesh-Stitch (needs a same-class, same-tier twin)."
		return
	var partner: MinionInstance = player.inventory.find_stitch_partner(_selected_minion)
	if partner == null:
		_status.text = "No matching duplicate (same class & tier) to stitch."
		return
	var merged: MinionInstance = player.inventory.stitch(_selected_minion, partner)
	_selected_minion = null
	roster_changed.emit()  # remove the fused pair from the field now
	if merged != null:
		_status.text = "Stitched into a Tier %d %s (inherits both parents' grafts). It waits in the Crypt." % [
			merged.tier, merged.class_id.capitalize()]

func _node_for(inst: MinionInstance) -> Minion:
	for m in get_tree().get_nodes_in_group("minions"):
		if m is Minion and (m as Minion).instance == inst:
			return m as Minion
	return null
