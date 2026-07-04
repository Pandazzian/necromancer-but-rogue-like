extends Node2D
## The Graveyard - the diegetic meta-progression hub (GDD 5.1). The undertaker
## physically walks the grounds: restore plots to raise Prestige, draft the
## wanderers those plots attract, choose a Tome at the pedestal, set the
## Grimoire loadout at the lectern, then march through the gate into a run.

const MAX_DRAFT: int = 3
const PLOT_MAX_LEVEL: int = 3
const INTERACT_RANGE: float = 80.0
const GROUND: Rect2 = Rect2(-700, -450, 1400, 900)

## Plot definitions (GDD 5.1 "Plot Types & Upgrades").
const PLOTS: Array = [
	{"id": "overgrown_a", "name": "Overgrown Plot", "pos": Vector2(-480, -220), "kind": "overgrown"},
	{"id": "overgrown_b", "name": "Overgrown Plot", "pos": Vector2(-520, 120), "kind": "overgrown"},
	{"id": "archer_trench", "name": "The Archer's Trench", "pos": Vector2(-240, -340), "kind": "trench"},
	{"id": "mausoleum", "name": "The Aristocrat's Mausoleum", "pos": Vector2(-260, 280), "kind": "mausoleum"},
]

const PEDESTAL_POS: Vector2 = Vector2(260, -260)
const LECTERN_POS: Vector2 = Vector2(260, 160)
const GATE_POS: Vector2 = Vector2(600, 0)

var _walker: CharacterBody2D
var _cam: Camera2D
var _hud: CanvasLayer
var _info: Label
var _prompt: Label
var _grimoire_ui: GrimoireUI
var _occupants: Array = []
var _flash_text: String = ""
var _flash_t: float = 0.0

func _ready() -> void:
	randomize()
	Audio.play_music("music_hub")
	Audio.set_desperation(false)  # clear any run-end muffle/heartbeat
	_build_walker()
	_build_hud()
	_spawn_occupants()

func _process(delta: float) -> void:
	_flash_t = maxf(0.0, _flash_t - delta)
	_move_walker(delta)
	_update_prompt()
	_update_info()
	queue_redraw()

# --- The undertaker ----------------------------------------------------------

func _build_walker() -> void:
	_walker = CharacterBody2D.new()
	_walker.position = Vector2(450, 220)
	add_child(_walker)
	_cam = Camera2D.new()
	_cam.zoom = Vector2(1.0, 1.0)
	_cam.position_smoothing_enabled = true
	_walker.add_child(_cam)
	_cam.make_current()

func _move_walker(_delta: float) -> void:
	if _grimoire_ui.visible:
		_walker.velocity = Vector2.ZERO
		return
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_walker.velocity = dir * 260.0
	_walker.move_and_slide()
	_walker.position = _walker.position.clamp(GROUND.position + Vector2(30, 30), GROUND.end - Vector2(30, 30))

# --- Interactions (walk close, press E) ---------------------------------------

## The nearest interactable within range: {kind, ...} or empty.
func _current_interactable() -> Dictionary:
	var wp: Vector2 = _walker.position
	var best: Dictionary = {}
	var best_d: float = INTERACT_RANGE
	for p in PLOTS:
		var d: float = wp.distance_to(p.pos)
		if d < best_d:
			best_d = d
			best = {"kind": "plot", "plot": p}
	for o in _occupants:
		if is_instance_valid(o):
			var d2: float = wp.distance_to(o.position)
			if d2 < best_d:
				best_d = d2
				best = {"kind": "occupant", "occupant": o}
	if wp.distance_to(PEDESTAL_POS) < best_d:
		best_d = wp.distance_to(PEDESTAL_POS)
		best = {"kind": "pedestal"}
	if wp.distance_to(LECTERN_POS) < best_d:
		best_d = wp.distance_to(LECTERN_POS)
		best = {"kind": "lectern"}
	if wp.distance_to(GATE_POS) < best_d:
		best = {"kind": "gate"}
	return best

