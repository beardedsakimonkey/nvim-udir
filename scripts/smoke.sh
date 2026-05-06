#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

NVIM_LOG_FILE="${TMPDIR:-/tmp}/udir-nvim.log" \
nvim --headless -u NONE -i NONE --noplugin \
  -c "set rtp^=$PWD" \
  -c "runtime plugin/udir.lua" \
  -c "luafile scripts/smoke.lua" \
  -c "qa"
