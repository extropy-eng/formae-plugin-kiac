#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/kiac" <<'EOF'
#!/bin/sh
if [ "$1" = "get" ]; then
  cat <<'JSON'
[{"name":"sdk-test-abc12345"},{"name":"sdk-test-abc12345-replaced"},{"name":"keep-me"}]
JSON
else
  printf '%s\n' "$*" >> "$LOG"
fi
EOF
chmod +x "$tmp/kiac"

export PATH="$tmp:$PATH"
export LOG="$tmp/log"
export cluster_prefix="sdk-test-"

bash "$here/clean-environment.sh"

grep -q '^delete cluster --name sdk-test-abc12345$' "$LOG"
grep -q '^delete cluster --name sdk-test-abc12345-replaced$' "$LOG"
if grep -q 'keep-me' "$LOG"; then
  echo "deleted an unrelated cluster" >&2
  exit 1
fi

echo "ok"
