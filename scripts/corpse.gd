extends Node2D
## A defeated enemy's remains (GDD 3.2 "Corpse State"). Persists until the
## Necromancer raises it with Soul Bind (or the room is left behind). Rendered
## as a bone-pile sprite tinted toward the dead unit's class colour, so the
## player can decide what to raise at a glance.

## Class id of the enemy that died here; Soul Bind raises a minion of this class.
var source_class: String = "warrior"
## The enemy's class colour, used (dulled) to tint the remains.
var source_color: Color = Color(0.6, 0.6, 0.6)
## Elite remains demand a Soul Jar charge to capture (GDD 3.2).
var source_elite: bool = false
## Tier of the minion this corpse raises into (elites 2, bosses 3).
var source_tier: int = 1

var _t: float = 0.0
var _sprite: Sprite2D = null

func _ready() -> void:
	add_to_group("corpses")
	var tex: Texture2D = load("res://assets/sprites/corpse.svg")
	if tex != null:
		_sprite = Sprite2D.new()
		_sprite.texture = tex
		_sprite.scale = Vector2(0.62, 0.62)  # ~40px of remains
		_sprite.position = Vector2(0.0, -4.0)
		# Dull wash of the class colour: hue stays legible, corpse reads as dead.
		_sprite.modulate = Color.WHITE.lerp(source_color, 0.45).darkened(0.12)
		add_child(_sprite)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if _sprite == null:
		# Fallback if the sprite failed to load: the old dulled disc.
		var dull: Color = source_color.lerp(Color(0.32, 0.32, 0.34), 0.4).darkened(0.15)
		dull.a = 0.9
		draw_circle(Vector2.ZERO, 12.0, dull)
	# Gentle pulsing ring in the full class colour hints it can be raised.
	var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
	var ring := Color(source_color.r, source_color.g, source_color.b, 0.22 + 0.33 * pulse)
	draw_arc(Vector2.ZERO, 15.0 + 2.0 * pulse, 0.0, TAU, 28, ring, 2.0)
	# Elite remains glint gold: worth a Soul Jar.
	if source_elite:
		draw_arc(Vector2.ZERO, 20.0 + 2.0 * pulse, 0.0, TAU, 28, Color(1.0, 0.8, 0.25, 0.5 + 0.3 * pulse), 2.0)
