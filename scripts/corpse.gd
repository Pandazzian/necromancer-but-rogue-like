extends Node2D
## A defeated enemy's remains. Exists for a few seconds (GDD 3.2 "Corpse State")
## before decaying. The Necromancer casts Soul Bind on it to raise a new minion.

@export var decay_time: float = 6.0

var _time_left: float

func _ready() -> void:
	_time_left = decay_time
	add_to_group("corpses")

func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var frac: float = clampf(_time_left / decay_time, 0.0, 1.0)
	var col := Color(0.55, 0.55, 0.6, 0.4 + 0.5 * frac)
	draw_circle(Vector2.ZERO, 12.0, col)
	# Decay timer ring - shrinks as the corpse rots away.
	draw_arc(Vector2.ZERO, 16.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 24, Color(0.7, 0.7, 0.8, 0.7), 2.0)
