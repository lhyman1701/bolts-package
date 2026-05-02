# Plan Isolation Rules (CRITICAL — Non-Negotiable)

## The Problem

`~/.claude/plans/` is a **GLOBAL** directory shared across ALL projects on this machine. Reading plans from there without verification leads to cross-project contamination.

**Incident:** On 2026-02-21, a session read a plan from `~/.claude/plans/` that belonged to CarEase (a different project) and incorrectly included it in the the project session summary.

## Rules

### Rule 1: NEVER Read Global Plans

```
❌ FORBIDDEN: Reading from ~/.claude/plans/
❌ FORBIDDEN: Assuming any file in ~/.claude/plans/ belongs to this project
❌ FORBIDDEN: Including content from ~/.claude/plans/ in session summaries
```

### Rule 2: ALWAYS Use Project-Local Plans

```
✅ REQUIRED: Store all plans in .claude/plans/
✅ REQUIRED: Read plans only from .claude/plans/
✅ REQUIRED: Plans are project-specific and tracked in git
```

### Rule 3: Plan Mode Enforcement

When entering plan mode:
1. Check if `.claude/plans/` exists
2. Create plan file in `.claude/plans/` NOT `~/.claude/plans/`
3. Use naming convention: `YYYY-MM-DD-<brief-description>.md`

### Rule 4: End-Session Plan Check

During end-session:
1. **DO** check `.claude/plans/` for recent plans
2. **DO NOT** check `~/.claude/plans/`
3. If you find yourself reading `~/.claude/plans/`, STOP immediately

## Verification Script

```bash
# List only project-local plans
ls -la .claude/plans/*.md 2>/dev/null

# NEVER run this during end-session:
# ls ~/.claude/plans/  # <-- WRONG - global directory
```

## Why This Exists

The global plans directory (`~/.claude/plans/`) is a Claude Code default that doesn't respect project boundaries. Until Claude Code supports project-specific plan paths natively, we enforce isolation through these rules.
