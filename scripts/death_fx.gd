class_name DeathFX
extends Node2D
## One-shot death animation: a ghost copy of the fallen unit's sprite topples
## over, sinks and fades, then frees itself. Purely visual - the real entity is
## queue_free'd instantly so game logic (drops, corpses, roster) never waits.

const DURATION: float = 0.5

var _sprite: Sprite2D = null
var _t: float = 0.0
var _fall_sign: float = 1.0

## Copy `src`'s sprite at its death spot. Safe no-op if it has no sprite.
static func spawn(parent: Node, src: BaseEntity) -> void:
	if parent == null or not is_instance_valid(parent) or src.sprite == null:
		return
	var fx := DeathFX.new()
	fx.position = src.global_position  # FX parents (Actors/Room) sit at the origin
	var ghost := Sprite2D.new()
	ghost.texture = src.sprite.texture
	ghost.scale = src.sprite.scale
	ghost.flip_h = src.sprite.flip_h
	ghost.modulate = src.sprite.modulate
	ghost.position = src.sprite.position
	fx._sprite = ghost
	fx._fall_sign = -1.0 if src.sprite.flip_h else 1.0
	fx.add_child(ghost)
	# Deferred: deaths happen inside physics callbacks.
	parent.call_deferred("add_child", fx)

func _process(delta: float) -> void:
	_t += delta
	var f: float = clampf(_t / DURATION, 0.0, 1.0)
	if _sprite != null:
		_sprite.rotation = _fall_sign * f * 1.35          # keel over
		_sprite.position.y += 26.0 * delta * f            # sink into the ground
		_sprite.scale.y = _sprite.scale.x * (1.0 - 0.35 * f)
		_sprite.modulate.a = 1.0 - f
		_sprite.modulate = _sprite.modulate.darkened(0.9 * delta)
	if _t >= DURATION:
		queue_free()
