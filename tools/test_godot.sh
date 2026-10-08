#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
engine="${GODOT_BIN:-godot}"
"$engine" --headless --path godot --editor --import --quit
"$engine" --headless --path godot --script res://tests/test_game.gd
"$engine" --headless --path godot --script res://tests/test_ui.gd -- --demo
"$engine" --headless --path godot --script res://tests/test_settlement.gd -- --demo
node tools/test_native_accounts.mjs
