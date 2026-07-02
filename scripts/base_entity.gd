class_name BaseEntity
extends CharacterBody2D
## Shared base for the Necromancer, minions and enemies.
## Owns HP, damage handling and death events (GDD 6.2 "BaseEntity (Abstract)").

signal died(entity: BaseEntity)
signal health_changed(current: float, maximum: float)

@export var max_hp: float = 100.0
## Radius of this actor's body, used for drawing and melee range checks.
@export var body_radius: float = 16.0
@export var body_color: Color = Color.WHITE

var current_hp: float
var is_dead: bool = false

func _ready() -> void:
	current_hp = max_hp

func take_damage(amount: float, _source: Node = null) -> void:
	if is_dead:
		return
	current_hp = maxf(0.0, current_hp - amount)
	health_changed.emit(current_hp, max_hp)
	if current_hp <= 0.0:
		die()

func heal(amount: float) -> void:
	if is_dead:
		return
	current_hp = minf(max_hp, current_hp + amount)
	health_changed.emit(current_hp, max_hp)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit(self)
	_on_death()

## Subclasses override to add drops, effects, etc. Default: despawn.
func _on_death() -> void:
	queue_free()

## Helper for subclasses: draw the body circle + a small HP bar in _draw().
func _draw_body_and_health() -> void:
	draw_circle(Vector2.ZERO, body_radius, body_color)
	draw_arc(Vector2.ZERO, body_radius, 0.0, TAU, 24, body_color.darkened(0.4), 2.0)
	if current_hp < max_hp and not is_dead:
		var w: float = body_radius * 2.0
		var y: float = -body_radius - 10.0
		var frac: float = clampf(current_hp / max_hp, 0.0, 1.0)
		draw_rect(Rect2(-body_radius, y, w, 4.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-body_radius, y, w * frac, 4.0), Color(0.3, 0.9, 0.3))
