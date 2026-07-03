extends Node
## Autoload save/load singleton (GDD 6.2 "PlayerProfileManager"). Owns everything
## that outlives a run: Account EXP/Level, Soul Essence, unlocked Grimoire pages,
## the equipped loadout, selected Tome, and Graveyard plot levels. Persists as
## JSON in user:// and saves eagerly after every mutation - a run can end (or
## crash) at any moment and the macabre real estate must survive.

const SAVE_PATH: String = "user://profile.json"
## EXP needed to go from level n to n+1.
const XP_PER_LEVEL: int = 100

signal essence_changed(total: int)

var account_xp: int = 0
var account_level: int = 1
var soul_essence: int = 0
var unlocked_pages: Array = []   # GrimoirePage ids owned forever
var equipped_pages: Array = []   # ids equipped for the next run
var selected_tome: String = "bone_carver"
## Plot id -> level (0 = ruined). Drives Graveyard Prestige (GDD 5.1).
var plot_levels: Dictionary = {}

func _ready() -> void:
	load_profile()

# --- Derived values ---------------------------------------------------------

## Total Arcane Capacity (GDD 5.2): grows with account level.
func arcane_capacity() -> int:
	return 8 + 2 * (account_level - 1)

## Graveyard Prestige: cumulative score of all plots (GDD 5.1).
func prestige() -> int:
	var total: int = 0
	for k in plot_levels:
		total += int(plot_levels[k]) * 10
	return total

# --- Mutations (each saves immediately) --------------------------------------

func add_essence(amount: int) -> void:
	soul_essence += amount
	essence_changed.emit(soul_essence)
	save_profile()

## Spend essence if affordable. Returns success.
func spend_essence(amount: int) -> bool:
	if soul_essence < amount:
		return false
	soul_essence -= amount
	essence_changed.emit(soul_essence)
	save_profile()
	return true

## Grant run EXP; levels up as thresholds pass (capacity grows with level).
func add_xp(amount: int) -> void:
	account_xp += amount
	while account_xp >= account_level * XP_PER_LEVEL:
		account_xp -= account_level * XP_PER_LEVEL
		account_level += 1
	save_profile()

func unlock_page(id: String) -> void:
	if not unlocked_pages.has(id):
		unlocked_pages.append(id)
		save_profile()

func set_equipped_pages(ids: Array) -> void:
	equipped_pages = ids.duplicate()
	save_profile()

func set_tome(id: String) -> void:
	selected_tome = id
	save_profile()

func set_plot_level(id: String, level: int) -> void:
	plot_levels[id] = level
	save_profile()

func plot_level(id: String) -> int:
	return int(plot_levels.get(id, 0))

# --- Persistence -------------------------------------------------------------

func save_profile() -> void:
	var data: Dictionary = {
		"xp": account_xp,
		"level": account_level,
		"essence": soul_essence,
		"unlocked_pages": unlocked_pages,
		"equipped_pages": equipped_pages,
		"tome": selected_tome,
		"plots": plot_levels,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))

func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return
	var d: Dictionary = parsed
	account_xp = int(d.get("xp", 0))
	account_level = int(d.get("level", 1))
	soul_essence = int(d.get("essence", 0))
	unlocked_pages = d.get("unlocked_pages", [])
	equipped_pages = d.get("equipped_pages", [])
	selected_tome = d.get("tome", "bone_carver")
	plot_levels = d.get("plots", {})
