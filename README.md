# Necromancer's Toll — Godot Prototype

A 2D top-down Action/RTS rogue-lite built in **Godot 4.7** from *The Necromancy Tome* GDD.

## What's in this slice (the combat micro-loop, GDD §3)

This is the playable **combat vertical slice** — the novel, risky heart of the game:

- **The Necromancer** — fragile `Player` with WASD movement. Never fights directly.
- **Aura of Command** (GDD 3.1) — a visible radius around the player. Minions only obey inside it.
- **Lethargy penalty** (GDD 3.1) — minions that leave the aura stop, dull, and slowly crumble.
- **RTS control** (GDD 3.1) — left-drag box-select, right-click move/attack, number keys `1-4` for control groups.
- **Soul Bind capture** (GDD 3.2) — defeated enemies leave a decaying corpse; stand next to it and **hold E** to raise it as a new minion. Channeling slows you 80%, exposing you to risk.
- **Desperation Mode** (GDD 3.3) — when your last minion dies while enemies remain, you're locked out of command and get a weak melee flail (`Space`). Kite, kill one enemy, Soul Bind it, recover.
- **Room-by-room progression** (Hades-style) — each room is a walled chamber. Inquisitors spawn on entry; the exit door stays sealed (red) until you clear them, then opens (green). Walk through to load the next room. Enemy count scales per room, and your surviving minions carry over.
- **Unit classes** — Warrior (balanced), Tank (high HP/defense), Archer (long-range projectile), Mage (AoE) — shared by minions **and** enemies, data-driven via `UnitArchetype` resources. Soul-binding an enemy raises a minion of its class.
- **The Crypt & Flesh-Stitching** (GDD 3.4) — captures beyond your active-party cap route into the stored Crypt. Between rooms (after walking through the door) a Crypt screen pauses the game so you can **merge two identical minions (same class + tier) into a Tier+1 version** (bigger, stronger, golden tier-pips) and swap units between the deployed party and the Crypt.

## Controls

| Input | Action |
|-------|--------|
| `WASD` | Move the Necromancer |
| Left-drag | Box-select minions (click empty = deselect) |
| Left-click a minion | Select single minion |
| Right-click | Selected minions Move (ground) or Attack (enemy) |
| `1`–`4` | Recall control group |
| `Ctrl`+`1`–`4` | Assign current selection to a group |
| Hold `E` | Cast Soul Bind on the nearest corpse in range |
| `Space` | Desperation attack (only when you have no minions) |

## Running

Open the project in Godot 4.7 and press **F5**, or from a terminal:

```
"<path>/Godot_v4.7-stable_win64.exe" --path . 
```

The main scene is `scenes/main.tscn`.

## Architecture — GDD (Unity) → Godot mapping

The GDD's §6 tech section is written in Unity terms. Godot equivalents used here:

| GDD / Unity term | Godot equivalent (this project) |
|------------------|----------------------------------|
| `BaseEntity` (abstract) | `scripts/base_entity.gd` — `CharacterBody2D` base with HP/damage/death signals |
| `PlayerController` | `scripts/player.gd` (`Player`) |
| `MinionController` + `NavMeshAgent` | `scripts/minion.gd` — simple steering (no NavMesh yet) |
| `EnemyController` | `scripts/enemy.gd` |
| `RTSCommander` | `scripts/rts_commander.gd` |
| `SphereCollider` Command Aura | distance check vs `Player.aura_radius` |
| `ScriptableObject` (TomeData, MinionData, GraftItem…) | Godot **`Resource`** classes (not yet built — see below) |
| Prefabs | `PackedScene` (`.tscn`) |
| `Vector3` | `Vector2` (top-down 2D) |

## Not yet built (next steps toward the full GDD)

- **Data resources**: `TomeData`, `MinionData`, `GraftItem`, `GrimoirePage` as Godot `Resource`s (GDD 6.1).
- **The 4 Tomes/Classes** (GDD §4) — swap aura shape/rules/desperation per class.
- **Crypt management & Flesh-Stitching/Grafting** (GDD 3.4–3.5) — between-room surgery UI.
- **Meta hub**: the Graveyard, Prestige, the Draft, Grimoire loadout & Arcane Capacity (GDD §5).
- **Save/Load** (`PlayerProfileManager` singleton, GDD 6.2).
- **Soul Jars / Elite captures, Grafts as battlefield loot.**
