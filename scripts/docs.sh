#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

if [ "${1:-}" = "--check" ]; then
  export UDIR_DOCS_CHECK=1
  shift
fi

if [ "$#" -ne 0 ]; then
  echo "usage: sh scripts/docs.sh [--check]" >&2
  exit 2
fi

NVIM_LOG_FILE="${TMPDIR:-/tmp}/udir-nvim.log" \
nvim --headless -u NONE -i NONE --noplugin \
  -c "set rtp^=$PWD" \
  -c "luafile scripts/docs.lua" \
  -c "qa"
