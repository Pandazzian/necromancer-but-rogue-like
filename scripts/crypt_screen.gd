extends CanvasLayer
## Between-rooms Crypt management (GDD 3.4). Pauses the game and lets the player
## Flesh-Stitch duplicate minions into higher tiers and swap units between the
## active party and the stored Crypt, before marching into the next room.

signal continue_pressed

var _root: Control
var _party_list: ItemList
var _crypt_list: ItemList
var _party_label: Label
var _crypt_label: Label
var _info: Label

# Which side/instance is currently selected.
var _sel_side: String = ""       # "party" | "crypt"
var _sel: MinionInstance = null

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep working while the tree is paused
	_build_ui()
	_root.visible = false

func open() -> void:
	get_tree().paused = true
	_sel = null
	_sel_side = ""
	_refresh()
	_root.visible = true

func _close() -> void:
	_root.visible = false
	get_tree().paused = false
	continue_pressed.emit()

# --- UI construction -------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.03, 0.05, 0.75)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 80
	panel.offset_top = 56
	panel.offset_right = -80
	panel.offset_bottom = -56
	_root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "THE CRYPT  —  Flesh-Stitching"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	vb.add_child(title)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 24)
	vb.add_child(cols)

	# Active party column.
	var party_col := VBoxContainer.new()
	party_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(party_col)
	_party_label = Label.new()
	_party_label.add_theme_font_size_override("font_size", 18)
	party_col.add_child(_party_label)
	_party_list = _make_list()
	_party_list.item_selected.connect(_on_party_selected)
	party_col.add_child(_party_list)

	# Crypt reserve column.
	var crypt_col := VBoxContainer.new()
	crypt_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(crypt_col)
	_crypt_label = Label.new()
	_crypt_label.add_theme_font_size_override("font_size", 18)
	crypt_col.add_child(_crypt_label)
	_crypt_list = _make_list()
	_crypt_list.item_selected.connect(_on_crypt_selected)
	crypt_col.add_child(_crypt_list)

	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 14)
	vb.add_child(_info)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	vb.add_child(buttons)
	buttons.add_child(_make_button("Deploy  →", _on_deploy))
	buttons.add_child(_make_button("→  Store in Crypt", _on_store))
	buttons.add_child(_make_button("Flesh-Stitch (merge)", _on_stitch))
	buttons.add_child(_make_button("March On  ⚔", _close))

func _make_list() -> ItemList:
	var l := ItemList.new()
	l.custom_minimum_size = Vector2(300, 320)
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return l

func _make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(cb)
	return b

# --- Data / refresh --------------------------------------------------------

func _label_for(inst: MinionInstance) -> String:
	var disp: String = Classes.minion(inst.class_id).display_name
	return "%s   —   Tier %d" % [disp, inst.tier]

func _refresh() -> void:
	_party_label.text = "ACTIVE PARTY  (%d / %d)" % [Crypt.party.size(), Crypt.party_cap]
	_crypt_label.text = "CRYPT  (%d / %d)" % [Crypt.reserve.size(), Crypt.reserve_cap]
	_party_list.clear()
	for inst in Crypt.party:
		_party_list.add_item(_label_for(inst))
	_crypt_list.clear()
	for inst in Crypt.reserve:
		_crypt_list.add_item(_label_for(inst))
	if _info.text == "":
		_info.text = "Select a minion, then Deploy/Store. Flesh-Stitch fuses two of the same class & tier into Tier+1."

func _on_party_selected(idx: int) -> void:
	_sel_side = "party"
	_sel = Crypt.party[idx] if idx < Crypt.party.size() else null
	_crypt_list.deselect_all()

func _on_crypt_selected(idx: int) -> void:
	_sel_side = "crypt"
	_sel = Crypt.reserve[idx] if idx < Crypt.reserve.size() else null
	_party_list.deselect_all()

# --- Actions ---------------------------------------------------------------

func _on_deploy() -> void:
	if _sel == null or _sel_side != "crypt":
		_flash("Select a minion in the Crypt to deploy.")
		return
	if not Crypt.deploy(_sel):
		_flash("Active party is full (%d)." % Crypt.party_cap)
		return
	_sel = null
	_refresh()

func _on_store() -> void:
	if _sel == null or _sel_side != "party":
		_flash("Select a party minion to store.")
		return
	if not Crypt.store(_sel):
		_flash("Crypt is full (%d)." % Crypt.reserve_cap)
		return
	_sel = null
	_refresh()

func _on_stitch() -> void:
	if _sel == null:
		_flash("Select a minion to Flesh-Stitch.")
		return
	var partner: MinionInstance = Crypt.find_stitch_partner(_sel)
	if partner == null:
		_flash("No matching duplicate (same class & tier) to stitch.")
		return
	var merged := Crypt.stitch(_sel, partner)
	_sel = null
	_flash("Stitched into a Tier %d %s!" % [merged.tier, Classes.minion(merged.class_id).display_name])
	_refresh()

func _flash(msg: String) -> void:
	_info.text = msg
