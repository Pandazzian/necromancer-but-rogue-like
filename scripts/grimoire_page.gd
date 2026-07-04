class_name GrimoirePage
extends Resource
## One page of the Grimoire (GDD 5.2/5.3 "GrimoirePage"). Pages are permanently
## unlocked with Soul Essence, then equipped in the hub within the player's
## Arcane Capacity. Effects are read by Player / Minion / Inventory at run time
## via `Grimoire.equipped_has(id)` rather than callbacks, keeping them data-only.

@export var id: String = ""
@export var display_name: String = "Page"
@export_multiline var description: String = ""
## Total equipped cost may not exceed Arcane Capacity.
@export var arcane_cost: int = 3
## One-time Soul Essence price to unlock permanently.
@export var unlock_cost: int = 40
## Matching this Tome reduces the Arcane Cost by 1 (GDD "Tome Affinity").
@export var affinity_tome: String = ""

## Effective cost given the selected tome (never below 1).
func cost_with(tome_id: String) -> int:
	if affinity_tome != "" and affinity_tome == tome_id:
		return maxi(1, arcane_cost - 1)
	return arcane_cost