func _update_prompt() -> void:
	var it: Dictionary = _current_interactable()
	if _grimoire_ui.visible or it.is_empty():
		_prompt.text = "" if _flash_t <= 0.0 else _flash_text
		return
	match it.kind:
		"plot":
			var p: Dictionary = it.plot
			var lvl: int = Profile.plot_level(p.id)
			if lvl >= PLOT_MAX_LEVEL:
				_prompt.text = "%s - fully restored (Lv %d)" % [p.name, lvl]
			else:
				_prompt.text = "%s (Lv %d)  -  E: restore for %d essence" % [p.name, lvl, _plot_cost(p.id)]
		"occupant":
			var inst: MinionInstance = it.occupant.instance
			_prompt.text = "%s (T%d %s)  -  E: draft into your party (%d/%d)" % [
				inst.unit_name, inst.tier, inst.class_id.capitalize(), RunState.drafted.size(), MAX_DRAFT]
		"pedestal":
			_prompt.text = "Tome Pedestal  -  E: swap Tome (now: %s)" % Tomes.get_or_default(Profile.selected_tome).display_name
		"lectern":
			_prompt.text = "Grimoire Lectern  -  E: open loadout"
		"gate":
			_prompt.text = "The Iron Gate  -  E: begin the run  (%d drafted%s)" % [
				RunState.drafted.size(), ", defaults added if none" if RunState.drafted.is_empty() else ""]
	if _flash_t > 0.0:
		_prompt.text = _flash_text

func _unhandled_input(event: InputEvent) -> void:
	if _grimoire_ui.visible:
		return
	if event.is_action_pressed("soul_bind"):
		var it: Dictionary = _current_interactable()
		if it.is_empty():
			return
		match it.kind:
			"plot":
				_try_upgrade_plot(it.plot)
			"occupant":
				_draft(it.occupant)
			"pedestal":
				_cycle_tome()
			"lectern":
				_grimoire_ui.open()
			"gate":
				_start_run()

func _plot_cost(id: String) -> int:
	return (Profile.plot_level(id) + 1) * 25

func _try_upgrade_plot(p: Dictionary) -> void:
	var lvl: int = Profile.plot_level(p.id)
	if lvl >= PLOT_MAX_LEVEL:
		return
	var cost: int = _plot_cost(p.id)
	if not Profile.spend_essence(cost):
		_flash("Not enough Soul Essence (%d needed)." % cost)
		return
	Profile.set_plot_level(p.id, lvl + 1)
	_flash("%s restored to level %d. Prestige rises." % [p.name, lvl + 1])
	_spawn_occupants()  # a finer graveyard draws finer dead

func _draft(o: Node2D) -> void:
	if RunState.drafted.size() >= MAX_DRAFT:
		_flash("Your cortege is full (%d)." % MAX_DRAFT)
		return
	RunState.drafted.append(o.instance)
	_occupants.erase(o)
	o.queue_free()
	_flash("%s shuffles into your cortege." % o.instance.unit_name)

func _cycle_tome() -> void:
	var ids: Array = Tomes.IDS
	var idx: int = ids.find(Profile.selected_tome)
	Profile.set_tome(ids[(idx + 1) % ids.size()])
	_flash(Tomes.get_or_default(Profile.selected_tome).display_name + " - " \
		+ Tomes.get_or_default(Profile.selected_tome).description)

func _start_run() -> void:
	RunState.begin_run()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _flash(msg: String) -> void:
	_flash_text = msg
	_flash_t = 3.0

# --- Occupants (the Draft, GDD 5.1) -------------------------------------------

