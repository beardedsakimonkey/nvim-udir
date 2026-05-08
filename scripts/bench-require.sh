#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

if [ "$#" -ne 0 ]; then
  echo "usage: UDIR_BENCH_ITERS=1000 sh scripts/bench-require.sh" >&2
  exit 2
fi

NVIM_LOG_FILE="${TMPDIR:-/tmp}/udir-nvim.log" \
nvim --headless -u NONE -i NONE --noplugin \
  -c "set rtp^=$PWD" \
  -c "luafile scripts/bench-require.lua" \
  -c "qa"
