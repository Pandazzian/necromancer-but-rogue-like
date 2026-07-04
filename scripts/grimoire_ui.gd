class_name GrimoireUI
extends Control
## The Grimoire loadout screen (GDD 5.2/5.3), opened at the hub lectern. Mouse
## driven: click a locked page to unlock it with Soul Essence, click an unlocked
## page to equip/unequip it. The equipped total may not exceed Arcane Capacity;
## pages matching the selected Tome cost 1 less (Tome Affinity).

var _list: VBoxContainer
var _header: Label
var _status: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		var kc: int = (event as InputEventKey).keycode
		if kc == KEY_ESCAPE or kc == KEY_I or kc == KEY_TAB:
			visible = false
			get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	_status.text = "Click a page to unlock (essence) or equip/unequip it."
	_rebuild()

# --- Construction ------------------------------------------------------------

func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.04, 0.7)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 80)
	add_child(margin)

	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.13, 0.98)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.6, 0.55, 0.8, 0.8)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(16)
	frame.add_theme_stylebox_override("panel", sb)
	margin.add_child(frame)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	frame.add_child(vb)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 22)
	_header.modulate = Color(0.85, 0.9, 1.0)
	vb.add_child(_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(560, 320)
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 14)
	_status.modulate = Color(0.9, 0.85, 0.6)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_status)

	var close := Button.new()
	close.text = "Close  (Esc)"
	close.pressed.connect(func() -> void: visible = false)
	vb.add_child(close)

# --- Population ----------------------------------------------------------------

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var tome_id: String = Profile.selected_tome
	_header.text = "THE GRIMOIRE    capacity %d / %d    essence %d" % [
		Grimoire.loadout_cost(Profile.equipped_pages, tome_id),
		Profile.arcane_capacity(), Profile.soul_essence]
	for pid in Grimoire.all_ids():
		var p: GrimoirePage = Grimoire.get_page(pid)
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 14)
		var cost: int = p.cost_with(tome_id)
		var affinity: String = "  (affinity -1)" if cost < p.arcane_cost else ""
		if not Profile.unlocked_pages.has(pid):
			btn.text = "%s   [LOCKED - unlock for %d essence]\n   Cost %d%s   %s" % [
				p.display_name, p.unlock_cost, cost, affinity, p.description]
			btn.modulate = Color(0.65, 0.65, 0.7)
		elif Profile.equipped_pages.has(pid):
			btn.text = "%s   [EQUIPPED - click to remove]\n   Cost %d%s   %s" % [
				p.display_name, cost, affinity, p.description]
			btn.modulate = Color(0.7, 1.0, 0.75)
		else:
			btn.text = "%s   [click to equip]\n   Cost %d%s   %s" % [
				p.display_name, cost, affinity, p.description]
		btn.pressed.connect(_on_page_pressed.bind(pid))
		_list.add_child(btn)

func _on_page_pressed(pid: String) -> void:
	var p: GrimoirePage = Grimoire.get_page(pid)
	var tome_id: String = Profile.selected_tome
	if not Profile.unlocked_pages.has(pid):
		if not Profile.spend_essence(p.unlock_cost):
			_status.text = "Not enough Soul Essence (%d needed)." % p.unlock_cost
			_rebuild()
			return
		Profile.unlock_page(pid)
		_status.text = "%s inscribed into your Grimoire forever." % p.display_name
	elif Profile.equipped_pages.has(pid):
		var eq: Array = Profile.equipped_pages.duplicate()
		eq.erase(pid)
		Profile.set_equipped_pages(eq)
		_status.text = "%s set aside." % p.display_name
	else:
		var eq2: Array = Profile.equipped_pages.duplicate()
		eq2.append(pid)
		if Grimoire.loadout_cost(eq2, tome_id) > Profile.arcane_capacity():
			_status.text = "Beyond your Arcane Capacity (%d). Level up or unequip something." % Profile.arcane_capacity()
			_rebuild()
			return
		Profile.set_equipped_pages(eq2)
		_status.text = "%s equipped." % p.display_name
	_rebuild()
