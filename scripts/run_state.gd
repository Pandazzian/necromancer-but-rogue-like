extends Node
## Autoload bridge between the Graveyard hub and a run. The hub fills it during
## the Preparation Phase (GDD 2.B): drafted starting minions, the chosen Tome,
## and a snapshot of the equipped Grimoire loadout. Main consumes it on run
## start; the run writes its rewards back here so the hub can bank them.

## MinionInstances drafted from the graveyard wanderers (free rewards, GDD 5.1).
var drafted: Array = []
## The Tome carried this run (id into the Tomes registry).
var tome_id: String = ""
## Equipped page ids, snapshotted at the gate so mid-run hub edits can't cheat.
var pages: Array = []

## Rewards accumulated during the current run (banked on death).
var run_essence: int = 0
var run_xp: int = 0
var rooms_cleared: int = 0
## Soul Jar charges (GDD 3.2): needed to capture Elite corpses. Bosses drop one.
var soul_jars: int = 1

## The active tome for this run (safe default when launching main.tscn directly).
func tome() -> TomeData:
	return Tomes.get_or_default(tome_id)

## Is a grimoire page active this run?
func page_active(id: String) -> bool:
	return pages.has(id)

## Called by the hub gate: snapshot the loadout and zero the run counters.
func begin_run() -> void:
	tome_id = Profile.selected_tome
	pages = Profile.equipped_pages.duplicate()
	run_essence = 0
	run_xp = 0
	rooms_cleared = 0
	soul_jars = 1

## Called by Main when the Necromancer falls: bank rewards into the Profile.
func end_run() -> void:
	Profile.add_essence(run_essence)
	Profile.add_xp(run_xp)
	drafted.clear()

## Take the drafted party (or a default trio when none were drafted / F6 launch).
func take_drafted_party() -> Array:
	var out: Array = drafted.duplicate()
	drafted.clear()
	if out.is_empty():
		for cid in ["warrior", "archer", "tank"]:
			out.append(MinionInstance.create(cid))
	return out
