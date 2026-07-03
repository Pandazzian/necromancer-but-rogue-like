class_name GraftPickup
extends Node2D
## A harvested body part lying on the battlefield (GDD 3.5 "physical items"). A
## Necromancer walks over it to collect it into their own inventory. Rendered as a
## small floating gem tinted with the graft's colour.

## The graft this pickup grants when collected.
var graft: GraftItem = null

var _t: float = 0.0

func _ready() -> void:
	add_to_group("graft_pickups")

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if graft == null:
		return
	var bob: float = sin(_t * 3.0) * 2.0
	var c: Vector2 = Vector2(0.0, bob)
	# Glow halo.
	draw_circle(c, 11.0, Color(graft.color.r, graft.color.g, graft.color.b, 0.18))
	# Gem: a small diamond.
	var r: float = 6.0
	var pts: PackedVector2Array = [
		c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]
	draw_colored_polygon(pts, graft.color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.7), 1.0)
