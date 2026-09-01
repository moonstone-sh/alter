#!/usr/bin/env sh
set -eu

ballad_root=${BALLAD_ROOT:?Set BALLAD_ROOT to the checked-out Ballad source}
ballad_main="$ballad_root/src/main.lua"
lua_path="$ballad_root/src/?.lua;$ballad_root/src/?/init.lua;;"

for package_dir in host json-backend toml-backend jsonc-backend; do
  moon -C "$package_dir" sync --locked
  moon -C "$package_dir" exec env LUA_PATH="$lua_path" lua "$ballad_main" play partiture.lua
done
