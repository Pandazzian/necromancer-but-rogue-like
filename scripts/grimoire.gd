extends Node
## Autoload registry of every GrimoirePage (GDD 5.3), plus helpers that answer
## "is this effect active this run?" from the Profile's equipped loadout.
## Access as `Grimoire.get_page(id)` / `Grimoire.equipped_has("phylactery")`.

var _defs: Dictionary = {}

func _ready() -> void:
	# Survival.
	_add("phylactery", "The Phylactery", 3, 40, "sanguine",
		"+15 Max HP. A splinter of your soul, kept elsewhere.")
	_add("death_defiance", "Death Defiance", 7, 120, "stitcher",
		"Once per run, a killing blow claims a random minion instead of you.")
	# Minion buffs.
	_add("ruthless_command", "Ruthless Command", 3, 50, "bone_carver",
		"Minions have a 15% chance to strike critically for double damage.")
	_add("explosive_decay", "Explosive Decay", 5, 80, "rotting",
		"Minions detonate on death, searing nearby enemies.")
	_add("vampiric_aura", "Vampiric Aura", 5, 80, "sanguine",
		"Minions drink back 20% of the damage they deal.")
	# Crypt mechanics.
	_add("ossuary", "The Ossuary", 4, 60, "stitcher",
		"+2 Crypt reserve slots. More shelves for the sleeping dead.")
	_add("stitching_mastery", "Flesh-Stitching Mastery", 6, 100, "rotting",
		"Every Flesh-Stitch grants the amalgam a random beneficial affix.")

func _add(id: String, name: String, cost: int, unlock: int, affinity: String, desc: String) -> void:
	var p := GrimoirePage.new()
	p.id = id
	p.display_name = name
	p.arcane_cost = cost
	p.unlock_cost = unlock
	p.affinity_tome = affinity
	p.description = desc
	_defs[id] = p

func get_page(id: String) -> GrimoirePage:
	return _defs.get(id, null)

func all_ids() -> Array:
	return _defs.keys()

## Is this page equipped in the current loadout? (Profile owns the loadout.)
func equipped_has(id: String) -> bool:
	return Profile.equipped_pages.has(id)

## Total Arcane Cost of a loadout under a given tome (affinity discounts apply).
func loadout_cost(page_ids: Array, tome_id: String) -> int:
	var total: int = 0
	for pid in page_ids:
		var p: GrimoirePage = _defs.get(pid, null)
		if p != null:
			total += p.cost_with(tome_id)
	return total
