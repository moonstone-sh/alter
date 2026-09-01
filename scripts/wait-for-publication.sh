#!/usr/bin/env sh
set -eu

descriptor_path=${1:?usage: wait-for-publication.sh <package.toml>}
registry_url=${MOONSTONE_REGISTRY_URL:-https://registry.moonstone.sh/registry/v0}
registry_url=${registry_url%/}
attempts=${MOONSTONE_PUBLICATION_ATTEMPTS:-90}
interval=${MOONSTONE_PUBLICATION_INTERVAL:-4}

package_name=$(awk '
  /^\[package\]$/ { in_package = 1; next }
  in_package && /^\[/ { exit }
  in_package && /^name = / { sub(/^name = "/, ""); sub(/"$/, ""); print; exit }
' "$descriptor_path")
package_version=$(awk '
  /^\[package\]$/ { in_package = 1; next }
  in_package && /^\[/ { exit }
  in_package && /^version = / { sub(/^version = "/, ""); sub(/"$/, ""); print; exit }
' "$descriptor_path")

test -n "$package_name" && test -n "$package_version" || {
  echo "error: $descriptor_path must contain [package] name and version" >&2
  exit 2
}

attempt=1
while [ "$attempt" -le "$attempts" ]; do
  index=$(mktemp)
  remote_descriptor=$(mktemp)
  if curl --fail --silent --show-error "$registry_url/index.toml" -o "$index" 2>/dev/null \
    && curl --fail --silent --show-error "$registry_url/packages/$package_name/$package_version/package.toml" -o "$remote_descriptor" 2>/dev/null \
    && grep -Fq "name = \"$package_name\"" "$index" \
    && grep -Fq "version = \"$package_version\"" "$remote_descriptor"; then
    rm -f "$index" "$remote_descriptor"
    echo "Published $package_name@$package_version is resolvable from $registry_url"
    exit 0
  fi
  rm -f "$index" "$remote_descriptor"
  test "$attempt" -lt "$attempts" || break
  echo "Waiting for $package_name@$package_version ($attempt/$attempts)..." >&2
  sleep "$interval"
  attempt=$((attempt + 1))
done

echo "error: $package_name@$package_version did not become resolvable from $registry_url" >&2
exit 1
