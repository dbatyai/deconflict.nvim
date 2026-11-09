#!/usr/bin/env bash
# Run the deconflict.nvim spec suite with a clean, minimal Neovim.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec nvim --headless --clean -u NONE -i NONE -l "$root/tests/run.lua" "$@"
