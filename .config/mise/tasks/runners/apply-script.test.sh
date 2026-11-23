#!/bin/sh

#MISE hide=true

set -o errexit
set -o nounset

here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/mac-runner" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$MAC_RUNNER_LOG"
if [ "$1" = "list" ]; then
  printf '  NAME  TARGET\n  runner-a  org\n  runner-b  org\n'
fi
EOF
chmod +x "$tmp/mac-runner"

cat > "$tmp/sudo" <<'EOF'
#!/bin/sh
# drop -n -u _macrunner
shift 3
exec "$@"
EOF
chmod +x "$tmp/sudo"

cat > "$tmp/contextify" <<'EOF'
#!/bin/sh
exit "$CONTEXTIFY_EXIT"
EOF
chmod +x "$tmp/contextify"

export PATH="$tmp:$PATH"
export MAC_RUNNER_BIN="$tmp/mac-runner"
export MACRUNNER_SUDO="$tmp/sudo"
export MACRUNNER_CONTEXTIFY="$tmp/contextify"
export MAC_RUNNER_LOG="$tmp/log"
export GH_ORG_TOKEN="token"

: > "$tmp/log"
CONTEXTIFY_EXIT=0 "$here/apply-script.sh"
if grep -q '^stop ' "$tmp/log"; then
  echo "restarted runners on a no-op" >&2
  exit 1
fi

: > "$tmp/log"
CONTEXTIFY_EXIT=10 "$here/apply-script.sh"
grep -q 'stop runner-a' "$tmp/log"
grep -q 'start runner-a' "$tmp/log"
grep -q 'stop runner-b' "$tmp/log"
grep -q 'start runner-b' "$tmp/log"

: > "$tmp/log"
if CONTEXTIFY_EXIT=1 "$here/apply-script.sh"; then
  echo "expected contextify failure to stop the task" >&2
  exit 1
fi
if grep -q '^stop ' "$tmp/log"; then
  echo "restarted runners after a contextify failure" >&2
  exit 1
fi

echo "ok"
