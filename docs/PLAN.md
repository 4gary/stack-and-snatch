# Build plan: design doc → code

Source: *Stack & Snatch: Game Design Write-Up* (Oct 3, 2026).
Agreed scope for build 1: **doc MVP (5.3) + full fairness set (4.4) + all 24
creatures + Muffin Meadows scooping + Bounce-Back Tickets**. Creatures and the
map are built from simple parts; delivered as a ready-to-open `.rbxlx`.

## What's in build 1

| Design doc | Build 1 | Where |
|---|---|---|
| **3.1 Map**: Sneeze Plaza, 8 base pads, conveyor loop, Muffin Meadows, Fizzy Shore | All built at runtime from parts. Shops ring the plaza; belt loops around it; meadow hills between plaza and pads; soda sea around the island | `server/Services/Map.luau` |
| **2.1 NPCs** (8) | All 8, each with a stall/podium, name tag and a job (shop, Index, tips, ribbons, emotes) | `Map.luau`, `client/Controllers/Prompts.luau` |
| **2.2 Roster** (24 creatures, 7 rarities, 6 shapes, traits) | All 24 with their stacking effects as rules (drape, ring, absorbers, top bonus, per-above bonus, adjacency, 3-layer height, alarm, confetti, dance) | `shared/Creatures.luau`, `Wobble.luau`, `Economy.luau`, `CreatureModel.luau` |
| **4.2 Stacking**: ghost preview, wobble meter, rules decide / animation shows, own topple loses nothing | Ghost swings in a figure-8 (server-time based, so the server can recompute the drop); jelly-bean bar; rules-based wobble score; physics only during the topple, then everyone hops back; the dropped creature lands on the ground | `shared/Wobble.luau`, `server/Services/Stacking.luau`, `Towers.luau`, `client/Controllers/Placement.luau`, `Animator.luau` |
| **4.3 Snatching**: top only, steady-hand minigame, topple on fail, carry slower with trail, owner/friend boop | All of it. Server checks every rule, sanity-checks the minigame timing, decides the result | `server/Services/Snatch.luau`, `client/Controllers/Minigames.luau` |
| **4.4 Fairness** | Arrival Bubble, Nap Mode, offline safety, owner/friends-only boop, shields can't be bypassed, no paid advantages, one snatcher at a time, Ruffled Feathers (90 s), Comfy Cushion, Fair Snatch Range, New Stacker Protection (20 min), Bounce-Back Ticket | `server/Services/Protection.luau`, `Snatch.luau` |
| **4.5 Progression** | Glue / Base / Shield shops, 5 levels each (coins only). Index with permanent +2%/creature bonus. Ribbons at 10/25/50/100 | `Shops.luau`, `Progress.luau`, `shared/Config.luau` |
| **4.6 Mutations** | Sprinkled, Glittery, Golden Toast; conveyor rolls + Sprinkle Rain weather | `shared/Mutations.luau`, `Conveyor.luau`, `Weather.luau`, `Stacking.luau` |
| **4.7 UI** | Coins + rate, timers, tower card, Fair Range, protection chips, server towers list, Shield/Boop buttons, bottom bar menus, accessibility (rarity shape badges, UI size, calm mode) | `client/Controllers/Hud.luau`, `client/Panels/*` |
| **4.8 Onboarding** | The 3-minute script: Professor → plate → conveyor → Sneaky Pete's practice tower (he topples it on purpose) → Lou's free shield upgrade → starter quests. Skippable | `server/Services/Onboarding.luau`, `client/Controllers/Dialog.luau` |
| **5.2 #2 Spawner** | Weighted rarity rolls; guaranteed Legendary (4 min) and Mythic (12 min) timers shown in the HUD; Captain Conveyor announces Rare+ | `Conveyor.luau` |
| **5.2 #8 Saving** | DataStore with session locking (UpdateAsync), unique creature ids, autosave, save on leave/shutdown, snatched-in-transit creatures come home | `server/Services/Data.luau`, `Plots.luau` |
| **5.2 #13 Anti-cheat basics** | Server decides spawns, prices, placement, snatch results, coins; distance checks; minigame timing checks; "perfect streak" logging | throughout |
| Social | Quick emotes (playable without chat), codes (coins only) | `Social.luau`, `Shops.luau` |
| Testing | Studio-only Dev panel (bots, coins, weather, protections...) | `server/Services/Dev.luau`, `client/Panels/Dev.luau` |

## Deliberately not in build 1 (later updates, per the doc)

- Gentle Gloves / Boop Glove upgrades, extra Comfy Cushions, Big Sneeze rebirth
- Levels 6–10 for the shops (just add rows in `Config.Upgrades`)
- More mutations (Upside-Down, Jelly, Bubbly, Tiny, Mega, Rainbow, Disco) and the Professor's Mixer
- Index page rewards, Big Wobble Weekend events, more weather types, new biomes
- Trading, group perks, leaderboards beyond the in-server board
- Monetization of any kind (doc: only after retention looks healthy)
- Analytics events
- Real 3D art, animations and sound design

## Design calls made while building (easy to change)

- **Placement skill**: the doc says "you choose where it goes; position matters".
  Build 1 makes that a timing skill: the ghost sways and you DROP when it's
  centered. Off-center drops add wobble and make the stack lean (the lean is
  visible and also adds wobble, so you can counter-balance).
- **Climbing pegs**: pressing Snatch hops you to the top in under a second
  instead of a climbing obstacle, to keep it quick and fair.
- **Coins are automatic** (no collecting from the jar) to keep the loop simple
  for young players. The jar is decoration.
- **Cushion creatures** earn their base rate without the height bonus.
- **Lord Jellington** (Secret) can appear on the belt at a tiny chance
  (0.01 weight) or via the Dev panel; events can hand it out later.
- **Topple threshold**: a tower topples when its wobble score passes 100 (+15
  with Waffle Walrus Jr. at the bottom). A careful stacker can reach ~54 Cuberts
  without glue; a sloppy zig-zag tops out around 15 (see `tests/rules.spec.luau`).

## Test checklist for the first Studio session

- [ ] Island, plaza, belt, meadows and 8 pads appear when pressing Play
- [ ] Tutorial: free Pancake Pup → DROP on plate → coins start
- [ ] Buying from the belt; carrying home; DROP; tower grows; "boop!" pitch rises
- [ ] Ghost swing + wobble bar match what happens (drop at the edge on a tall tower → topple → everyone hops back, creature on the ground → Pick up)
- [ ] Practice snatch minigame feels fair on mouse, touch (Studio device emulator) and gamepad
- [ ] Shield button, recharge timer, dome over the tower
- [ ] Muffin Meadows scoop
- [ ] Dev → Bot tower → real snatch → carry home → it's yours; Bounce-Back Ticket for the bot side
- [ ] 2-player test: snatch, owner boop sends it home, Ruffled Feathers, Fair Range messages
- [ ] Shops, Index silhouettes → discovered, ribbons at 10 tall, Sprinkle Rain mutation
- [ ] Leave and rejoin (published place with API access): tower, box, upgrades and Index are saved
