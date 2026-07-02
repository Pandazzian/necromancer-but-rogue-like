class_name MinionInstance
extends RefCounted
## The persistent data of one specific minion (GDD 6.1 "MinionInstance").
## Lives in the Crypt roster; a field Minion node is spawned from it each room.
## (Future: AppliedAffixes and EquippedGrafts live here too.)

var class_id: String = "warrior"
var tier: int = 1

func _init(cid: String = "warrior", t: int = 1) -> void:
	class_id = cid
	tier = t

## Two instances can be Flesh-Stitched only if same class and same tier.
func can_stitch_with(other: MinionInstance) -> bool:
	return other != null and other != self \
		and class_id == other.class_id and tier == other.tier
