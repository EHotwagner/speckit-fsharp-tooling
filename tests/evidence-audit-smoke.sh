#!/usr/bin/env bash
#
# Smoke-test the evidence extension without requiring a full Speckit install.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_AUDIT="$ROOT/extensions/evidence/scripts/bash/run-audit.sh"
TASKS_TEMPLATE="$ROOT/presets/fsharp-opinionated/templates/tasks-template.md"
DEPS_TEMPLATE="$ROOT/presets/fsharp-opinionated/templates/tasks-deps-template.yml"

fail() {
  echo "evidence-audit-smoke: $*" >&2
  exit 1
}

assert_json() {
  local file="$1"
  local expr="$2"
  python3 - "$file" "$expr" <<'PY'
import json
import sys

path, expr = sys.argv[1], sys.argv[2]
data = json.load(open(path, encoding="utf-8"))
if not eval(expr, {"data": data}):
    raise SystemExit(f"assertion failed: {expr}")
PY
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cd "$WORK"
git init -q -b main
git config user.name "Evidence Smoke"
git config user.email "evidence-smoke@example.invalid"
mkdir -p specs/001-smoke/readiness src docs .specify
printf "baseline\n" > README.md
git add -A
git commit -qm "baseline"

git checkout -qb feature/evidence-smoke
cp "$TASKS_TEMPLATE" specs/001-smoke/tasks.md
cp "$DEPS_TEMPLATE" specs/001-smoke/tasks.deps.yml
perl -0pi -e 's/- \[ \] T011/- [S] T011/; s/- \[ \] T015/- [X] T015/' specs/001-smoke/tasks.md
cat > src/Feature.fs <<'EOF'
module Feature

let mockUser = 42
let banner = "SYNTHETIC: canned response"
EOF
cat > docs/notes.md <<'EOF'
TODO: documentation work marker is whitelisted for markdown.
EOF
git add -A
git commit -qm "feature with synthetic evidence"

set +e
"$RUN_AUDIT" specs/001-smoke --base main > audit.out 2> audit.err
AUDIT_EXIT=$?
set -e
[[ "$AUDIT_EXIT" -eq 2 ]] || fail "expected NEEDS-EVIDENCE exit 2, got $AUDIT_EXIT"

GRAPH_JSON="specs/001-smoke/readiness/task-graph.json"
HITS_JSON="specs/001-smoke/readiness/diff-scan-hits.json"

assert_json "$GRAPH_JSON" "any(t['id'] == 'T011' and t['effective'] == 'synthetic' for t in data['tasks'])"
assert_json "$GRAPH_JSON" "any(t['id'] == 'T015' and t['effective'] == 'auto-synthetic' and t['root_cause'] == ['T011'] for t in data['tasks'])"
assert_json "$HITS_JSON" "len(data['blocking']) == 1"
assert_json "$HITS_JSON" "data['blocking'][0]['pattern'] == 'mock-identifiers'"
assert_json "$HITS_JSON" "len(data['advisory']) == 1"
assert_json "$HITS_JSON" "data['advisory'][0]['pattern'] == 'synthetic-banner'"

cat > .specify/audit-patterns.overrides.yml <<'EOF'
severity_overrides:
  mock-identifiers: advisory
EOF
git add .specify/audit-patterns.overrides.yml
git commit -qm "downgrade mock identifiers for audit smoke"

set +e
"$RUN_AUDIT" specs/001-smoke --base main > audit-overrides.out 2> audit-overrides.err
OVERRIDE_EXIT=$?
set -e
[[ "$OVERRIDE_EXIT" -eq 2 ]] || fail "expected synthetic graph to keep exit 2, got $OVERRIDE_EXIT"
assert_json "$HITS_JSON" "len(data['blocking']) == 0"
assert_json "$HITS_JSON" "sorted(h['pattern'] for h in data['advisory']) == ['mock-identifiers', 'synthetic-banner']"

echo "evidence-audit-smoke: PASS"
