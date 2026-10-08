# Gravehold

A playable gothic dungeon and settlement game for modern Chrome. No production dependencies; Node.js 22+ runs the web server and account store.

## Run

The entire browser game—markup, styles, scripts, SVG art, and journal—is in `public/index.html`. Open that file directly in Chrome to play locally without installing anything. It has no external asset or font dependencies. Guest progress is saved in that browser.

For accounts and cross-device saves, serve the same file with the backend:

```sh
npm ci
npm start
```

Open the server on port 3000. Start by gathering wood and stone, construct a production building, then explore the dungeon tab. The journal introduces every screen on first use. Workers produce resources at full rate during active play and half rate while away, subject to storage caps.

## Included

- Timed manual gathering, production buildings, highlighted profession-specific worker hiring, and storage upgrades with increasing costs.
- Three generated dungeon choices, combat-simulation risk estimates, and automatic side-view battles centered on a large hero with small supporting troops behind them. Individual HP, attack animations, damage numbers, critical hits, and healing remain visible; the full combat log and loot details are expandable. Each dungeon has 15 waves, extraction at waves 5 and 10, and a final boss.
- Three supporting troop classes with reduced HP and damage, actions every other turn, modest healing, and a warrior defense bonus for the hero. The hero acts every turn and leads the front line. Recruits retain slow experience progression and paid revival. Ten hero equipment slots: head, cape, neck, weapon, body, shield, legs, hands, feet, and ring. New and reset saves start with all ten slots empty; existing owned gear is preserved. Gear adds attack, defense, HP, and higher-tier bonuses for critical hits, evasion, and life steal. Equipment drops only at cleared waves 5, 10, and 15: 8% chance on easy, 10% on medium, 12% on hard. Easy/medium/hard finds are tier 1/2/3. Extract to secure equipment, then equip it from Inventory; replaced equipment stays in the bag. Consumable blueprints and materials drop separately and are rare. Blueprints forge the next tier of an existing item; empty slots cannot be filled through crafting. Upgrades and tier forging cost substantial resources and scale upward.
- Streamlined loadout shows equipment slots, attack/defense/HP, and selected-item actions. Bonus stats and recipes expand on demand.
- Footer **Save settings** offers **Reset save…** with typed `RESET` confirmation. Reset clears gameplay progress, including a signed-in account’s server save, while retaining the account.
- Compact Inventory dialog in the top bar tracks secured iron, rivets, leather, essence, and blueprints. A visible expedition spoils panel shows gold, every material, blueprints, and highlighted gear finds. Secured rewards remain visible after extraction; defeat reports the lost run. Combat effects are cleared when each wave finishes. Existing two-slot saves migrate to the expanded loadout.
- Hero emergency loans, manual repayment, 1% simple interest per five expeditions, and five-minute recovery when an outstanding debt blocks borrowing.
- Local guest saves, email/password accounts with scrypt password hashing, server-side save storage, Google OAuth integration, contextual journal progress.

## Accounts and deployment

Deploy one Node process on a host with HTTPS and a persistent writable data volume. Set `NODE_ENV=production`, `PORT` as needed, and `DATA_DIR` to the mounted data directory. Accounts and saves reside in `users.json`; back it up securely. Cross-device access requires deploying this server at a shared URL. This environment's running development server is not a public deployment.

