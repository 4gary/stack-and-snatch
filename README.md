# Stack & Snatch

Catch silly creatures, stack them into a wobbly tower on your base, and watch the
Giggle Coins roll in. Other players can sneak over and pull a creature off the
top, but only with a steady hand, and if the tower topples everyone just
bounces back home.

This repo is the first playable build of the design doc *Stack & Snatch: Game
Design Write-Up* (Oct 2026). Scope: the doc's **MVP**, plus the full
**fairness set**, **all 24 creatures**, **Muffin Meadows** scooping and
**Bounce-Back Tickets**. See [`docs/PLAN.md`](docs/PLAN.md) for what's in and out.

---

## Open it in Roblox Studio (quickest)

1. Download **`StackAndSnatch.rbxlx`** from this repo.
2. In Roblox Studio, go to **File → Open from File...** and pick it.
3. Press **Play** (F5). The island is built when the game starts, so the
   Workspace is empty until you press Play.

Optional Studio settings:

| Setting | Where | Why |
|---|---|---|
| Max Players = **8** | Game Settings → Places (after publishing) | There are 8 base pads. |
| **Enable Studio Access to API Services** | Game Settings → Security (place must be published) | Turns on saving. Without it the game still runs, but progress isn't saved and the HUD shows "Not saving". |

### Or: live-sync with Rojo

If you'd rather edit the code in VS Code and have Studio update live:

```bash
# install Rojo 7.x (https://rojo.space) and its Studio plugin, then:
rojo serve
```

Then connect from the Rojo plugin in Studio. To rebuild the place file:

```bash
rojo build -o StackAndSnatch.rbxlx
```

---

## How to test

### Solo (Play / F5)

1. **Tutorial**: Professor Puddlewick hands you a Pancake Pup. Stand on your base
   pad and press **DROP** (or **Q**) when the swinging ghost is centered.
2. **Conveyor**: walk to the belt around the plaza, press **E** on a creature to
   buy it, carry it home and DROP it.
3. **Practice snatch**: go to Sneaky Pete's practice tower in the plaza, press
   **E** (hold briefly). In the minigame, **hold the mouse button and drag** to
   keep the dot inside the ring until the Steady bar fills.
4. **Shield**: press the big **Shield** button (or **G**).
5. **Muffin Meadows**: walk into the cake hills between the plaza and the base
   pads, press **E** on a wild creature, then tap **SCOOP!** when the marker is
   in the green.

The **🛠️ Dev** button (bottom bar, Studio only) has test tools: coins, give any
creature, fill your tower, **spawn a bot tower to snatch from**, start Sprinkle
Rain, put a Legendary on the belt, toggle your protections, reset your data.

### Snatching between two players

1. **Test** tab → **Clients and Servers** → **2 players** → **Start**.
2. New players are protected for 20 minutes (New Stacker), so in the window of
   the player being snatched from, open **🛠️ Dev → My protections ON/OFF**.
   That also lifts the Fair Snatch Range limit for testing.
3. Stack a few creatures on that player's tower. With the other player, walk to
   the pegs at the base of that tower (plaza side) and press **E**.
4. On success you carry the creature home (slower, with a glowing trail). The
   owner can press **Boop (F)** near you to send it back.
5. When you make it home, the owner gets a **Bounce-Back Ticket**: one revenge
   snatch on your tower that ignores your shield.

### Controls

| Action | Keyboard | Touch | Gamepad |
|---|---|---|---|
| Buy / Scoop / Snatch / Talk | E | tap the prompt | X |
| Drop held creature | Q or DROP button | DROP button | R1 |
| Bubble Shield | G | Shield button | L1 |
| Boop | F | Boop button | Y |
| Snatch minigame | hold mouse + drag | hold + drag thumb | hold R2/A + left stick |

---

## Project layout

```
default.project.json      Rojo project (what goes where in the place)
StackAndSnatch.rbxlx      built place file (open this in Studio)
src/shared/               ReplicatedStorage.Shared - used by server and client
  Config.luau             EVERY tunable number (prices, timers, wobble, shields...)
  Creatures.luau          the 24 Stackables (rarity, shape, rate, price, traits)
  Wobble.luau             stacking rules + the placement swing (pure functions)
  Economy.luau            coin rates, upgrades, Fair Snatch Range
  CreatureModel.luau      builds each creature out of simple parts
  ...
src/server/               ServerScriptService.Server
  Main.server.luau        starts every service
  Services/               Map, Data (saving), Plots, Towers, Stacking, Snatch,
                          Protection, Conveyor, Meadows, Shops, Weather,
                          Progress (Index/ribbons/quests), Onboarding, Dev...
src/client/               StarterPlayerScripts.Client
  Main.client.luau        starts every controller
  Controllers/            Hud, Placement, Minigames, Prompts, Animator, Effects...
  Panels/                 Shop, Index, Tower, Box, Emotes, Codes, Settings, Dev
tests/                    Luau unit tests for the pure rules (run outside Roblox)
docs/PLAN.md              how the design doc maps onto the code
```

### Balancing

Open `src/shared/Config.luau`. Prices, coin rates (in `Creatures.luau`), upgrade
costs, shield times, protection timers, conveyor odds, wobble rules and the
snatch minigame difficulty are all there.

### Tests

```bash
cd tests
npm install
npm test               # wobble rules, economy, formatting, roster checks
node compile.mjs       # compiles every .luau file with the real Luau compiler
```

---

## Placeholders to swap later

- **Art**: creatures, NPCs and the island are built from simple parts in code
  (`CreatureModel.luau`, `Map.luau`). Each creature has one recipe function, so
  it can be replaced with a real model one at a time.
- **Sounds**: built-in engine sounds stand in for the boops, boings and slide
  whistles. Paste Creator Store sound ids into `Config.Sounds` (there's a slot
  for background music too).
- **Monetization**: none, on purpose (doc 5.4: only after retention looks healthy).
