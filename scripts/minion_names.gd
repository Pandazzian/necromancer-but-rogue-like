extends Node
## Autoload that mints random placeholder names for raised minions, themed for
## the shambling undead. Access as `Names.random_name()`. Names are deliberately
## disposable-but-memorable so the player can tell one skeleton from another (and
## avoid marching a beloved minion into a meat grinder).

const FIRST: PackedStringArray = [
	"Grimble", "Mortis", "Bonewick", "Cadwyn", "Ashen", "Grethel", "Vex",
	"Marrow", "Pallid", "Sallow", "Grave", "Dross", "Rictus", "Wither",
	"Osric", "Bleak", "Corvin", "Dregg", "Ebon", "Fester", "Gaunt",
	"Hollow", "Ives", "Knell", "Loam", "Mabel", "Nettle", "Ondrick",
	"Pyre", "Quill", "Rue", "Sorrel", "Tibbs", "Umber", "Vesper", "Wick",
]

const EPITHET: PackedStringArray = [
	"the Pale", "the Unlucky", "the Twice-Dead", "the Slow", "the Gnawed",
	"the Loyal", "the Forgotten", "the Brittle", "the Grim", "the Patient",
]

## A single themed name, sometimes with a flavour epithet for extra distinctness.
func random_name() -> String:
	var base: String = FIRST[randi() % FIRST.size()]
	if randf() < 0.4:
		return "%s %s" % [base, EPITHET[randi() % EPITHET.size()]]
	return base
