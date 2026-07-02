class_name UnitArchetype
extends Resource
## Data for one unit class (GDD 6.1 "MinionData"). Shared by minions and enemies;
## the same four classes exist on both sides, differing only by faction/colour.

enum AttackType {
	MELEE,  ## Direct damage in melee range.
	RANGED, ## Fires a single-target projectile.
	AOE,    ## Fires a projectile that explodes for area damage.
}

@export var id: String = "warrior"
@export var display_name: String = "Warrior"
@export var color: Color = Color.WHITE
@export var body_radius: float = 13.0

@export_group("Stats")
@export var max_hp: float = 55.0
@export var defense: float = 0.0  ## Flat damage reduction per hit.
@export var move_speed: float = 200.0

@export_group("Attack")
@export var attack_damage: float = 9.0
@export var attack_range: float = 42.0
@export var attack_cooldown: float = 0.8
@export var attack_type: AttackType = AttackType.MELEE
@export var projectile_speed: float = 480.0
@export var aoe_radius: float = 0.0  ## Only used by AOE attacks.
