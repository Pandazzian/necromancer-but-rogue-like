extends Node
## Headless self-test for the meta-loop logic (run: godot --headless scenes/dev_selftest.tscn).
## Exercises the pure-data paths a passive soak can't reach: capture routing,
## Flesh-Stitching amplification/affixes, Grimoire costs, Profile persistence.
## Prints SELFTEST OK and quits 0, or fails loudly with a nonzero exit.

var _failures: int = 0

func _ready() -> void:
	# Keep the developer's real profile intact: snapshot, test, restore.
	var snapshot: String = JSON.stringify({
		"xp": Profile.account_xp, "level": Profile.account_level,
		"essence": Profile.soul_essence, "unlocked": Profile.unlocked_pages,
		"equipped": Profile.equipped_pages, "tome": Profile.selected_tome,
		"plots": Profile.plot_levels})

	_test_tomes()
	_test_grimoire()
	_test_profile()
	_test_inventory()
	_test_instances()

	var d: Dictionary = JSON.parse_string(snapshot)
	Profile.account_xp = int(d.xp)
	Profile.account_level = int(d.level)
	Profile.soul_essence = int(d.essence)
	Profile.unlocked_pages = d.unlocked
	Profile.equipped_pages = d.equipped
	Profile.selected_tome = d.tome
	Profile.plot_levels = d.plots
	Profile.save_profile()
	RunState.tome_id = ""
	RunState.pages = []

	if _failures == 0:
		print("SELFTEST OK")
		get_tree().quit(0)
	else:
		print("SELFTEST FAILED: %d assertion(s)" % _failures)
		get_tree().quit(1)

func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		push_error("FAIL: " + what)
		print("FAIL: " + what)

func _test_tomes() -> void:
	_check(Tomes.IDS.size() == 4, "four tomes registered")
	_check(Tomes.get_tome("stitcher").party_cap_override == 2, "stitcher hard-caps party at 2")
	_check(Tomes.get_tome("rotting").party_cap_add == 3, "rotting adds +3 party cap")
	_check(Tomes.get_tome("sanguine").hp_mult == 2.0, "sanguine doubles HP")
	_check(Tomes.get_tome("bone_carver").aura_shape == TomeData.AuraShape.CONE, "bone-carver cone aura")
	_check(Tomes.get_or_default("nonsense").id == "none", "unknown tome falls back to default")

func _test_grimoire() -> void:
	var p: GrimoirePage = Grimoire.get_page("phylactery")
	_check(p != null, "phylactery exists")
	_check(p.cost_with("sanguine") == p.arcane_cost - 1, "tome affinity discounts cost by 1")
	_check(p.cost_with("rotting") == p.arcane_cost, "no discount without affinity")
	_check(Grimoire.loadout_cost(["phylactery", "ossuary"], "sanguine")
		== p.arcane_cost - 1 + Grimoire.get_page("ossuary").arcane_cost, "loadout cost sums with discounts")

func _test_profile() -> void:
	Profile.soul_essence = 50
	_check(Profile.spend_essence(30) and Profile.soul_essence == 20, "essence spends down")
	_check(not Profile.spend_essence(100), "cannot overspend essence")
	Profile.account_level = 1
	Profile.account_xp = 0
	Profile.add_xp(250)  # 100 to reach L2, 200 to reach L3 -> lands mid-L2
	_check(Profile.account_level == 2 and Profile.account_xp == 150, "xp levels up with carryover")
	Profile.plot_levels = {"a": 2, "b": 1}
	_check(Profile.prestige() == 30, "prestige sums plot levels x10")
	Profile.save_profile()
	Profile.soul_essence = 999
	Profile.load_profile()
	_check(Profile.soul_essence == 20, "profile roundtrips through disk")

func _test_inventory() -> void:
	RunState.tome_id = "stitcher"
	RunState.pages = ["stitching_mastery"]
	var inv := Inventory.new()
	inv.party_cap = 2
	inv.reserve_cap = 2
	_check(inv.capture("warrior").dest == "party", "first capture joins party")
	_check(inv.capture("warrior", 2).dest == "party", "second capture joins party")
	_check(inv.party[1].tier == 2, "elite capture raises at tier 2")
	_check(inv.capture("archer").dest == "crypt", "overflow routes to crypt")
	inv.capture("mage")
	_check(inv.capture("tank").dest == "full", "everything full refuses")
	# Stitch the two same-tier warriors... tiers differ (1 and 2), so no partner.
	_check(inv.find_stitch_partner(inv.party[0]) == null, "tier mismatch cannot stitch")
	var w2 := MinionInstance.create("warrior")
	inv.crypt[0] = w2  # replace the archer with a warrior twin for the merge
	var g: GraftItem = Grafts.get_graft("bone_blades")
	inv.party[0].grafts.append(g)
	w2.grafts.append(Grafts.get_graft("mirror_scales"))
	var merged: MinionInstance = inv.stitch(inv.party[0], w2)
	_check(merged != null and merged.tier == 2, "stitch produced a tier 2 amalgam")
	_check(merged.grafts.size() == 2, "amalgam inherited both parents' grafts")
	_check(absf(merged.graft_amp - 1.2) < 0.001, "stitcher amplifies inherited grafts 20%")
	_check(merged.affix_names.size() == 1, "mastery granted a random affix")
	_check(merged.graft_slots() == merged.tier + 1, "stitcher grants +1 graft slot")
	# Graft application respects slots.
	var inv2 := Inventory.new()
	inv2.grafts.append(g)
	var solo := MinionInstance.create("tank")  # tier 1 + stitcher bonus = 2 slots
	_check(inv2.apply_graft(solo, g), "graft applies into a free slot")
	_check(not inv2.apply_graft(solo, g), "graft not in stash refuses")

func _test_instances() -> void:
	RunState.tome_id = ""
	var inst := MinionInstance.create("mage")
	inst.tier = 2
	inst.affix_hp = 20.0
	inst.grafts.append(Grafts.get_graft("gravebound_plate"))
	var back := MinionInstance.from_dict(inst.to_dict())
	_check(back.class_id == "mage" and back.tier == 2, "instance roundtrips class/tier")
	_check(back.affix_hp == 20.0, "instance roundtrips affixes")
	_check(back.grafts.size() == 1 and back.grafts[0].id == "gravebound_plate", "instance roundtrips grafts by id")
	_check(back.hp_bonus() == 50.0, "hp bonus = graft 30 + affix 20")
	_check(Grafts.get_graft("bone_blades").bleed_dps > 0.0, "bone-blades carry bleed")
	_check(Grafts.get_graft("bile_gland").death_explosion > 0.0, "bile gland explodes")
	_check(Grafts.get_graft("mirror_scales").reflect_pct > 0.0, "mirror scales reflect")
