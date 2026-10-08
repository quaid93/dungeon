# Gravehold
<!-- impeccable:product-schema 1 -->

## Platform
Web. The playable game remains a single self-contained `public/index.html`, including graphics, styles, and scripts. It works offline in a browser; optional server accounts provide cross-device saves.

## Players and purpose
Players build a persistent settlement, gather and hire workers, improve a hero's scarce equipment, and watch automatic dungeon battles. One hero leads up to three much smaller companions. Farm resources support recruitment and recovery; dungeon rewards fund settlement projects and equipment progression.

## Confirmed commitments
The user's established direction is dark gothic pixel art, menu-based interaction, and a side-view battle with actual HP and combat events. Combat is automatic with no player abilities. There are three dungeon difficulties, 15 waves each, extraction every five waves, and a final boss. Preserve existing mechanics, balance, saves, and account flows.

## Current design request
Rewrite the UI with recognizable icons, neat organization, drastically better battle presentation, and less wording. Keep the hero centered in Loadout, recent finds on the left, and selected-slot equipment on the right. Keep crafting below the hero, revealed on slot selection. The game should feel playable rather than like reading a book.

## Stack
Inline HTML, CSS, JavaScript and SVG. Node server and Playwright tests already exist. No new framework or runtime dependencies required.

## Confirmed connected systems
Enemy guards, archers and healers; favored-material dungeon families; two paths at checkpoints; bounded weapon mastery with partial replacement transfer; a shared Storehouse preserving resource capacities; pre-entry recovery costs and debt-free waiting recovery. Maintain the existing compact gothic UI.
