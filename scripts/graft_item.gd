class_name GraftItem
extends Resource
## A harvested body part (GDD 3.5 Flesh-Grafting). Applied to a MinionInstance to
## permanently augment it - and lost forever if that minion dies. Identified by a
## stable `id` so drops, saves, and co-op network sync all reference the id rather
## than an object pointer.

enum Category { LIMB, ORGAN, CARAPACE }

@export var id: String = ""
@export var display_name: String = "Graft"
@export var category: Category = Category.LIMB
@export_multiline var description: String = ""
@export var color: Color = Color(0.8, 0.5, 0.9)

## Flat / multiplicative modifiers applied to the host minion.
@export_group("Modifiers")
@export var bonus_hp: float = 0.0
@export var bonus_damage: float = 0.0
@export var bonus_defense: float = 0.0
@export var attack_speed_mult: float = 1.0  ## < 1.0 = faster attacks
@export var move_speed_mult: float = 1.0

func category_name() -> String:
	return ["Limb", "Organ", "Carapace"][category]

## One-line effect summary for tooltips/lists.
func effect_text() -> String:
	var parts: PackedStringArray = []
	if bonus_hp != 0.0:
		parts.append("+%d HP" % roundi(bonus_hp))
	if bonus_damage != 0.0:
		parts.append("+%d DMG" % roundi(bonus_damage))
	if bonus_defense != 0.0:
		parts.append("+%d DEF" % roundi(bonus_defense))
	if attack_speed_mult != 1.0:
		parts.append("%d%% atk speed" % roundi((1.0 / attack_speed_mult - 1.0) * 100.0))
	if move_speed_mult != 1.0:
		parts.append("%+d%% move" % roundi((move_speed_mult - 1.0) * 100.0))
	return ", ".join(parts) if parts.size() > 0 else "No effect"
