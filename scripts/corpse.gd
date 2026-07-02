extends Node2D
## A defeated enemy's remains (GDD 3.2 "Corpse State"). Persists until the
## Necromancer raises it with Soul Bind (or the room is left behind). Keeps the
## dead unit's class colour, dulled, so the player can decide what to raise.

## Class id of the enemy that died here; Soul Bind raises a minion of this class.
var source_class: String = "warrior"
## The enemy's class colour, used (dulled) to render the corpse.
var source_color: Color = Color(0.6, 0.6, 0.6)

var _t: float = 0.0

func _ready() -> void:
	add_to_group("corpses")

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	# Dulled body: desaturated + darkened but hue preserved, so classes stay legible.
	var dull: Color = source_color.lerp(Color(0.32, 0.32, 0.34), 0.4).darkened(0.15)
	dull.a = 0.9
	draw_circle(Vector2.ZERO, 12.0, dull)
	# Slain marker.
	var arm: float = 5.5
	draw_line(Vector2(-arm, -arm), Vector2(arm, arm), Color(0, 0, 0, 0.5), 2.0)
	draw_line(Vector2(-arm, arm), Vector2(arm, -arm), Color(0, 0, 0, 0.5), 2.0)
	# Gentle pulsing ring in the full class colour hints it can be raised.
	var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
	var ring := Color(source_color.r, source_color.g, source_color.b, 0.22 + 0.33 * pulse)
	draw_arc(Vector2.ZERO, 15.0 + 2.0 * pulse, 0.0, TAU, 28, ring, 2.0)
