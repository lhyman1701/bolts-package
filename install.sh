#!/usr/bin/env bash
# install.sh — install bolts-package into a target project's .claude/ tree
#
# Usage:
#   /path/to/bolts-package/install.sh /path/to/target/project
#   # or, from inside bolts-package:
#   ./install.sh /path/to/target/project
#
# Idempotent — safe to re-run for upgrades.

set -euo pipefail

# Resolve where this script lives — that's the package source
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PKG_ROOT="$SCRIPT_DIR"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/target/project" >&2
  exit 2
fi

TARGET="$1"

if [[ ! -d "$TARGET" ]]; then
  echo "FAIL: target directory does not exist: $TARGET" >&2
  exit 2
fi

if [[ ! -d "$TARGET/.git" ]]; then
  echo "FAIL: target is not a git repository: $TARGET" >&2
  echo "      run 'cd $TARGET && git init' first" >&2
  exit 2
fi

echo "==> Installing bolts-package into: $TARGET"
echo "    package source: $PKG_ROOT"

# 1. Verify package integrity at source first
echo ""
echo "==> Verifying package integrity at source"
( cd "$PKG_ROOT/plans" && shasum -a 256 -c MANIFEST.sha256 )
echo "    ✓ source MANIFEST verified"

# 2. Plan files
mkdir -p "$TARGET/.claude/plans"
PLAN_FILES=(
  "2026-05-02-make-bolt-run-bolt-port-spec.md"
  "2026-05-02-make-bolt-KICKOFF-PROMPT.md"
  "2026-05-02-make-bolt-kg-research.md"
  "2026-05-02-make-bolt-hipaa-research.md"
  "2026-05-02-make-bolt-perfection-research.md"
  "bolt.config.yaml.example"
  ".mcp.json.example"
  "MANIFEST.sha256"
)
echo ""
echo "==> Copying plans/"
for f in "${PLAN_FILES[@]}"; do
  if [[ ! -f "$PKG_ROOT/plans/$f" ]]; then
    echo "FAIL: source missing: $PKG_ROOT/plans/$f" >&2
    exit 1
  fi
  cp "$PKG_ROOT/plans/$f" "$TARGET/.claude/plans/$f"
  echo "    ✓ .claude/plans/$f"
done

# 3. Anti-laziness rules + protocols
mkdir -p "$TARGET/.claude/rules" "$TARGET/.claude/protocols"
echo ""
echo "==> Copying rules/ + protocols/"
for f in accountability.md diagnostics.md completion-contracts.md plans-isolation.md; do
  if [[ -f "$PKG_ROOT/rules/$f" ]]; then
    cp "$PKG_ROOT/rules/$f" "$TARGET/.claude/rules/$f"
    echo "    ✓ .claude/rules/$f"
  fi
done
if [[ -f "$PKG_ROOT/protocols/no-blockers-mandatory.md" ]]; then
  cp "$PKG_ROOT/protocols/no-blockers-mandatory.md" "$TARGET/.claude/protocols/no-blockers-mandatory.md"
  echo "    ✓ .claude/protocols/no-blockers-mandatory.md"
fi

# 4. Reference (abstracted source-skill mechanics — no verbatim code)
mkdir -p "$TARGET/.claude/reference"
echo ""
echo "==> Copying reference/"
if [[ -f "$PKG_ROOT/reference/SOURCE-SKILL-MECHANICS.md" ]]; then
  cp "$PKG_ROOT/reference/SOURCE-SKILL-MECHANICS.md" \
     "$TARGET/.claude/reference/SOURCE-SKILL-MECHANICS.md"
  echo "    ✓ .claude/reference/SOURCE-SKILL-MECHANICS.md"
fi

# 5. .gitignore additions (idempotent)
GITIGNORE="$TARGET/.gitignore"
touch "$GITIGNORE"
echo ""
echo "==> Updating .gitignore"
for entry in ".claude/run-bolt-state/" ".bolt/" ; do
  if ! grep -qF "$entry" "$GITIGNORE"; then
    echo "$entry" >> "$GITIGNORE"
    echo "    ✓ added: $entry"
  else
    echo "    = already present: $entry"
  fi
done
# .claude/reference/ stays gitignored OR committed depending on user preference;
# default is to commit so the kickoff prompt can find it. Comment out next line if you want it ignored.
# echo ".claude/reference/" >> "$GITIGNORE"

# 6. Re-verify at destination
echo ""
echo "==> Verifying integrity at destination"
( cd "$TARGET/.claude/plans" && shasum -a 256 -c MANIFEST.sha256 )
echo "    ✓ destination MANIFEST verified"

# 7. Required-files check (mirrors kickoff prompt's pre-flight)
cd "$TARGET"
REQUIRED=(
  ".claude/plans/2026-05-02-make-bolt-run-bolt-port-spec.md"
  ".claude/plans/2026-05-02-make-bolt-KICKOFF-PROMPT.md"
  ".claude/plans/2026-05-02-make-bolt-kg-research.md"
  ".claude/plans/2026-05-02-make-bolt-hipaa-research.md"
  ".claude/plans/2026-05-02-make-bolt-perfection-research.md"
  ".claude/plans/bolt.config.yaml.example"
  ".claude/plans/.mcp.json.example"
  ".claude/plans/MANIFEST.sha256"
  ".claude/rules/accountability.md"
  ".claude/protocols/no-blockers-mandatory.md"
  ".claude/reference/SOURCE-SKILL-MECHANICS.md"
)
ALL_PRESENT=true
echo ""
echo "==> Required-files check"
for path in "${REQUIRED[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "    ✗ missing: $path"
    ALL_PRESENT=false
  fi
done

if $ALL_PRESENT; then
  echo ""
  echo "==> INSTALL COMPLETE — package ready for use"
  echo ""
  echo "Next steps:"
  echo "  1. cd $TARGET"
  echo "  2. git add .claude/ .gitignore"
  echo "  3. git commit -m 'chore: install bolts-package v1.0.0 (plan rev 2026-05-02)'"
  echo "  4. claude                    # open Claude Code"
  echo "  5. /model                    # select opus[1m]"
  echo "  6. /plan                     # enter plan mode"
  echo "  7. cat .claude/plans/2026-05-02-make-bolt-KICKOFF-PROMPT.md"
  echo "     # paste the ENTIRE ## Prompt section verbatim into the chat"
  echo ""
  exit 0
else
  echo ""
  echo "==> INSTALL INCOMPLETE — fix missing files above" >&2
  exit 1
fi
