# Necromancer's Toll — Godot Prototype

A 2D top-down Action/RTS rogue-lite built in **Godot 4.7** from *The Necromancy Tome* GDD.
The full loop is in: **Graveyard hub → draft & loadout → room-by-room runs → die → bank Soul Essence → improve the graveyard → go again.**

## The loop

### The Graveyard (hub, GDD §5)
You spawn in your graveyard. Walk with `WASD`, press `E` to interact:

- **Plots** — spend Soul Essence to restore Overgrown Plots, the Archer's Trench, and the Aristocrat's Mausoleum. Restored plots raise **Prestige** and attract more (and higher-tier) wanderers.
- **The Draft** — walk up to a wandering occupant and draft it (up to 3) as your free starting party.
- **Tome Pedestal** — cycle between the four Tomes (below).
- **Grimoire Lectern** — unlock pages with essence, equip them within your **Arcane Capacity** (grows with account level; pages matching your Tome cost 1 less).
- **The Iron Gate** — begin the run.

### The Run (GDD §3)
- **Aura of Command** — minions only obey inside it; outside they fall into **Lethargy** and crumble.
- **RTS control** — drag-select, right-click orders, `1-4` control groups, role formations.
- **Soul Bind** — hold `E` by a corpse to raise it. Party full? It goes to the Crypt. **Elite corpses cost a Soul Jar** and rise at Tier 2 (bosses Tier 3).
- **Desperation Mode** — lose your last minion and your Tome's desperation weapon is all that's left (`Space`).
- **Crypt screen** (`I`/`Tab`, and between rooms) — deploy/store minions, **Flesh-Stitch** duplicates into Tier+1 amalgams (inheriting both parents' grafts), and apply **Grafts** harvested from the dead.
- **Elites & Bosses** — elites from room 3, a boss every 5th room. They guarantee graft drops.
- **Death** — the only exit. Essence, EXP, and rooms cleared are banked to your profile.

### The Four Tomes (GDD §4)
| Tome | Passive | Aura | Desperation |
|---|---|---|---|
| **Stitcher's Almanac** | Party cap 2; +1 graft slot; stitched grafts +20% | Small; minions take 30% less damage | Scalpel: marks foes to take 3x from your next minion |
| **Rotting Ledger** | Party cap +3; minions rot each second | Massive; deaths inside leave toxic slowing clouds | Corpse-rats that gnaw and stun |
| **Sanguine Pact** | Double HP; Soul Bind costs blood, not speed; `Q` transfuses HP into minion healing | Standard circle | Rooted tether that siphons life back |
| **Bone-Carver's Codex** | Marrow shield regrows while standing still | Wide cone toward cursor; +30% attack speed inside | Huge spectral scythe with knockback |

## Controls

| Input | Action |
|-------|--------|
| `WASD` | Move (hub and run) |
| `E` | Interact (hub) / hold to Soul Bind (run) |
| Left-drag / click | Select minions |
| Right-click | Move / attack order |
| `1`–`4` (+`Ctrl`) | Control groups |
| `I` / `Tab` | Crypt: inventory, grafting, stitching, deploy/store |
| `Q` | Transfusion (Sanguine Pact only) |
| `Space` | Desperation weapon (when the last minion falls) |
| `Enter` | Return to the Graveyard after death |

## Running

Open the project in Godot 4.7 and press **F5** (main scene: `scenes/hub.tscn`).
Run `scenes/main.tscn` directly to skip the hub with a default loadout.

Headless self-test of the meta-loop logic:

```
godot --headless scenes/dev_selftest.tscn
```

## Architecture

| System | Where |
|---|---|
| `BaseEntity` (HP/damage/bleed/marks) | `scripts/base_entity.gd` |
| Player + Tome integration | `scripts/player.gd`, `scripts/tome_data.gd`, `scripts/tomes.gd` |
| Minions + instances (name/tier/grafts) | `scripts/minion.gd`, `scripts/minion_instance.gd` |
| Per-player Inventory (party/crypt/grafts, stitching) | `scripts/inventory.gd`, UI in `scripts/inventory_ui.gd` |
| Grafts registry + drops | `scripts/graft_item.gd`, `scripts/grafts.gd`, `scripts/graft_pickup.gd` |
| Grimoire pages + loadout | `scripts/grimoire_page.gd`, `scripts/grimoire.gd`, `scripts/grimoire_ui.gd` |
| Save/load (`PlayerProfileManager`) | `scripts/profile.gd` → `user://profile.json` |
| Hub ↔ run bridge | `scripts/run_state.gd` |
| The Graveyard hub | `scripts/hub.gd`, `scenes/hub.tscn` |
| Rooms, elites, bosses | `scripts/room.gd`, `scripts/enemy.gd` |

Everything is data-first and id-keyed (tomes, grafts, pages, minion instances serialize to dicts) with per-player, owner-tagged inventories — groundwork for the planned co-op multiplayer; no netcode yet.

## Not yet built

- Multiplayer netcode (architecture is per-player/serializable and ready for it).
- Meta-hub polish: mausoleum visuals, more plot types, graveyard decorations.
- More graft/page/tome content; balance passes.
