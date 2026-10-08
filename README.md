# Gravehold

A menu-based gothic dungeon and settlement game for Chrome. The complete playable game—UI, rules, pixel art, and journal—is in **`public/index.html`**. Current development focuses on the HTML game; the Godot project remains available separately.

## Play

Download the repository ZIP, extract it, then open **`public/index.html`** in Chrome. Guest progress saves automatically in that browser. No installation or account server is needed for local play.

For email/password accounts and cross-device saves:

```sh
npm ci
npm start
```

Open `http://localhost:3000`. Cross-device accounts require deploying the server to a shared HTTPS host with persistent storage. See [account/deployment documentation](docs/browser-prototype.md).

## Settlement projects and weapon collection

**Settlement → Settlement projects** now contains a three-phase infirmary restoration. Establish the barracks first, then fund each construction phase with farm supplies, gold, and dungeon materials. Phases take one, two, and three minutes; construction continues while away. Completed phases and committed resources persist across saves.

The finished infirmary provides **one free recovery bed with a saved recovery queue**. Admit a fallen hero or recruit from Settlement, Treasury, or Recruits; recovery takes **60 seconds**, including while away. Hero defeat automatically queues the fallen party with hero first. Treasury also offers **Queue all fallen**. Use the up/down controls to reorder waiting companions; the active patient keeps their progress. Each treatment takes a full minute, and elapsed time carries across patients while offline. Expeditions wait until the queue finishes. **Finish early** pays a fraction of the current scaled gold/food revival price, decreasing with time remaining. Revival counts still advance, existing debt remains payable, and instant gold/food revival remains an alternative when the bed is empty.

Weapons now drop from a six-item identity pool at the existing rare five-wave loot milestones:

| Style | Weapon | Tradeoff |
| --- | --- | --- |
| Balanced | Blade | Standard damage and attack cadence |
| Swift | Dirk | Lower damage, 35% faster attacks |
| Heavy | War maul | Higher damage, 25% slower attacks |
| Guardian | Guard spear | Lower damage, additional defense |
| Bloodbound | Blood sickle | Lower damage, modest life steal |
| Precise | Dueling sabre | Slightly lower damage, additional critical chance |

Each style has its own inline pixel icon and held weapon art. Attack speed changes actual combat actions and risk simulations. Identity stays with equipment through swaps, saves, upgrades, and blueprint forging. Rarity and overall drop chances remain unchanged. Different styles at the same tier are distinct items, with comparisons showing the stat tradeoffs. The Loadout's optional **Weapon collection** panel explains every style.

Existing browser saves migrate automatically; previous weapons retain the balanced blade identity. Fresh and reset games still begin without equipment. Prestige resets infirmary projects and weapon collection along with the adventure.

## Connected progression and combat readiness

- Click the **combat score info icon** in the top bar for a source breakdown and individual equipment/recruit details. The full-health score incorporates effective attack cadence, critical hits, defense, HP, evasion, life steal, set bonuses, worker support, prestige/combat talents, and living companions (including levels, healing and bonds). Solo objectives exclude recruits; a fallen hero has zero readiness. Dungeon cards show recommended scores for all 15 waves, adjusted for enemy strength and combat modifiers. These are rough recommendations; the existing simulation-based clear chance remains the more specific risk forecast.
- **Prepare recruit quarters** through three farm-supply milestones, then spend dungeon gold to hire. The summed wood, stone, food and gold cost matches the previous hiring total exactly; preparation replaces those farm costs. Each milestone saves independently; the settlement barracks shows three beds as occupied, being prepared, or available in future. Costs still scale for successive recruits. Existing companions are retained.
- **Pin an upgrade, forge, infirmary phase, or recruitment goal.** A shared have/need tracker and route recommendation follow you across tabs. Spare equipment can be tracked before equipping; its goal follows the item when equipped. Material tooltips explain dungeon sources and Materials reward focus. Disabled actions show requirements or exact missing resources.
- The compact **Blacksmith workshop** in Settlement and Loadout connects item inspection, upgrades, forging, goal tracking, and spare-item salvage. Base equipment services remain available; Varric's existing workshop unlock still grants its upgrade gold discount.
- Expedition reports highlight supplies now sufficient for a pinned goal, project, recruit or upgrade. Defeat reports connect recovery, supply gaps, defense/HP and easier routes.
- Weapon cadence now preserves the DPS contribution of base and other-slot attack instead of granting fast weapons a free multiplier on the whole loadout. Fast and heavy styles have similar unarmored sustained output; armor and overkill change their usefulness. Life steal uses actual fractional damage, without granting one whole HP for every tiny strike.

All systems remain inside the single HTML file. New queues, goals, preparation milestones, and item identities save with existing browser/account progress.

## Tests

```sh
npm ci
CHROMIUM_PATH=/usr/bin/chromium npm test
```

Tests cover the economy, real combat, timed projects, revival, identity preservation, equipment comparisons, offline saves, menu interactions, accounts, and mobile layout. Omit `CHROMIUM_PATH` when using Playwright's installed Chromium.

## Preserved Godot project

The Godot version is a separate earlier desktop prototype. Its walkable settlement is not part of this HTML update, and these new HTML systems have not been ported to it. See [Godot instructions](docs/godot-project.md) for its existing workflow.
