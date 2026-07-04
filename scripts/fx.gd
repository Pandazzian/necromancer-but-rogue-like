class_name FX
extends RefCounted
## One-shot particle effects (CPUParticles2D - works on the GL Compatibility
## renderer). Every effect is fire-and-forget: it frees itself when finished.
## Nodes are added deferred so effects can be spawned from physics callbacks,
## and use top_level so positions are world-space whatever the parent is.

const SOUL_GREEN := Color(0.5, 0.91, 0.63)
const BONE_WHITE := Color(0.91, 0.88, 0.8)

## Core emitter builder. `dir` Vector2.ZERO = radial burst (360 spread).
static func _emit(parent: Node, pos: Vector2, color: Color, count: int,
		speed: float, life: float, size: float, dir: Vector2 = Vector2.ZERO,
		spread: float = 180.0, grav: Vector2 = Vector2.ZERO) -> CPUParticles2D:
	if parent == null or not is_instance_valid(parent):
		return null
	var p := CPUParticles2D.new()
	p.top_level = true  # world coordinates, independent of the parent's transform
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = count
	p.lifetime = life
	p.direction = dir if dir != Vector2.ZERO else Vector2.UP
	p.spread = spread if dir != Vector2.ZERO else 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = grav
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))  # fade to nothing
	p.color_ramp = ramp
	p.finished.connect(p.queue_free)
	p.emitting = true
	parent.call_deferred("add_child", p)
	return p

# --- Necromancy ---------------------------------------------------------------

## Soul motes drifting up out of disturbed earth (minion rising, GDD 3.2).
static func soul_rise(parent: Node, pos: Vector2) -> void:
	_emit(parent, pos, SOUL_GREEN, 14, 55.0, 0.8, 3.2, Vector2.UP, 55.0, Vector2(0, -70))
	_emit(parent, pos + Vector2(0, 4), Color(0.35, 0.3, 0.24), 8, 45.0, 0.5, 3.6,
		Vector2.UP, 80.0, Vector2(0, 260))  # kicked-up dirt falls back

## The big payoff burst when a Soul Bind completes over a corpse.
static func soul_burst(parent: Node, pos: Vector2) -> void:
	_emit(parent, pos, SOUL_GREEN, 26, 120.0, 0.7, 3.6, Vector2.ZERO, 180.0, Vector2(0, -90))

## Continuous wisp stream while channeling Soul Bind (corpse -> Necromancer).
## Caller updates `direction`/velocity as the player moves; end with stop_stream.
static func soul_stream(parent: Node, pos: Vector2, dir: Vector2, speed: float) -> CPUParticles2D:
	if parent == null or not is_instance_valid(parent):
		return null
	var p := CPUParticles2D.new()
	p.top_level = true
	p.position = pos
	p.amount = 18
	p.lifetime = 0.5
	p.direction = dir
	p.spread = 10.0
	p.initial_velocity_min = speed * 0.85
	p.initial_velocity_max = speed * 1.15
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.4
	var ramp := Gradient.new()
	ramp.set_color(0, SOUL_GREEN)
	ramp.set_color(1, Color(SOUL_GREEN.r, SOUL_GREEN.g, SOUL_GREEN.b, 0.0))
	p.color_ramp = ramp
	p.emitting = true
	parent.call_deferred("add_child", p)
	return p

## Gracefully end a soul_stream: stop emitting, free once live wisps expire.
static func stop_stream(p: CPUParticles2D) -> void:
	if p == null or not is_instance_valid(p):
		return
	p.emitting = false
	if not p.is_inside_tree():
		p.queue_free()
		return
	p.get_tree().create_timer(p.lifetime + 0.1).timeout.connect(p.queue_free)

# --- Combat --------------------------------------------------------------------

## Bone chips scattering when an undead (or armoured foe) is destroyed.
static func bone_burst(parent: Node, pos: Vector2) -> void:
	_emit(parent, pos, BONE_WHITE, 12, 130.0, 0.6, 3.0, Vector2.UP, 100.0, Vector2(0, 320))

## Small impact sparks whenever something takes a real hit.
static func hit_spark(parent: Node, pos: Vector2, color: Color = Color(1.0, 0.85, 0.6)) -> void:
	_emit(parent, pos, color, 6, 100.0, 0.25, 2.4)

## AoE detonation debris (mage bolts), sized to the blast.
static func blast(parent: Node, pos: Vector2, color: Color, radius: float) -> void:
	_emit(parent, pos, color, 22, radius * 2.6, 0.4, 3.4)

# --- Pickups / support ----------------------------------------------------------

## Rising sparkle when the Necromancer harvests a graft.
static func pickup_sparkle(parent: Node, pos: Vector2, color: Color) -> void:
	_emit(parent, pos, color, 10, 70.0, 0.6, 2.8, Vector2.UP, 40.0, Vector2(0, -110))

## Red-warm motes over minions mended by Transfusion (GDD 4.3).
static func heal_motes(parent: Node, pos: Vector2) -> void:
	_emit(parent, pos, Color(0.95, 0.35, 0.4), 8, 45.0, 0.7, 2.8, Vector2.UP, 45.0, Vector2(0, -80))
