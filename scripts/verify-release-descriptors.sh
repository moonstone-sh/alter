#!/usr/bin/env sh
set -eu

expect_dependency() {
  descriptor=$1
  package_name=$2
  grep -A4 '^\[\[dependencies\]\]$' "$descriptor" | grep -Fq "name = \"$package_name\""
}

host=host/dist/registry/package.toml
json=json-backend/dist/registry/package.toml
toml=toml-backend/dist/registry/package.toml
jsonc=jsonc-backend/dist/registry/package.toml

for descriptor in "$host" "$json" "$toml" "$jsonc"; do
  test -f "$descriptor"
  ! grep -Fq 'resolver = "path"' "$descriptor"
  ! grep -Fq 'moonstone/ballad' "$descriptor"
  ! grep -Fq 'moonstone/valua' "$descriptor"
done

! grep -q '^\[\[dependencies\]\]$' "$host"
expect_dependency "$json" moonstone/alter
expect_dependency "$toml" moonstone/alter
expect_dependency "$jsonc" moonstone/alter
expect_dependency "$jsonc" moonstone/alter-json

echo "Alter release descriptors have the expected runtime dependency surface"