For Google sign-in, create a Google OAuth web application and supply `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, and `PUBLIC_URL` through the host's secure environment settings. Register `PUBLIC_URL/auth/google/callback` as the redirect URI. OAuth cannot be exercised until those credentials and the host are configured. Email/password works independently.

This is a first playable prototype. Save data and combat calculations are client-controlled; competitive or public release needs server-authoritative simulation and validation, request limits, email verification/password recovery, a database, and durable sessions. In-memory login sessions expire on server restart. Concurrent devices use last saved progress, rather than merging divergent expeditions. Battle sprites and settlement art are original SVG placeholders.

## Tests

```sh
npm ci
npx playwright install chromium
npm test
```

If Chromium is installed by the system, run `CHROMIUM_PATH=/usr/bin/chromium npm test` instead. The end-to-end test starts an isolated server and temporary account store and exercises gathering, building, hiring, equipment slots, bonuses, inventory, checkpoint extraction, responsive battle display, revival borrowing, and account loading from a second browser context. Economy and combat tests cover save migration, storage scaling, actual damage and healing, hero targeting and support cadence, risk-simulation isolation, reset confirmation/cancellation, and local/account reset persistence.

Each cloud task is already isolated: use this checkout directly; do not create a worktree unless requested.

## Scarcity tuning

- Gear: one roll per cleared five-wave milestone, with an 8%/10%/12% chance by difficulty. It is not awarded merely for reaching or losing at a milestone.
- Blueprints: 1.5%/2%/2.5% per cleared wave.
- Materials: easy-wave chances are iron 8%, rivets 6%, leather 5%, essence 2.5%. Each harder difficulty adds one percentage point. Successful rolls award one material.
- Upgrades: gold starts at `150 + 50 × tier` and rises with upgrade level; iron starts at `8 + 2 × tier` and also rises. Tier forging starts at 600 gold plus rare materials and a blueprint, with costs increasing by tier.
- First recruit: 500 wood, 400 stone, 450 food. Later recruits cost more. Storage expansion and worker production are needed before hiring.

These are initial balance values to tune through playtesting; tests verify the rules and persistence, not long-term economy pacing.

## Revival, active gathering, and duplicates

Each character tracks completed revivals. Gold costs increase by 35% per revival and food by 25%, rounded up. Hero loans use the current price, and both loan revivals and free recoveries advance the hero’s counter. Failed payments do not advance it.

Manual gathering still takes eight seconds. Its reward grows from 12 with gathering practice (a gradual square-root bonus), worker level, and storage upgrades. The promised amount is fixed when gathering starts and collection respects storage capacity.

Spare equipment can be salvaged in Inventory after confirmation. Duplicates are labeled; equipping or keeping them remains optional. Rarity is preserved when swapping or forging gear. Common/uncommon/rare/epic/legendary salvage returns 20/50/120/250/600 gold plus increasing quantities of iron, rivets, and essence. Equipped items cannot be salvaged. Harder dungeons have better rarity rolls; existing equipment receives a compatible rarity on migration.

## Information and long-term progression

Resource tooltips explain spending uses and worker production. The top bar shows amount/capacity, current nominal income, and full-storage status. Storage warns at 90%. Worker, storage, and equipment upgrades preview their effects. Camp Foreman requires all three workers plus 300 wood, 200 stone, and 250 food; it collects ready manual tasks, but does not start new ones.

Alive warriors grant +5% hero defense, archers +3 percentage points of critical chance, and healers +5 maximum HP. Three equipped tier-2 Gravewarden pieces grant +10% HP. Equipment rarity colors appear in slots, inventory, and loot alerts. Journal introductions can be disabled with “Don’t show tutorials again”; manual journal access remains.

Expedition history tracks total runs, best wave reached, bosses defeated, secured gold, and recent outcomes. New statistics cannot reconstruct rewards from older saves; existing run counts and the last known wave migrate. History survives prestige, but a full Reset Save clears it.

Dungeon choices can have Double Loot (twice quantities), Elite Enemies (+25% HP/attack), or Starting Damage (hero starts at 75% HP). The clear-chance simulation includes the modifier.

After defeating a boss in the current lifetime and clearing debt, prestige resets the adventure and grants `3 + 2 × bosses defeated this lifetime` prestige Grave Essence. Each prestige permanently grants +5% hero attack, HP, and worker income. Prestige essence is separate from crafting essence. Talent paths spend it on five sequential ranks: Warrior attack, Survivor HP, or Treasure Hunter loot value/drop chances (+5% per rank). Talents, essence, history, and tutorial preferences survive prestige.

Fully cleared routes unlock a queue of one or three offline expeditions. Each completes after five minutes, is resolved through combat simulation, and returns 50% rewards. A defeat requires revival and stops the queue. Gear and team changes are locked while away. Queue timestamps survive browser closure; completed runs settle on reopening, without a persistent server process. Like the rest of this prototype, queue validation is client-controlled and needs server authority before public competitive use.

Settlement and expedition progression are connected: staffed woodcutting, quarry,
and homestead sites grant the hero +1 attack, +1 defense, and +5 HP respectively.
Recruitment now requires a barracks, unlocked by staffing all three professions
and reaching dungeon wave five. Construction costs 700 wood, 600 stone, 400 food,
and 120 dungeon gold. First recruitment costs 900 wood, 750 stone, 800 food, and
150 gold; later companions cost more. Existing companions are preserved.
The redesigned crypt and armory use inline SVG art with no external assets.

Reward focus is chosen before entry: gold gives +60% gold, materials doubles
material drop chances and gives +50% blueprint chance, and equipment gives +75%
equipment chance at five-wave milestones. Balanced keeps normal drops. Focus
never changes enemy strength; saved cleared routes retain their focus for queues.
Settlement art responds to constructed sites, storage upgrades, workers, and troops.
Companions receive persistent names, +2 HP per level, +1 attack every fourth level,
and a modest level-five trait (warrior +1 personal defense, archer +2% personal crit,
healer +1 healing). Twenty survived expeditions earn a level. Growth previews
show the next benefit. New expedition reports track actual damage/healing and
final attackers, including queued runs. Historical saves retain their old rewards
without inventing unavailable combat reports. Secondary UI panels stay collapsed.

The centered armory shows up to five newest unhandled spare items. Equip,
confirmed salvage, or Dismiss removes a find from that list; Dismiss preserves
it in the collection. Merely selecting a slot does not handle its items. Older
unhandled finds fill freed spaces. Swapped-out equipment is already handled.
Slot selection reveals available equipment ranked by weighted net hero combat
benefit (including set and permanent bonuses), with rarity/tier breaking ties.
Comparisons display every changed combat stat; mixed tradeoffs remain visible.
Each equipment type has a custom inline icon with tier and rarity treatments.
