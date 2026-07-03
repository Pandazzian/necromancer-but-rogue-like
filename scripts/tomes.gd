extends Node
## Autoload registry of the four Tomes of Power (GDD §4), mirroring Classes and
## Grafts. Built in code, keyed by stable id. Access as `Tomes.get_tome(id)`.

var _defs: Dictionary = {}

const IDS: Array[String] = ["stitcher", "rotting", "sanguine", "bone_carver"]

func _ready() -> void:
	var t: TomeData

	# 4.1 The Stitcher's Almanac - quality over quantity super-mutants.
	t = TomeData.new()
	t.id = "stitcher"
	t.display_name = "The Stitcher's Almanac"
	t.description = "Party capped at 2, but minions gain +1 graft slot and stitched grafts are amplified 20%. Small aura shields minions (30% less damage). Desperation: a scalpel that marks foes to take 3x damage from your next minion."
	t.color = Color(0.55, 0.95, 0.75)
	t.party_cap_override = 2
	t.graft_slot_bonus = 1
	t.stitch_amp = 1.2
	t.aura_radius = 220.0
	t.aura_damage_reduction = 0.3
	t.desperation_weapon = TomeData.DesperationWeapon.SCALPEL
	_defs[t.id] = t

	# 4.2 The Rotting Ledger - frantic, disposable swarm.
	t = TomeData.new()
	t.id = "rotting"
	t.display_name = "The Rotting Ledger"
	t.description = "Party cap +3, but every minion rots (loses Max HP each second). Massive aura; minions dying inside it leave a toxic slowing cloud. Desperation: hurl corpse-rats that gnaw and stun."
	t.color = Color(0.65, 0.85, 0.35)
	t.party_cap_add = 3
	t.minion_decay_pct = 0.012
	t.aura_radius = 520.0
	t.death_clouds = true
	t.desperation_weapon = TomeData.DesperationWeapon.RATS
	_defs[t.id] = t

	# 4.3 The Sanguine Pact - blood-fuelled support caster.
	t = TomeData.new()
	t.id = "sanguine"
	t.display_name = "The Sanguine Pact"
	t.description = "Double HP. Soul Bind never slows you - it costs 10% of your current blood instead. Press Q to transfuse: sacrifice 5% HP to heal every minion in the aura 20%. Desperation: a rooted tether that siphons life."
	t.color = Color(0.9, 0.35, 0.4)
	t.hp_mult = 2.0
	t.bind_costs_hp = true
	t.has_transfusion = true
	t.desperation_weapon = TomeData.DesperationWeapon.GRASP
	_defs[t.id] = t

	# 4.4 The Bone-Carver's Codex - vanguard leading from the front.
	t = TomeData.new()
	t.id = "bone_carver"
	t.display_name = "The Bone-Carver's Codex"
	t.description = "A marrow shield regenerates while you stand still. The aura is a wide cone toward your cursor; minions inside swing 30% faster. Desperation: a huge spectral scythe with brutal knockback."
	t.color = Color(0.85, 0.8, 0.6)
	t.marrow_shield = 26.0
	t.aura_shape = TomeData.AuraShape.CONE
	t.aura_radius = 430.0
	t.aura_half_angle = 0.85
	t.aura_attack_speed = 0.3
	t.desperation_weapon = TomeData.DesperationWeapon.SCYTHE
	_defs[t.id] = t

func get_tome(id: String) -> TomeData:
	return _defs.get(id, null)

## Fallback-safe accessor: unknown ids get a plain default Tome (base rules).
func get_or_default(id: String) -> TomeData:
	var t: TomeData = _defs.get(id, null)
	if t == null:
		t = TomeData.new()
		t.id = "none"
		t.display_name = "Unbound Practice"
		t.description = "The subtle arts, unshaped by any Tome."
	return t
