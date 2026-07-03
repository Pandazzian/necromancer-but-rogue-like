class_name MinionInstance
extends Resource
## Persistent per-minion data (GDD 6.1 "MinionInstance"). Unlike the transient
## Minion node, this survives between rooms and carries the unit's identity, tier,
## wounds and grafts. When a minion dies its instance (and any grafts) is lost -
## which is exactly why the player wants to name and protect valuable minions.

## Player-facing name. Random and themed on creation; renamable in the field.
@export var unit_name: String = ""
## Which UnitArchetype (class) this minion is - looked up via Classes.minion(id).
@export var class_id: String = "warrior"
## Merge tier (GDD 3.4 Flesh-Stitching). Base 1; higher = stronger + more graft slots.
@export var tier: int = 1
## HP carried between rooms. -1 means "spawn at full health".
@export var stored_hp: float = -1.0
## Equipped grafts (foundation for GDD 3.5 Flesh-Grafting; unused this slice).
@export var grafts: Array = []

## Build a fresh instance, giving it a random themed name unless one is supplied.
static func create(p_class_id: String, p_name: String = "") -> MinionInstance:
	var inst := MinionInstance.new()
	inst.class_id = p_class_id
	inst.unit_name = p_name if p_name != "" else Names.random_name()
	return inst

## Graft slots available at this tier (GDD 3.5 - grows with Tier). Tomes will
## add to this later; kept here so both the field and the Crypt agree.
func graft_slots() -> int:
	return tier

func used_slots() -> int:
	return grafts.size()

## Two instances can be Flesh-Stitched only if same class and same tier (GDD 3.4).
func can_stitch_with(other: MinionInstance) -> bool:
	return other != null and other != self \
		and class_id == other.class_id and tier == other.tier

# --- Aggregate graft modifiers (read by the Minion node for its live stats) ---

func hp_bonus() -> float:
	var s: float = 0.0
	for g in grafts:
		s += g.bonus_hp
	return s

func damage_bonus() -> float:
	var s: float = 0.0
	for g in grafts:
		s += g.bonus_damage
	return s

func defense_bonus() -> float:
	var s: float = 0.0
	for g in grafts:
		s += g.bonus_defense
	return s

func attack_speed_mult() -> float:
	var m: float = 1.0
	for g in grafts:
		m *= g.attack_speed_mult
	return m

func move_speed_mult() -> float:
	var m: float = 1.0
	for g in grafts:
		m *= g.move_speed_mult
	return m

# --- Serialization (save / co-op sync foundation) --------------------------

func to_dict() -> Dictionary:
	var graft_ids: Array = []
	for g in grafts:
		graft_ids.append(g.id)
	return {
		"name": unit_name,
		"class": class_id,
		"tier": tier,
		"hp": stored_hp,
		"grafts": graft_ids,
	}

static func from_dict(d: Dictionary) -> MinionInstance:
	var inst := MinionInstance.new()
	inst.unit_name = d.get("name", "")
	inst.class_id = d.get("class", "warrior")
	inst.tier = int(d.get("tier", 1))
	inst.stored_hp = d.get("hp", -1.0)
	for gid in d.get("grafts", []):
		var g: GraftItem = Grafts.get_graft(gid)
		if g != null:
			inst.grafts.append(g)
	return inst
