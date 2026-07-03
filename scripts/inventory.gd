class_name Inventory
extends Resource
## One necromancer's belongings (GDD 3.4/6.2 "CryptManager"). Per-player and
## owner-tagged so co-op can sync each player's own stash independently. Holds the
## graft stash plus the minion roster (active party + stored crypt). Kept as plain
## serializable data - `to_dict()/from_dict()` make it network- and save-ready,
## though no netcode is wired yet.

## Fired whenever contents change, so UI can rebuild.
signal inventory_changed

## Which peer owns this inventory (1 = host/local in single-player).
@export var owner_peer_id: int = 1
## Harvested grafts not yet applied to a minion.
@export var grafts: Array[GraftItem] = []
## MinionInstances currently spawned on the field.
@export var party: Array[MinionInstance] = []
## MinionInstances in reserve (overflow captures / benched units).
@export var crypt: Array[MinionInstance] = []

## Active Party limit (GDD 4). Crypt reserve limit (GDD: expandable via Ossuary).
@export var party_cap: int = 5
@export var reserve_cap: int = 12

# --- Grafts ----------------------------------------------------------------

func add_graft(g: GraftItem) -> void:
	if g == null:
		return
	grafts.append(g)
	inventory_changed.emit()

## Move a stash graft onto a minion, respecting its tier's slot limit.
## Returns true on success. This is the core "Flesh-Grafting" operation.
func apply_graft(inst: MinionInstance, g: GraftItem) -> bool:
	if inst == null or g == null:
		return false
	if not grafts.has(g):
		return false
	if inst.used_slots() >= inst.graft_slots():
		return false
	grafts.erase(g)
	inst.grafts.append(g)
	inventory_changed.emit()
	return true

# --- Roster ----------------------------------------------------------------

func add_to_party(inst: MinionInstance) -> void:
	if inst != null and not party.has(inst):
		party.append(inst)
		inventory_changed.emit()

func remove_from_party(inst: MinionInstance) -> void:
	if party.has(inst):
		party.erase(inst)
		inventory_changed.emit()

## Drop a dead/lost minion from the roster entirely (its grafts die with it).
func remove(inst: MinionInstance) -> void:
	var changed: bool = party.has(inst) or crypt.has(inst)
	party.erase(inst)
	crypt.erase(inst)
	if changed:
		inventory_changed.emit()

func reset_run() -> void:
	party.clear()
	crypt.clear()
	grafts.clear()
	inventory_changed.emit()

## Route a fresh capture (GDD 3.2): a new minion of `cid` joins the active party
## if there's room, else the Crypt, else it's turned away. Returns {inst, dest}
## where dest is "party", "crypt", or "full".
func capture(cid: String) -> Dictionary:
	var inst := MinionInstance.create(cid)
	if party.size() < party_cap:
		party.append(inst)
		inventory_changed.emit()
		return {"inst": inst, "dest": "party"}
	elif crypt.size() < reserve_cap:
		crypt.append(inst)
		inventory_changed.emit()
		return {"inst": inst, "dest": "crypt"}
	return {"inst": null, "dest": "full"}

# --- Crypt management (between rooms) --------------------------------------

func can_deploy() -> bool:
	return party.size() < party_cap

## Move a reserve minion into the active party.
func deploy(inst: MinionInstance) -> bool:
	if crypt.has(inst) and can_deploy():
		crypt.erase(inst)
		party.append(inst)
		inventory_changed.emit()
		return true
	return false

## Bench an active minion into the Crypt reserve.
func store(inst: MinionInstance) -> bool:
	if party.has(inst) and crypt.size() < reserve_cap:
		party.erase(inst)
		crypt.append(inst)
		inventory_changed.emit()
		return true
	return false

## Find any other roster member this one can Flesh-Stitch with.
func find_stitch_partner(inst: MinionInstance) -> MinionInstance:
	for other in party + crypt:
		if inst.can_stitch_with(other):
			return other
	return null

## Merge two same-class/same-tier minions into one of Tier+1 (into the Crypt).
## The amalgam inherits the grafts of BOTH parents (GDD 3.5 stitching synergy).
func stitch(a: MinionInstance, b: MinionInstance) -> MinionInstance:
	if not a.can_stitch_with(b):
		return null
	var merged := MinionInstance.create(a.class_id)
	merged.tier = a.tier + 1
	merged.grafts = a.grafts.duplicate() + b.grafts.duplicate()
	remove(a)  # emits
	remove(b)
	crypt.append(merged)
	inventory_changed.emit()
	return merged

# --- Serialization (save / co-op sync foundation) --------------------------

func to_dict() -> Dictionary:
	var graft_ids: Array = []
	for g in grafts:
		graft_ids.append(g.id)
	var party_data: Array = []
	for m in party:
		party_data.append(m.to_dict())
	var crypt_data: Array = []
	for m in crypt:
		crypt_data.append(m.to_dict())
	return {
		"owner": owner_peer_id,
		"grafts": graft_ids,
		"party": party_data,
		"crypt": crypt_data,
	}

static func from_dict(d: Dictionary) -> Inventory:
	var inv := Inventory.new()
	inv.owner_peer_id = int(d.get("owner", 1))
	for gid in d.get("grafts", []):
		var g: GraftItem = Grafts.get_graft(gid)
		if g != null:
			inv.grafts.append(g)
	for md in d.get("party", []):
		inv.party.append(MinionInstance.from_dict(md))
	for md in d.get("crypt", []):
		inv.crypt.append(MinionInstance.from_dict(md))
	return inv
