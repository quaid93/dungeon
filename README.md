# Gravehold

A playable gothic dungeon and settlement game for modern Chrome. No production dependencies; Node.js 22+ runs the web server and account store.

## Run

```sh
npm ci
npm start
```

Open the server on port 3000. Start by gathering wood and stone, construct a production building, then explore the dungeon tab. The journal introduces every screen on first use. Workers produce resources at full rate during active play and half rate while away, subject to storage caps.

## Included

- Timed manual gathering, production buildings, hired workers with experience, and upgradeable storage.
- Three generated dungeon choices, loadout-based risk estimates, automatic side-view pixel battles, 15 waves, extraction at waves 5 and 10, final boss.
- Three troop classes, slow experience progression, paid revival, hero equipment, consumed blueprints, separate material drops, upgrades and tier crafting.
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

If Chromium is installed by the system, run `CHROMIUM_PATH=/usr/bin/chromium npm test` instead. The end-to-end test starts an isolated server and temporary account store and exercises gathering, building, hiring, crafting, upgrades, checkpoint extraction, revival borrowing, and account loading from a second browser context.

Each cloud task is already isolated: use this checkout directly; do not create a worktree unless requested.
