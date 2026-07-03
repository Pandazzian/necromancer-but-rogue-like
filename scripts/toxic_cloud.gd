class_name ToxicCloud
extends Node2D
## A miasma left where a Rotting Ledger minion died inside the aura (GDD 4.2).
## Enemies caught in it are slowed and gently dissolved for the cloud's lifetime.

var radius: float = 85.0
var duration: float = 4.0
var dps: float = 4.0

var _age: float = 0.0

static func spawn(parent: Node, pos: Vector2) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var c := ToxicCloud.new()
	c.global_position = pos
	parent.add_child(c)

func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not (e as Enemy).is_dead:
			if global_position.distance_to((e as Enemy).global_position) <= radius:
				(e as Enemy).apply_slow(0.35)
				(e as Enemy).take_true_damage(dps * delta)
	queue_redraw()

func _draw() -> void:
	var fade: float = clampf(1.0 - _age / duration, 0.0, 1.0)
	var wob: float = 4.0 * sin(_age * 2.5)
	draw_circle(Vector2.ZERO, radius + wob, Color(0.5, 0.85, 0.3, 0.10 * fade))
	draw_circle(Vector2.ZERO, radius * 0.6, Color(0.6, 0.9, 0.35, 0.10 * fade))
	draw_arc(Vector2.ZERO, radius + wob, 0.0, TAU, 36, Color(0.6, 0.95, 0.4, 0.35 * fade), 1.5)
