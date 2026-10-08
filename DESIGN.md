# Gravehold UI

The player's established dark gothic pixel-art brief is the visual authority. Screens use forest-black stone, worn brass, pale bone text and restrained green/red combat feedback. Cinzel headings and Barlow controls are embedded in the single HTML file; every icon and sprite is inline SVG. No external asset requests.

## Structure
Compact icon-and-label navigation, resource amounts/capacities/rates, accessible utility buttons, and a single short screen heading. Production cards expose gathering and hiring; settlement projects are collapsed. Three illustrated dungeon doors lead selection. Loadout remains recent finds left, enlarged Warden center, selected-slot equipment right, with upgrades below. Responsive layouts put the hero first.

## Battle
A full-width layered torchlit crypt, architectural depth and pixel-art combatants. The hero dominates; support troops remain behind and much smaller. HP meters and amounts belong to each unit. Attack, hit and floating-number effects follow real combat events and stop at checkpoints or cleared waves. Wave progress, checkpoint actions and a compact persistent loot strip remain readable.

## Information
Actions use short verbs. Costs, comparisons, income and missing requirements remain visible. Rules live in hover tips, the existing journal and collapsible panels. No gameplay, progression or save-system replacement.

## States and access
Keyboard focus, named icon buttons, health meters, reduced motion, all empty/disabled states and 390px mobile layouts are required. The CSS is a single coherent source, replacing the accumulated redesign overrides.
