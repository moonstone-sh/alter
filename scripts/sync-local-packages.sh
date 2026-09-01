#!/usr/bin/env sh
set -eu

# Backend manifests intentionally use live path dependencies during
# development. Resolve them for the current host before tests or the root
# locked orbit consume their environments.
for package_dir in host json-backend toml-backend jsonc-backend; do
  moon -C "$package_dir" sync
done
