extends Node
## Autoload registry of unit classes. Access as `Classes.minion("archer")`,
## `Classes.enemy(id)`, or `Classes.random_enemy_id()`.

const MINION: Dictionary = {
	"warrior": preload("res://resources/archetypes/minion_warrior.tres"),
	"tank": preload("res://resources/archetypes/minion_tank.tres"),
	"archer": preload("res://resources/archetypes/minion_archer.tres"),
	"mage": preload("res://resources/archetypes/minion_mage.tres"),
}

const ENEMY: Dictionary = {
	"warrior": preload("res://resources/archetypes/enemy_warrior.tres"),
	"tank": preload("res://resources/archetypes/enemy_tank.tres"),
	"archer": preload("res://resources/archetypes/enemy_archer.tres"),
	"mage": preload("res://resources/archetypes/enemy_mage.tres"),
}

const IDS: Array[String] = ["warrior", "tank", "archer", "mage"]

func minion(id: String) -> UnitArchetype:
	return MINION.get(id, MINION["warrior"])

func enemy(id: String) -> UnitArchetype:
	return ENEMY.get(id, ENEMY["warrior"])

## Weighted pick for wave composition: mostly warriors, some ranged, few tanks.
func random_enemy_id() -> String:
	var r: float = randf()
	if r < 0.45:
		return "warrior"
	elif r < 0.70:
		return "archer"
	elif r < 0.85:
		return "mage"
	else:
		return "tank"
