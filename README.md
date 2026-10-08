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

The finished infirmary provides **one free recovery bed**. Admit a fallen hero or recruit from Settlement, Treasury, or Recruits; recovery takes **60 seconds**, including while away. Expeditions wait until the current patient finishes. Revival counts still advance, existing debt remains payable, and instant gold/food revival remains an alternative when the bed is empty.

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

## Tests

```sh
npm ci
CHROMIUM_PATH=/usr/bin/chromium npm test
```

Tests cover the economy, real combat, timed projects, revival, identity preservation, equipment comparisons, offline saves, menu interactions, accounts, and mobile layout. Omit `CHROMIUM_PATH` when using Playwright's installed Chromium.

## Preserved Godot project

The Godot version is a separate earlier desktop prototype. Its walkable settlement is not part of this HTML update, and these new HTML systems have not been ported to it. See [Godot instructions](docs/godot-project.md) for its existing workflow.
