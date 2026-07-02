extends Node
## Autoload roster for a run (GDD 3.4 / 6.2 "CryptManager").
## `party` = the active minions deployed each room. `reserve` = the stored Crypt.
## Captured minions route to the party if there's room, else into the Crypt.

var party: Array[MinionInstance] = []
var reserve: Array[MinionInstance] = []

@export var party_cap: int = 5    # Active Party limit (GDD 4)
@export var reserve_cap: int = 12  # Crypt slots (GDD: expandable via the Ossuary)

func reset_run() -> void:
	party.clear()
	reserve.clear()

func add_to_party(cid: String, tier: int = 1) -> MinionInstance:
	var inst := MinionInstance.new(cid, tier)
	party.append(inst)
	return inst

## Route a fresh capture (GDD 3.2). Returns the destination:
## "party" (with the instance in `inst`), "crypt", or "full".
func capture(cid: String) -> Dictionary:
	var inst := MinionInstance.new(cid, 1)
	if party.size() < party_cap:
		party.append(inst)
		return {"inst": inst, "dest": "party"}
	elif reserve.size() < reserve_cap:
		reserve.append(inst)
		return {"inst": inst, "dest": "crypt"}
	return {"inst": null, "dest": "full"}

func remove(inst: MinionInstance) -> void:
	party.erase(inst)
	reserve.erase(inst)

# --- Crypt management (between rooms) --------------------------------------

func can_deploy() -> bool:
	return party.size() < party_cap

func deploy(inst: MinionInstance) -> bool:
	if reserve.has(inst) and can_deploy():
		reserve.erase(inst)
		party.append(inst)
		return true
	return false

func store(inst: MinionInstance) -> bool:
	if party.has(inst) and reserve.size() < reserve_cap:
		party.erase(inst)
		reserve.append(inst)
		return true
	return false

## Find any other roster member this one can Flesh-Stitch with.
func find_stitch_partner(inst: MinionInstance) -> MinionInstance:
	for other in party + reserve:
		if inst.can_stitch_with(other):
			return other
	return null

## Merge two identical-tier minions into one of Tier+1 (goes to the Crypt).
func stitch(a: MinionInstance, b: MinionInstance) -> MinionInstance:
	if not a.can_stitch_with(b):
		return null
	remove(a)
	remove(b)
	var merged := MinionInstance.new(a.class_id, a.tier + 1)
	reserve.append(merged)
	return merged
