extends Node
## Autoload registry of every GraftItem definition (GDD 3.5), mirroring how
## `Classes` registers unit archetypes. Grafts are built in code and keyed by a
## stable id so drops, saves and future co-op sync all pass ids, not objects.
## Access as `Grafts.get_graft("bone_blades")` or `Grafts.random_drop()`.

var _defs: Dictionary = {}  # id -> GraftItem

func _ready() -> void:
	_add("bone_blades", "Serrated Bone-Blades", GraftItem.Category.LIMB,
		Color(0.9, 0.85, 0.7), "Jagged limbs that carve deeper.", {"dmg": 5.0})
	_add("iron_sinew", "Iron Sinew", GraftItem.Category.LIMB,
		Color(0.7, 0.75, 0.85), "Wound-tight muscle; strikes come faster.", {"atk": 0.8})
	_add("bile_gland", "Volatile Bile Gland", GraftItem.Category.ORGAN,
		Color(0.6, 0.9, 0.4), "A swollen organ that fuels furious effort.", {"dmg": 3.0, "atk": 0.9})
	_add("swift_tendon", "Swiftrot Tendon", GraftItem.Category.ORGAN,
		Color(0.5, 0.8, 0.9), "Twitching tendons quicken the dead.", {"move": 1.25})
	_add("mirror_scales", "Mirror-Glass Scales", GraftItem.Category.CARAPACE,
		Color(0.85, 0.8, 0.95), "Glassy plating that turns aside blows.", {"def": 3.0})
	_add("gravebound_plate", "Gravebound Plate", GraftItem.Category.CARAPACE,
		Color(0.7, 0.6, 0.5), "Slabs of coffin-iron. Heavy, but hard to fell.", {"hp": 30.0, "move": 0.9})

func _add(id: String, name: String, cat: int, col: Color, desc: String, mods: Dictionary) -> void:
	var g := GraftItem.new()
	g.id = id
	g.display_name = name
	g.category = cat
	g.color = col
	g.description = desc
	g.bonus_hp = mods.get("hp", 0.0)
	g.bonus_damage = mods.get("dmg", 0.0)
	g.bonus_defense = mods.get("def", 0.0)
	g.attack_speed_mult = mods.get("atk", 1.0)
	g.move_speed_mult = mods.get("move", 1.0)
	_defs[id] = g

func get_graft(id: String) -> GraftItem:
	return _defs.get(id, null)

func all_ids() -> Array:
	return _defs.keys()

## A random graft definition - what an enemy drops on death.
func random_drop() -> GraftItem:
	var ids: Array = _defs.keys()
	return _defs[ids[randi() % ids.size()]]
