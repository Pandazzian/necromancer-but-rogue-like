class_name MinionPanel
extends PanelContainer
## Mouse-driven info + rename card for a single selected minion. Anchored to the
## bottom-left of the HUD, it shows the minion's name, class, tier and live HP;
## the Rename button opens an inline text field so the player can give a valued
## minion a memorable name and avoid sending the wrong one into danger. Built in
## code and parented under the HUD CanvasLayer (matches the build-UI-in-code style).

var player: Player = null

var _minion: Minion = null
var _name_label: Label
var _stats_label: Label
var _hint_label: Label
var _rename_btn: Button
var _name_edit: LineEdit

func _ready() -> void:
	# Anchor to the bottom-left corner with an explicit size so the card is always
	# visible when shown (no reliance on content min-size, which can collapse).
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 12.0
	offset_bottom = -12.0
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size = Vector2(250.0, 96.0)
	mouse_filter = Control.MOUSE_FILTER_STOP  # clicks on the card don't hit the field

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.11, 0.93)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.5, 0.6, 0.8, 0.7)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	add_theme_stylebox_override("panel", sb)

	_build()
	hide()

func _process(_delta: float) -> void:
	if not visible:
		return
	if _minion == null or not is_instance_valid(_minion) or _minion.is_dead:
		hide_panel()
	elif not _name_edit.visible:
		_refresh()

# --- Public API ------------------------------------------------------------

func show_for(m: Minion) -> void:
	_cancel_edit()
	_minion = m
	show()
	_refresh()

func hide_panel() -> void:
	_cancel_edit()
	_minion = null
	hide()

# --- Construction ----------------------------------------------------------

func _build() -> void:
	var vb := VBoxContainer.new()
	add_child(vb)

	_hint_label = Label.new()
	_hint_label.text = "SELECTED MINION"
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.modulate = Color(0.6, 0.7, 0.9)
	vb.add_child(_hint_label)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	vb.add_child(_name_label)

	_name_edit = LineEdit.new()
	_name_edit.visible = false
	_name_edit.max_length = 24
	_name_edit.placeholder_text = "Name this minion"
	_name_edit.custom_minimum_size = Vector2(220.0, 0.0)
	_name_edit.text_submitted.connect(_on_name_submitted)
	_name_edit.focus_exited.connect(_commit_rename)
	vb.add_child(_name_edit)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 13)
	_stats_label.modulate = Color(0.8, 0.85, 0.95)
	vb.add_child(_stats_label)

	_rename_btn = Button.new()
	_rename_btn.text = "Rename"
	_rename_btn.pressed.connect(_begin_rename)
	vb.add_child(_rename_btn)

# --- Display ---------------------------------------------------------------

func _refresh() -> void:
	if _minion == null or not is_instance_valid(_minion):
		return
	var inst: MinionInstance = _minion.instance
	_name_label.text = inst.unit_name
	_stats_label.text = "%s   Tier %d   HP %d/%d" % [
		inst.class_id.capitalize(), inst.tier,
		roundi(_minion.current_hp), roundi(_minion.max_hp)]

# --- Renaming (mouse-invoked, text typed) ----------------------------------

func _begin_rename() -> void:
	if _minion == null or not is_instance_valid(_minion):
		return
	_name_edit.text = _minion.instance.unit_name
	_name_edit.visible = true
	_name_label.visible = false
	_lock_input(true)
	_name_edit.grab_focus()
	_name_edit.select_all()

func _on_name_submitted(_text: String) -> void:
	_name_edit.release_focus()  # triggers focus_exited -> _commit_rename

func _commit_rename() -> void:
	if not _name_edit.visible:
		return
	if _minion != null and is_instance_valid(_minion):
		var t: String = _name_edit.text.strip_edges()
		if t != "":
			_minion.instance.unit_name = t
			_minion.queue_redraw()
	_cancel_edit()
	_refresh()

## Leave rename mode without committing (also releases the input lock).
func _cancel_edit() -> void:
	if _name_edit != null:
		_name_edit.visible = false
	if _name_label != null:
		_name_label.visible = true
	_lock_input(false)

func _lock_input(v: bool) -> void:
	if player != null and is_instance_valid(player):
		player.input_locked = v
