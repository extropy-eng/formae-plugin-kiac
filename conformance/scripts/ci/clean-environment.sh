#!/usr/bin/env bash

# Idempotent script called before AND after conformance tests
# to clean up test resources in the target deployment environment.
#
# Purpose:
# - Before tests: Remove orphaned resources from previous failed runs
# - After tests: Clean up resources created during the test run

set -o errexit
set -o nounset
set -o pipefail

# prefix used for test resources - should match what conformance tests create
cluster_prefix="${cluster_prefix:-sdk-test-}"

pattern="^${cluster_prefix}[0-9a-f]{8}(-replaced)?$"
cluster_filter="(. // [])[] | select(.name | test(\"${pattern}\")) | .name"

echo "Deleting clusters with prefix '${cluster_prefix}'"

kiac get clusters -o json \
  | jq --raw-output "$(echo "$cluster_filter")" \
  | while IFS= read -r cluster_name; do \
      kiac delete cluster --name "$cluster_name" 2> /dev/null || true; \
    done

echo "Cleanup complete"