## Wanderers attracted by the graveyard's condition. Rebuilt when plots change.
func _spawn_occupants() -> void:
	for o in _occupants:
		if is_instance_valid(o):
			o.queue_free()
	_occupants.clear()

	var total_levels: int = 0
	for p in PLOTS:
		total_levels += Profile.plot_level(p.id)
	var count: int = clampi(1 + total_levels, 1, 6)

	var pool: Array = []
	# Overgrown plots host basic skeletons; the trench guarantees a ranged one.
	if Profile.plot_level("archer_trench") > 0:
		pool.append("archer")
	for i in count - pool.size():
		pool.append(["warrior", "tank", "warrior", "mage"][randi() % 4])

	for cid in pool:
		var inst := MinionInstance.create(cid)
		# The Mausoleum sometimes attracts a Tier 2 aristocrat among the dead.
		var t2_chance: float = 0.18 * Profile.plot_level("mausoleum") + 0.002 * Profile.prestige()
		if randf() < t2_chance:
			inst.tier = 2
		var o := Occupant.new()
		o.instance = inst
		o.position = Vector2(randf_range(-100, 350), randf_range(-260, 260))
		add_child(o)
		_occupants.append(o)

class Occupant:
	extends Node2D
	## A restless tenant of the graveyard, available for the Draft. Wanders
	## aimlessly between short waits; drawn like a dulled minion with a name tag.

	var instance: MinionInstance = null
	var _target: Vector2
	var _wait: float = 0.0

	func _ready() -> void:
		_target = position

	func _process(delta: float) -> void:
		_wait -= delta
		if _wait <= 0.0:
			_target = position + Vector2(randf_range(-90, 90), randf_range(-90, 90))
			_wait = randf_range(1.5, 4.0)
		position = position.move_toward(_target, 30.0 * delta)
		queue_redraw()

	func _draw() -> void:
		var arch: UnitArchetype = Classes.minion(instance.class_id)
		var col: Color = arch.color.lerp(Color(0.5, 0.5, 0.55), 0.35)
		draw_circle(Vector2.ZERO, arch.body_radius, col)
		draw_arc(Vector2.ZERO, arch.body_radius, 0.0, TAU, 24, col.darkened(0.4), 2.0)
		if instance.tier > 1:
			for i in range(instance.tier - 1):
				draw_circle(Vector2(-6.0 + float(i) * 6.0, -arch.body_radius - 7.0), 2.4, Color(1.0, 0.85, 0.3))
		var font: Font = ThemeDB.fallback_font
		var w: float = font.get_string_size(instance.unit_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, Vector2(-w * 0.5, -arch.body_radius - 14.0), instance.unit_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.85, 0.9, 0.7))

# --- HUD -----------------------------------------------------------------------

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)

	_info = Label.new()
	_info.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_info.offset_left = 12.0
	_info.offset_top = 8.0
	_info.add_theme_font_size_override("font_size", 15)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 4)
	_hud.add_child(_info)

	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -84.0
	_prompt.offset_left = 12.0
	_prompt.offset_right = -12.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.add_theme_font_size_override("font_size", 16)
	_prompt.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 4)
	_hud.add_child(_prompt)

	_grimoire_ui = GrimoireUI.new()
	_hud.add_child(_grimoire_ui)

func _update_info() -> void:
	var tome: TomeData = Tomes.get_or_default(Profile.selected_tome)
	var lines := PackedStringArray()
	lines.append("THE GRAVEYARD    Prestige: %d    Soul Essence: %d" % [Profile.prestige(), Profile.soul_essence])
	lines.append("Account Lv %d (%d/%d exp)    Arcane Capacity: %d/%d    Tome: %s" % [
		Profile.account_level, Profile.account_xp, Profile.account_level * Profile.XP_PER_LEVEL,
		Grimoire.loadout_cost(Profile.equipped_pages, Profile.selected_tome), Profile.arcane_capacity(),
		tome.display_name])
	lines.append("WASD walk | E interact | restore plots, draft the dead, choose your Tome, then take the gate")
	_info.text = "\n".join(lines)

# --- Grounds rendering ----------------------------------------------------------

