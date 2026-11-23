#!/bin/sh

#MISE hide=true

set -o errexit
set -o nounset

repo_root=$(cd "$(dirname "$0")/../../../.." && pwd)

cd "$repo_root"
mac_runner="${MAC_RUNNER_BIN:-mac-runner}"
sudo_cmd="${MACRUNNER_SUDO:-sudo}"
contextify="${MACRUNNER_CONTEXTIFY:-/run/current-system/sw/bin/macrunner-contextify}"

# gh prefers GH_TOKEN over the system-wide GITHUB_TOKEN, which lacks org admin scope
GH_TOKEN="$GH_ORG_TOKEN" "$mac_runner" apply \
  --file .github/mac-runner.yaml --yes

patched=0
"$sudo_cmd" -n -u _macrunner "$contextify" || patched=$?
case "$patched" in
  0) exit 0 ;;
  10) ;;
  *) exit "$patched" ;;
esac

"$mac_runner" list \
  | awk 'NR > 1 && $1 != "" { print $1 }' \
  | while IFS= read -r name; do
      "$mac_runner" stop "$name" || true
      "$mac_runner" start "$name"
    done
