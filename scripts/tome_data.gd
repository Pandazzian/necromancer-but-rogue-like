class_name TomeData
extends Resource
## One school of necromancy (GDD §4 / 6.1 "TomeData"). Selected at the pedestal
## before each run, it rewrites the Necromancer's passives, Command Aura shape,
## Soul Bind rules and Desperation weapon. Registered id-keyed in the Tomes
## autoload so saves and co-op sync pass ids, not objects.

enum AuraShape { CIRCLE, CONE }
enum DesperationWeapon { FLAIL, SCALPEL, RATS, GRASP, SCYTHE }

@export var id: String = ""
@export var display_name: String = "Tome"
@export_multiline var description: String = ""
@export var color: Color = Color(0.7, 0.8, 1.0)

@export_group("Passives")
## Player HP multiplier (Sanguine Pact doubles it).
@export var hp_mult: float = 1.0
## Absolute Active Party cap; -1 keeps the base cap (Stitcher hard-caps at 2).
@export var party_cap_override: int = -1
## Added to the base party cap (Rotting Ledger +3).
@export var party_cap_add: int = 0
## Extra graft slot on every minion (Stitcher Bio-Engineering).
@export var graft_slot_bonus: int = 0
## Inherited graft amplification on Flesh-Stitching (Stitcher: 1.2).
@export var stitch_amp: float = 1.0
## Minions lose this fraction of Max HP per second (Rotting Rapid Decay).
@export var minion_decay_pct: float = 0.0
## Physical shield that regenerates while standing still (Bone-Carver).
@export var marrow_shield: float = 0.0

@export_group("Aura")
@export var aura_shape: AuraShape = AuraShape.CIRCLE
@export var aura_radius: float = 340.0
## Cone half-angle in radians (Bone-Carver Directional Command).
@export var aura_half_angle: float = 0.9
## Damage reduction for minions inside the aura (Stitcher: 0.3).
@export var aura_damage_reduction: float = 0.0
## Attack speed bonus for minions inside the aura (Bone-Carver: 0.3).
@export var aura_attack_speed: float = 0.0
## Minions dying inside the aura leave a toxic slowing cloud (Rotting).
@export var death_clouds: bool = false
## Active ability: sacrifice HP to heal minions in the aura (Sanguine Transfusion).
@export var has_transfusion: bool = false

@export_group("Soul Bind")
## If true, Soul Bind no longer slows the caster but costs HP (Sanguine).
@export var bind_costs_hp: bool = false
@export var bind_hp_cost_pct: float = 0.1

@export_group("Desperation")
@export var desperation_weapon: DesperationWeapon = DesperationWeapon.FLAIL