func _draw() -> void:
	# Ground.
	draw_rect(GROUND, Color(0.09, 0.11, 0.09))
	# Scattered unrestored graves for flavour.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		var gp := Vector2(rng.randf_range(GROUND.position.x + 60, GROUND.end.x - 60),
			rng.randf_range(GROUND.position.y + 60, GROUND.end.y - 60))
		draw_rect(Rect2(gp, Vector2(14, 20)), Color(0.16, 0.17, 0.18))
	# Plots.
	for p in PLOTS:
		_draw_plot(p)
	# Tome pedestal: a pillar with the tome's colour burning above it.
	var tcol: Color = Tomes.get_or_default(Profile.selected_tome).color
	draw_rect(Rect2(PEDESTAL_POS - Vector2(12, 12), Vector2(24, 24)), Color(0.4, 0.4, 0.45))
	draw_circle(PEDESTAL_POS + Vector2(0, -20), 8.0, tcol)
	draw_arc(PEDESTAL_POS + Vector2(0, -20), 12.0, 0.0, TAU, 20, Color(tcol.r, tcol.g, tcol.b, 0.5), 2.0)
	# Grimoire lectern.
	draw_rect(Rect2(LECTERN_POS - Vector2(10, 14), Vector2(20, 28)), Color(0.35, 0.28, 0.2))
	draw_rect(Rect2(LECTERN_POS - Vector2(16, 20), Vector2(32, 10)), Color(0.5, 0.42, 0.3))
	# The Iron Gate.
	draw_rect(Rect2(GATE_POS - Vector2(8, 90), Vector2(16, 180)), Color(0.25, 0.25, 0.3))
	for i in 5:
		draw_line(GATE_POS + Vector2(-6, -80 + i * 40), GATE_POS + Vector2(6, -80 + i * 40), Color(0.5, 0.5, 0.55), 2.0)
	draw_arc(GATE_POS + Vector2(0, -90), 26.0, PI, TAU, 20, Color(0.5, 0.5, 0.55), 3.0)
	# The undertaker.
	draw_circle(_walker.position, 15.0, Color(0.75, 0.85, 1.0))
	draw_arc(_walker.position, 15.0, 0.0, TAU, 24, Color(0.45, 0.55, 0.7), 2.0)

func _draw_plot(p: Dictionary) -> void:
	var lvl: int = Profile.plot_level(p.id)
	var frac: float = float(lvl) / float(PLOT_MAX_LEVEL)
	var base: Color
	match p.kind:
		"trench":
			base = Color(0.35, 0.45, 0.3)
		"mausoleum":
			base = Color(0.45, 0.4, 0.5)
		_:
			base = Color(0.3, 0.35, 0.3)
	# Plot bed brightens as it's restored; weeds fade away.
	draw_rect(Rect2(p.pos - Vector2(45, 30), Vector2(90, 60)), base.lerp(Color(0.5, 0.55, 0.5), frac * 0.5))
	if p.kind == "mausoleum":
		draw_rect(Rect2(p.pos - Vector2(20, 26), Vector2(40, 34)), Color(0.55, 0.5, 0.6).darkened(0.4 * (1.0 - frac)))
		draw_arc(p.pos + Vector2(0, -26), 20.0, PI, TAU, 16, Color(0.6, 0.55, 0.65), 2.0)
	else:
		# Tombstones stand up one per level.
		for i in lvl:
			draw_rect(Rect2(p.pos + Vector2(-30 + i * 24, -16), Vector2(14, 22)), Color(0.6, 0.6, 0.62))
	if lvl == 0:
		# Weeds.
		for i in 5:
			var wp: Vector2 = p.pos + Vector2(-32 + i * 16, 16)
			draw_line(wp, wp + Vector2(-3, -10), Color(0.25, 0.45, 0.2), 2.0)
			draw_line(wp, wp + Vector2(3, -9), Color(0.3, 0.5, 0.25), 2.0)
	var font: Font = ThemeDB.fallback_font
	var label: String = "%s  Lv %d" % [p.name, lvl]
	var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, p.pos + Vector2(-w * 0.5, 48.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.8, 0.85, 0.8))
