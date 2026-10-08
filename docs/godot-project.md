# Gravehold

A native desktop gothic dungeon and settlement game, built with **Godot 4.6 and GDScript**. The game runs without Chrome or Node. The earlier browser prototype remains available as a migration reference.

## Play and develop

Install [Godot 4.6 standard](https://godotengine.org/download/) (the .NET edition is unnecessary). Import `godot/project.godot` in the project manager and press **F5**.

From this repository:

```sh
godot --editor --path godot   # open the editor
godot --path godot            # play directly
```

**The settlement is now a walkable top-down world.** Move with **WASD or arrow keys**, press **E** near a site, or **click a building** to walk there. Buildings block movement and click navigation routes around them. Visit the woodcutting camp, quarry, and homestead for timed gathering, construction, worker hiring, and storage. Visit the barracks for recruits, blacksmith for equipment, quartermaster for revival/debt, campfire for talents/prestige, and dungeon gate for expedition selection. Companions follow you around home.

Start with timed gathering, build production sites, and hire workers. Their income and bonuses support expeditions. Combat is automatic; choose your route and objectives, then extract at checkpoints or continue toward the boss. Journal introductions explain each screen. F11 toggles fullscreen. The settlement position saves automatically. Dungeon fights remain side-view automatic battles in this first world-interaction update.

## Native conversion

- All six screens use native Godot controls, with hover help, collapsible details, live resource income, and storage warnings.
- Pixel art battles show individual HP, attacks, healing, critical hits, and smaller supporting companions. Settlement buildings, workers, and rescued specialists appear at home.
- The centered ten-slot armory keeps recent finds on the left and ranked equipment for the selected slot on the right. Item art matches the hero. Equipment comparisons, salvage, upgrades, forging, and rarity colors remain available.
- The progression systems include settlement support, rare milestone loot, scaling recruit/revival costs, objectives, companion bonds, specialist services, debt, prestige, talents, and cleared-dungeon queues.
- Saves use atomic local JSON writes and a backup. Offline production stays at half rate and respects capacity. Active expeditions can resume from saves.

[Walkable settlement preview](images/native-settlement.png) · [Native battle preview](images/native-battle.png) · [Native loadout preview](images/native-loadout.png)

The runtime is GDScript. JavaScript remains only in the optional account service, legacy prototype, and development tools.

## Bring your existing save

Open the browser prototype and choose **Save settings → Export save for Godot**. In the native game, choose **Save settings → Import JSON…** and select that JSON file. Import replaces the currently loaded profile after confirmation. Gear, settlement, recruits, progression, and active combat migrate together. Native saves can also be exported as JSON.

Guest and account saves are separate. Native local files live in Godot's `user://` directory for **Gravehold**; Save settings provides import/export without requiring you to locate that directory.

## Optional accounts

```sh
npm ci
npm start
```

In the native **Account** dialog, use `http://127.0.0.1:3000` for local development or your deployed HTTPS server URL. Register or sign in with email/password. The server's saved progress loads on sign-in; local backups remain available when disconnected. Sessions remain in memory, and passwords are never written to native saves. Different devices need the same deployed server; saves use the latest uploaded state.

**Google sign-in is not implemented in the desktop client.** The existing browser OAuth flow needs a desktop handoff and configured Google credentials before it can be used natively. Email/password works independently.

See [the account server and browser documentation](browser-prototype.md) for deployment requirements and prototype security limitations.

## Desktop exports

Install the matching **4.6 export templates** through **Editor → Manage Export Templates**, then use **Project → Export**. Presets are supplied for Linux, Windows, and macOS. Create `builds/` before command-line exports:

```sh
mkdir -p builds
godot --headless --path godot --export-release Linux ../builds/gravehold.x86_64
godot --headless --path godot --export-release Windows ../builds/Gravehold.exe
godot --headless --path godot --export-release macOS ../builds/Gravehold.zip
```

The conversion has been tested with Godot **4.6.3** on Linux. Platform export binaries require the templates and are not committed to the repository. macOS distribution may also require signing/notarization.

## Verification

```sh
npm run test:native
```

Runs the native gameplay suite, real scene/control checks, settlement navigation and interactions, and email-account synchronization against a temporary server. Godot and Node 22+ must be on PATH. Set `GODOT_BIN` to select another engine executable. The gameplay suite compares formulas and save migration against browser fixtures.

The preserved browser suite runs separately:

```sh
CHROMIUM_PATH=/usr/bin/chromium npm test
```

## Project structure

| Path | Purpose |
| --- | --- |
| `godot/scripts/game_model.gd` | Gameplay rules, combat, progression, migration |
| `godot/scripts/main.gd` | Native screens and interactions |
| `godot/scripts/settlement_world.gd` | Settlement movement, navigation, collision, interactions, and rendering |
| `godot/scripts/world_view.gd` | Battle and settlement rendering |
| `godot/scripts/save_store.gd` | Atomic saves, backups, import/export |
| `godot/scripts/account_client.gd` | Optional HTTP account synchronization |
| `godot/assets/` | Original pixel art characters and equipment |
| `godot/tests/` | Native regression tests and browser parity fixtures |
| `public/index.html` | Preserved browser prototype and save exporter |
